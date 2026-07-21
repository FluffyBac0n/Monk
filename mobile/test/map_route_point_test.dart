import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/map/presentation/map_screen.dart';

void main() {
  test('finds the route point nearest a stage distance', () {
    const points = [
      RoutePoint(
        pointIndex: 0,
        lat: 34.7,
        lng: 32.4,
        altitudeM: 10,
        distanceKm: 0,
        reverseDistanceKm: 20,
      ),
      RoutePoint(
        pointIndex: 1,
        lat: 34.8,
        lng: 32.5,
        altitudeM: 20,
        distanceKm: 10,
        reverseDistanceKm: 10,
      ),
      RoutePoint(
        pointIndex: 2,
        lat: 34.9,
        lng: 32.6,
        altitudeM: 30,
        distanceKm: 20,
        reverseDistanceKm: 0,
      ),
    ];

    expect(routePointNearestDistance(points, 6).pointIndex, 1);
    expect(routePointNearestDistance(points, -1).pointIndex, 0);
    expect(routePointNearestDistance(points, 30).pointIndex, 2);
  });
}
