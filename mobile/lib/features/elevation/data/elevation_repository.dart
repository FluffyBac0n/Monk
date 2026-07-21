import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../domain/route_point.dart';

class ElevationRepository {
  ElevationRepository({
    required AppDatabase database,
    FirebaseFirestore? firestore,
  }) : _database = database,
       _firestore = firestore;

  final AppDatabase _database;
  final FirebaseFirestore? _firestore;

  Future<List<RoutePoint>> loadLocal(String trailId) {
    return _database.readRoutePoints(trailId);
  }

  Future<List<RoutePoint>> sync(String trailId) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firebase is not configured for this build.');
    }

    final trail = firestore.collection('trails').doc(trailId);
    final results = await Future.wait([
      trail.collection('routeMetadata').doc('main').get(),
      trail.collection('routeChunks').orderBy('chunkIndex').get(),
    ]);
    final metadata = (results[0] as DocumentSnapshot<Map<String, dynamic>>)
        .data();
    if (metadata == null) throw StateError('Missing route metadata.');
    final stride = (metadata['pointStride'] as num?)?.toInt() ?? 5;
    if (stride < 5) {
      throw const FormatException('Route point stride must be at least 5.');
    }

    final chunks = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final points = expandRoutePointValues(
      chunks.docs.map((chunk) => (chunk.data()['points'] as List).cast<num>()),
      stride: stride,
    );
    await _database.replaceRoutePoints(trailId, points);
    return points;
  }
}

List<RoutePoint> expandRoutePointValues(
  Iterable<List<num>> chunks, {
  int stride = 5,
}) {
  if (stride < 5) {
    throw const FormatException('Route point stride must be at least 5.');
  }
  final points = <RoutePoint>[];
  var pointIndex = 0;
  for (final values in chunks) {
    if (values.length % stride != 0) {
      throw const FormatException('Invalid route chunk.');
    }
    for (var offset = 0; offset < values.length; offset += stride) {
      points.add(
        RoutePoint(
          pointIndex: pointIndex++,
          lat: values[offset].toDouble(),
          lng: values[offset + 1].toDouble(),
          altitudeM: values[offset + 2].toDouble(),
          distanceKm: values[offset + 3].toDouble(),
          reverseDistanceKm: values[offset + 4].toDouble(),
        ),
      );
    }
  }
  return points;
}
