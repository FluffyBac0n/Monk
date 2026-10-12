import 'dart:async';
import 'package:eurotrex/features/reports/data/trail_issues.dart';
import 'package:eurotrex/features/reports/domain/trail_issue.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/elevation/presentation/elevation_controller.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/stages/presentation/stages_controller.dart';
import 'package:eurotrex/features/map/presentation/map_screen.dart';
import 'package:eurotrex/features/map/presentation/map_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

class _Elevation extends ElevationController {
  @override
  Future<List<RoutePoint>> build() async => const [
    RoutePoint(
      pointIndex: 0,
      lat: 34.884,
      lng: 32.864,
      altitudeM: 1000,
      distanceKm: 0,
      reverseDistanceKm: 2,
    ),
    RoutePoint(
      pointIndex: 1,
      lat: 34.895,
      lng: 32.87,
      altitudeM: 1100,
      distanceKm: 2,
      reverseDistanceKm: 0,
    ),
  ];
}

class _Stages extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: 'start',
      sequence: 3,
      name: 'Start',
      services: {},
      accumulatedDistanceKm: 0,
    ),
    TrailStage(
      id: 'middle',
      sequence: 2,
      name: 'Middle',
      services: {},
      accumulatedDistanceKm: 1,
    ),
    TrailStage(
      id: 'finish',
      sequence: 1,
      name: 'Finish',
      services: {},
      accumulatedDistanceKm: 2,
    ),
  ];
}

Future<void> waitFor(
  WidgetTester tester,
  FutureOr<bool> Function() ready,
) async {
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (await ready()) return;
  }
  fail('Map did not reach the expected state');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'approved issue appears and disappears on resolution without moving camera',
    (tester) async {
      MapboxOptions.setAccessToken(mapboxAccessToken);
      final updates = StreamController<List<TrailIssue>>();
      addTearDown(updates.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapSessionProvider(
              'cyprus-e4',
            ).overrideWith((ref) => MapSession()..stagesVisible = true),
            elevationProvider.overrideWith(_Elevation.new),
            stagesProvider.overrideWith(_Stages.new),
            trailIssuesProvider(
              'cyprus-e4',
            ).overrideWith((ref) => updates.stream),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      updates.add([]);
      await waitFor(tester, () => find.byType(MapWidget).evaluate().isNotEmpty);
      final dynamic native = tester.state(find.byType(MapWidget));
      await waitFor(tester, () => native.mapboxMap != null);
      final map = native.mapboxMap as MapboxMap;
      await waitFor(tester, () => map.style.isStyleLoaded());
      await tester.pump(const Duration(seconds: 2));
      const issue = TrailIssue(
        id: 'approved',
        trailId: 'cyprus-e4',
        category: 'signpost',
        description: 'Broken sign at the junction.',
        passability: 'difficult',
        latitude: 34.89,
        longitude: 32.867,
      );
      final point = Point(
        coordinates: Position(issue.longitude, issue.latitude),
      );
      await map.setCamera(CameraOptions(center: point, zoom: 14, bearing: 20));
      await tester.pump(const Duration(seconds: 1));
      final before = await map.getCameraState();
      updates.add([issue]);
      Future<List<String>> issueLayers() async =>
          (await map.style.getStyleLayers())
              .where((l) => l?.id.contains('eurotrex-official-issues') == true)
              .map((l) => l!.id)
              .toList();
      await waitFor(tester, () async => (await issueLayers()).isNotEmpty);
      await tester.pump(const Duration(seconds: 1));
      final size = tester.getSize(find.byType(MapWidget));
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(x: 0, y: 0),
            max: ScreenCoordinate(x: size.width, y: size.height),
          ),
        ),
        RenderedQueryOptions(layerIds: await issueLayers()),
      );
      expect(features.whereType<QueriedRenderedFeature>(), isNotEmpty);
      // WidgetTester cannot deliver a tap into iOS platform views. Enable this
      // branch for a real simulator tap through Device Hub during visual QA.
      if (const bool.fromEnvironment('MANUAL_NATIVE_TAP')) {
        for (
          var i = 0;
          i < 480 && find.text(issue.description).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.text(issue.description), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      }
      updates.add([]);
      await waitFor(tester, () async => (await issueLayers()).isEmpty);
      await tester.pumpAndSettle();
      expect(find.text(issue.description), findsNothing);
      final after = await map.getCameraState();
      expect(after.zoom, closeTo(before.zoom, 0.001));
      expect(after.bearing, closeTo(before.bearing, 0.001));
      expect(
        after.center.coordinates.lat,
        closeTo(before.center.coordinates.lat, 0.000001),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
