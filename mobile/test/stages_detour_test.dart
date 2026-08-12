import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/features/detours/domain/trail_detour.dart';
import 'package:monk_mobile/features/detours/presentation/detour_controller.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/elevation/presentation/elevation_controller.dart';
import 'package:monk_mobile/features/excursions/presentation/excursion_controller.dart';
import 'package:monk_mobile/features/map/presentation/map_screen.dart';
import 'package:monk_mobile/features/stages/domain/stage.dart';
import 'package:monk_mobile/features/stages/presentation/stages_controller.dart';
import 'package:monk_mobile/features/stages/presentation/stages_screen.dart';

void main() {
  testWidgets('affected stages show the detour marker and comparison card', (
    tester,
  ) async {
    const detour = TrailDetour(
      id: 'teishia-tis-madaris',
      name: 'Teishia tis Madaris',
      routeDistanceKm: 6.6702,
      elevationUpM: 399.52,
      elevationDownM: 480.74,
      estimatedWalkingTimeMinutes: 120,
      replacedMainTrailDistanceKm: 5.5032,
      replacedElevationUpM: 324.85,
      replacedElevationDownM: 403.21,
      replacedEstimatedWalkingTimeMinutes: 99,
      distanceDifferenceKm: 1.167,
      estimatedWalkingTimeDifferenceMinutes: 21,
      averageDistanceFromTrailKm: 0.664,
      maximumDistanceFromTrailKm: 1.128,
      affectedStageIds: ['66-spilia', '65-saranti'],
      affectedStageSequences: [66, 65],
      affectedStageNames: ['Spilia', 'Saranti'],
      pointStride: 5,
      startMainTrailDistanceKm: 268.394,
      endMainTrailDistanceKm: 273.897,
    );
    const detourRoute = TrailDetourRoute(
      detour: detour,
      points: [
        RoutePoint(
          pointIndex: 0,
          lat: 34.95,
          lng: 32.96,
          altitudeM: 1300,
          distanceKm: 0,
          reverseDistanceKm: 6.67,
        ),
        RoutePoint(
          pointIndex: 1,
          lat: 34.96,
          lng: 32.99,
          altitudeM: 1250,
          distanceKm: 6.67,
          reverseDistanceKm: 0,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stagesProvider.overrideWith(_DetourStagesController.new),
          elevationProvider.overrideWith(_DetourElevationController.new),
          detoursForTrailProvider.overrideWith((ref) async => [detour]),
          detourRoutesForTrailProvider.overrideWith(
            (ref) async => [detourRoute],
          ),
          excursionsForTrailProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final marker = find.byKey(const ValueKey('stage-detour-marker-66-spilia'));
    final card = find.byKey(const ValueKey('stage-card-66-spilia'));
    expect(marker, findsOneWidget);
    expect(
      find.byKey(const ValueKey('stage-detour-tab-66-spilia')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-detour-choice-teishia-tis-madaris')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('stage-detour-choice-card-teishia-tis-madaris'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-detour-connectors-teishia-tis-madaris')),
      findsOneWidget,
    );
    final detourCard = find.byKey(
      const ValueKey('stage-detour-choice-card-teishia-tis-madaris'),
    );
    final detourTimelineAxis = find.byKey(
      const ValueKey('stage-detour-timeline-axis-teishia-tis-madaris'),
    );
    final e4PathMarker = find.byKey(
      const ValueKey('stage-detour-e4-path-marker-66-spilia'),
    );
    expect(e4PathMarker, findsOneWidget);
    expect(
      (tester.widget<Container>(e4PathMarker).decoration! as BoxDecoration)
          .color,
      const Color(0xFF277653),
    );
    expect(
      tester.getCenter(e4PathMarker).dx,
      closeTo(tester.getCenter(detourTimelineAxis).dx, 0.01),
    );
    expect(
      tester.getCenter(card).dx,
      lessThan(tester.getCenter(detourCard).dx),
    );
    final sarantiMarker = find.byKey(const ValueKey('stage-marker-65-saranti'));
    expect(
      tester.getCenter(detourTimelineAxis).dx,
      closeTo(tester.getCenter(sarantiMarker).dx, 0.01),
    );
    expect(
      find.byKey(const ValueKey('stage-side-metrics-66-spilia')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-e4-badge-66-spilia')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('E4')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-ascent-66-spilia')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-descent-66-spilia')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-length-66-spilia')),
      findsOneWidget,
    );
    final stageDistance = find.byKey(
      const ValueKey('stage-card-distance-66-spilia'),
    );
    expect(stageDistance, findsOneWidget);
    expect(
      find.descendant(of: stageDistance, matching: find.byType(Text)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: stageDistance,
        matching: find.byIcon(Icons.hiking_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-card-altitude-66-spilia')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stage-filter-start')), findsNothing);
    expect(find.byKey(const ValueKey('stage-filter-finish')), findsNothing);
    expect(find.byKey(const ValueKey('stage-filter-detours')), findsNothing);
    expect(find.byKey(const ValueKey('stage-filter-excursions')), findsNothing);
    final applyFilters = find.byKey(const Key('apply-service-filters'));
    await tester.scrollUntilVisible(
      applyFilters,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(applyFilters);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-card-67-adventure-mountain-park')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stage-card-66-spilia')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-65-saranti')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stage-detour-choice-teishia-tis-madaris')),
      findsOneWidget,
    );

    await tester.tap(detourCard);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('detour-detail-teishia-tis-madaris')),
      findsOneWidget,
    );
    expect(find.text('CYPRUS E4 · DETOUR'), findsOneWidget);
    expect(find.text('Teishia tis Madaris'), findsWidgets);

    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('detour-detail-teishia-tis-madaris')),
      ),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(card);
    await tester.pumpAndSettle();

    final summary = find.byKey(
      const ValueKey('stage-detour-teishia-tis-madaris'),
    );
    await tester.scrollUntilVisible(
      summary,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(summary, findsOneWidget);
    expect(find.text('Detours'), findsOneWidget);
    expect(find.text('Teishia tis Madaris'), findsOneWidget);
    expect(find.text('Alternative route'), findsOneWidget);
    expect(find.text('6.7 km'), findsOneWidget);
    expect(find.text('5.5 km'), findsOneWidget);
    expect(find.text('+1.2 km'), findsOneWidget);
    expect(find.text('+21 min'), findsOneWidget);

    final mapPreview = find.byKey(const Key('stage-map-open'));
    await tester.scrollUntilVisible(
      mapPreview,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(mapPreview);
    await tester.pumpAndSettle();
    final mapScreen = tester.widget<MapScreen>(find.byType(MapScreen));
    expect(mapScreen.initialDetours, [detourRoute]);
  });
}

class _DetourElevationController extends ElevationController {
  @override
  Future<List<RoutePoint>> build() async => const [
    RoutePoint(
      pointIndex: 0,
      lat: 34.93,
      lng: 32.94,
      altitudeM: 1250,
      distanceKm: 268.3,
      reverseDistanceKm: 7.36,
    ),
    RoutePoint(
      pointIndex: 1,
      lat: 34.94,
      lng: 32.95,
      altitudeM: 1200,
      distanceKm: 270,
      reverseDistanceKm: 5.66,
    ),
    RoutePoint(
      pointIndex: 2,
      lat: 34.97,
      lng: 33.0,
      altitudeM: 1100,
      distanceKm: 275.66,
      reverseDistanceKm: 0,
    ),
  ];
}

class _DetourStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: '67-adventure-mountain-park',
      sequence: 67,
      name: 'Adventure Mountain Park',
      accumulatedDistanceKm: 268.3,
      segmentLengthKm: 3,
      elevationUpM: 100,
      elevationDownM: 80,
      altitudeM: 1250,
      services: {},
    ),
    TrailStage(
      id: '66-spilia',
      sequence: 66,
      name: 'Spilia',
      distanceFromPathKm: 0.2,
      accumulatedDistanceKm: 270,
      segmentLengthKm: 1.7,
      elevationUpM: 200,
      elevationDownM: 150,
      altitudeM: 1200,
      services: {},
    ),
    TrailStage(
      id: '65-saranti',
      sequence: 65,
      name: 'Saranti',
      accumulatedDistanceKm: 275.66,
      segmentLengthKm: 5.66,
      elevationUpM: 120,
      elevationDownM: 180,
      altitudeM: 1100,
      services: {},
    ),
  ];
}
