import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/stages/domain/stage.dart';
import 'package:monk_mobile/features/stages/domain/trail_location_matcher.dart';
import 'package:monk_mobile/features/trail/domain/trail_direction.dart';

void main() {
  group('findNearbyTrailStage', () {
    test('matches the stage section at the midpoint of a long leg', () {
      final result = findNearbyTrailStage(
        latitude: 35.00004,
        longitude: 33.05002,
        locationAccuracyM: 5,
        routePoints: _sectionRoute,
        stages: _sectionStages,
        direction: TrailDirection.pafosToLarnaka,
      );

      expect(result, isNotNull);
      expect(result!.stageId, 'long-leg-end');
      expect(result.distanceFromTrailM, lessThan(10));
      expect(result.projectedRouteDistanceKm, closeTo(5, 0.01));
    });

    test('maps the same long section to its reverse destination', () {
      final result = findNearbyTrailStage(
        latitude: 35.00004,
        longitude: 33.05002,
        locationAccuracyM: 5,
        routePoints: _sectionRoute,
        stages: _sectionStages,
        direction: TrailDirection.larnakaToPafos,
      );

      expect(result, isNotNull);
      expect(result!.stageId, 'start');
      expect(result.projectedRouteDistanceKm, closeTo(5, 0.01));
    });

    test('uses the forward stage boundary on and around a waypoint', () {
      for (final testCase in const [
        (distanceKm: 9.9, expectedStageId: 'long-leg-end'),
        (distanceKm: 10.0, expectedStageId: 'long-leg-end'),
        (distanceKm: 10.1, expectedStageId: 'finish'),
      ]) {
        final result = findNearbyTrailStage(
          latitude: 35,
          longitude: _longitudeAtDistance(testCase.distanceKm),
          locationAccuracyM: 5,
          routePoints: _sectionRoute,
          stages: _sectionStages,
          direction: TrailDirection.pafosToLarnaka,
        );

        expect(
          result?.stageId,
          testCase.expectedStageId,
          reason: 'route distance ${testCase.distanceKm}',
        );
        expect(
          result?.projectedRouteDistanceKm,
          closeTo(testCase.distanceKm, 0.001),
        );
      }
    });

    test('uses the reverse stage boundary on and around a waypoint', () {
      for (final testCase in const [
        (distanceKm: 10.1, expectedStageId: 'long-leg-end'),
        (distanceKm: 10.0, expectedStageId: 'long-leg-end'),
        (distanceKm: 9.9, expectedStageId: 'start'),
      ]) {
        final result = findNearbyTrailStage(
          latitude: 35,
          longitude: _longitudeAtDistance(testCase.distanceKm),
          locationAccuracyM: 5,
          routePoints: _sectionRoute,
          stages: _sectionStages,
          direction: TrailDirection.larnakaToPafos,
        );

        expect(
          result?.stageId,
          testCase.expectedStageId,
          reason: 'route distance ${testCase.distanceKm}',
        );
        expect(
          result?.projectedRouteDistanceKm,
          closeTo(testCase.distanceKm, 0.001),
        );
      }
    });

    test('interpolates route distance across a coarse GPX segment', () {
      final result = findNearbyTrailStage(
        latitude: 35.00004,
        longitude: _longitudeAtDistance(5),
        locationAccuracyM: 5,
        routePoints: const [
          RoutePoint(
            pointIndex: 0,
            lat: 35,
            lng: 33,
            altitudeM: 0,
            distanceKm: 0,
            reverseDistanceKm: 12,
          ),
          RoutePoint(
            pointIndex: 1,
            lat: 35,
            lng: 33.12,
            altitudeM: 0,
            distanceKm: 12,
            reverseDistanceKm: 0,
          ),
        ],
        stages: _sectionStages,
        direction: TrailDirection.pafosToLarnaka,
      );

      expect(result, isNotNull);
      expect(result!.stageId, 'long-leg-end');
      expect(result.distanceFromTrailM, lessThan(10));
      expect(result.projectedRouteDistanceKm, closeTo(5, 0.01));
    });

    test('returns null when the midpoint is outside trail tolerance', () {
      final result = findNearbyTrailStage(
        latitude: 35.002,
        longitude: _longitudeAtDistance(5),
        locationAccuracyM: 5,
        routePoints: _sectionRoute,
        stages: _sectionStages,
        direction: TrailDirection.pafosToLarnaka,
      );

      expect(result, isNull);
    });

    test('uses reported accuracy to expand the trail tolerance', () {
      const latitudeAbout130MetersFromTrail = 35.00117;

      final accurateLocationResult = findNearbyTrailStage(
        latitude: latitudeAbout130MetersFromTrail,
        longitude: _longitudeAtDistance(5),
        locationAccuracyM: 5,
        routePoints: _sectionRoute,
        stages: _sectionStages,
        direction: TrailDirection.pafosToLarnaka,
      );
      final lowerAccuracyLocationResult = findNearbyTrailStage(
        latitude: latitudeAbout130MetersFromTrail,
        longitude: _longitudeAtDistance(5),
        locationAccuracyM: 120,
        routePoints: _sectionRoute,
        stages: _sectionStages,
        direction: TrailDirection.pafosToLarnaka,
      );

      expect(accurateLocationResult, isNull);
      expect(lowerAccuracyLocationResult, isNotNull);
      expect(lowerAccuracyLocationResult!.stageId, 'long-leg-end');
      expect(
        lowerAccuracyLocationResult.distanceFromTrailM,
        inInclusiveRange(125, 135),
      );
      expect(
        lowerAccuracyLocationResult.projectedRouteDistanceKm,
        closeTo(5, 0.01),
      );
    });

    test('uses walking direction to resolve a retraced-route tie', () {
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
      const retracedStages = [
        TrailStage(
          id: 'outbound',
          sequence: 0,
          name: 'Outbound',
          accumulatedDistanceKm: 0,
          services: {},
        ),
        TrailStage(
          id: 'return',
          sequence: 2,
          name: 'Return',
          accumulatedDistanceKm: 2,
          services: {},
        ),
      ];

      final forwardResult = findNearbyTrailStage(
        latitude: 35,
        longitude: 33,
        locationAccuracyM: 5,
        routePoints: retracedRoute,
        stages: retracedStages,
        direction: TrailDirection.pafosToLarnaka,
      );
      final reverseResult = findNearbyTrailStage(
        latitude: 35,
        longitude: 33,
        locationAccuracyM: 5,
        routePoints: retracedRoute,
        stages: retracedStages,
        direction: TrailDirection.larnakaToPafos,
      );

      expect(forwardResult?.stageId, 'outbound');
      expect(forwardResult?.projectedRouteDistanceKm, 0);
      expect(reverseResult?.stageId, 'return');
      expect(reverseResult?.projectedRouteDistanceKm, 2);
    });
  });
}

double _longitudeAtDistance(double distanceKm) => 33 + distanceKm * 0.01;

const _sectionStages = [
  TrailStage(
    id: 'start',
    sequence: 0,
    name: 'Start',
    accumulatedDistanceKm: 0,
    segmentLengthKm: 0,
    services: {},
  ),
  TrailStage(
    id: 'long-leg-end',
    sequence: 1,
    name: 'Long leg end',
    accumulatedDistanceKm: 10,
    segmentLengthKm: 10,
    services: {},
  ),
  TrailStage(
    id: 'finish',
    sequence: 2,
    name: 'Finish',
    accumulatedDistanceKm: 12,
    segmentLengthKm: 2,
    services: {},
  ),
];

const _sectionRoute = [
  RoutePoint(
    pointIndex: 0,
    lat: 35,
    lng: 33,
    altitudeM: 0,
    distanceKm: 0,
    reverseDistanceKm: 12,
  ),
  RoutePoint(
    pointIndex: 1,
    lat: 35,
    lng: 33.05,
    altitudeM: 0,
    distanceKm: 5,
    reverseDistanceKm: 7,
  ),
  RoutePoint(
    pointIndex: 2,
    lat: 35,
    lng: 33.099,
    altitudeM: 0,
    distanceKm: 9.9,
    reverseDistanceKm: 2.1,
  ),
  RoutePoint(
    pointIndex: 3,
    lat: 35,
    lng: 33.1,
    altitudeM: 0,
    distanceKm: 10,
    reverseDistanceKm: 2,
  ),
  RoutePoint(
    pointIndex: 4,
    lat: 35,
    lng: 33.101,
    altitudeM: 0,
    distanceKm: 10.1,
    reverseDistanceKm: 1.9,
  ),
  RoutePoint(
    pointIndex: 5,
    lat: 35,
    lng: 33.11,
    altitudeM: 0,
    distanceKm: 11,
    reverseDistanceKm: 1,
  ),
  RoutePoint(
    pointIndex: 6,
    lat: 35,
    lng: 33.12,
    altitudeM: 0,
    distanceKm: 12,
    reverseDistanceKm: 0,
  ),
];
