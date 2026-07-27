import 'dart:math' as math;

import '../../elevation/domain/route_point.dart';
import '../../trail/domain/trail_direction.dart';
import 'stage.dart';

const defaultTrailProximityM = 100.0;
const maximumUsableLocationAccuracyM = 150.0;

class NearbyTrailStage {
  const NearbyTrailStage({
    required this.stageId,
    required this.distanceFromTrailM,
    required this.projectedRouteDistanceKm,
  });

  final String stageId;
  final double distanceFromTrailM;
  final double projectedRouteDistanceKm;
}

NearbyTrailStage? findNearbyTrailStage({
  required double latitude,
  required double longitude,
  required double locationAccuracyM,
  required List<RoutePoint> routePoints,
  required List<TrailStage> stages,
  required TrailDirection direction,
}) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      routePoints.isEmpty ||
      stages.isEmpty) {
    return null;
  }

  final stageRouteIndex = _buildStageRouteIndex(
    stages: stages,
    direction: direction,
  );
  if (stageRouteIndex.boundaries.isEmpty) return null;

  final match = _nearestStageRouteSection(
    latitude: latitude,
    longitude: longitude,
    routePoints: routePoints,
    stageRouteIndex: stageRouteIndex,
  );
  if (match == null) return null;

  final accuracyAllowanceM = locationAccuracyM.isFinite
      ? locationAccuracyM.clamp(0, maximumUsableLocationAccuracyM)
      : 0.0;
  final trailToleranceM = math.max(
    defaultTrailProximityM,
    accuracyAllowanceM + 25,
  );
  if (match.distanceM > trailToleranceM) return null;

  return NearbyTrailStage(
    stageId: stageRouteIndex.boundaries[match.stageIndex].stage.id,
    distanceFromTrailM: match.distanceM,
    projectedRouteDistanceKm: match.routeDistanceKm,
  );
}

typedef _StageRouteBoundary = ({TrailStage stage, double progressKm});
typedef _StageRouteIndex = ({
  List<_StageRouteBoundary> boundaries,
  bool isReversed,
});
typedef _StageRouteMatch = ({
  int stageIndex,
  double distanceM,
  double routeDistanceKm,
});
typedef _SegmentProjection = ({double distanceM, double fraction});

_StageRouteIndex _buildStageRouteIndex({
  required List<TrailStage> stages,
  required TrailDirection direction,
}) {
  final canonicalBoundaries = <({TrailStage stage, double distanceKm})>[];
  for (final stage in stages) {
    final distanceKm = stage.accumulatedDistanceKm;
    if (distanceKm == null || !distanceKm.isFinite) continue;
    if (canonicalBoundaries.isNotEmpty &&
        (canonicalBoundaries.last.distanceKm - distanceKm).abs() < 0.000001) {
      continue;
    }
    canonicalBoundaries.add((stage: stage, distanceKm: distanceKm));
  }
  final orderedBoundaries = direction.isReversed
      ? canonicalBoundaries.reversed
      : canonicalBoundaries;
  final boundaries = <_StageRouteBoundary>[
    for (final boundary in orderedBoundaries)
      (
        stage: boundary.stage,
        progressKm: direction.isReversed
            ? -boundary.distanceKm
            : boundary.distanceKm,
      ),
  ];
  return (boundaries: boundaries, isReversed: direction.isReversed);
}

_StageRouteMatch? _nearestStageRouteSection({
  required double latitude,
  required double longitude,
  required List<RoutePoint> routePoints,
  required _StageRouteIndex stageRouteIndex,
}) {
  if (routePoints.length == 1) {
    final point = routePoints.first;
    if (!point.lat.isFinite ||
        !point.lng.isFinite ||
        !point.distanceKm.isFinite) {
      return null;
    }
    final stageIndex = _stageIndexAtRouteDistance(
      point.distanceKm,
      stageRouteIndex,
    );
    return (
      stageIndex: stageIndex,
      distanceM: _haversineDistanceM(latitude, longitude, point.lat, point.lng),
      routeDistanceKm: point.distanceKm,
    );
  }

  _StageRouteMatch? bestMatch;
  for (var index = 1; index < routePoints.length; index++) {
    final start = routePoints[index - 1];
    final end = routePoints[index];
    if (!start.lat.isFinite ||
        !start.lng.isFinite ||
        !start.distanceKm.isFinite ||
        !end.lat.isFinite ||
        !end.lng.isFinite ||
        !end.distanceKm.isFinite) {
      continue;
    }
    final projection = _projectOntoSegment(
      latitude: latitude,
      longitude: longitude,
      start: start,
      end: end,
    );
    final routeDistanceKm =
        start.distanceKm +
        (end.distanceKm - start.distanceKm) * projection.fraction;
    final stageIndex = _stageIndexAtRouteDistance(
      routeDistanceKm,
      stageRouteIndex,
    );
    final currentBest = bestMatch;
    if (currentBest == null ||
        projection.distanceM < currentBest.distanceM - 0.01 ||
        ((projection.distanceM - currentBest.distanceM).abs() <= 0.01 &&
            stageIndex < currentBest.stageIndex)) {
      bestMatch = (
        stageIndex: stageIndex,
        distanceM: projection.distanceM,
        routeDistanceKm: routeDistanceKm,
      );
    }
  }
  return bestMatch;
}

int _stageIndexAtRouteDistance(
  double routeDistanceKm,
  _StageRouteIndex stageRouteIndex,
) {
  final progressKm = stageRouteIndex.isReversed
      ? -routeDistanceKm
      : routeDistanceKm;
  final boundaries = stageRouteIndex.boundaries;
  var low = 0;
  var high = boundaries.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (boundaries[middle].progressKm < progressKm) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low.clamp(0, boundaries.length - 1);
}

_SegmentProjection _projectOntoSegment({
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
    return (
      distanceM: math.sqrt(
        startPoint.x * startPoint.x + startPoint.y * startPoint.y,
      ),
      fraction: 0,
    );
  }

  final fraction =
      (-(startPoint.x * segmentX + startPoint.y * segmentY) /
              segmentLengthSquared)
          .clamp(0.0, 1.0)
          .toDouble();
  final closestX = startPoint.x + fraction * segmentX;
  final closestY = startPoint.y + fraction * segmentY;
  return (
    distanceM: math.sqrt(closestX * closestX + closestY * closestY),
    fraction: fraction,
  );
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
