import 'package:eurotrex/features/accommodation/data/lodging_repository.dart';
import 'package:eurotrex/features/accommodation/domain/lodging.dart';
import 'package:eurotrex/features/accommodation/presentation/accommodation_controller.dart';
import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/core/database/database_provider.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/elevation/presentation/elevation_controller.dart';
import 'package:eurotrex/features/route_planner/presentation/route_planner_screen.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/stages/presentation/stages_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('planner saves a choice through the three-step wizard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = _PlannerDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          stagesProvider.overrideWith(_PlannerStagesController.new),
          lodgingRepositoryProvider.overrideWithValue(
            const _PlannerLodgingRepository(),
          ),
        ],
        child: const MaterialApp(home: RoutePlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-planner-screen')), findsOneWidget);
    expect(find.text('Premium'), findsNothing);
    expect(find.text('My routes'), findsWidgets);
    expect(find.byKey(const ValueKey('saved-routes-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-planner-build')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('route-planner-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-planner-step-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-planner-step-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-planner-step-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-planner-days')), findsNothing);
    expect(find.byKey(const ValueKey('route-planner-goal')), findsNothing);
    expect(
      find.byKey(const ValueKey('route-planner-selection-map')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('route-planner-start-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('route-planner-finish-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('route-planner-map-stages')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('route-planner-map-gps')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('route-planner-map-center')),
      findsOneWidget,
    );

    final routeNext = find.byKey(const ValueKey('route-planner-route-next'));
    await tester.ensureVisible(routeNext);
    await tester.pumpAndSettle();
    await tester.tap(routeNext);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-planner-days')), findsOneWidget);
    expect(find.byTooltip('Remove walking day'), findsOneWidget);
    expect(find.byTooltip('Add walking day'), findsOneWidget);
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('route-planner-days-minus')));
      await tester.pump();
    }
    expect(find.text('2 days'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('route-planner-pace-slider')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('route-planner-pace-unit')),
        matching: find.text('km'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('25 km per day'), findsOneWidget);

    final paceNext = find.byKey(const ValueKey('route-planner-pace-next'));
    await tester.ensureVisible(paceNext);
    await tester.pumpAndSettle();
    await tester.tap(paceNext);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('route-planner-price-range')),
      findsOneWidget,
    );
    final stayType = find.byKey(const ValueKey('route-planner-stay-type'));
    await tester.tap(
      find.descendant(of: stayType, matching: find.text('Camping')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('route-planner-price-range')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: stayType, matching: find.text('Stays')),
    );
    await tester.pumpAndSettle();

    final buildButton = find.byKey(const ValueKey('route-planner-build'));
    await tester.ensureVisible(buildButton);
    await tester.pumpAndSettle();
    await tester.tap(buildButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-option-relaxed')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-option-balanced')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('route-option-adventurous')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('route-option-balanced')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-planner-result')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-plan-day-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-plan-day-2')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('route-saved-confirmation')),
      findsNothing,
    );
    expect(database.settings, isNot(contains('savedRoutesV1')));

    final save = find.byKey(const ValueKey('route-planner-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('route-saved-confirmation')),
      findsOneWidget,
    );

    final done = find.byKey(const ValueKey('route-planner-done'));
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-routes-empty')), findsNothing);
    expect(find.byKey(const ValueKey('route-planner-add')), findsOneWidget);
    expect(database.settings, contains('savedRoutesV1'));
    expect(database.settings['savedRoutesV1'], contains('pafosToLarnaka'));

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-saved-route')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-routes-empty')), findsOneWidget);
  });

  testWidgets('stage taps on the route map choose start and finish', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(_PlannerDatabase()),
          stagesProvider.overrideWith(_PlannerStagesController.new),
          elevationProvider.overrideWith(_PlannerElevationController.new),
          lodgingRepositoryProvider.overrideWithValue(
            const _PlannerLodgingRepository(),
          ),
        ],
        child: const MaterialApp(home: RoutePlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-planner-add')));
    await tester.pumpAndSettle();

    final map = find.byKey(const ValueKey('route-planner-selection-map'));
    final topLeft = tester.getTopLeft(map);
    final size = tester.getSize(map);
    final routeY = topLeft.dy + size.height / 2 - 17;
    await tester.tapAt(Offset(topLeft.dx + size.width / 2, routeY));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('route-planner-stage-callout')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('route-planner-callout-start')));
    await tester.pumpAndSettle();
    expect(find.textContaining('overnight → finish'), findsOneWidget);

    await tester.tapAt(Offset(topLeft.dx + size.width * 0.72, routeY));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('route-planner-callout-finish')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('overnight → waypoint-2'), findsOneWidget);
  });

  testWidgets('trip map fills the screen and stage fields are searchable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(_PlannerDatabase()),
          stagesProvider.overrideWith(_PlannerStagesController.new),
          elevationProvider.overrideWith(_PlannerElevationController.new),
          lodgingRepositoryProvider.overrideWithValue(
            const _PlannerLodgingRepository(),
          ),
        ],
        child: const MaterialApp(home: RoutePlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-planner-add')));
    await tester.pumpAndSettle();

    final map = find.byKey(const ValueKey('route-planner-selection-map'));
    expect(tester.getSize(map).height, greaterThan(700));

    await tester.tap(find.byKey(const ValueKey('route-planner-start-stage')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('route-planner-stage-search')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('route-planner-stage-search')),
      'waypoint-1',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('waypoint-1').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('waypoint-1 → finish'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('route-planner-swap-stages')));
    await tester.pumpAndSettle();
    expect(find.textContaining('finish → waypoint-1'), findsOneWidget);
  });

  testWidgets('large trail geometry opens the Trip step without blocking', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(_PlannerDatabase()),
          stagesProvider.overrideWith(_PlannerStagesController.new),
          elevationProvider.overrideWith(_LargePlannerElevationController.new),
          lodgingRepositoryProvider.overrideWithValue(
            const _PlannerLodgingRepository(),
          ),
        ],
        child: const MaterialApp(home: RoutePlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('route-planner-add')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-planner-selection-map')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('route-planner-route-next')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _PlannerDatabase extends AppDatabase {
  final settings = <String, String>{};

  @override
  Future<Map<String, String>> readSettings() async => Map.of(settings);

  @override
  Future<void> writeSetting(String key, String value) async {
    settings[key] = value;
  }
}

class _PlannerStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => [
    _stage('start', 5, 0),
    _stage('waypoint-1', 4, 10),
    _stage('overnight', 3, 20, lodging: true),
    _stage('waypoint-2', 2, 30),
    _stage('finish', 1, 40),
  ];
}

class _PlannerElevationController extends ElevationController {
  @override
  Future<List<RoutePoint>> build() async => [
    for (var index = 0; index < 5; index++)
      RoutePoint(
        pointIndex: index,
        lat: 35,
        lng: 32 + index * 0.25,
        altitudeM: 100,
        distanceKm: index * 10,
        reverseDistanceKm: 40 - index * 10,
      ),
  ];
}

class _LargePlannerElevationController extends ElevationController {
  @override
  Future<List<RoutePoint>> build() async => List.generate(24000, (index) {
    final progress = index / 23999;
    return RoutePoint(
      pointIndex: index,
      lat: 34.7 + progress * 0.4,
      lng: 32.4 + progress * 0.7,
      altitudeM: 100 + progress * 900,
      distanceKm: progress * 40,
      reverseDistanceKm: (1 - progress) * 40,
    );
  });
}

class _PlannerLodgingRepository implements LodgingRepository {
  const _PlannerLodgingRepository();

  static const lodging = Lodging(
    id: 'stay',
    stageId: 'overnight',
    name: 'Trail Inn',
    priceMinEur: 40,
  );

  @override
  Future<List<Lodging>> loadForStage({
    required String trailId,
    required String stageId,
  }) async => stageId == lodging.stageId ? const [lodging] : const [];

  @override
  Future<List<Lodging>> loadForTrail({required String trailId}) async => const [
    lodging,
  ];
}

TrailStage _stage(
  String id,
  int sequence,
  double distance, {
  bool lodging = false,
}) {
  return TrailStage(
    id: id,
    sequence: sequence,
    name: id,
    distanceFromPathKm: 0,
    accumulatedDistanceKm: distance,
    segmentLengthKm: 10,
    elevationUpM: 100,
    elevationDownM: 50,
    services: {'lodging': lodging, 'tent': false},
  );
}
