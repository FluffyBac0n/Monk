import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/lodging.dart';

abstract interface class LodgingRepository {
  Future<List<Lodging>> loadForStage({
    required String trailId,
    required String stageId,
  });
}

class FirestoreLodgingRepository implements LodgingRepository {
  const FirestoreLodgingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  @override
  Future<List<Lodging>> loadForStage({
    required String trailId,
    required String stageId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firebase is not configured for this build.');
    }

    final snapshot = await firestore
        .collection('trails')
        .doc(trailId)
        .collection('lodgings')
        .where('stageId', isEqualTo: stageId)
        .get();

    return sortLodgingsForDisplay(
      snapshot.docs.map(
        (document) => Lodging.fromFirestore(document.id, document.data()),
      ),
    );
  }
}

List<Lodging> sortLodgingsForDisplay(Iterable<Lodging> lodgings) {
  final sorted = lodgings.toList(growable: false);
  sorted.sort((left, right) {
    final distanceComparison = _compareNullableDistances(
      left.distanceFromTrailKm,
      right.distanceFromTrailKm,
    );
    if (distanceComparison != 0) return distanceComparison;

    final nameComparison = (left.name ?? '').toLowerCase().compareTo(
      (right.name ?? '').toLowerCase(),
    );
    if (nameComparison != 0) return nameComparison;
    return left.id.compareTo(right.id);
  });
  return sorted;
}

int _compareNullableDistances(double? left, double? right) {
  if (left == null) return right == null ? 0 : 1;
  if (right == null) return -1;
  return left.compareTo(right);
}
