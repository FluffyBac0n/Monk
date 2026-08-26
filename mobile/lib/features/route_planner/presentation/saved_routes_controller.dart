import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/saved_route_repository.dart';
import '../domain/saved_route.dart';

final savedRouteRepositoryProvider = Provider<SavedRouteRepository>((ref) {
  return SavedRouteRepository(ref.watch(appDatabaseProvider));
});

final savedRoutesProvider =
    AsyncNotifierProvider<SavedRoutesController, List<SavedRoute>>(
      SavedRoutesController.new,
    );

class SavedRoutesController extends AsyncNotifier<List<SavedRoute>> {
  @override
  Future<List<SavedRoute>> build() {
    return ref.watch(savedRouteRepositoryProvider).load();
  }

  Future<void> save(SavedRoute route) async {
    final routes = await ref.read(savedRouteRepositoryProvider).save(route);
    state = AsyncData(routes);
  }

  Future<void> delete(String routeId) async {
    final routes = await ref.read(savedRouteRepositoryProvider).delete(routeId);
    state = AsyncData(routes);
  }
}
