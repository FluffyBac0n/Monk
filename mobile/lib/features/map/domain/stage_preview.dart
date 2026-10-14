import '../../elevation/domain/elevation_profile.dart';
import '../../elevation/domain/route_point.dart';
import '../../stages/domain/stage.dart';

/// Matches the stage details: the section arriving at this stage, or the first
/// section when previewing the trail's start. Stages are in travel order.
List<RoutePoint> stagePreviewPoints({
  required List<RoutePoint> points,
  required List<TrailStage> stages,
  required int stageIndex,
}) {
  if (points.length < 2 ||
      stages.length < 2 ||
      stageIndex < 0 ||
      stageIndex >= stages.length) {
    return const [];
  }
  final start =
      stages[stageIndex == 0 ? 0 : stageIndex - 1].accumulatedDistanceKm;
  final end = stages[stageIndex == 0 ? 1 : stageIndex].accumulatedDistanceKm;
  if (start == null ||
      end == null ||
      !start.isFinite ||
      !end.isFinite ||
      (end - start).abs() < 0.001) {
    return const [];
  }
  final section = elevationSection(
    points,
    startDistanceKm: start,
    endDistanceKm: end,
  );
  return end < start ? section.reversed.toList(growable: false) : section;
}
