import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/elevation/domain/elevation_totals.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';

void main() {
  test(
    'calculates total ascent and descent from consecutive profile points',
    () {
      const points = [
        RoutePoint(
          pointIndex: 0,
          lat: 0,
          lng: 0,
          altitudeM: 100,
          distanceKm: 0,
          reverseDistanceKm: 3,
        ),
        RoutePoint(
          pointIndex: 1,
          lat: 0,
          lng: 0,
          altitudeM: 160,
          distanceKm: 1,
          reverseDistanceKm: 2,
        ),
        RoutePoint(
          pointIndex: 2,
          lat: 0,
          lng: 0,
          altitudeM: 125,
          distanceKm: 2,
          reverseDistanceKm: 1,
        ),
        RoutePoint(
          pointIndex: 3,
          lat: 0,
          lng: 0,
          altitudeM: 145,
          distanceKm: 3,
          reverseDistanceKm: 0,
        ),
      ];

      final totals = calculateElevationTotals(points);

      expect(totals.ascentM, 80);
      expect(totals.descentM, 35);
    },
  );

  test('returns zero totals for an empty or single-point profile', () {
    expect(calculateElevationTotals(const []).ascentM, 0);
    expect(
      calculateElevationTotals(const [
        RoutePoint(
          pointIndex: 0,
          lat: 0,
          lng: 0,
          altitudeM: 100,
          distanceKm: 0,
          reverseDistanceKm: 0,
        ),
      ]).descentM,
      0,
    );
  });
}
