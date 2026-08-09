import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/core/localization/app_localizations.dart';
import 'package:monk_mobile/core/settings/app_settings.dart';
import 'package:monk_mobile/core/settings/measurement_formatter.dart';
import 'package:monk_mobile/features/accommodation/domain/lodging.dart';
import 'package:monk_mobile/features/accommodation/presentation/lodging_type_icon.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/map/presentation/map_screen.dart';
import 'package:monk_mobile/features/stages/domain/stage.dart';
import 'package:monk_mobile/features/stages/presentation/stages_screen.dart';
import 'package:monk_mobile/features/trail/domain/trail_direction.dart';

void main() {
  const west = RoutePoint(
    pointIndex: 0,
    lat: 34.8,
    lng: 32.4,
    altitudeM: 10,
    distanceKm: 0,
    reverseDistanceKm: 100,
  );
  const east = RoutePoint(
    pointIndex: 1,
    lat: 34.8,
    lng: 33.6,
    altitudeM: 10,
    distanceKm: 100,
    reverseDistanceKm: 0,
  );

  test('map endpoint flags swap roles with the trail direction', () {
    const stages = [
      TrailStage(
        id: 'pafos',
        sequence: 3,
        name: 'Pafos',
        accumulatedDistanceKm: 0,
        services: {},
      ),
      TrailStage(
        id: 'middle',
        sequence: 2,
        name: 'Middle',
        accumulatedDistanceKm: 50,
        services: {},
      ),
      TrailStage(
        id: 'larnaka',
        sequence: 1,
        name: 'Larnaka',
        accumulatedDistanceKm: 100,
        services: {},
      ),
    ];

    expect(mapStageEndpointIndexes(stages, TrailDirection.pafosToLarnaka), (
      startIndex: 0,
      finishIndex: 2,
    ));
    expect(mapStageEndpointIndexes(stages, TrailDirection.larnakaToPafos), (
      startIndex: 2,
      finishIndex: 0,
    ));
  });

  test('map endpoint flags remain visible when stages are hidden', () {
    expect(
      mapVisibleStageIndexes(
        locatedStageIndexes: const [0, 1, 2, 3],
        endpointIndexes: (startIndex: 3, finishIndex: 0),
        stagesVisible: false,
        stagesExplicitlyHidden: true,
        initialStageIndex: 2,
      ),
      [0, 3],
    );
    expect(
      mapVisibleStageIndexes(
        locatedStageIndexes: const [0, 1, 2, 3],
        endpointIndexes: (startIndex: 3, finishIndex: 0),
        stagesVisible: true,
        stagesExplicitlyHidden: false,
        initialStageIndex: 2,
      ),
      [0, 1, 2, 3],
    );
  });

  test('stage toggle changes only intermediate map markers', () {
    expect(
      mapVisibleIntermediateStageIndexes(
        locatedStageIndexes: const [0, 1, 2, 3],
        endpointIndexes: (startIndex: 3, finishIndex: 0),
        stagesVisible: false,
        stagesExplicitlyHidden: true,
        initialStageIndex: 2,
      ),
      isEmpty,
    );
    expect(
      mapVisibleIntermediateStageIndexes(
        locatedStageIndexes: const [0, 1, 2, 3],
        endpointIndexes: (startIndex: 3, finishIndex: 0),
        stagesVisible: true,
        stagesExplicitlyHidden: false,
        initialStageIndex: 2,
      ),
      [1, 2],
    );
  });

  test('map stage points use the shared trail-distance colours', () {
    const onTrail = TrailStage(
      id: 'on-trail',
      sequence: 2,
      name: 'On trail',
      distanceFromPathKm: 0.49,
      services: {},
    );
    const offTrail = TrailStage(
      id: 'off-trail',
      sequence: 1,
      name: 'Off trail',
      distanceFromPathKm: 0.5,
      services: {},
    );

    expect(mapStagePointColor(onTrail), const Color(0xFF277653));
    expect(mapStagePointColor(offTrail), const Color(0xFFF2C94C));
    expect(
      mapStagePointColor(offTrail, isSelected: true),
      const Color(0xFF1565C0),
    );
  });

  test('stage snapshot keeps start and finish ordered in reverse', () {
    expect(
      stageMapEndpointIndexes(
        routePoints: const [west, east],
        startDistanceKm: 0,
        finishDistanceKm: 100,
      ),
      (startIndex: 0, finishIndex: 1),
    );
    expect(
      stageMapEndpointIndexes(
        routePoints: const [west, east],
        startDistanceKm: 100,
        finishDistanceKm: 0,
      ),
      (startIndex: 1, finishIndex: 0),
    );
  });

  test('first stage preview suppresses only its finish flag', () {
    expect(stagePreviewShowsFinishFlag(0), isFalse);
    expect(stagePreviewShowsFinishFlag(1), isTrue);
    expect(stagePreviewShowsRoute(0), isFalse);
    expect(stagePreviewShowsRoute(1), isTrue);
  });

  test('whole-route fit stays north-up on a portrait map', () {
    expect(routeFitBearing(const [west, east], const Size(390, 760)), 0);
  });

  test('whole-route fit stays north-up on a landscape map', () {
    expect(routeFitBearing(const [west, east], const Size(760, 390)), 0);
  });

  test('lodging types use matching Mapbox Maki POI icons', () {
    expect(lodgingMakiIconName('Picnic site'), 'picnic-site');
    expect(lodgingMakiIconName('Campsite'), 'campsite');
    expect(lodgingMakiIconName('Mountain shelter'), 'shelter');
    expect(lodgingMakiIconName('Agrotourism'), 'farm');
    expect(lodgingMakiIconName('Religious'), 'place-of-worship');
    expect(lodgingMakiIconName('Municipal'), 'town-hall');
    expect(lodgingMakiIconName('Apartment'), 'residential-community');
    expect(lodgingMakiIconName('Hostel'), 'suitcase');
    expect(lodgingMakiIconName('Guesthouse'), 'home');
    expect(lodgingMakiIconName('Bed & Breakfast'), 'home');
    expect(lodgingMakiIconName('Hotel'), 'lodging');
    expect(lodgingMakiIconName(null), 'lodging');
  });

  test('lodging types use the Mapbox Outdoors marker palette', () {
    expect(
      lodgingMakiMarkerColor('Picnic site'),
      mapboxOutdoorAccommodationGreen,
    );
    expect(lodgingMakiMarkerColor('Campsite'), mapboxOutdoorAccommodationGreen);
    expect(lodgingMakiMarkerColor('Hotel'), mapboxLodgingMauve);
    expect(lodgingMakiMarkerColor('Apartment'), mapboxLodgingMauve);
  });

  testWidgets('map route direction remains readable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MapScreen(accessToken: ''),
        ),
      ),
    );

    final subtitle = tester.widget<Text>(
      find.byKey(const ValueKey('map-route-direction')),
    );
    expect(subtitle.data, contains('FLUGHAFEN PAFOS'));
    expect(subtitle.data, contains('FLUGHAFEN LARNAKA'));
    expect(subtitle.maxLines, 2);
    expect(subtitle.softWrap, isTrue);
    expect(subtitle.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected stage opens as a full-width draggable info sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var openCount = 0;
    var closeCount = 0;
    const stages = [
      TrailStage(
        id: 'start',
        sequence: 2,
        name: 'Start',
        accumulatedDistanceKm: 0,
        services: {},
      ),
      TrailStage(
        id: 'forest-stage',
        sequence: 1,
        name: 'Forest stage',
        accumulatedDistanceKm: 8.4,
        segmentLengthKm: 8.4,
        elevationUpM: 180,
        elevationDownM: 45,
        altitudeM: 320,
        services: {'drinkableWater': true},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const ColoredBox(color: Colors.green),
              MapStageInfoSheet(
                stage: stages[1],
                stageIndex: 1,
                stages: stages,
                direction: TrailDirection.pafosToLarnaka,
                formatter: const MeasurementFormatter(MeasurementSystem.metric),
                onOpenDetails: () => openCount++,
                onClose: () => closeCount++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('map-stage-info-sheet'));
    final header = find.byKey(const ValueKey('map-stage-info-sheet-header'));
    expect(sheet, findsOneWidget);
    expect(find.text('Forest stage'), findsOneWidget);
    expect(tester.getSize(sheet).width, 400);
    expect(tester.getBottomLeft(sheet).dy, closeTo(800, 0.1));
    final compactHeight = tester.getSize(sheet).height;
    expect(compactHeight, lessThan(150));

    await tester.drag(header, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, greaterThan(compactHeight + 300));
    expect(tester.getBottomLeft(sheet).dy, closeTo(800, 0.1));
    expect(find.byKey(const ValueKey('stage-info-cards')), findsOneWidget);
    expect(find.text('Trail position'), findsOneWidget);
    expect(find.text('Drinking water'), findsOneWidget);
    expect(find.byKey(const Key('stage-map-preview')), findsNothing);
    expect(
      find.byKey(const ValueKey('stage-detail-bottom-navigation')),
      findsNothing,
    );

    final openAction = find.byKey(const ValueKey('map-open-stage-info'));
    await tester.scrollUntilVisible(
      openAction,
      180,
      scrollable: find.descendant(of: sheet, matching: find.byType(Scrollable)),
    );
    await tester.tap(openAction);
    expect(openCount, 1);

    await tester.tap(find.byTooltip('Close stage summary'));
    expect(closeCount, 1);
  });

  testWidgets('lodging map summary localizes details and handles card tap', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _lodgingSummaryApp(
        locale: const Locale('de'),
        lodging: const Lodging(
          id: 'forest-inn',
          name: 'Pafos Airport',
          type: 'Guesthouse',
          village: 'Larnaka Airport',
          distanceFromTrailKm: 0.4,
          website: 'https://booking.example.com/forest-inn',
        ),
        onTap: () => tapCount++,
      ),
    );

    expect(find.text('Flughafen Pafos'), findsOneWidget);
    expect(find.text('Gästehaus · Flughafen Larnaka · 0.4 km'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('lodging-map-summary-forest-inn')),
    );
    expect(tapCount, 1);
  });

  testWidgets('lodging map summary localizes an unavailable booking link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _lodgingSummaryApp(
        locale: const Locale('es'),
        lodging: const Lodging(
          id: 'mountain-shelter',
          name: 'Accommodation',
          type: 'Guesthouse',
          village: 'Pafos Airport',
        ),
      ),
    );

    expect(find.text('Alojamiento'), findsOneWidget);
    expect(
      find.text(
        'Casa de huéspedes · Aeropuerto de Pafos · '
        'Enlace de reserva no disponible',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
  });

  testWidgets('lodging map summary close does not invoke the card tap', (
    tester,
  ) async {
    var tapCount = 0;
    var closeCount = 0;

    await tester.pumpWidget(
      _lodgingSummaryApp(
        lodging: const Lodging(
          id: 'village-hotel',
          name: 'Village Hotel',
          website: 'https://booking.example.com/village-hotel',
        ),
        onTap: () => tapCount++,
        onClose: () => closeCount++,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('lodging-map-summary-close-village-hotel')),
    );

    expect(closeCount, 1);
    expect(tapCount, 0);
  });
}

Widget _lodgingSummaryApp({
  required Lodging lodging,
  Locale locale = const Locale('en'),
  VoidCallback? onTap,
  VoidCallback? onClose,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 76,
          child: LodgingMapSummaryCard(
            lodging: lodging,
            formatter: const MeasurementFormatter(MeasurementSystem.metric),
            onTap: onTap ?? _doNothing,
            onClose: onClose ?? _doNothing,
          ),
        ),
      ),
    ),
  );
}

void _doNothing() {}
