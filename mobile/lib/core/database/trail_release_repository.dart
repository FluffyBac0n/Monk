import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../features/trails/presentation/selected_trail.dart';
import 'database_provider.dart';

import '../../features/elevation/domain/route_point.dart';
import '../../features/stages/domain/stage.dart';
import 'app_database.dart';

// Both controllers watch this exact snapshot, including when a refresh activates
// a new release. They cannot retain geometry and stages from different releases.
final publishedTrailReleaseProvider = FutureProvider<TrailReleaseData?>((
  ref,
) async {
  final id = ref.watch(selectedTrailIdProvider);
  if (!ref.watch(firebaseReadyProvider)) return null;
  try {
    return await TrailReleaseRepository(
      ref.watch(appDatabaseProvider),
      FirebaseFirestore.instance,
    ).sync(id);
  } catch (_) {
    return null;
  } // Existing complete offline data remains available.
});

class TrailReleaseData {
  const TrailReleaseData(this.releaseId, this.points, this.stages);
  final String releaseId;
  final List<RoutePoint> points;
  final List<TrailStage> stages;
}

/// Geometry and stage distances are validated and activated in one SQLite commit.
class TrailReleaseRepository {
  TrailReleaseRepository(this.database, this.firestore);
  final AppDatabase database;
  final FirebaseFirestore firestore;
  static final _pending = <String, Future<TrailReleaseData?>>{};

  Future<TrailReleaseData?> sync(String trailId) {
    final key =
        '${identityHashCode(database)}:${identityHashCode(firestore)}:$trailId';
    return _pending.putIfAbsent(
      key,
      () => _sync(trailId).whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  Future<TrailReleaseData?> _sync(String trailId) async {
    final trail = firestore.collection('trails').doc(trailId);
    final root = await trail.get(const GetOptions(source: Source.server));
    final releaseId = root.data()?['publishedReleaseId'] as String?;
    if (releaseId == null) {
      return null; // Legacy trails keep their existing readers.
    }
    final settings = await database.readSettings();
    if (settings['trailRelease:$trailId'] == releaseId) {
      final points = await database.readRoutePoints(trailId);
      final stages = await database.readStages(trailId);
      if (points.length >= 2 && stages.length >= 2) {
        return TrailReleaseData(releaseId, points, stages);
      }
    }
    final release = trail.collection('releases').doc(releaseId);
    final manifest = (await release.get(
      const GetOptions(source: Source.server),
    )).data();
    if (manifest == null || manifest['published'] != true) {
      throw const FormatException('Trail release is not published.');
    }
    final snapshots = await Future.wait([
      release
          .collection('routeChunks')
          .orderBy('chunkIndex')
          .get(const GetOptions(source: Source.server)),
      release
          .collection('stages')
          .orderBy('sequence', descending: true)
          .get(const GetOptions(source: Source.server)),
    ]);
    final chunks = snapshots[0].docs.map((d) => d.data()).toList();
    final stageRows = snapshots[1].docs;
    if (chunks.length != manifest['chunkCount'] ||
        stageRows.length != manifest['stageCount']) {
      throw const FormatException('Incomplete trail release.');
    }
    final points = decodeReleasePoints(manifest, chunks);
    final stages = stageRows
        .map((d) => TrailStage.fromFirestore(d.id, d.data()))
        .toList();
    if (stages.length < 2 ||
        stages.any(
          (s) =>
              s.accumulatedDistanceKm == null ||
              !s.accumulatedDistanceKm!.isFinite ||
              s.accumulatedDistanceKm! < 0 ||
              s.accumulatedDistanceKm! > points.last.distanceKm + 0.01,
        )) {
      throw const FormatException('Invalid release stages.');
    }
    await database.replaceTrailRelease(
      trailId,
      releaseId,
      points,
      stages,
      metadata: {
        'source': manifest['source'],
        'attribution': manifest['attribution'],
        'verifiedBy': manifest['verifyingOrganisationName'],
        'publishedAtMs':
            (manifest['publishedAt'] as Timestamp?)?.millisecondsSinceEpoch,
      },
    );
    return TrailReleaseData(releaseId, points, stages);
  }
}

List<RoutePoint> decodeReleasePoints(
  Map<String, dynamic> manifest,
  List<Map<String, dynamic>> chunks,
) {
  if (manifest['pointStride'] != 5 || chunks.length != manifest['chunkCount']) {
    throw const FormatException('Unsupported or incomplete release.');
  }
  final points = <RoutePoint>[];
  for (var i = 0; i < chunks.length; i++) {
    final chunk = chunks[i];
    final values = chunk['points'];
    if (chunk['chunkIndex'] != i ||
        chunk['startPointIndex'] != points.length ||
        values is! List ||
        values.length % 5 != 0) {
      throw const FormatException('Invalid release chunk order.');
    }
    for (var n = 0; n < values.length; n += 5) {
      final p = values.sublist(n, n + 5);
      if (p.any((v) => v is! num || !v.isFinite)) {
        throw const FormatException('Invalid release coordinate.');
      }
      final v = p.cast<num>();
      if (v[0].abs() > 90 ||
          v[1].abs() > 180 ||
          v[3] < 0 ||
          v[4] < 0 ||
          (points.isNotEmpty && v[3] < points.last.distanceKm)) {
        throw const FormatException('Invalid release distances.');
      }
      points.add(
        RoutePoint(
          pointIndex: points.length,
          lat: v[0].toDouble(),
          lng: v[1].toDouble(),
          altitudeM: v[2].toDouble(),
          distanceKm: v[3].toDouble(),
          reverseDistanceKm: v[4].toDouble(),
        ),
      );
    }
    if (chunk['endPointIndex'] != points.length - 1) {
      throw const FormatException('Incomplete release chunk.');
    }
  }
  if (points.length < 2 ||
      points.length != manifest['pointCount'] ||
      points.first.distanceKm.abs() > 0.001 ||
      points.last.reverseDistanceKm.abs() > 0.001 ||
      points.any(
        (p) =>
            (p.distanceKm + p.reverseDistanceKm - points.last.distanceKm)
                .abs() >
            0.001,
      )) {
    throw const FormatException('Incomplete release points.');
  }
  return points;
}
