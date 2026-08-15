import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../elevation/presentation/elevation_controller.dart';
import 'stages_controller.dart';

const cyprusE4TrailDataUpdatedAtSetting = 'cyprusE4TrailDataUpdatedAtUtc';

final trailDataLastUpdatedProvider =
    AsyncNotifierProvider<TrailDataMetadataController, DateTime?>(
      TrailDataMetadataController.new,
    );

class TrailDataMetadataController extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() async {
    try {
      final settings = await ref.read(appDatabaseProvider).readSettings();
      return DateTime.tryParse(
        settings[cyprusE4TrailDataUpdatedAtSetting] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> markUpdated() async {
    final updatedAt = DateTime.now().toUtc();
    state = AsyncData(updatedAt);
    try {
      await ref
          .read(appDatabaseProvider)
          .writeSetting(
            cyprusE4TrailDataUpdatedAtSetting,
            updatedAt.toIso8601String(),
          );
    } catch (_) {
      // Keep the timestamp for this session if local metadata cannot be saved.
    }
  }

  Future<void> downloadTrailData() => _syncTrailData(refreshElevation: false);

  Future<void> refreshTrailData() => _syncTrailData(refreshElevation: true);

  Future<void> _syncTrailData({required bool refreshElevation}) async {
    await Future.wait<void>([
      ref.read(stagesProvider.notifier).sync(),
      _loadElevation(refreshExisting: refreshElevation),
    ]);
    final stages = ref.read(stagesProvider);
    final route = ref.read(elevationProvider);
    if (stages.hasValue &&
        stages.requireValue.isNotEmpty &&
        route.hasValue &&
        route.requireValue.isNotEmpty) {
      await markUpdated();
    }
  }

  Future<void> _loadElevation({required bool refreshExisting}) async {
    try {
      final existing = await ref.read(elevationProvider.future);
      if (!refreshExisting && existing.isNotEmpty) return;
    } catch (_) {
      // An explicit refresh below gets one more chance to load the route.
    }
    await ref.read(elevationProvider.notifier).refresh();
  }

  Future<void> clear() async {
    state = const AsyncData(null);
    try {
      await ref
          .read(appDatabaseProvider)
          .writeSetting(cyprusE4TrailDataUpdatedAtSetting, '');
    } catch (_) {
      // The cleared trail state remains authoritative for this session.
    }
  }
}
