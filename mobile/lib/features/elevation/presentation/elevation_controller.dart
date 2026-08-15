import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/database/database_provider.dart';
import '../../stages/presentation/stages_controller.dart';
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
    final local = await repository.loadLocal(cyprusE4TrailId);
    if (local.isNotEmpty) return local;
    return repository.sync(cyprusE4TrailId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<RoutePoint>>();
    state = await AsyncValue.guard(
      () => ref.read(elevationRepositoryProvider).sync(cyprusE4TrailId),
    );
  }

  void clearOfflineState() {
    state = const AsyncData<List<RoutePoint>>([]);
  }
}
