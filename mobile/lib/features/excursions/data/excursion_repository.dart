import 'package:cloud_firestore/cloud_firestore.dart';

import '../../elevation/data/elevation_repository.dart';
import '../domain/trail_excursion.dart';

abstract interface class ExcursionRepository {
  Future<List<TrailExcursion>> loadForTrail({required String trailId});

  Future<List<TrailExcursionRoute>> loadRoutesForTrail({
    required String trailId,
    required List<TrailExcursion> excursions,
  });
}

class FirestoreExcursionRepository implements ExcursionRepository {
  const FirestoreExcursionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  @override
  Future<List<TrailExcursion>> loadForTrail({required String trailId}) async {
    final snapshot = await _excursionsCollection(trailId).get();
    final excursions = snapshot.docs
        .map(
          (document) =>
              TrailExcursion.fromFirestore(document.id, document.data()),
        )
        .toList(growable: false);
    excursions.sort((left, right) {
      final leftPosition = left.mainTrailDistanceKm ?? double.infinity;
      final rightPosition = right.mainTrailDistanceKm ?? double.infinity;
      final positionComparison = leftPosition.compareTo(rightPosition);
      if (positionComparison != 0) return positionComparison;
      return left.displayName.compareTo(right.displayName);
    });
    return excursions;
  }

  @override
  Future<List<TrailExcursionRoute>> loadRoutesForTrail({
    required String trailId,
    required List<TrailExcursion> excursions,
  }) async {
    return Future.wait([
      for (final excursion in excursions)
        _loadRoute(trailId: trailId, excursion: excursion),
    ]);
  }

  Future<TrailExcursionRoute> _loadRoute({
    required String trailId,
    required TrailExcursion excursion,
  }) async {
    final snapshot = await _excursionsCollection(
      trailId,
    ).doc(excursion.id).collection('routeChunks').orderBy('chunkIndex').get();
    final points = expandRoutePointValues(
      snapshot.docs.map(
        (chunk) => (chunk.data()['points'] as List).cast<num>(),
      ),
      stride: excursion.pointStride,
    );
    return TrailExcursionRoute(excursion: excursion, points: points);
  }

  CollectionReference<Map<String, dynamic>> _excursionsCollection(
    String trailId,
  ) {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firebase is not configured for this build.');
    }
    return firestore.collection('trails').doc(trailId).collection('excursions');
  }
}
