import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/database/database_provider.dart';
import '../data/stage_repository.dart';
import '../domain/stage.dart';

const cyprusE4TrailId = 'cyprus-e4';

final stageRepositoryProvider = Provider<StageRepository>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  return StageRepository(
    database: ref.watch(appDatabaseProvider),
    firestore: firebaseReady ? FirebaseFirestore.instance : null,
  );
});

final stagesProvider =
    AsyncNotifierProvider<StagesController, List<TrailStage>>(
      StagesController.new,
    );

class StagesController extends AsyncNotifier<List<TrailStage>> {
  @override
  Future<List<TrailStage>> build() async {
    final repository = ref.watch(stageRepositoryProvider);
    final localStages = await repository.loadLocal(cyprusE4TrailId);
    final needsDistanceFromPathBackfill =
        localStages.isNotEmpty &&
        localStages.every((stage) => stage.distanceFromPathKm == null);
    if (!needsDistanceFromPathBackfill) return localStages;

    try {
      return await repository.sync(cyprusE4TrailId);
    } on FirebaseNotConfiguredException {
      return localStages;
    } on FirebaseException {
      return localStages;
    }
  }

  Future<void> sync() async {
    state = const AsyncLoading<List<TrailStage>>();
    state = await AsyncValue.guard(
      () => ref.read(stageRepositoryProvider).sync(cyprusE4TrailId),
    );
  }

  void clearOfflineState() {
    state = const AsyncData<List<TrailStage>>([]);
  }
}
