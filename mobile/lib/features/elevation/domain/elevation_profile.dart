import 'dart:math' as math;

import 'route_point.dart';

List<RoutePoint> smoothElevationProfile(
  List<RoutePoint> points, {
  int windowRadius = 3,
}) {
  if (points.length < 3 || windowRadius <= 0) return points;

  final altitudePrefix = List<double>.filled(points.length + 1, 0);
  final validPrefix = List<int>.filled(points.length + 1, 0);
  for (var index = 0; index < points.length; index++) {
    final altitude = points[index].altitudeM;
    altitudePrefix[index + 1] =
        altitudePrefix[index] + (altitude.isFinite ? altitude : 0);
    validPrefix[index + 1] = validPrefix[index] + (altitude.isFinite ? 1 : 0);
  }

  return [
    for (var index = 0; index < points.length; index++)
      _copyWithAltitude(
        points[index],
        _windowAverage(
          points: points,
          index: index,
          radius: windowRadius,
          altitudePrefix: altitudePrefix,
          validPrefix: validPrefix,
        ),
      ),
  ];
}

List<RoutePoint> elevationSection(
  List<RoutePoint> points, {
  required double startDistanceKm,
  required double endDistanceKm,
}) {
  if (points.isEmpty || !startDistanceKm.isFinite || !endDistanceKm.isFinite) {
    return const [];
  }
  final start = math.min(startDistanceKm, endDistanceKm);
  final end = math.max(startDistanceKm, endDistanceKm);
  final startPoint = routePointAtDistance(points, start);
  final endPoint = routePointAtDistance(points, end);
  if (startPoint == null || endPoint == null) return const [];
  if ((end - start).abs() < 0.000001) return [startPoint];

  return [
    startPoint,
    for (final point in points)
      if (point.distanceKm > start && point.distanceKm < end) point,
    endPoint,
  ];
}

RoutePoint? routePointAtDistance(List<RoutePoint> points, double distanceKm) {
  if (points.isEmpty || !distanceKm.isFinite) return null;
  if (distanceKm <= points.first.distanceKm) return points.first;
  if (distanceKm >= points.last.distanceKm) return points.last;

  var low = 0;
  var high = points.length - 1;
  while (low + 1 < high) {
    final middle = (low + high) ~/ 2;
    if (points[middle].distanceKm <= distanceKm) {
      low = middle;
    } else {
      high = middle;
    }
  }
  final start = points[low];
  final end = points[high];
  final distanceSpan = end.distanceKm - start.distanceKm;
  if (distanceSpan.abs() < 0.000001) return start;
  final fraction = ((distanceKm - start.distanceKm) / distanceSpan).clamp(
    0.0,
    1.0,
  );
  double interpolate(double first, double second) =>
      first + (second - first) * fraction;

  return RoutePoint(
    pointIndex: start.pointIndex,
    lat: interpolate(start.lat, end.lat),
    lng: interpolate(start.lng, end.lng),
    altitudeM: interpolate(start.altitudeM, end.altitudeM),
    distanceKm: distanceKm,
    reverseDistanceKm: interpolate(
      start.reverseDistanceKm,
      end.reverseDistanceKm,
    ),
  );
}

double _windowAverage({
  required List<RoutePoint> points,
  required int index,
  required int radius,
  required List<double> altitudePrefix,
  required List<int> validPrefix,
}) {
  final start = math.max(0, index - radius);
  final end = math.min(points.length, index + radius + 1);
  final validCount = validPrefix[end] - validPrefix[start];
  if (validCount == 0) return points[index].altitudeM;
  return (altitudePrefix[end] - altitudePrefix[start]) / validCount;
}

RoutePoint _copyWithAltitude(RoutePoint point, double altitudeM) => RoutePoint(
  pointIndex: point.pointIndex,
  lat: point.lat,
  lng: point.lng,
  altitudeM: altitudeM,
  distanceKm: point.distanceKm,
  reverseDistanceKm: point.reverseDistanceKm,
);
