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
import 'dart:convert';
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
      lat: 34.8895,
      lng: 32.867,
      altitudeM: 1050,
      distanceKm: 1,
      reverseDistanceKm: 1,
    ),
    RoutePoint(
      pointIndex: 2,
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
      id: 'middle',
      sequence: 2,
      name: 'Selection test stage',
      services: {},
      accumulatedDistanceKm: 1,
    ),
    TrailStage(
      id: 'forest',
      sequence: 3,
      name: 'Forest',
      services: {},
      accumulatedDistanceKm: 2,
    ),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('selected stage stays enlarged without a ring at every zoom', (
    tester,
  ) async {
    MapboxOptions.setAccessToken(mapboxAccessToken);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          elevationProvider.overrideWith(_Elevation.new),
          stagesProvider.overrideWith(_Stages.new),
          lodgingsForTrailProvider.overrideWith((ref) async => [_hotel]),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MapScreen(initialStageIndex: 1),
        ),
      ),
    );
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find
          .byKey(const ValueKey('poi-directions-button'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const ValueKey('poi-directions-button')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    final dynamic native = tester.state(find.byType(MapWidget));
    final map = native.mapboxMap as MapboxMap;
    final selected = await map.getCameraState();
    expect(selected.center.coordinates.lat, closeTo(34.8895, .0001));
    expect(selected.center.coordinates.lng, closeTo(32.867, .0001));
    final size = tester.getSize(find.byType(MapWidget));
    for (final zoom in [7.0, 12.0, 17.0]) {
      await map.setCamera(CameraOptions(zoom: zoom, pitch: 45));
      await tester.pump(const Duration(seconds: 2));
      final layers = await map.style.getStyleLayers();
      final ringLayers = <String>[];
      final symbolLayers = <String>[];
      for (final layer in layers) {
        if (layer == null) continue;
        if (layer.type == 'circle') {
          final scale = await map.style.getStyleLayerProperty(
            layer.id,
            'circle-pitch-scale',
          );
          if (scale.value == 'viewport') ringLayers.add(layer.id);
        }
        if (layer.type == 'symbol') symbolLayers.add(layer.id);
      }
      final box = RenderedQueryGeometry.fromScreenBox(
        ScreenBox(
          min: ScreenCoordinate(x: 0, y: 0),
          max: ScreenCoordinate(x: size.width, y: size.height),
        ),
      );
      if (ringLayers.isNotEmpty) {
        final rings = await map.queryRenderedFeatures(
          box,
          RenderedQueryOptions(layerIds: ringLayers),
        );
        expect(
          rings.whereType<QueriedRenderedFeature>().where((ring) {
            final properties = ring.queriedFeature.feature['properties'] as Map;
            final paint = properties['layerProperties'] ?? properties;
            return paint is Map &&
                paint['circle-radius'] == mapSelectedLodgingRingRadius;
          }),
          isEmpty,
          reason: 'Stage selection must not draw a ring',
        );
      }
      final pins = await map.queryRenderedFeatures(
        box,
        RenderedQueryOptions(layerIds: symbolLayers),
      );
      final selectedPins = pins
          .whereType<QueriedRenderedFeature>()
          .where(
            (pin) => jsonEncode(
              pin.queriedFeature.feature,
            ).contains('Selection test stage'),
          )
          .toList();
      expect(
        selectedPins,
        isNotEmpty,
        reason: 'Selected pin must stay visible at zoom $zoom',
      );
      for (final pin in selectedPins) {
        final properties = pin.queriedFeature.feature['properties'] as Map;
        final layout = properties['layerProperties'] as Map? ?? properties;
        expect(layout['icon-size'], 1.25);
      }
    }
  });
}
