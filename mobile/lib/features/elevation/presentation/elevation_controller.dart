import '../../../core/database/trail_release_repository.dart';
import '../../trails/presentation/selected_trail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/database/database_provider.dart';
import '../data/elevation_repository.dart';
import '../domain/route_point.dart';

final elevationRepositoryProvider = Provider<ElevationRepository>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  return ElevationRepository(
    database: ref.watch(appDatabaseProvider),
    firestore: firebaseReady ? FirebaseFirestore.instance : null,
  );
});

final elevationProvider =
    AsyncNotifierProvider<ElevationController, List<RoutePoint>>(
      ElevationController.new,
    );

class ElevationController extends AsyncNotifier<List<RoutePoint>> {
  @override
  Future<List<RoutePoint>> build() async {
    final repository = ref.watch(elevationRepositoryProvider);
    final release = await ref.watch(publishedTrailReleaseProvider.future);
    if (release != null) return release.points;
    final local = await repository.loadLocal(
      ref.watch(selectedTrailIdProvider),
    );
    if (local.isNotEmpty) return local;
    return repository.sync(ref.watch(selectedTrailIdProvider));
  }

  Future<void> refresh() async {
    if (ref.read(firebaseReadyProvider)) {
      ref.invalidate(publishedTrailReleaseProvider);
      final release = await ref.read(publishedTrailReleaseProvider.future);
      if (release != null) {
        state = AsyncData(release.points);
        return;
      }
    }
    state = const AsyncLoading<List<RoutePoint>>();
    state = await AsyncValue.guard(
      () => ref
          .read(elevationRepositoryProvider)
          .sync(ref.read(selectedTrailIdProvider)),
    );
  }

  void clearOfflineState() {
    state = const AsyncData<List<RoutePoint>>([]);
  }
}
