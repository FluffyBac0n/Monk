import 'package:eurotrex/core/localization/app_localizations.dart';
import 'package:eurotrex/features/accommodation/domain/lodging.dart';
import 'package:eurotrex/features/accommodation/presentation/accommodation_controller.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/elevation/presentation/elevation_controller.dart';
import 'package:eurotrex/features/map/data/poi_directions_service.dart';
import 'package:eurotrex/features/map/domain/poi_directions.dart';
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

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  await tester.pump();
  for (var i = 0; i < 180; i++) {
    if (ready()) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('Timed out waiting for directions UI');
}

Future<List<Map<String?, Object?>>> _nativeRouteFeatures(
  MapboxMap map,
  Size size,
) async {
  final layers = await map.style.getStyleLayers();
  final ids = layers
      .where((layer) => layer?.id.contains('eurotrex-poi-directions') == true)
      .map((layer) => layer!.id)
      .toList();
  expect(ids, isNotEmpty, reason: 'The native directions layer must exist');
  final features = await map.queryRenderedFeatures(
    RenderedQueryGeometry.fromScreenBox(
      ScreenBox(
        min: ScreenCoordinate(x: 0, y: 0),
        max: ScreenCoordinate(x: size.width, y: size.height),
      ),
    ),
    RenderedQueryOptions(layerIds: ids),
  );
  // Rendered queries may return fragments of the same annotation in several
  // map tiles. Count unique routes rather than tile fragments.
  final unique = <Object?, Map<String?, Object?>>{};
  for (final feature in features) {
    if (feature == null) continue;
    final value = feature.queriedFeature.feature;
    unique.putIfAbsent(value['id'], () => value);
  }
  return unique.values.toList();
}

Future<double> _expandWithDrag(WidgetTester tester, bool useStage) async {
  final card = find.byType(DraggableScrollableSheet);
  final compactHeight = tester.getSize(card).height;
  final drag = await tester.startGesture(
    tester.getCenter(find.text(useStage ? 'Platres' : 'Platres accommodation')),
  );
  await drag.moveBy(const Offset(0, -20));
  await tester.pump();
  await drag.moveBy(const Offset(0, -120));
  await tester.pump();
  await tester.pump();
  await drag.moveBy(const Offset(0, -80));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  final expandedHeight = tester.getSize(card).height;
  expect(expandedHeight, greaterThan(compactHeight + 150));
  await drag.up();
  await tester.pumpAndSettle();
  expect(tester.getSize(card).height, closeTo(expandedHeight, 1));
  return expandedHeight;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final controlsOnly in [true, false]) {
    for (final useStage in [false, true]) {
      testWidgets(
        '${controlsOnly ? 'Map controls' : 'Directions'} / ${useStage ? 'Stage' : 'Accommodation'}: ${controlsOnly ? 'centering and draggable cards' : 'native GPS, walking/driving routes, clear and error states'}',
        (tester) async {
          expect(
            mapboxAccessToken.isNotEmpty,
            true,
            reason: 'Launch with the local environment define file',
          );
          MapboxOptions.setAccessToken(mapboxAccessToken);
          var online = true;
          var denyPermission = false;
          final nativeService = PoiDirectionsService(
            accessToken: mapboxAccessToken,
          );
          final service = PoiDirectionsService(
            accessToken: mapboxAccessToken,
            locate: () async {
              if (controlsOnly) {
                return (latitude: 34.8900, longitude: 32.8700);
              }
              if (denyPermission) {
                throw const DirectionsException(
                  DirectionsFailure.permissionDenied,
                );
              }
              // Uses the real Geolocator plugin and the simulator's seeded GPS fix.
              return nativeService.locate();
            },
            isOnline: () async => !controlsOnly && online,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                elevationProvider.overrideWith(_Elevation.new),
                stagesProvider.overrideWith(_Stages.new),
                lodgingsForTrailProvider.overrideWith((ref) async => [_hotel]),
                poiDirectionsServiceProvider(
                  mapboxAccessToken,
                ).overrideWithValue(service),
              ],
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: useStage
                    ? MapScreen(initialStageIndex: 0)
                    : MapScreen(initialLodging: _hotel),
              ),
            ),
          );
          await _waitFor(
            tester,
            () => find
                .byKey(const ValueKey('poi-directions-button'))
                .evaluate()
                .isNotEmpty,
          );
          await tester.pump(const Duration(seconds: 2));
          final dynamic state = tester.state(find.byType(MapWidget));
          final map = state.mapboxMap as MapboxMap;
          final mapSize = tester.getSize(find.byType(MapWidget));
          expect(await map.style.isStyleLoaded(), true);

          final fit = find.byKey(const ValueKey('map-fit-trail-control'));
          final card = find.byType(DraggableScrollableSheet);
          expect(
            tester.getRect(fit).bottom,
            lessThan(tester.getRect(card).top),
          );
          // WidgetTester pointer events do not pan the native iOS platform view.
          // Deliver its gesture callback, then move the real Mapbox camera to
          // verify that the Flutter centering button recovers from that state.
          tester.widget<MapWidget>(find.byType(MapWidget)).onScrollListener!(
            MapContentGestureContext(
              touchPosition: ScreenCoordinate(x: 100, y: 100),
              point: Point(coordinates: Position(33, 35)),
              gestureState: GestureState.ended,
            ),
          );
          await map.setCamera(
            CameraOptions(
              center: Point(coordinates: Position(33, 35)),
              zoom: 15,
            ),
          );
          final afterPan = await map.getCameraState();
          await tester.tap(fit);
          await tester.pump(const Duration(seconds: 1));
          for (final coordinate in [
            Position(32.864, 34.884),
            Position(32.87, 34.895),
          ]) {
            final pixel = await map.pixelForCoordinate(
              Point(coordinates: coordinate),
            );
            expect(pixel.x, inInclusiveRange(0, mapSize.width));
            expect(
              pixel.y,
              inInclusiveRange(
                0,
                tester.getRect(card).top -
                    tester.getRect(find.byType(MapWidget)).top,
              ),
            );
          }
          final afterFit = await map.getCameraState();
          expect(
            (afterFit.center.coordinates.lat - afterPan.center.coordinates.lat)
                .abs(),
            greaterThan(0.00001),
            reason: 'Centering must still move the camera after a map gesture',
          );

          final directions = find.byKey(
            const ValueKey('poi-directions-button'),
          );
          if (controlsOnly) {
            final expandedHeight = await _expandWithDrag(tester, useStage);
            if (useStage) {
              expect(
                find.byKey(const ValueKey('map-open-stage-info')),
                findsOneWidget,
              );
            } else {
              expect(find.textContaining('from trail'), findsOneWidget);
            }
            await tester.tap(directions);
            await _waitFor(
              tester,
              () => find
                  .byKey(const ValueKey('poi-directions-error'))
                  .evaluate()
                  .isNotEmpty,
            );
            expect(
              find.text('Connect to the internet to get directions.'),
              findsOneWidget,
            );
            expect(tester.getSize(card).height, closeTo(expandedHeight, 1));
            await tester.tap(
              find.text(useStage ? 'Platres' : 'Platres accommodation'),
            );
            await tester.pumpAndSettle();
            expect(directions.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(fit).bottom,
              lessThan(tester.getRect(card).top),
            );
            expect(tester.takeException(), isNull);
            return;
          }
          await tester.tap(directions);
          await _waitFor(
            tester,
            () =>
                find
                    .byKey(const ValueKey('poi-directions-summary'))
                    .evaluate()
                    .isNotEmpty ||
                find
                    .byKey(const ValueKey('poi-directions-error'))
                    .evaluate()
                    .isNotEmpty,
          );
          expect(
            find.byKey(const ValueKey('poi-directions-error')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('poi-directions-summary')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('poi-directions-summary')),
                )
                .data,
            contains('Walking'),
          );
          await tester.pump(const Duration(seconds: 2));
          final walkingFeatures = await _nativeRouteFeatures(map, mapSize);
          expect(walkingFeatures, hasLength(1));
          final geometry = walkingFeatures.single['geometry'] as Map;
          final coordinates = geometry['coordinates'] as List;
          final coordinateCount = geometry['type'] == 'MultiLineString'
              ? coordinates.fold<int>(
                  0,
                  (count, line) => count + (line as List).length,
                )
              : coordinates.length;
          expect(coordinateCount, greaterThan(2));
          if (!useStage) {
            expect(find.textContaining('from trail'), findsNothing);
          }
          expect(
            find.byKey(const ValueKey('poi-directions-instructions')),
            findsNothing,
          );
          await _expandWithDrag(tester, useStage);
          if (!useStage) {
            expect(find.textContaining('from trail'), findsOneWidget);
          }
          expect(
            find.byKey(const ValueKey('poi-directions-instructions')),
            findsOneWidget,
          );
          await tester.tap(
            find.text(useStage ? 'Platres' : 'Platres accommodation'),
          );
          await tester.pumpAndSettle();
          if (!useStage) {
            expect(find.textContaining('from trail'), findsNothing);
          }

          await tester.tap(find.byKey(const ValueKey('poi-directions-mode')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Driving').last);
          await _waitFor(
            tester,
            () => find
                .byKey(const ValueKey('poi-directions-summary'))
                .evaluate()
                .isNotEmpty,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('poi-directions-summary')),
                )
                .data,
            contains('Driving'),
          );
          await tester.pump(const Duration(seconds: 2));
          expect(await _nativeRouteFeatures(map, mapSize), hasLength(1));

          await tester.tap(find.byKey(const ValueKey('poi-directions-clear')));
          await tester.pump(const Duration(seconds: 1));
          expect(
            find.byKey(const ValueKey('poi-directions-summary')),
            findsNothing,
          );
          expect(await _nativeRouteFeatures(map, mapSize), isEmpty);

          online = false;
          await tester.tap(directions);
          await _waitFor(
            tester,
            () => find
                .byKey(const ValueKey('poi-directions-error'))
                .evaluate()
                .isNotEmpty,
          );
          expect(
            find.text('Connect to the internet to get directions.'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('poi-straight-line-distance')),
            findsOneWidget,
          );
          expect(await _nativeRouteFeatures(map, mapSize), isEmpty);

          online = true;
          denyPermission = true;
          await tester.tap(directions);
          await _waitFor(
            tester,
            () => find
                .text('Allow location access to get directions.')
                .evaluate()
                .isNotEmpty,
          );
          expect(
            find.byKey(const ValueKey('poi-straight-line-distance')),
            findsNothing,
          );
          expect(await _nativeRouteFeatures(map, mapSize), isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
