import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/saved_route.dart';

const savedRoutesSettingKey = 'savedRoutesV1';

class SavedRouteRepository {
  const SavedRouteRepository(this._database);

  final AppDatabase _database;

  Future<List<SavedRoute>> load() async {
    try {
      final settings = await _database.readSettings();
      final encoded = settings[savedRoutesSettingKey];
      if (encoded == null || encoded.isEmpty) return const [];
      final values = jsonDecode(encoded) as List<Object?>;
      final routes = <SavedRoute>[];
      for (final value in values) {
        try {
          routes.add(
            SavedRoute.fromJson(
              Map<String, Object?>.from(value! as Map<Object?, Object?>),
            ),
          );
        } catch (_) {
          // Ignore a malformed saved route while preserving the other routes.
        }
      }
      routes.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return List.unmodifiable(routes);
    } catch (_) {
      return const [];
    }
  }

  Future<List<SavedRoute>> save(SavedRoute route) async {
    final routes = (await load()).toList();
    final index = routes.indexWhere((item) => item.id == route.id);
    if (index < 0) {
      routes.insert(0, route);
    } else {
      routes[index] = route;
    }
    await _write(routes);
    return List.unmodifiable(routes);
  }

  Future<List<SavedRoute>> delete(String routeId) async {
    final routes = (await load())
        .where((route) => route.id != routeId)
        .toList(growable: false);
    await _write(routes);
    return List.unmodifiable(routes);
  }

  Future<void> _write(List<SavedRoute> routes) => _database.writeSetting(
    savedRoutesSettingKey,
    jsonEncode([for (final route in routes) route.toJson()]),
  );
}
