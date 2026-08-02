import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../stages/presentation/stages_controller.dart';
import '../data/lodging_repository.dart';
import '../domain/lodging.dart';

final lodgingRepositoryProvider = Provider<LodgingRepository>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  return FirestoreLodgingRepository(
    firestore: firebaseReady ? FirebaseFirestore.instance : null,
  );
});

final lodgingsForTrailProvider = FutureProvider<List<Lodging>>((ref) {
  return ref
      .watch(lodgingRepositoryProvider)
      .loadForTrail(trailId: cyprusE4TrailId);
});

final lodgingsForStageProvider = FutureProvider.autoDispose
    .family<List<Lodging>, String>((ref, stageId) {
      return ref
          .watch(lodgingRepositoryProvider)
          .loadForStage(trailId: cyprusE4TrailId, stageId: stageId);
    });
