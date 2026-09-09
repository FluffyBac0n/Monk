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
        maximumAccommodationPriceEur: 100,
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

  test('returns no plan when known accommodation prices exceed the range', () {
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
        maximumAccommodationPriceEur: 50,
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
        overnightPreference: RouteOvernightPreference.camping,
      ),
    );

    expect(plan, isNotNull);
    expect(plan!.days.first.usesCamping, isTrue);
    expect(plan.unknownPriceNights, 1);
  });

  test('honours exact walking days and the daily time limit', () {
    final stages = [
      _stage('start', 5, 0),
      _stage('night-1', 4, 10, lodging: true),
      _stage('night-2', 3, 20, lodging: true),
      _stage('night-3', 2, 30, lodging: true),
      _stage('finish', 1, 40),
    ];
    const lodgings = [
      Lodging(id: 'one', stageId: 'night-1', priceMinEur: 50),
      Lodging(id: 'two', stageId: 'night-2', priceMinEur: 50),
      Lodging(id: 'three', stageId: 'night-3', priceMinEur: 50),
    ];

    RoutePlan? build(int maximumMinutes) => buildDeterministicRoutePlan(
      stages: stages,
      lodgings: lodgings,
      direction: TrailDirection.pafosToLarnaka,
      request: RoutePlanRequest(
        startStageId: 'start',
        finishStageId: 'finish',
        minimumDailyDistanceKm: 5,
        maximumDailyDistanceKm: 25,
        maximumDailyWalkingMinutes: maximumMinutes,
        walkingDays: 4,
        minimumAccommodationPriceEur: 40,
        maximumAccommodationPriceEur: 60,
      ),
    );

    expect(build(140)!.days, hasLength(4));
    expect(build(120), isNull);
  });

  test(
    'accepts accommodation whose listed price range overlaps the filter',
    () {
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
            priceMinEur: 40,
            priceMaxEur: 100,
          ),
        ],
        direction: TrailDirection.pafosToLarnaka,
        request: const RoutePlanRequest(
          startStageId: 'start',
          finishStageId: 'finish',
          minimumDailyDistanceKm: 15,
          maximumDailyDistanceKm: 25,
          minimumAccommodationPriceEur: 60,
          maximumAccommodationPriceEur: 80,
        ),
      );

      expect(plan, isNotNull);
    },
  );

  test('relaxed and adventurous choose different accommodation options', () {
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
        style: style,
      ),
    );

    expect(
      build(RoutePlanStyle.relaxed)!.days.first.accommodation!.id,
      'hotel',
    );
    expect(
      build(RoutePlanStyle.adventurous)!.days.first.accommodation!.id,
      'hostel',
    );
  });

  test('rebuilds a route around edited stops and explicit lodging choices', () {
    final stages = [
      _stage('start', 5, 0),
      _stage('night-1', 4, 10, lodging: true),
      _stage('night-2', 3, 20, lodging: true),
      _stage('night-3', 2, 30, lodging: true),
      _stage('finish', 1, 40),
    ];
    const lodgings = [
      Lodging(id: 'basic', stageId: 'night-2', priceMinEur: 30),
      Lodging(id: 'chosen', stageId: 'night-2', priceMinEur: 75),
    ];

    final plan = buildRoutePlanFromStops(
      stages: stages,
      lodgings: lodgings,
      direction: TrailDirection.pafosToLarnaka,
      request: const RoutePlanRequest(
        startStageId: 'start',
        finishStageId: 'finish',
        minimumDailyDistanceKm: 5,
        maximumDailyDistanceKm: 30,
      ),
      stopStageIds: const ['night-2'],
      accommodationIdsByStage: const {'night-2': 'chosen'},
    );

    expect(plan, isNotNull);
    expect(plan!.days, hasLength(2));
    expect(plan.days.first.finish.id, 'night-2');
    expect(plan.days.first.accommodation?.id, 'chosen');
    expect(plan.estimatedAccommodationCostEur, 75);
  });

  test(
    'daily pace is the hard constraint and does not enforce walking days',
    () {
      final plan = buildDeterministicRoutePlan(
        stages: [
          _stage('start', 4, 0),
          _stage('night-1', 3, 10, lodging: true),
          _stage('night-2', 2, 20, lodging: true),
          _stage('finish', 1, 30),
        ],
        lodgings: const [
          Lodging(id: 'one', stageId: 'night-1', priceMinEur: 40),
          Lodging(id: 'two', stageId: 'night-2', priceMinEur: 40),
        ],
        direction: TrailDirection.pafosToLarnaka,
        request: const RoutePlanRequest(
          startStageId: 'start',
          finishStageId: 'finish',
          minimumDailyDistanceKm: 1,
          maximumDailyDistanceKm: 12,
          walkingDays: 1,
          constraint: RoutePlanConstraint.dailyPace,
        ),
      );

      expect(plan, isNotNull);
      expect(plan!.days, hasLength(3));
    },
  );

  test('unknown accommodation prices are an explicit preference', () {
    RoutePlan? build({required bool includeUnknown}) =>
        buildDeterministicRoutePlan(
          stages: [
            _stage('start', 3, 0),
            _stage('overnight', 2, 20, lodging: true),
            _stage('finish', 1, 40),
          ],
          lodgings: const [Lodging(id: 'unknown', stageId: 'overnight')],
          direction: TrailDirection.pafosToLarnaka,
          request: RoutePlanRequest(
            startStageId: 'start',
            finishStageId: 'finish',
            minimumDailyDistanceKm: 15,
            maximumDailyDistanceKm: 25,
            minimumAccommodationPriceEur: 40,
            maximumAccommodationPriceEur: 120,
            includeUnknownAccommodationPrices: includeUnknown,
          ),
        );

    expect(build(includeUnknown: true), isNotNull);
    expect(build(includeUnknown: false), isNull);

    final failure = diagnoseRoutePlanFailure(
      stages: [
        _stage('start', 3, 0),
        _stage('overnight', 2, 20, lodging: true),
        _stage('finish', 1, 40),
      ],
      lodgings: const [Lodging(id: 'unknown', stageId: 'overnight')],
      direction: TrailDirection.pafosToLarnaka,
      request: const RoutePlanRequest(
        startStageId: 'start',
        finishStageId: 'finish',
        minimumDailyDistanceKm: 15,
        maximumDailyDistanceKm: 25,
        includeUnknownAccommodationPrices: false,
      ),
    );
    expect(failure, RoutePlanFailure.unknownPricesExcluded);
  });

  test('diagnoses a section that is too far for selected days', () {
    final failure = diagnoseRoutePlanFailure(
      stages: [_stage('start', 2, 0), _stage('finish', 1, 80)],
      lodgings: const [],
      direction: TrailDirection.pafosToLarnaka,
      request: const RoutePlanRequest(
        startStageId: 'start',
        finishStageId: 'finish',
        minimumDailyDistanceKm: 1,
        maximumDailyDistanceKm: 25,
        walkingDays: 2,
      ),
    );

    expect(failure, RoutePlanFailure.tooFarForSelectedDays);
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
