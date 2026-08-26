import 'package:eurotrex/features/accommodation/domain/lodging.dart';
import 'package:eurotrex/features/route_planner/domain/route_plan.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/trail/domain/trail_direction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a balanced itinerary between valid overnight stages', () {
    final plan = buildDeterministicRoutePlan(
      stages: [
        _stage('start', 5, 0),
        _stage('waypoint-1', 4, 10),
        _stage('overnight', 3, 20, lodging: true),
        _stage('waypoint-2', 2, 30),
        _stage('finish', 1, 40),
      ],
      lodgings: const [
        Lodging(
          id: 'stay',
          stageId: 'overnight',
          name: 'Trail Inn',
          priceMinEur: 40,
        ),
      ],
      direction: TrailDirection.pafosToLarnaka,
      request: const RoutePlanRequest(
        startStageId: 'start',
        finishStageId: 'finish',
        minimumDailyDistanceKm: 15,
        maximumDailyDistanceKm: 25,
        allowCamping: false,
        accommodationBudgetEur: 100,
      ),
    );

    expect(plan, isNotNull);
    expect(plan!.days, hasLength(2));
    expect(plan.days.first.finish.id, 'overnight');
    expect(plan.days.first.distanceKm, 20);
    expect(plan.days.first.estimatedCostEur, 40);
    expect(plan.estimatedAccommodationCostEur, 40);
    expect(plan.unknownPriceNights, 0);
  });

  test('returns no plan when known accommodation prices exceed the budget', () {
    final plan = buildDeterministicRoutePlan(
      stages: [
        _stage('start', 3, 0),
        _stage('overnight', 2, 20, lodging: true),
        _stage('finish', 1, 40),
      ],
      lodgings: const [
        Lodging(
          id: 'stay',
          stageId: 'overnight',
          name: 'Trail Inn',
          priceMinEur: 80,
        ),
      ],
      direction: TrailDirection.pafosToLarnaka,
      request: const RoutePlanRequest(
        startStageId: 'start',
        finishStageId: 'finish',
        minimumDailyDistanceKm: 15,
        maximumDailyDistanceKm: 25,
        allowCamping: false,
        accommodationBudgetEur: 50,
      ),
    );

    expect(plan, isNull);
  });

  test('can use a camping stage when accommodation is unavailable', () {
    final plan = buildDeterministicRoutePlan(
      stages: [
        _stage('start', 3, 0),
        _stage('camp', 2, 20, tent: true),
        _stage('finish', 1, 40),
      ],
      lodgings: const [],
      direction: TrailDirection.pafosToLarnaka,
      request: const RoutePlanRequest(
        startStageId: 'start',
        finishStageId: 'finish',
        minimumDailyDistanceKm: 15,
        maximumDailyDistanceKm: 25,
        allowCamping: true,
      ),
    );

    expect(plan, isNotNull);
    expect(plan!.days.first.usesCamping, isTrue);
    expect(plan.unknownPriceNights, 1);
  });

  test('budget and comfort choose different valid accommodation options', () {
    const stages = [
      TrailStage(
        id: 'start',
        sequence: 3,
        name: 'start',
        distanceFromPathKm: 0,
        accumulatedDistanceKm: 0,
        segmentLengthKm: 0,
        services: {},
      ),
      TrailStage(
        id: 'overnight',
        sequence: 2,
        name: 'overnight',
        distanceFromPathKm: 0,
        accumulatedDistanceKm: 20,
        segmentLengthKm: 20,
        services: {'lodging': true},
      ),
      TrailStage(
        id: 'finish',
        sequence: 1,
        name: 'finish',
        distanceFromPathKm: 0,
        accumulatedDistanceKm: 40,
        segmentLengthKm: 20,
        services: {},
      ),
    ];
    const lodgings = [
      Lodging(
        id: 'hostel',
        stageId: 'overnight',
        name: 'Hostel',
        type: 'hostel',
        priceMinEur: 25,
        distanceFromTrailKm: 1,
      ),
      Lodging(
        id: 'hotel',
        stageId: 'overnight',
        name: 'Hotel',
        type: 'hotel',
        priceMinEur: 80,
        distanceFromTrailKm: 0.1,
      ),
    ];

    RoutePlan? build(RoutePlanStyle style) => buildDeterministicRoutePlan(
      stages: stages,
      lodgings: lodgings,
      direction: TrailDirection.pafosToLarnaka,
      request: RoutePlanRequest(
        startStageId: 'start',
        finishStageId: 'finish',
        minimumDailyDistanceKm: 15,
        maximumDailyDistanceKm: 25,
        allowCamping: false,
        accommodationBudgetEur: 100,
        style: style,
      ),
    );

    expect(
      build(RoutePlanStyle.budget)!.days.first.accommodation!.id,
      'hostel',
    );
    expect(
      build(RoutePlanStyle.comfort)!.days.first.accommodation!.id,
      'hotel',
    );
  });
}

TrailStage _stage(
  String id,
  int sequence,
  double distance, {
  bool lodging = false,
  bool tent = false,
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
    services: {'lodging': lodging, 'tent': tent},
  );
}
