import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../elevation/domain/route_point.dart';
import '../data/offline_map_repository.dart';
import '../domain/offline_map_state.dart';

final offlineMapRepositoryProvider = Provider<OfflineMapRepository>(
  (ref) => OfflineMapRepository(),
);

final offlineMapProvider =
    AsyncNotifierProvider<OfflineMapController, OfflineMapState>(
      OfflineMapController.new,
    );

class OfflineMapController extends AsyncNotifier<OfflineMapState> {
  @override
  Future<OfflineMapState> build() {
    return ref.watch(offlineMapRepositoryProvider).readStatus();
  }

  Future<void> download(List<RoutePoint> points) async {
    if (state.value?.isDownloading == true) return;
    state = const AsyncData(
      OfflineMapState.downloading(progress: 0, completedBytes: 0),
    );
    try {
      final result = await ref
          .read(offlineMapRepositoryProvider)
          .download(
            points,
            onProgress: (progress, completedBytes) {
              state = AsyncData(
                OfflineMapState.downloading(
                  progress: progress,
                  completedBytes: completedBytes,
                ),
              );
            },
          );
      state = AsyncData(result);
    } catch (_) {
      final interrupted = state.value;
      state = AsyncData(
        OfflineMapState.failed(
          'The offline map could not be downloaded. Check your connection and try again.',
          failure: OfflineMapFailure.download,
          progress: interrupted?.progress ?? 0,
          completedBytes: interrupted?.completedBytes ?? 0,
        ),
      );
    }
  }

  Future<void> delete() async {
    if (state.value?.isDownloading == true) return;
    final previous = state.value;
    state = const AsyncLoading();
    try {
      await ref.read(offlineMapRepositoryProvider).delete();
      state = const AsyncData(OfflineMapState.notDownloaded());
    } catch (_) {
      state = AsyncData(
        OfflineMapState.failed(
          'The offline map could not be removed.',
          failure: OfflineMapFailure.removal,
          completedBytes: previous?.completedBytes ?? 0,
          downloadedAt: previous?.downloadedAt,
        ),
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(offlineMapRepositoryProvider).readStatus(),
    );
  }
}
