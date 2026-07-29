import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/core/localization/app_localizations.dart';
import 'package:monk_mobile/core/location/device_location.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/elevation/presentation/elevation_controller.dart';
import 'package:monk_mobile/features/map/domain/offline_map_state.dart';
import 'package:monk_mobile/features/map/presentation/map_screen.dart';
import 'package:monk_mobile/features/map/presentation/offline_map_controller.dart';
import 'package:monk_mobile/features/stages/domain/stage.dart';
import 'package:monk_mobile/features/stages/presentation/stages_controller.dart';
import 'package:monk_mobile/features/stages/presentation/stages_screen.dart';

void main() {
  testWidgets(
    'GPS highlights a distant on-trail stage and scrolls it into view',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semanticsHandle = tester.ensureSemantics();
      var locationReadCount = 0;

      await tester.pumpWidget(
        _GpsTestApp(
          location: const DeviceLocation(
            latitude: _gpsRouteLatitude + _gpsLateralOffset,
            longitude:
                _gpsRouteStartLongitude +
                _forwardLocationDistanceKm * _gpsRoutePointStep,
            accuracyM: 5,
          ),
          onLocationRead: () => locationReadCount++,
        ),
      );
      await tester.pumpAndSettle();

      final gpsButton = find.byKey(const ValueKey('stage-bottom-gps'));
      expect(find.byKey(const ValueKey('stage-gps-locate')), findsNothing);
      final gpsTooltip = tester.widget<Tooltip>(
        find.descendant(of: gpsButton, matching: find.byType(Tooltip)),
      );
      expect(find.text('Find my stage'), findsNothing);
      expect(gpsTooltip.message, 'Find my stage');
      _expectGpsToggleState(tester, gpsButton, isToggled: false);

      final selectedCard = find.byKey(
        const ValueKey('stage-card-gps-stage-24'),
      );
      final scrollController = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      final offsetBeforeGps = scrollController.offset;
      expect(tester.getTopLeft(selectedCard).dy, greaterThan(900));

      await tester.tap(gpsButton);
      await tester.pumpAndSettle();

      expect(locationReadCount, 1);
      expect(scrollController.offset, greaterThan(offsetBeforeGps));
      expect(tester.getTopLeft(selectedCard).dy, greaterThanOrEqualTo(0));
      expect(tester.getBottomLeft(selectedCard).dy, lessThanOrEqualTo(900));
      expect(
        tester.widget<Material>(selectedCard).color,
        const Color(0xFFE8F1FC),
      );
      final selectedMarker = tester.widget<Container>(
        find.byKey(const ValueKey('stage-marker-gps-stage-24')),
      );
      expect(
        (selectedMarker.decoration! as BoxDecoration).color,
        const Color(0xFF1565C0),
      );
      expect(find.textContaining('Nearby stage'), findsNothing);

      await tester.tap(selectedCard);
      await tester.pumpAndSettle();

      final detail = tester.widget<StageDetailScreen>(
        find.byType(StageDetailScreen),
      );
      expect(detail.locationStageId, 'gps-stage-24');

      final preview = find.byKey(const Key('stage-map-preview'));
      await tester.scrollUntilVisible(
        preview,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('stage-map-user-location-enabled')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('stage-map-open')));
      await tester.pumpAndSettle();

      final mapScreen = tester.widget<MapScreen>(find.byType(MapScreen));
      expect(mapScreen.initialStageIndex, 24);
      expect(mapScreen.locationStageId, 'gps-stage-24');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(gpsButton, findsOneWidget);
      _expectGpsToggleState(tester, gpsButton, isToggled: true);
      await tester.tap(gpsButton);
      await tester.pumpAndSettle();

      expect(locationReadCount, 1);
      _expectGpsToggleState(tester, gpsButton, isToggled: false);
      expect(tester.widget<Material>(selectedCard).color, Colors.white);
      expect(
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('stage-marker-gps-stage-24')),
                    )
                    .decoration!
                as BoxDecoration)
            .color,
        const Color(0xFF17201B),
      );
      semanticsHandle.dispose();
    },
  );

  testWidgets('GPS selects the destination of a mid-leg position in reverse', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _GpsTestApp(
        location: const DeviceLocation(
          latitude: _gpsRouteLatitude + _gpsLateralOffset,
          longitude:
              _gpsRouteStartLongitude +
              _reverseLocationDistanceKm * _gpsRoutePointStep,
          accuracyM: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reverse-trail-direction')));
    await tester.pumpAndSettle();

    final gpsButton = find.byKey(const ValueKey('stage-bottom-gps'));
    final selectedCard = find.byKey(const ValueKey('stage-card-gps-stage-3'));
    final adjacentCard = find.byKey(const ValueKey('stage-card-gps-stage-4'));
    final scrollController = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final offsetBeforeGps = scrollController.offset;
    expect(tester.getTopLeft(selectedCard).dy, greaterThan(900));

    await tester.tap(gpsButton);
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(offsetBeforeGps));
    expect(tester.getTopLeft(selectedCard).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomLeft(selectedCard).dy, lessThanOrEqualTo(900));
    expect(
      tester.widget<Material>(selectedCard).color,
      const Color(0xFFE8F1FC),
    );
    expect(tester.widget<Material>(adjacentCard).color, Colors.white);
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const ValueKey('stage-marker-gps-stage-3')),
                  )
                  .decoration!
              as BoxDecoration)
          .color,
      const Color(0xFF1565C0),
    );
  });

  testWidgets(
    'GPS reports an off-trail location without highlighting a stage',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _GpsTestApp(
          locale: const Locale('de'),
          location: const DeviceLocation(
            latitude: _gpsRouteLatitude + 0.01,
            longitude:
                _gpsRouteStartLongitude +
                _forwardLocationDistanceKm * _gpsRoutePointStep,
            accuracyM: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gpsButton = find.byKey(const ValueKey('stage-bottom-gps'));
      await tester.tap(gpsButton);
      await tester.pumpAndSettle();

      expect(find.text('Du befindest dich nicht auf dem Weg.'), findsOneWidget);
      for (var index = 0; index < _gpsStageCount; index++) {
        expect(
          tester
              .widget<Material>(
                find.byKey(ValueKey('stage-card-gps-stage-$index')),
              )
              .color,
          Colors.white,
        );
      }
    },
  );
}

class _GpsTestApp extends StatelessWidget {
  const _GpsTestApp({
    required this.location,
    this.locale = const Locale('en'),
    this.onLocationRead,
  });

  final DeviceLocation location;
  final Locale locale;
  final VoidCallback? onLocationRead;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        deviceLocationReaderProvider.overrideWithValue(() async {
          onLocationRead?.call();
          return location;
        }),
        elevationProvider.overrideWith(_GpsElevationController.new),
        stagesProvider.overrideWith(_GpsStagesController.new),
        offlineMapProvider.overrideWith(_GpsOfflineMapController.new),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const StagesScreen(),
      ),
    );
  }
}

class _GpsElevationController extends ElevationController {
  @override
  Future<List<RoutePoint>> build() async => List.generate(
    _gpsRoutePointCount,
    (index) => RoutePoint(
      pointIndex: index,
      lat: _gpsRouteLatitude,
      lng: _gpsRouteStartLongitude + index * _gpsRoutePointStep,
      altitudeM: index * 10,
      distanceKm: index.toDouble(),
      reverseDistanceKm: (_gpsTotalDistanceKm - index).toDouble(),
    ),
  );
}

class _GpsStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => List.generate(
    _gpsStageCount,
    (index) => TrailStage(
      id: 'gps-stage-$index',
      sequence: _gpsStageCount - index,
      name: 'GPS stage $index',
      accumulatedDistanceKm: (index * _gpsStageSpacingKm).toDouble(),
      segmentLengthKm: index == 0 ? 0 : _gpsStageSpacingKm.toDouble(),
      altitudeM: index * 10,
      services: const {},
    ),
  );
}

class _GpsOfflineMapController extends OfflineMapController {
  @override
  Future<OfflineMapState> build() async =>
      const OfflineMapState.notDownloaded();
}

void _expectGpsToggleState(
  WidgetTester tester,
  Finder gpsButton, {
  required bool isToggled,
}) {
  final toggleSemantics = tester
      .widgetList<Semantics>(
        find.descendant(of: gpsButton, matching: find.byType(Semantics)),
      )
      .where((semantics) => semantics.properties.toggled != null)
      .single;
  expect(
    toggleSemantics.properties.toggled,
    isToggled,
    reason: 'GPS button toggle state',
  );
}

const _gpsRouteLatitude = 35.0;
const _gpsRouteStartLongitude = 33.0;
const _gpsRoutePointStep = 0.0001;
const _gpsLateralOffset = 0.00002;
const _gpsStageCount = 28;
const _gpsStageSpacingKm = 10;
const _gpsTotalDistanceKm = (_gpsStageCount - 1) * _gpsStageSpacingKm;
const _gpsRoutePointCount = _gpsTotalDistanceKm + 1;
const _forwardLocationDistanceKm = 234.0;
const _reverseLocationDistanceKm = 36.0;
