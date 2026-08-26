import 'dart:convert';

import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/core/database/database_provider.dart';
import 'package:eurotrex/features/route_planner/data/saved_route_repository.dart';
import 'package:eurotrex/features/route_planner/domain/route_plan.dart';
import 'package:eurotrex/features/route_planner/domain/saved_route.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/stages/presentation/stages_controller.dart';
import 'package:eurotrex/features/stages/presentation/stages_screen.dart';
import 'package:eurotrex/features/trail/domain/trail_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a saved itinerary is available in Stage filters', (
    tester,
  ) async {
    final route = SavedRoute(
      id: 'week-one',
      createdAt: DateTime(2026, 8, 24),
      style: RoutePlanStyle.balanced,
      direction: TrailDirection.pafosToLarnaka,
      startStageId: 'start',
      startStageName: 'Start',
      finishStageId: 'finish',
      finishStageName: 'Finish',
      minimumDailyDistanceKm: 10,
      maximumDailyDistanceKm: 20,
      accommodationBudgetEur: 100,
      allowCamping: false,
      days: const [
        SavedRouteDay(
          dayNumber: 1,
          startStageId: 'start',
          startStageName: 'Start',
          finishStageId: 'finish',
          finishStageName: 'Finish',
          distanceKm: 20,
          ascentM: 100,
          descentM: 50,
          estimatedWalkingMinutes: 250,
          usesCamping: false,
          accommodationName: null,
          estimatedCostEur: 0,
        ),
      ],
      estimatedAccommodationCostEur: 0,
      unknownPriceNights: 0,
    );
    final database = _SavedRouteDatabase({
      savedRoutesSettingKey: jsonEncode([route.toJson()]),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          stagesProvider.overrideWith(_SavedRouteStagesController.new),
        ],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stage-filter-saved-routes-panel')),
      findsOneWidget,
    );
    final routeChip = find.byKey(const ValueKey('saved-route-filter-week-one'));
    expect(routeChip, findsOneWidget);
    await tester.tap(routeChip);
    await tester.pumpAndSettle();

    final apply = find.byKey(const Key('apply-service-filters'));
    await tester.scrollUntilVisible(
      apply,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stage-card-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-middle')), findsNothing);
    expect(find.byKey(const ValueKey('stage-card-finish')), findsOneWidget);
  });
}

class _SavedRouteDatabase extends AppDatabase {
  _SavedRouteDatabase(this.settings);

  final Map<String, String> settings;

  @override
  Future<Map<String, String>> readSettings() async => Map.of(settings);

  @override
  Future<void> writeSetting(String key, String value) async {
    settings[key] = value;
  }
}

class _SavedRouteStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: 'start',
      sequence: 3,
      name: 'Start',
      distanceFromPathKm: 0,
      accumulatedDistanceKm: 0,
      segmentLengthKm: 0,
      services: {},
    ),
    TrailStage(
      id: 'middle',
      sequence: 2,
      name: 'Middle',
      distanceFromPathKm: 0,
      accumulatedDistanceKm: 10,
      segmentLengthKm: 10,
      services: {},
    ),
    TrailStage(
      id: 'finish',
      sequence: 1,
      name: 'Finish',
      distanceFromPathKm: 0,
      accumulatedDistanceKm: 20,
      segmentLengthKm: 10,
      services: {},
    ),
  ];
}
