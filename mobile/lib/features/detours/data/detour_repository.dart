import 'package:cloud_firestore/cloud_firestore.dart';

import '../../elevation/data/elevation_repository.dart';
import '../domain/trail_detour.dart';

abstract interface class DetourRepository {
  Future<List<TrailDetour>> loadForTrail({required String trailId});

  Future<List<TrailDetourRoute>> loadRoutesForTrail({
    required String trailId,
    required List<TrailDetour> detours,
  });
}

class FirestoreDetourRepository implements DetourRepository {
  const FirestoreDetourRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  @override
  Future<List<TrailDetour>> loadForTrail({required String trailId}) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firebase is not configured for this build.');
    }
    final snapshot = await firestore
        .collection('trails')
        .doc(trailId)
        .collection('detours')
        .get();
    final detours = snapshot.docs
        .map(
          (document) => TrailDetour.fromFirestore(document.id, document.data()),
        )
        .toList(growable: false);
    detours.sort((left, right) {
      final leftPosition = left.startMainTrailDistanceKm ?? double.infinity;
      final rightPosition = right.startMainTrailDistanceKm ?? double.infinity;
      final positionComparison = leftPosition.compareTo(rightPosition);
      if (positionComparison != 0) return positionComparison;
      return left.name.compareTo(right.name);
    });
    return detours;
  }

  @override
  Future<List<TrailDetourRoute>> loadRoutesForTrail({
    required String trailId,
    required List<TrailDetour> detours,
  }) async {
    return Future.wait([
      for (final detour in detours)
        _loadRoute(trailId: trailId, detour: detour),
    ]);
  }

  Future<TrailDetourRoute> _loadRoute({
    required String trailId,
    required TrailDetour detour,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firebase is not configured for this build.');
    }
    final snapshot = await firestore
        .collection('trails')
        .doc(trailId)
        .collection('detours')
        .doc(detour.id)
        .collection('routeChunks')
        .orderBy('chunkIndex')
        .get();
    final points = expandRoutePointValues(
      snapshot.docs.map(
        (chunk) => (chunk.data()['points'] as List).cast<num>(),
      ),
      stride: detour.pointStride,
    );
    return TrailDetourRoute(detour: detour, points: points);
  }
}
