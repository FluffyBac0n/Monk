import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/app.dart';
import 'package:monk_mobile/core/settings/app_settings.dart';
import 'package:monk_mobile/core/settings/app_settings_controller.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/elevation/presentation/elevation_controller.dart';
import 'package:monk_mobile/features/elevation/presentation/elevation_screen.dart';
import 'package:monk_mobile/features/map/presentation/map_screen.dart';
import 'package:monk_mobile/features/map/domain/offline_map_state.dart';
import 'package:monk_mobile/features/map/presentation/offline_map_controller.dart';
import 'package:monk_mobile/features/stages/domain/stage.dart';
import 'package:monk_mobile/features/stages/presentation/stages_controller.dart';
import 'package:monk_mobile/features/stages/presentation/stages_screen.dart';

void main() {
  testWidgets('shows the trail library and opens Cyprus E4', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MonkApp()));
    await tester.pumpAndSettle();

    expect(find.text('Explore trails'), findsOneWidget);
    expect(find.text('Cyprus E4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('explore-cyprus-e4')));
    await tester.pumpAndSettle();
    expect(find.text('Take the trail offline'), findsOneWidget);
    expect(find.text('Download trail'), findsWidgets);
  });

  testWidgets('stage detail presents route metrics and services', (
    tester,
  ) async {
    const stage = TrailStage(
      id: '124-pafos-airport',
      sequence: 124,
      name: 'Pafos Airport',
      accumulatedDistanceKm: 0,
      segmentLengthKm: 6.3,
      altitudeM: 2,
      services: {'lodging': true, 'drinkableWater': true, 'busStop': true},
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StageDetailScreen(stages: [stage], initialIndex: 0),
        ),
      ),
    );

    expect(find.text('Pafos Airport'), findsOneWidget);
    expect(find.text('6.3 km'), findsOneWidget);
    expect(find.text('Drinking water'), findsOneWidget);
    expect(find.text('Available offline'), findsOneWidget);
  });

  testWidgets('stage detail shortcut returns past the map to stages', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'stage-one',
      sequence: 1,
      name: 'Stage one',
      accumulatedDistanceKm: 10,
      services: {},
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (rootContext) => Scaffold(
              body: TextButton(
                key: const Key('open-map-route'),
                onPressed: () => Navigator.of(rootContext).push(
                  MaterialPageRoute<void>(
                    builder: (mapContext) => Scaffold(
                      body: TextButton(
                        key: const Key('open-stage-from-map'),
                        onPressed: () => Navigator.of(mapContext).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const StageDetailScreen(
                              stages: [stage],
                              initialIndex: 0,
                            ),
                          ),
                        ),
                        child: const Text('Map screen'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Stages screen'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-map-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-stage-from-map')));
    await tester.pumpAndSettle();
    expect(find.text('Stage one'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stage-detail-stages-shortcut')));
    await tester.pumpAndSettle();
    expect(find.text('Stages screen'), findsOneWidget);
    expect(find.text('Map screen'), findsNothing);
  });

  testWidgets('stages can reverse the shared trail direction', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stagesProvider.overrideWith(_FakeStagesController.new)],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pafos Airport  →  Larnaka Airport'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reverse-trail-direction')));
    await tester.pumpAndSettle();
    expect(find.text('Larnaka Airport  →  Pafos Airport'), findsOneWidget);
  });

  testWidgets('dashboard filters stages by selected services', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stagesProvider.overrideWith(_FakeStagesController.new)],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Filter by services'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('service-filter-lodging')));
    await tester.tap(find.byKey(const Key('apply-service-filters')));
    await tester.pumpAndSettle();
    expect(find.text('No stages match these services.'), findsOneWidget);

    final clearFilters = find.byKey(const Key('clear-service-filters'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(clearFilters);
    await tester.pumpAndSettle();
    expect(find.text('No stages match these services.'), findsNothing);
  });

  testWidgets('stage controls jump to the end and back to the top', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stagesProvider.overrideWith(_ManyStagesController.new)],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    final controller = scrollView.controller!;
    expect(controller.offset, 0);

    await tester.tap(find.byKey(const Key('stage-scroll-end')));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, controller.position.maxScrollExtent);

    await tester.tap(find.byKey(const Key('stage-scroll-top')));
    await tester.pumpAndSettle();
    expect(controller.offset, controller.position.minScrollExtent);
  });

  testWidgets('settings change language and measurement system app-wide', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stagesProvider.overrideWith(_FakeStagesController.new),
          appSettingsProvider.overrideWith(_FakeAppSettingsController.new),
          offlineMapProvider.overrideWith(_FakeOfflineMapController.new),
        ],
        child: const MonkApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Metric'), findsOneWidget);
    expect(
      find.byKey(const Key('settings-delete-offline-maps')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settings-delete-offline-maps')));
    await tester.pumpAndSettle();
    expect(find.text('Delete offline maps?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-offline-maps')));
    await tester.pumpAndSettle();
    expect(find.text('No offline maps downloaded.'), findsOneWidget);

    await tester.tap(find.text('Imperial'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('347 mi'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Maßeinheiten'), findsOneWidget);
  });

  testWidgets('elevation stage markers can be shown and hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          elevationProvider.overrideWith(_FakeElevationController.new),
          stagesProvider.overrideWith(_FakeStagesController.new),
        ],
        child: const MaterialApp(home: ElevationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.transformationConfig.scaleAxis, FlScaleAxis.horizontal);
    expect(chart.transformationConfig.maxScale, 15);
    final transformationController =
        chart.transformationConfig.transformationController!;
    final chartCenter = tester.getCenter(find.byType(LineChart));
    final leftFinger = await tester.startGesture(
      chartCenter - const Offset(20, 0),
      pointer: 1,
    );
    final rightFinger = await tester.startGesture(
      chartCenter + const Offset(20, 0),
      pointer: 2,
    );
    await leftFinger.moveTo(chartCenter - const Offset(70, 0));
    await rightFinger.moveTo(chartCenter + const Offset(70, 0));
    await tester.pump();
    await leftFinger.up();
    await rightFinger.up();
    expect(transformationController.value.storage[0], greaterThan(1));

    await tester.tap(find.byKey(const Key('elevation-reset-view')));
    await tester.pump();
    expect(transformationController.value.storage[0], 1);

    await tester.tap(find.byKey(const Key('elevation-zoom-in')));
    await tester.pump();
    final translationBeforePan = transformationController.value.storage[12];
    await tester.drag(find.byType(LineChart), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(
      transformationController.value.storage[12],
      isNot(translationBeforePan),
    );
    await tester.tap(find.byKey(const Key('elevation-reset-view')));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('elevation-stage-toggle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('elevation-stage-toggle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('map explains how to supply a missing Mapbox token', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MapScreen(accessToken: '')),
      ),
    );

    expect(find.text('Connect Mapbox'), findsOneWidget);
    expect(find.text('--dart-define=MAPBOX_ACCESS_TOKEN=pk…'), findsOneWidget);
  });
}

class _FakeElevationController extends ElevationController {
  @override
  Future<List<RoutePoint>> build() async => const [
    RoutePoint(
      pointIndex: 0,
      lat: 34.7,
      lng: 32.4,
      altitudeM: 2,
      distanceKm: 0,
      reverseDistanceKm: 10,
    ),
    RoutePoint(
      pointIndex: 1,
      lat: 34.8,
      lng: 32.5,
      altitudeM: 100,
      distanceKm: 10,
      reverseDistanceKm: 0,
    ),
  ];
}

class _FakeStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: '124-pafos-airport',
      sequence: 124,
      name: 'Pafos Airport',
      accumulatedDistanceKm: 0,
      altitudeM: 2,
      services: {},
    ),
  ];
}

class _ManyStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => List.generate(
    30,
    (index) => TrailStage(
      id: 'stage-$index',
      sequence: 30 - index,
      name: 'Stage place $index',
      accumulatedDistanceKm: index * 10,
      altitudeM: index * 20,
      services: const {},
    ),
  );
}

class _FakeAppSettingsController extends AppSettingsController {
  @override
  AppSettings build() => const AppSettings();

  @override
  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
  }

  @override
  void setMeasurementSystem(MeasurementSystem measurementSystem) {
    state = state.copyWith(measurementSystem: measurementSystem);
  }
}

class _FakeOfflineMapController extends OfflineMapController {
  @override
  Future<OfflineMapState> build() async =>
      const OfflineMapState.ready(completedBytes: 1024 * 1024);

  @override
  Future<void> delete() async {
    state = const AsyncData(OfflineMapState.notDownloaded());
  }
}
