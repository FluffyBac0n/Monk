import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/stages/domain/stage.dart';
import 'package:monk_mobile/features/stages/domain/trail_location_matcher.dart';

void main() {
  group('findNearbyTrailStage', () {
    test(
      'returns the physically nearest stage when the location is on trail',
      () {
        final result = findNearbyTrailStage(
          latitude: 35.00005,
          longitude: 33.0101,
          locationAccuracyM: 5,
          routePoints: _straightRoute,
          stages: const [
            TrailStage(
              id: 'start',
              sequence: 0,
              name: 'Start',
              accumulatedDistanceKm: 0,
              services: {},
            ),
            TrailStage(
              id: 'middle',
              sequence: 1,
              name: 'Middle',
              accumulatedDistanceKm: 1,
              services: {},
            ),
            TrailStage(
              id: 'finish',
              sequence: 2,
              name: 'Finish',
              accumulatedDistanceKm: 2,
              services: {},
            ),
          ],
        );

        expect(result, isNotNull);
        expect(result!.stageId, 'middle');
        expect(result.distanceFromTrailM, lessThan(10));
        expect(result.distanceFromStageM, lessThan(15));
      },
    );

    test('returns null when the location is outside the trail tolerance', () {
      final result = findNearbyTrailStage(
        latitude: 35.01,
        longitude: 33.01,
        locationAccuracyM: 5,
        routePoints: _straightRoute,
        stages: const [
          TrailStage(
            id: 'middle',
            sequence: 1,
            name: 'Middle',
            accumulatedDistanceKm: 1,
            services: {},
          ),
        ],
      );

      expect(result, isNull);
    });

    test('uses reported accuracy to expand the trail tolerance', () {
      const latitudeAbout130MetersFromTrail = 35.00117;
      const stage = TrailStage(
        id: 'middle',
        sequence: 1,
        name: 'Middle',
        accumulatedDistanceKm: 1,
        services: {},
      );

      final accurateLocationResult = findNearbyTrailStage(
        latitude: latitudeAbout130MetersFromTrail,
        longitude: 33.01,
        locationAccuracyM: 5,
        routePoints: _straightRoute,
        stages: const [stage],
      );
      final lowerAccuracyLocationResult = findNearbyTrailStage(
        latitude: latitudeAbout130MetersFromTrail,
        longitude: 33.01,
        locationAccuracyM: 120,
        routePoints: _straightRoute,
        stages: const [stage],
      );

      expect(accurateLocationResult, isNull);
      expect(lowerAccuracyLocationResult, isNotNull);
      expect(lowerAccuracyLocationResult!.stageId, 'middle');
      expect(
        lowerAccuracyLocationResult.distanceFromTrailM,
        inInclusiveRange(125, 135),
      );
    });

    test('uses stage list order to break a physical-distance tie', () {
      const outboundStage = TrailStage(
        id: 'outbound',
        sequence: 0,
        name: 'Outbound',
        accumulatedDistanceKm: 0,
        services: {},
      );
      const returnStage = TrailStage(
        id: 'return',
        sequence: 2,
        name: 'Return',
        accumulatedDistanceKm: 2,
        services: {},
      );
      const retracedRoute = [
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
          lng: 33.01,
          altitudeM: 0,
          distanceKm: 1,
          reverseDistanceKm: 1,
        ),
        RoutePoint(
          pointIndex: 2,
          lat: 35,
          lng: 33,
          altitudeM: 0,
          distanceKm: 2,
          reverseDistanceKm: 0,
        ),
      ];

      final forwardResult = findNearbyTrailStage(
        latitude: 35,
        longitude: 33,
        locationAccuracyM: 5,
        routePoints: retracedRoute,
        stages: const [outboundStage, returnStage],
      );
      final reverseResult = findNearbyTrailStage(
        latitude: 35,
        longitude: 33,
        locationAccuracyM: 5,
        routePoints: retracedRoute,
        stages: const [returnStage, outboundStage],
      );

      expect(forwardResult?.stageId, 'outbound');
      expect(reverseResult?.stageId, 'return');
    });
  });
}

const _straightRoute = [
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
    lng: 33.01,
    altitudeM: 0,
    distanceKm: 1,
    reverseDistanceKm: 1,
  ),
  RoutePoint(
    pointIndex: 2,
    lat: 35,
    lng: 33.02,
    altitudeM: 0,
    distanceKm: 2,
    reverseDistanceKm: 0,
  ),
];
