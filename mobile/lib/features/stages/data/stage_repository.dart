import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../domain/stage.dart';

class FirebaseNotConfiguredException implements Exception {
  const FirebaseNotConfiguredException();
}

class StageRepository {
  StageRepository({required AppDatabase database, FirebaseFirestore? firestore})
    : _database = database,
      _firestore = firestore;

  final AppDatabase _database;
  final FirebaseFirestore? _firestore;

  Future<List<TrailStage>> loadLocal(String trailId) =>
      _database.readStages(trailId);

  Future<List<TrailStage>> sync(String trailId) async {
    final firestore = _firestore;
    if (firestore == null) throw const FirebaseNotConfiguredException();

    final snapshot = await firestore
        .collection('trails')
        .doc(trailId)
        .collection('stages')
        .orderBy('sequence', descending: true)
        .get();
    final stages = snapshot.docs
        .map((doc) => TrailStage.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
    await _database.replaceStages(trailId, stages);
    return stages;
  }
}
