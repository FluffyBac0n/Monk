import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/map/domain/map_location_context.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:eurotrex/features/trail/domain/trail_direction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const points = [
    RoutePoint(
      pointIndex: 0,
      lat: 35,
      lng: 33,
      altitudeM: 0,
      distanceKm: 0,
      reverseDistanceKm: 2,
    ),
    RoutePoint(
      pointIndex: 1,
      lat: 35,
      lng: 33.02,
      altitudeM: 0,
      distanceKm: 2,
      reverseDistanceKm: 0,
    ),
  ];
  const stages = [
    TrailStage(
      id: 'start',
      sequence: 2,
      name: 'Start',
      services: {},
      accumulatedDistanceKm: 0,
    ),
    TrailStage(
      id: 'finish',
      sequence: 1,
      name: 'Finish',
      services: {},
      accumulatedDistanceKm: 2,
    ),
  ];

  test(
    'GPS matching works in a background isolate in both directions',
    () async {
      for (final direction in TrailDirection.values) {
        final result = await compute(calculateMapLocationContext, (
          latitude: 35.0001,
          longitude: 33.01,
          accuracyM: 5.0,
          points: points,
          stages: direction.isReversed ? stages.reversed.toList() : stages,
          direction: direction,
        ));

        // The section ends at Finish forwards and Start in reverse.
        expect(result.stageIndex, 1);
        expect(result.distanceM, closeTo(11.119, 0.01));
      }
    },
  );

  test(
    'outside the stage radius still reports distance from the trail',
    () async {
      final result = await compute(calculateMapLocationContext, (
        latitude: 37.0,
        longitude: 33.01,
        accuracyM: 5.0,
        points: points,
        stages: stages,
        direction: TrailDirection.pafosToLarnaka,
      ));

      expect(result.stageIndex, isNull);
      expect(result.distanceM, closeTo(222390, 2));
    },
  );

  test('GPS distance remains available before stage data loads', () async {
    final result = await compute(calculateMapLocationContext, (
      latitude: 35.0001,
      longitude: 33.01,
      accuracyM: 5.0,
      points: points,
      stages: const <TrailStage>[],
      direction: TrailDirection.pafosToLarnaka,
    ));

    expect(result.stageIndex, isNull);
    expect(result.distanceM, closeTo(11.119, 0.01));
  });
}
