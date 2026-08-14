import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/elevation/domain/elevation_profile.dart';
import 'package:eurotrex/features/elevation/domain/elevation_totals.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';

void main() {
  test('smooths altitude jitter without changing route positions', () {
    final points = [
      for (var index = 0; index < 5; index++)
        RoutePoint(
          pointIndex: index,
          lat: 34 + index / 100,
          lng: 32 + index / 100,
          altitudeM: index * 10,
          distanceKm: index.toDouble(),
          reverseDistanceKm: (4 - index).toDouble(),
        ),
    ];

    final smoothed = smoothElevationProfile(points, windowRadius: 1);

    expect(smoothed.map((point) => point.altitudeM), [5, 10, 20, 30, 35]);
    expect(
      smoothed.map((point) => point.distanceKm),
      points.map((point) => point.distanceKm),
    );
    expect(smoothed.first.lat, points.first.lat);
    expect(smoothed.last.lng, points.last.lng);
  });

  test('extracts a stage profile with interpolated boundaries', () {
    final points = [
      for (var index = 0; index < 4; index++)
        RoutePoint(
          pointIndex: index,
          lat: index.toDouble(),
          lng: index.toDouble(),
          altitudeM: index * 100,
          distanceKm: index.toDouble(),
          reverseDistanceKm: (3 - index).toDouble(),
        ),
    ];

    final section = elevationSection(
      points,
      startDistanceKm: 0.5,
      endDistanceKm: 2.5,
    );

    expect(section.map((point) => point.distanceKm), [0.5, 1, 2, 2.5]);
    expect(section.first.altitudeM, 50);
    expect(section.last.altitudeM, 250);
  });

  test('filters sub-threshold jitter while preserving accumulated climbs', () {
    final altitudes = <double>[0, 0.5, 1, 2, 1.5, -1];
    final points = [
      for (var index = 0; index < altitudes.length; index++)
        RoutePoint(
          pointIndex: index,
          lat: 0,
          lng: 0,
          altitudeM: altitudes[index],
          distanceKm: index.toDouble(),
          reverseDistanceKm: (altitudes.length - 1 - index).toDouble(),
        ),
    ];

    final totals = calculateElevationTotals(points, minimumChangeM: 1.5);

    expect(totals.ascentM, 2);
    expect(totals.descentM, 3);
  });
}
