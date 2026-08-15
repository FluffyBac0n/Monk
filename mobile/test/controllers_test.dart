import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/core/database/database_provider.dart';
import 'package:eurotrex/core/legal/legal_consent.dart';
import 'package:eurotrex/core/legal/legal_consent_controller.dart';
import 'package:eurotrex/core/settings/app_settings.dart';
import 'package:eurotrex/core/settings/app_settings_controller.dart';
import 'package:eurotrex/features/elevation/data/elevation_repository.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/elevation/presentation/elevation_controller.dart';
import 'package:eurotrex/features/map/data/offline_map_repository.dart';
import 'package:eurotrex/features/map/domain/offline_map_state.dart';
import 'package:eurotrex/features/map/presentation/offline_map_controller.dart';
import 'package:eurotrex/features/stages/data/stage_repository.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/stages/presentation/stages_controller.dart';

void main() {
  group('StagesController', () {
    test(
      'keeps an empty offline library until download is requested',
      () async {
        final repository = _TestStageRepository(remote: const [_remoteStage]);
        final container = ProviderContainer(
          overrides: [stageRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        expect(await container.read(stagesProvider.future), isEmpty);
        expect(repository.syncCalls, 0);
      },
    );

    test('uses a complete offline copy without an unnecessary sync', () async {
      final repository = _TestStageRepository(
        local: const [_stageWithPathDistance],
        remote: const [_remoteStage],
      );
      final container = ProviderContainer(
        overrides: [stageRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final result = await container.read(stagesProvider.future);

      expect(result, const [_stageWithPathDistance]);
      expect(repository.loadCalls, 1);
      expect(repository.syncCalls, 0);
    });

    test('backfills a legacy offline copy missing trail distances', () async {
      final repository = _TestStageRepository(
        local: const [_legacyStage],
        remote: const [_remoteStage],
      );
      final container = ProviderContainer(
        overrides: [stageRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final result = await container.read(stagesProvider.future);

      expect(result, const [_remoteStage]);
      expect(repository.syncCalls, 1);
      expect(repository.lastTrailId, cyprusE4TrailId);
    });

    test('keeps a legacy copy when Firebase is unavailable', () async {
      for (final error in <Object>[
        const FirebaseNotConfiguredException(),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ]) {
        final repository = _TestStageRepository(
          local: const [_legacyStage],
          syncError: error,
        );
        final container = ProviderContainer(
          overrides: [stageRepositoryProvider.overrideWithValue(repository)],
        );

        expect(await container.read(stagesProvider.future), const [
          _legacyStage,
        ]);
        expect(repository.syncCalls, 1);
        container.dispose();
      }
    });

    test(
      'manual sync replaces state and exposes unexpected failures',
      () async {
        final repository = _TestStageRepository(
          local: const [_stageWithPathDistance],
          remote: const [_remoteStage],
        );
        final container = ProviderContainer(
          overrides: [stageRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        await container.read(stagesProvider.future);

        await container.read(stagesProvider.notifier).sync();
        expect(container.read(stagesProvider).value, const [_remoteStage]);

        repository.syncError = StateError('network failed');
        await container.read(stagesProvider.notifier).sync();
        expect(container.read(stagesProvider).hasError, isTrue);
      },
    );
  });

  group('ElevationController', () {
    test(
      'uses cached elevation and syncs only when the cache is empty',
      () async {
        final cachedRepository = _TestElevationRepository(
          local: const [_routeStart],
          remote: const [_routeFinish],
        );
        final cachedContainer = ProviderContainer(
          overrides: [
            elevationRepositoryProvider.overrideWithValue(cachedRepository),
          ],
        );

        expect(await cachedContainer.read(elevationProvider.future), const [
          _routeStart,
        ]);
        expect(cachedRepository.syncCalls, 0);
        cachedContainer.dispose();

        final emptyRepository = _TestElevationRepository(
          remote: const [_routeFinish],
        );
        final emptyContainer = ProviderContainer(
          overrides: [
            elevationRepositoryProvider.overrideWithValue(emptyRepository),
          ],
        );
        addTearDown(emptyContainer.dispose);

        expect(await emptyContainer.read(elevationProvider.future), const [
          _routeFinish,
        ]);
        expect(emptyRepository.syncCalls, 1);
        expect(emptyRepository.lastTrailId, cyprusE4TrailId);
      },
    );

    test('refresh replaces data and records repository failures', () async {
      final repository = _TestElevationRepository(
        local: const [_routeStart],
        remote: const [_routeFinish],
      );
      final container = ProviderContainer(
        overrides: [elevationRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(elevationProvider.future);

      await container.read(elevationProvider.notifier).refresh();
      expect(container.read(elevationProvider).value, const [_routeFinish]);

      repository.syncError = StateError('route unavailable');
      await container.read(elevationProvider.notifier).refresh();
      expect(container.read(elevationProvider).hasError, isTrue);
    });
  });

  group('AppSettingsController', () {
    test('restores language and measurement preferences', () async {
      final database = _SettingsDatabase({
        'language': 'fr',
        'measurementSystem': 'imperial',
      });
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      expect(container.read(appSettingsProvider), const AppSettings());
      await _flushAsyncWork();

      final restored = container.read(appSettingsProvider);
      expect(restored.language, AppLanguage.french);
      expect(restored.measurementSystem, MeasurementSystem.imperial);
    });

    test(
      'persists changes and keeps them in memory if persistence fails',
      () async {
        final database = _SettingsDatabase(const {});
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
        );
        addTearDown(container.dispose);
        container.read(appSettingsProvider);
        await _flushAsyncWork();

        final controller = container.read(appSettingsProvider.notifier);
        controller.setLanguage(AppLanguage.italian);
        controller.setMeasurementSystem(MeasurementSystem.imperial);
        await _flushAsyncWork();

        expect(database.writes, {
          'language': 'it',
          'measurementSystem': 'imperial',
        });
        database.throwOnWrite = true;
        controller.setLanguage(AppLanguage.german);
        await _flushAsyncWork();
        expect(
          container.read(appSettingsProvider).language,
          AppLanguage.german,
        );
      },
    );

    test('uses safe defaults when stored settings cannot be read', () async {
      final database = _SettingsDatabase(const {})..throwOnRead = true;
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await _flushAsyncWork();

      expect(container.read(appSettingsProvider), const AppSettings());
    });
  });

  group('LegalConsentController', () {
    test('persists decline and later one-time acceptance', () async {
      final database = _SettingsDatabase(const {});
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      expect(container.read(legalConsentProvider).isLoading, isTrue);
      await _flushAsyncWork();
      expect(
        container.read(legalConsentProvider).requiresInitialPrompt,
        isTrue,
      );

      final controller = container.read(legalConsentProvider.notifier);
      await controller.continueWithoutAccepting();
      expect(container.read(legalConsentProvider).promptSeen, isTrue);
      expect(container.read(legalConsentProvider).accepted, isFalse);
      expect(database.writes[legalTermsPromptSeenSetting], 'true');

      await controller.acceptTerms();
      final accepted = container.read(legalConsentProvider);
      expect(accepted.accepted, isTrue);
      expect(accepted.acceptedVersion, currentLegalTermsVersion);
      expect(accepted.acceptedAtUtc, isNotEmpty);
      expect(database.writes[legalTermsAcceptedSetting], 'true');
      expect(
        database.writes[legalTermsAcceptedVersionSetting],
        currentLegalTermsVersion,
      );

      final acceptedAt = accepted.acceptedAtUtc;
      await controller.continueWithoutAccepting();
      await controller.acceptTerms();
      expect(container.read(legalConsentProvider).accepted, isTrue);
      expect(container.read(legalConsentProvider).acceptedAtUtc, acceptedAt);
    });

    test('restores a previously accepted decision', () async {
      final database = _SettingsDatabase({
        legalTermsPromptSeenSetting: 'true',
        legalTermsAcceptedSetting: 'true',
        legalTermsAcceptedAtSetting: '2026-08-15T07:00:00.000Z',
        legalTermsAcceptedVersionSetting: currentLegalTermsVersion,
      });
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      container.read(legalConsentProvider);
      await _flushAsyncWork();

      final restored = container.read(legalConsentProvider);
      expect(restored.isLoading, isFalse);
      expect(restored.promptSeen, isTrue);
      expect(restored.accepted, isTrue);
      expect(restored.acceptedVersion, currentLegalTermsVersion);
    });
  });

  group('OfflineMapController', () {
    test('loads status and completes a download with progress', () async {
      final repository = _TestOfflineMapRepository(
        status: const OfflineMapState.notDownloaded(),
        downloadResult: const OfflineMapState.ready(completedBytes: 4096),
      );
      final container = ProviderContainer(
        overrides: [offlineMapRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(
        (await container.read(offlineMapProvider.future)).phase,
        OfflineMapPhase.notDownloaded,
      );
      await container.read(offlineMapProvider.notifier).download(const [
        _routeStart,
      ]);

      final state = container.read(offlineMapProvider).requireValue;
      expect(state.isReady, isTrue);
      expect(state.completedBytes, 4096);
      expect(repository.downloadCalls, 1);
      expect(repository.receivedPoints, const [_routeStart]);
    });

    test('ignores duplicate actions while a download is active', () async {
      final pending = Completer<OfflineMapState>();
      final repository = _TestOfflineMapRepository(
        status: const OfflineMapState.notDownloaded(),
        pendingDownload: pending,
      );
      final container = ProviderContainer(
        overrides: [offlineMapRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(offlineMapProvider.future);

      final controller = container.read(offlineMapProvider.notifier);
      final firstDownload = controller.download(const [_routeStart]);
      await _flushAsyncWork();
      expect(
        container.read(offlineMapProvider).requireValue.isDownloading,
        isTrue,
      );

      await controller.download(const [_routeStart]);
      await controller.delete();
      expect(repository.downloadCalls, 1);
      expect(repository.deleteCalls, 0);

      pending.complete(const OfflineMapState.ready(completedBytes: 1024));
      await firstDownload;
      expect(container.read(offlineMapProvider).requireValue.isReady, isTrue);
    });

    test('preserves interrupted progress when download fails', () async {
      final repository = _TestOfflineMapRepository(
        status: const OfflineMapState.notDownloaded(),
        downloadError: StateError('offline'),
      );
      final container = ProviderContainer(
        overrides: [offlineMapRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(offlineMapProvider.future);

      await container.read(offlineMapProvider.notifier).download(const [
        _routeStart,
      ]);

      final state = container.read(offlineMapProvider).requireValue;
      expect(state.failure, OfflineMapFailure.download);
      expect(state.progress, 0.42);
      expect(state.completedBytes, 2048);
    });

    test(
      'deletes downloads and preserves metadata on removal failure',
      () async {
        final downloadedAt = DateTime.utc(2026, 8, 1);
        final repository = _TestOfflineMapRepository(
          status: OfflineMapState.ready(
            completedBytes: 8192,
            downloadedAt: downloadedAt,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            offlineMapRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        await container.read(offlineMapProvider.future);

        repository.deleteError = StateError('locked');
        await container.read(offlineMapProvider.notifier).delete();
        final failed = container.read(offlineMapProvider).requireValue;
        expect(failed.failure, OfflineMapFailure.removal);
        expect(failed.completedBytes, 8192);
        expect(failed.downloadedAt, downloadedAt);

        repository.deleteError = null;
        await container.read(offlineMapProvider.notifier).delete();
        expect(
          container.read(offlineMapProvider).requireValue.phase,
          OfflineMapPhase.notDownloaded,
        );
      },
    );

    test('refresh updates status and exposes read failures', () async {
      final repository = _TestOfflineMapRepository(
        status: const OfflineMapState.notDownloaded(),
      );
      final container = ProviderContainer(
        overrides: [offlineMapRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(offlineMapProvider.future);

      repository.status = const OfflineMapState.ready(completedBytes: 200);
      await container.read(offlineMapProvider.notifier).refresh();
      expect(container.read(offlineMapProvider).requireValue.isReady, isTrue);

      repository.readError = StateError('status unavailable');
      await container.read(offlineMapProvider.notifier).refresh();
      expect(container.read(offlineMapProvider).hasError, isTrue);
    });
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _legacyStage = TrailStage(
  id: 'legacy',
  sequence: 1,
  name: 'Legacy',
  services: {},
);

const _stageWithPathDistance = TrailStage(
  id: 'cached',
  sequence: 1,
  name: 'Cached',
  distanceFromPathKm: 0.2,
  services: {},
);

const _remoteStage = TrailStage(
  id: 'remote',
  sequence: 1,
  name: 'Remote',
  distanceFromPathKm: 0.3,
  services: {},
);

const _routeStart = RoutePoint(
  pointIndex: 0,
  lat: 34.7,
  lng: 32.4,
  altitudeM: 10,
  distanceKm: 0,
  reverseDistanceKm: 10,
);

const _routeFinish = RoutePoint(
  pointIndex: 1,
  lat: 34.8,
  lng: 32.5,
  altitudeM: 20,
  distanceKm: 10,
  reverseDistanceKm: 0,
);

class _TestStageRepository extends StageRepository {
  _TestStageRepository({
    this.local = const [],
    this.remote = const [],
    this.syncError,
  }) : super(database: AppDatabase());

  final List<TrailStage> local;
  final List<TrailStage> remote;
  Object? syncError;
  int loadCalls = 0;
  int syncCalls = 0;
  String? lastTrailId;

  @override
  Future<List<TrailStage>> loadLocal(String trailId) async {
    loadCalls++;
    lastTrailId = trailId;
    return local;
  }

  @override
  Future<List<TrailStage>> sync(String trailId) async {
    syncCalls++;
    lastTrailId = trailId;
    if (syncError case final error?) throw error;
    return remote;
  }
}

class _TestElevationRepository extends ElevationRepository {
  _TestElevationRepository({this.local = const [], this.remote = const []})
    : super(database: AppDatabase());

  final List<RoutePoint> local;
  final List<RoutePoint> remote;
  Object? syncError;
  int syncCalls = 0;
  String? lastTrailId;

  @override
  Future<List<RoutePoint>> loadLocal(String trailId) async {
    lastTrailId = trailId;
    return local;
  }

  @override
  Future<List<RoutePoint>> sync(String trailId) async {
    syncCalls++;
    lastTrailId = trailId;
    if (syncError case final error?) throw error;
    return remote;
  }
}

class _SettingsDatabase extends AppDatabase {
  _SettingsDatabase(this.stored);

  final Map<String, String> stored;
  final Map<String, String> writes = {};
  bool throwOnRead = false;
  bool throwOnWrite = false;

  @override
  Future<Map<String, String>> readSettings() async {
    if (throwOnRead) throw StateError('read unavailable');
    return Map.of(stored);
  }

  @override
  Future<void> writeSetting(String key, String value) async {
    if (throwOnWrite) throw StateError('write unavailable');
    writes[key] = value;
  }
}

class _TestOfflineMapRepository extends OfflineMapRepository {
  _TestOfflineMapRepository({
    required this.status,
    this.downloadResult,
    this.pendingDownload,
    this.downloadError,
  });

  OfflineMapState status;
  final OfflineMapState? downloadResult;
  final Completer<OfflineMapState>? pendingDownload;
  final Object? downloadError;
  Object? readError;
  Object? deleteError;
  int downloadCalls = 0;
  int deleteCalls = 0;
  List<RoutePoint>? receivedPoints;

  @override
  Future<OfflineMapState> readStatus() async {
    if (readError case final error?) throw error;
    return status;
  }

  @override
  Future<OfflineMapState> download(
    List<RoutePoint> points, {
    required OfflineProgressCallback onProgress,
  }) async {
    downloadCalls++;
    receivedPoints = points;
    onProgress(0.42, 2048);
    if (downloadError case final error?) throw error;
    if (pendingDownload case final pending?) return pending.future;
    return downloadResult ?? status;
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    if (deleteError case final error?) throw error;
  }
}
