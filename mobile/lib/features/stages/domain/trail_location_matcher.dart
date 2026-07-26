import 'dart:math' as math;

import '../../elevation/domain/route_point.dart';
import 'stage.dart';

const defaultTrailProximityM = 100.0;
const maximumUsableLocationAccuracyM = 150.0;

class NearbyTrailStage {
  const NearbyTrailStage({
    required this.stageId,
    required this.distanceFromTrailM,
    required this.distanceFromStageM,
  });

  final String stageId;
  final double distanceFromTrailM;
  final double distanceFromStageM;
}

NearbyTrailStage? findNearbyTrailStage({
  required double latitude,
  required double longitude,
  required double locationAccuracyM,
  required List<RoutePoint> routePoints,
  required List<TrailStage> stages,
}) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      routePoints.isEmpty ||
      stages.isEmpty) {
    return null;
  }

  final distanceFromTrailM = _distanceFromRouteM(
    latitude: latitude,
    longitude: longitude,
    routePoints: routePoints,
  );
  final accuracyAllowanceM = locationAccuracyM.isFinite
      ? locationAccuracyM.clamp(0, maximumUsableLocationAccuracyM)
      : 0.0;
  final trailToleranceM = math.max(
    defaultTrailProximityM,
    accuracyAllowanceM + 25,
  );
  if (distanceFromTrailM > trailToleranceM) {
    return null;
  }

  TrailStage? nearestStage;
  var nearestStageDistanceM = double.infinity;
  for (final stage in stages) {
    final distanceKm = stage.accumulatedDistanceKm;
    if (distanceKm == null || !distanceKm.isFinite) continue;
    final routePoint = _routePointNearestDistance(routePoints, distanceKm);
    final stageDistanceM = _haversineDistanceM(
      latitude,
      longitude,
      routePoint.lat,
      routePoint.lng,
    );
    if (stageDistanceM < nearestStageDistanceM) {
      nearestStage = stage;
      nearestStageDistanceM = stageDistanceM;
    }
  }
  if (nearestStage == null) return null;

  return NearbyTrailStage(
    stageId: nearestStage.id,
    distanceFromTrailM: distanceFromTrailM,
    distanceFromStageM: nearestStageDistanceM,
  );
}

double _distanceFromRouteM({
  required double latitude,
  required double longitude,
  required List<RoutePoint> routePoints,
}) {
  if (routePoints.length == 1) {
    final point = routePoints.first;
    return _haversineDistanceM(latitude, longitude, point.lat, point.lng);
  }

  var minimumDistanceM = double.infinity;
  for (var index = 1; index < routePoints.length; index++) {
    final distanceM = _distanceFromSegmentM(
      latitude: latitude,
      longitude: longitude,
      start: routePoints[index - 1],
      end: routePoints[index],
    );
    if (distanceM < minimumDistanceM) {
      minimumDistanceM = distanceM;
    }
  }
  return minimumDistanceM;
}

double _distanceFromSegmentM({
  required double latitude,
  required double longitude,
  required RoutePoint start,
  required RoutePoint end,
}) {
  const earthRadiusM = 6371000.0;
  final latitudeRadians = latitude * math.pi / 180;

  ({double x, double y}) relativePoint(double pointLat, double pointLng) {
    return (
      x:
          (pointLng - longitude) *
          math.pi /
          180 *
          math.cos(latitudeRadians) *
          earthRadiusM,
      y: (pointLat - latitude) * math.pi / 180 * earthRadiusM,
    );
  }

  final startPoint = relativePoint(start.lat, start.lng);
  final endPoint = relativePoint(end.lat, end.lng);
  final segmentX = endPoint.x - startPoint.x;
  final segmentY = endPoint.y - startPoint.y;
  final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;
  if (segmentLengthSquared == 0) {
    return math.sqrt(startPoint.x * startPoint.x + startPoint.y * startPoint.y);
  }

  final projection =
      (-(startPoint.x * segmentX + startPoint.y * segmentY) /
              segmentLengthSquared)
          .clamp(0.0, 1.0);
  final closestX = startPoint.x + projection * segmentX;
  final closestY = startPoint.y + projection * segmentY;
  return math.sqrt(closestX * closestX + closestY * closestY);
}

RoutePoint _routePointNearestDistance(
  List<RoutePoint> points,
  double distanceKm,
) {
  var low = 0;
  var high = points.length - 1;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (points[middle].distanceKm < distanceKm) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  if (low == 0) return points.first;
  final before = points[low - 1];
  final after = points[low];
  return (distanceKm - before.distanceKm).abs() <=
          (after.distanceKm - distanceKm).abs()
      ? before
      : after;
}

double _haversineDistanceM(
  double startLat,
  double startLng,
  double endLat,
  double endLng,
) {
  const earthRadiusM = 6371000.0;
  final latitudeDelta = (endLat - startLat) * math.pi / 180;
  final longitudeDelta = (endLng - startLng) * math.pi / 180;
  final startLatitude = startLat * math.pi / 180;
  final endLatitude = endLat * math.pi / 180;
  final haversine =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(startLatitude) *
          math.cos(endLatitude) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(haversine.clamp(0.0, 1.0)));
}
