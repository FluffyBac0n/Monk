import '../../../core/database/trail_release_repository.dart';
import '../../trails/presentation/selected_trail.dart';
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
    final release = await ref.watch(publishedTrailReleaseProvider.future);
    if (release != null) return release.stages;
    final localStages = await repository.loadLocal(
      ref.watch(selectedTrailIdProvider),
    );
    final needsDistanceFromPathBackfill =
        localStages.isNotEmpty &&
        localStages.every((stage) => stage.distanceFromPathKm == null);
    if (!needsDistanceFromPathBackfill) return localStages;

    if (localStages.isEmpty) return localStages;
    try {
      return await repository.sync(ref.watch(selectedTrailIdProvider));
    } on FirebaseNotConfiguredException {
      return localStages;
    } on FirebaseException {
      return localStages;
    }
  }

  Future<void> sync() async {
    if (ref.read(firebaseReadyProvider)) {
      ref.invalidate(publishedTrailReleaseProvider);
      final release = await ref.read(publishedTrailReleaseProvider.future);
      if (release != null) {
        state = AsyncData(release.stages);
        return;
      }
    }
    state = const AsyncLoading<List<TrailStage>>();
    state = await AsyncValue.guard(
      () => ref
          .read(stageRepositoryProvider)
          .sync(ref.read(selectedTrailIdProvider)),
    );
  }

  void clearOfflineState() {
    state = const AsyncData<List<TrailStage>>([]);
  }
}
