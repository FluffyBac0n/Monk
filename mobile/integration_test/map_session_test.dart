import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:eurotrex/features/map/presentation/map_session.dart';
import 'package:eurotrex/features/map/presentation/map_background_sheet.dart';
import 'package:eurotrex/core/localization/app_localizations.dart';
import 'package:eurotrex/features/accommodation/domain/lodging.dart';
import 'package:eurotrex/features/accommodation/presentation/accommodation_controller.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/elevation/presentation/elevation_controller.dart';
import 'package:eurotrex/features/map/presentation/map_screen.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/stages/presentation/stages_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

const _hotel = Lodging(
  id: 'simulator-platres-hotel',
  name: 'Platres accommodation',
  type: 'Hotel',
  village: 'Pano Platres',
  distanceFromTrailKm: 2.4,
  location: LodgingLocation(latitude: 34.8877, longitude: 32.8610),
);

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
      id: 'platres',
      sequence: 1,
      name: 'Platres',
      services: {},
      accumulatedDistanceKm: 0,
    ),
    TrailStage(
      id: 'forest',
      sequence: 2,
      name: 'Forest',
      services: {},
      accumulatedDistanceKm: 2,
    ),
  ];
}

class _Gps extends geo.GeolocatorPlatform {
  final fixes = StreamController<geo.Position>.broadcast();
  geo.Position position(double latitude) => geo.Position(
    longitude: 32.867,
    latitude: latitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 1000,
    altitudeAccuracy: 2,
    heading: 0,
    headingAccuracy: 1,
    speed: 1,
    speedAccuracy: 1,
  );
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<geo.LocationPermission> checkPermission() async =>
      geo.LocationPermission.whileInUse;
  @override
  Future<geo.Position> getCurrentPosition({
    geo.LocationSettings? locationSettings,
  }) async => position(34.89);
  @override
  Stream<geo.Position> getPositionStream({
    geo.LocationSettings? locationSettings,
  }) => fixes.stream;
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (ready()) return;
  }
  fail('Map session did not finish loading');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'GPS preserves camera and layers; map navigation restores the session',
    (tester) async {
      MapboxOptions.setAccessToken(mapboxAccessToken);
      final oldGps = geo.GeolocatorPlatform.instance;
      final gps = _Gps();
      geo.GeolocatorPlatform.instance = gps;
      addTearDown(() async {
        geo.GeolocatorPlatform.instance = oldGps;
        await gps.fixes.close();
      });
      final container = ProviderContainer(
        overrides: [
          elevationProvider.overrideWith(_Elevation.new),
          stagesProvider.overrideWith(_Stages.new),
          lodgingsForTrailProvider.overrideWith((ref) async => [_hotel]),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(mapSessionProvider('cyprus-e4'));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigator,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MapScreen()),
                  ),
                  child: const Text('Open map'),
                ),
              ),
            ),
          ),
        ),
      );
      Future<MapboxMap> open() async {
        await tester.tap(find.text('Open map'));
        await _wait(tester, () => find.byType(MapWidget).evaluate().isNotEmpty);
        final dynamic native = tester.state(find.byType(MapWidget));
        await _wait(tester, () => native.mapboxMap != null);
        final map = native.mapboxMap as MapboxMap;
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          if (await map.style.isStyleLoaded()) break;
        }
        await tester.pump(const Duration(seconds: 2));
        return map;
      }

      var map = await open();
      await tester.tap(find.byKey(const ValueKey('map-poi-control')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-layer-stages')));
      await _wait(tester, () => session.stagesVisible);
      await tester.tap(find.byKey(const ValueKey('map-layer-accommodation')));
      await _wait(tester, () => session.lodgingsVisible);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-layers-control')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satellite'));
      await _wait(tester, () => session.background == MapBackground.satellite);
      await tester.pump(const Duration(seconds: 2));
      await map.setCamera(CameraOptions(zoom: 16.5, bearing: 28, pitch: 30));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('map-location-control')));
      await _wait(tester, () => session.gpsEnabled);
      await tester.pump(const Duration(seconds: 2));
      final located = await map.getCameraState();
      expect(located.zoom, closeTo(16.5, .01));
      expect(located.bearing, closeTo(28, .01));
      expect(located.pitch, closeTo(30, .01));
      for (final latitude in [34.891, 34.892, 34.893]) {
        gps.fixes.add(gps.position(latitude));
        await tester.pump(const Duration(seconds: 2));
        final next = await map.getCameraState();
        expect(next.zoom, closeTo(located.zoom, .01));
        expect(next.bearing, closeTo(located.bearing, .01));
        expect(next.pitch, closeTo(located.pitch, .01));
        expect(
          next.center.coordinates.lat,
          closeTo(located.center.coordinates.lat, .00001),
        );
        expect(await map.style.getStyleURI(), MapBackground.satellite.styleUri);
      }
      // WidgetTester cannot pan an iOS platform view. Send its gesture callback
      // and move the real native camera, then verify restoration on a new map.
      tester.widget<MapWidget>(find.byType(MapWidget)).onZoomListener!(
        MapContentGestureContext(
          touchPosition: ScreenCoordinate(x: 100, y: 100),
          point: Point(coordinates: Position(32.87, 34.895)),
          gestureState: GestureState.ended,
        ),
      );
      await map.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(32.872, 34.894)),
          zoom: 17.25,
          bearing: 41,
          pitch: 20,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final beforeLeaving = await map.getCameraState();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        gps.fixes.hasListener,
        isFalse,
        reason: 'Leaving the map releases GPS updates',
      );
      map = await open();
      await _wait(tester, () => gps.fixes.hasListener);
      await tester.pump(const Duration(seconds: 2));
      final returned = await map.getCameraState();
      expect(returned.zoom, closeTo(beforeLeaving.zoom, .01));
      expect(returned.bearing, closeTo(beforeLeaving.bearing, .01));
      expect(returned.pitch, closeTo(beforeLeaving.pitch, .01));
      expect(
        returned.center.coordinates.lat,
        closeTo(beforeLeaving.center.coordinates.lat, .00001),
      );
      expect(
        returned.center.coordinates.lng,
        closeTo(beforeLeaving.center.coordinates.lng, .00001),
      );
      expect(await map.style.getStyleURI(), MapBackground.satellite.styleUri);
      expect((await map.location.getSettings()).enabled, isTrue);
      await tester.tap(find.byKey(const ValueKey('map-poi-control')));
      await tester.pumpAndSettle();
      final dynamic stageRow = tester.widget(
        find.byKey(const ValueKey('map-layer-stages')),
      );
      final dynamic lodgingRow = tester.widget(
        find.byKey(const ValueKey('map-layer-accommodation')),
      );
      expect(stageRow.selected, isTrue);
      expect(lodgingRow.selected, isTrue);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-location-control')));
      await _wait(tester, () => !session.gpsEnabled);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      map = await open();
      expect((await map.location.getSettings()).enabled, isNot(true));
      expect(gps.fixes.hasListener, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
