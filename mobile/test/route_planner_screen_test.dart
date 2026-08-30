import 'package:eurotrex/features/accommodation/data/lodging_repository.dart';
import 'package:eurotrex/features/accommodation/domain/lodging.dart';
import 'package:eurotrex/features/accommodation/presentation/accommodation_controller.dart';
import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/core/database/database_provider.dart';
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
    expect(find.byKey(const ValueKey('route-planner-days')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-planner-goal')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('route-planner-start-preference')),
      findsOneWidget,
    );

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('route-planner-days-minus')));
      await tester.pump();
    }
    expect(find.text('2 days'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('route-planner-start-preference')),
        matching: find.text('Larnaka'),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('route-planner-route-next')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const ValueKey('route-planner-pace-next')));
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
      find.descendant(of: stayType, matching: find.text('Accommodation')),
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
      findsOneWidget,
    );

    final done = find.byKey(const ValueKey('route-planner-done'));
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-routes-empty')), findsNothing);
    expect(find.byKey(const ValueKey('route-planner-add')), findsOneWidget);
    expect(database.settings, contains('savedRoutesV1'));
    expect(database.settings['savedRoutesV1'], contains('larnakaToPafos'));

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-saved-route')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-routes-empty')), findsOneWidget);
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
