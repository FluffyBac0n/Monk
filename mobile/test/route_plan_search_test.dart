import 'dart:math';

import 'package:eurotrex/features/accommodation/domain/lodging.dart';
import 'package:eurotrex/features/route_planner/domain/route_plan.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/trail/domain/trail_direction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search agrees with exhaustive itineraries across 1200 requests', () {
    final random = Random(7142);
    for (var fixture = 0; fixture < 100; fixture++) {
      var distance = 0.0;
      final stages = List.generate(7, (index) {
        if (index > 0) distance += 2 + random.nextInt(14);
        return TrailStage(
          id: '$index',
          sequence: 7 - index,
          name: '$index',
          accumulatedDistanceKm: distance,
          distanceFromPathKm: 0,
          elevationUpM: random.nextInt(1000).toDouble(),
          elevationDownM: random.nextInt(1000).toDouble(),
          services: {'lodging': random.nextBool(), 'tent': random.nextBool()},
        );
      });
      final lodgings = <Lodging>[
        for (var i = 1; i < 6; i++)
          if (random.nextBool())
            Lodging(
              id: 'stay-$i',
              stageId: '$i',
              priceMinEur: random.nextBool()
                  ? null
                  : (20 + random.nextInt(100)).toDouble(),
            ),
      ];
      for (final direction in TrailDirection.values) {
        final ordered = direction.isReversed
            ? stages.reversed.toList()
            : stages;
        for (final style in RoutePlanStyle.values) {
          for (final constraint in RoutePlanConstraint.values) {
            final request = RoutePlanRequest(
              startStageId: ordered.first.id,
              finishStageId: ordered.last.id,
              minimumDailyDistanceKm: 1 + random.nextInt(5).toDouble(),
              maximumDailyDistanceKm: 15 + random.nextInt(35).toDouble(),
              maximumDailyWalkingMinutes: random.nextBool()
                  ? null
                  : 300 + random.nextInt(300),
              walkingDays: 1 + random.nextInt(6),
              constraint: constraint,
              style: style,
              overnightPreference:
                  RouteOvernightPreference.values[random.nextInt(3)],
              minimumAccommodationPriceEur: 40,
              maximumAccommodationPriceEur: 80,
              includeUnknownAccommodationPrices: random.nextBool(),
            );
            final candidates = <List<int>>[];
            // Enumerate every possible subset of the five intermediate stops.
            // This oracle has no dynamic-programming state pruning.
            for (var mask = 0; mask < 32; mask++) {
              final stops = [
                0,
                for (var i = 1; i < 6; i++)
                  if (mask & (1 << (i - 1)) != 0) i,
                6,
              ];
              if (constraint == RoutePlanConstraint.fixedDays &&
                  stops.length - 1 != request.walkingDays) {
                continue;
              }
              var valid = true;
              for (var leg = 1; leg < stops.length; leg++) {
                final from = stops[leg - 1];
                final to = stops[leg];
                final km =
                    (ordered[to].accumulatedDistanceKm! -
                            ordered[from].accumulatedDistanceKm!)
                        .abs();
                var ascent = 0.0;
                for (var j = from + 1; j <= to; j++) {
                  ascent += direction.isReversed
                      ? ordered[j - 1].elevationDownM!
                      : ordered[j].elevationUpM!;
                }
                final minutes = (km * 12 + ascent / 10).round();
                if (km < request.minimumDailyDistanceKm ||
                    km > request.maximumDailyDistanceKm ||
                    (request.maximumDailyWalkingMinutes != null &&
                        minutes > request.maximumDailyWalkingMinutes!)) {
                  valid = false;
                }
                if (to == 6) continue;
                final atStop = lodgings
                    .where((l) => l.stageId == ordered[to].id)
                    .toList();
                final canStay =
                    request.allowsAccommodation &&
                    (atStop.any(
                          (l) => l.priceMinEur == null
                              ? request.includeUnknownAccommodationPrices
                              : l.priceMinEur! >= 40 && l.priceMinEur! <= 80,
                        ) ||
                        (atStop.isEmpty &&
                            ordered[to].services['lodging'] == true &&
                            request.includeUnknownAccommodationPrices));
                final canCamp =
                    request.allowsCamping &&
                    ordered[to].services['tent'] == true;
                if (!canStay && !canCamp) valid = false;
              }
              if (valid) candidates.add(stops);
            }
            final plan = buildDeterministicRoutePlan(
              stages: stages,
              lodgings: lodgings,
              direction: direction,
              request: request,
            );
            final label = 'fixture $fixture, $direction, $style, $constraint';
            expect(plan != null, candidates.isNotEmpty, reason: label);
            if (plan != null) {
              final stops = [
                0,
                ...plan.days.map(
                  (day) => ordered.indexWhere((s) => s.id == day.finish.id),
                ),
              ];
              expect(candidates, contains(equals(stops)), reason: label);
              expect(plan.totalDistanceKm, distance, reason: label);
              for (final day in plan.days.take(plan.days.length - 1)) {
                if (request.overnightPreference ==
                    RouteOvernightPreference.camping) {
                  expect(day.usesCamping, isTrue, reason: label);
                }
              }
            }
          }
        }
      }
    }
  });

  test('reverse walking effort uses descent of the forward segments', () {
    const stages = [
      TrailStage(
        id: 'start',
        sequence: 2,
        name: 'start',
        services: {},
        accumulatedDistanceKm: 0,
        elevationUpM: 0,
        elevationDownM: 0,
      ),
      TrailStage(
        id: 'finish',
        sequence: 1,
        name: 'finish',
        services: {},
        accumulatedDistanceKm: 10,
        elevationUpM: 1200,
        elevationDownM: 100,
      ),
    ];
    final result = buildDeterministicRoutePlan(
      stages: stages,
      lodgings: [],
      direction: TrailDirection.larnakaToPafos,
      request: const RoutePlanRequest(
        startStageId: 'finish',
        finishStageId: 'start',
        minimumDailyDistanceKm: 1,
        maximumDailyDistanceKm: 15,
        maximumDailyWalkingMinutes: 150,
      ),
    );
    expect(result, isNotNull);
    expect(result!.days.single.ascentM, 100);
    expect(result.days.single.descentM, 1200);
    expect(result.days.single.estimatedWalkingMinutes, 130);
  });
}
