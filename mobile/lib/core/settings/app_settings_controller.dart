import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'app_settings.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    unawaited(_restore());
    return const AppSettings();
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(appDatabaseProvider).readSettings();
      final unit = stored['measurementSystem'];
      state = AppSettings(
        language: AppLanguage.fromCode(stored['language']),
        measurementSystem: unit == MeasurementSystem.imperial.name
            ? MeasurementSystem.imperial
            : MeasurementSystem.metric,
      );
    } catch (_) {
      // Tests and unsupported platforms may not expose the SQLite plugin.
    }
  }

  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
    unawaited(_writeSetting('language', language.code));
  }

  void setMeasurementSystem(MeasurementSystem measurementSystem) {
    state = state.copyWith(measurementSystem: measurementSystem);
    unawaited(_writeSetting('measurementSystem', measurementSystem.name));
  }

  Future<void> _writeSetting(String key, String value) async {
    try {
      await ref.read(appDatabaseProvider).writeSetting(key, value);
    } catch (_) {
      // Keep the in-memory choice if persistence is temporarily unavailable.
    }
  }
}
