import 'package:eurotrex/core/localization/app_localizations.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/map/presentation/stage_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native terrain preview renders and supports 2D, 3D and reset', (
    tester,
  ) async {
    MapboxOptions.setAccessToken(
      const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    );
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: StagePreviewScreen(
          stageName: 'Troodos preview test',
          points: [
            RoutePoint(
              pointIndex: 0,
              lat: 34.91,
              lng: 32.865,
              altitudeM: 1400,
              distanceKm: 0,
              reverseDistanceKm: 4,
            ),
            RoutePoint(
              pointIndex: 1,
              lat: 34.925,
              lng: 32.87,
              altitudeM: 1650,
              distanceKm: 2,
              reverseDistanceKm: 2,
            ),
            RoutePoint(
              pointIndex: 2,
              lat: 34.937,
              lng: 32.875,
              altitudeM: 1750,
              distanceKm: 4,
              reverseDistanceKm: 0,
            ),
          ],
        ),
      ),
    );
    final reset = find.byKey(const ValueKey('stage-preview-reset'));
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (tester.widget<OutlinedButton>(reset).onPressed != null) break;
    }
    expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);
    final dynamic native = tester.state(find.byType(MapWidget));
    final map = native.mapboxMap as MapboxMap;
    expect((await map.getCameraState()).pitch, closeTo(55, .1));
    expect(
      (await map.style.getStyleTerrainProperty('source')).value,
      'stage-preview-dem',
    );
    expect(
      await map.style.styleLayerExists('stage-preview-route-line'),
      isTrue,
    );
    double? elevation;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      elevation = await map.getElevation(
        Point(coordinates: Position(32.87, 34.925)),
      );
      if (elevation != null && elevation > 500) break;
    }
    expect(elevation, greaterThan(500));
    await tester.tap(find.text('2D view'));
    await tester.pump(const Duration(seconds: 2));
    expect((await map.getCameraState()).pitch, closeTo(0, .1));
    expect((await map.style.getStyleTerrainProperty('exaggeration')).value, 0);
    await tester.tap(find.text('3D view'));
    await tester.pump(const Duration(seconds: 2));
    expect((await map.getCameraState()).pitch, closeTo(55, .1));
    expect((await map.style.getStyleTerrainProperty('exaggeration')).value, 1);
    final original = await map.getCameraState();
    await map.setCamera(CameraOptions(zoom: original.zoom + 1, bearing: 80));
    await tester.pump(const Duration(milliseconds: 500));
    // Switching modes rebuilds the controls without resetting the user's zoom.
    await tester.tap(find.text('2D view'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('3D view'));
    await tester.pump(const Duration(seconds: 2));
    expect((await map.getCameraState()).zoom, closeTo(original.zoom + 1, .1));
    await tester.tap(reset);
    await tester.pump(const Duration(seconds: 2));
    expect((await map.getCameraState()).bearing % 360, closeTo(335, .1));
    expect((await map.getCameraState()).zoom, closeTo(original.zoom, .1));
    expect(tester.takeException(), isNull);
  });
}
