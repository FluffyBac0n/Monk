import '../../elevation/domain/route_point.dart';
import '../../stages/domain/stage.dart';
import '../../stages/domain/trail_location_matcher.dart';
import '../../trail/domain/trail_direction.dart';

typedef MapLocationRequest = ({
  double latitude,
  double longitude,
  double accuracyM,
  List<RoutePoint> points,
  List<TrailStage> stages,
  TrailDirection direction,
});

typedef MapLocationContext = ({int? stageIndex, double? distanceM});

/// Isolate-safe calculation so GPS updates do not block map interaction.
MapLocationContext calculateMapLocationContext(MapLocationRequest request) {
  final match = findNearbyTrailStage(
    latitude: request.latitude,
    longitude: request.longitude,
    locationAccuracyM: request.accuracyM,
    routePoints: request.points,
    // The screen supplies walking order; the matcher expects canonical order.
    stages: request.direction.isReversed
        ? request.stages.reversed.toList(growable: false)
        : request.stages,
    direction: request.direction,
    proximityThresholdM: 100000,
  );
  final stageIndex = match == null
      ? -1
      : request.stages.indexWhere((stage) => stage.id == match.stageId);
  return (
    stageIndex: stageIndex < 0 ? null : stageIndex,
    distanceM:
        match?.distanceFromTrailM ??
        distanceFromTrailM(
          latitude: request.latitude,
          longitude: request.longitude,
          routePoints: request.points,
        ),
  );
}
