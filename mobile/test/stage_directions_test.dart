import 'package:eurotrex/core/settings/app_settings.dart';
import 'package:eurotrex/core/settings/measurement_formatter.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/map/data/poi_directions_service.dart';
import 'package:eurotrex/features/map/presentation/map_screen.dart';
import 'package:eurotrex/features/map/presentation/poi_directions_card.dart';
import 'package:eurotrex/features/map/presentation/poi_directions_controller.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/trail/domain/trail_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'poi_directions_test.dart' as fixtures;

const _points = [
  RoutePoint(
    pointIndex: 0,
    lat: 34.8,
    lng: 32.8,
    altitudeM: 10,
    distanceKm: 0,
    reverseDistanceKm: 10,
  ),
  RoutePoint(
    pointIndex: 1,
    lat: 34.9,
    lng: 32.9,
    altitudeM: 20,
    distanceKm: 10,
    reverseDistanceKm: 0,
  ),
];
const _stages = [
  TrailStage(
    id: 'start',
    name: 'Start village',
    sequence: 1,
    services: {},
    accumulatedDistanceKm: 0,
  ),
  TrailStage(
    id: 'finish',
    name: 'Finish village',
    sequence: 2,
    services: {},
    accumulatedDistanceKm: 10,
  ),
];

void main() {
  test('stage routing uses the same canonical position as its map marker', () {
    expect(mapStageDirectionsDestination(_stages.first, _points), (
      latitude: 34.8,
      longitude: 32.8,
    ));
    expect(mapStageDirectionsDestination(_stages.last, _points), (
      latitude: 34.9,
      longitude: 32.9,
    ));
    final reverseDisplay = _stages.reversed.toList();
    expect(mapStageDirectionsDestination(reverseDisplay.first, _points), (
      latitude: 34.9,
      longitude: 32.9,
    ));
  });

  test('missing geometry or stage distance does not invent a destination', () {
    expect(mapStageDirectionsDestination(_stages.first, []), isNull);
    expect(
      mapStageDirectionsDestination(
        const TrailStage(
          id: 'unknown',
          name: 'Unknown',
          sequence: 3,
          services: {},
        ),
        _points,
      ),
      isNull,
    );
  });

  testWidgets('stage card has compact directions and expanded stage info', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = PoiDirectionsController(
      PoiDirectionsService(
        accessToken: 'test',
        locate: () async => fixtures.origin,
        isOnline: () async => true,
        transport: (_) async => fixtures.routeJson(),
      ),
    );
    addTearDown(controller.dispose);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => MapStageInfoSheet(
              stage: _stages.first,
              stageIndex: 0,
              stages: _stages,
              direction: TrailDirection.pafosToLarnaka,
              formatter: const MeasurementFormatter(MeasurementSystem.metric),
              onOpenDetails: () => opened++,
              onClose: controller.clear,
              route: controller.route,
              directions: PoiDirectionsCard(
                controller: controller,
                formatter: const MeasurementFormatter(MeasurementSystem.metric),
                onDirections: (mode) => controller.load(
                  destination: mapStageDirectionsDestination(
                    _stages.first,
                    _points,
                  )!,
                  mode: mode,
                  language: 'en',
                ),
                onClear: controller.clear,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start village'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-open-stage-info')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('poi-directions-button')));
    await tester.pumpAndSettle();
    expect(find.text('1.2 km · 15 min · Walking'), findsOneWidget);
    final sheet = find.byType(DraggableScrollableSheet);
    final compactHeight = tester.getSize(sheet).height;
    final drag = await tester.startGesture(
      tester.getCenter(find.text('Start village')),
    );
    await drag.moveBy(const Offset(0, -20));
    await tester.pump();
    await drag.moveBy(const Offset(0, -120));
    await tester.pump();
    await tester.pump();
    await drag.moveBy(const Offset(0, -60));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final draggedHeight = tester.getSize(sheet).height;
    expect(draggedHeight, greaterThan(compactHeight + 140));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, closeTo(draggedHeight, 1));
    expect(
      find.byKey(const ValueKey('poi-directions-instructions')),
      findsOneWidget,
    );
    final open = find.byKey(const ValueKey('map-open-stage-info'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
