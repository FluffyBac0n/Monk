import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/core/localization/app_localizations.dart';
import 'package:monk_mobile/core/location/device_location.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/elevation/presentation/elevation_controller.dart';
import 'package:monk_mobile/features/map/domain/offline_map_state.dart';
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

      await tester.pumpWidget(
        _GpsTestApp(
          location: const DeviceLocation(
            latitude: _gpsRouteLatitude,
            longitude:
                _gpsRouteStartLongitude + _selectedStageIndex * _gpsRouteStep,
            accuracyM: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gpsButton = find.byKey(const ValueKey('stage-gps-locate'));
      await tester.ensureVisible(gpsButton);
      await tester.pumpAndSettle();

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
      expect(find.text('Nearby stage: GPS stage 24'), findsOneWidget);
    },
  );

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
                _gpsRouteStartLongitude + _selectedStageIndex * _gpsRouteStep,
            accuracyM: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gpsButton = find.byKey(const ValueKey('stage-gps-locate'));
      await tester.ensureVisible(gpsButton);
      await tester.pumpAndSettle();
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
  const _GpsTestApp({required this.location, this.locale = const Locale('en')});

  final DeviceLocation location;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        deviceLocationReaderProvider.overrideWithValue(() async => location),
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
    _gpsStageCount,
    (index) => RoutePoint(
      pointIndex: index,
      lat: _gpsRouteLatitude,
      lng: _gpsRouteStartLongitude + index * _gpsRouteStep,
      altitudeM: index * 10,
      distanceKm: index.toDouble(),
      reverseDistanceKm: (_gpsStageCount - 1 - index).toDouble(),
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
      accumulatedDistanceKm: index.toDouble(),
      segmentLengthKm: index == 0 ? 0 : 1,
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

const _gpsRouteLatitude = 35.0;
const _gpsRouteStartLongitude = 33.0;
const _gpsRouteStep = 0.001;
const _gpsStageCount = 28;
const _selectedStageIndex = 24;
