import '../../accommodation/domain/lodging.dart';
import '../../stages/domain/stage.dart';
import '../../trail/domain/trail_direction.dart';

enum RoutePlanStyle { budget, balanced, comfort }

class RoutePlanRequest {
  const RoutePlanRequest({
    required this.startStageId,
    required this.finishStageId,
    required this.minimumDailyDistanceKm,
    required this.maximumDailyDistanceKm,
    required this.allowCamping,
    this.accommodationBudgetEur,
    this.style = RoutePlanStyle.balanced,
  });

  final String startStageId;
  final String finishStageId;
  final double minimumDailyDistanceKm;
  final double maximumDailyDistanceKm;
  final bool allowCamping;
  final double? accommodationBudgetEur;
  final RoutePlanStyle style;
}

class RoutePlanDay {
  const RoutePlanDay({
    required this.dayNumber,
    required this.start,
    required this.finish,
    required this.distanceKm,
    required this.ascentM,
    required this.descentM,
    required this.estimatedWalkingMinutes,
    required this.usesCamping,
    required this.accommodation,
    required this.estimatedCostEur,
  });

  final int dayNumber;
  final TrailStage start;
  final TrailStage finish;
  final double distanceKm;
  final double ascentM;
  final double descentM;
  final int estimatedWalkingMinutes;
  final bool usesCamping;
  final Lodging? accommodation;
  final double? estimatedCostEur;
}

class RoutePlan {
  const RoutePlan({
    required this.days,
    required this.estimatedAccommodationCostEur,
    required this.unknownPriceNights,
  });

  final List<RoutePlanDay> days;
  final double estimatedAccommodationCostEur;
  final int unknownPriceNights;

  double get totalDistanceKm =>
      days.fold(0, (total, day) => total + day.distanceKm);
}

RoutePlan? buildDeterministicRoutePlan({
  required List<TrailStage> stages,
  required List<Lodging> lodgings,
  required TrailDirection direction,
  required RoutePlanRequest request,
}) {
  if (request.minimumDailyDistanceKm <= 0 ||
      request.maximumDailyDistanceKm < request.minimumDailyDistanceKm) {
    return null;
  }

  final ordered = direction.isReversed
      ? stages.reversed.toList(growable: false)
      : stages.toList(growable: false);
  final startIndex = ordered.indexWhere(
    (stage) => stage.id == request.startStageId,
  );
  final finishIndex = ordered.indexWhere(
    (stage) => stage.id == request.finishStageId,
  );
  if (startIndex < 0 || finishIndex <= startIndex) return null;

  final routeStages = ordered
      .sublist(startIndex, finishIndex + 1)
      .where(
        (stage) =>
            stage.accumulatedDistanceKm != null &&
            stageIsOnTrail(stage) != false,
      )
      .toList(growable: false);
  if (routeStages.length < 2 ||
      routeStages.first.id != request.startStageId ||
      routeStages.last.id != request.finishStageId) {
    return null;
  }

  final lodgingsByStage = <String, List<Lodging>>{};
  for (final lodging in lodgings) {
    final stageId = lodging.stageId;
    if (stageId == null) continue;
    lodgingsByStage.putIfAbsent(stageId, () => []).add(lodging);
  }

  final states = List.generate(routeStages.length, (_) => <_PlannerState>[]);
  states[0].add(const _PlannerState(score: 0, knownCostEur: 0, legs: []));
  final targetDistance = switch (request.style) {
    RoutePlanStyle.budget => request.maximumDailyDistanceKm,
    RoutePlanStyle.balanced =>
      (request.minimumDailyDistanceKm + request.maximumDailyDistanceKm) / 2,
    RoutePlanStyle.comfort => request.minimumDailyDistanceKm,
  };

  for (
    var sourceIndex = 0;
    sourceIndex < routeStages.length - 1;
    sourceIndex++
  ) {
    for (final sourceState in states[sourceIndex]) {
      for (
        var destinationIndex = sourceIndex + 1;
        destinationIndex < routeStages.length;
        destinationIndex++
      ) {
        final distance = _distanceBetween(
          routeStages[sourceIndex],
          routeStages[destinationIndex],
        );
        if (distance == null) continue;
        if (distance > request.maximumDailyDistanceKm + 0.0001) break;
        if (distance + 0.0001 < request.minimumDailyDistanceKm) continue;

        final isFinalDestination = destinationIndex == routeStages.length - 1;
        final budget = request.accommodationBudgetEur;
        final stop = _resolveOvernightStop(
          stage: routeStages[destinationIndex],
          lodgings:
              lodgingsByStage[routeStages[destinationIndex].id] ?? const [],
          allowCamping: request.allowCamping,
          isFinalDestination: isFinalDestination,
          style: request.style,
          maximumCostEur: budget == null
              ? null
              : budget - sourceState.knownCostEur,
        );
        if (stop == null) continue;

        final nextKnownCost = sourceState.knownCostEur + (stop.costEur ?? 0);
        if (budget != null && nextKnownCost > budget + 0.0001) continue;

        final effort = _effortBetween(
          orderedStages: routeStages,
          sourceIndex: sourceIndex,
          destinationIndex: destinationIndex,
          direction: direction,
        );
        final walkingMinutes = (distance * 12 + effort.ascentM / 10).round();
        final distanceDelta = distance - targetDistance;
        final hasUnknownPrice = stop.costEur == null && !isFinalDestination;
        final legScore = switch (request.style) {
          RoutePlanStyle.budget =>
            distanceDelta * distanceDelta * 0.08 +
                (stop.costEur ?? 0) * 4 +
                (hasUnknownPrice ? 80 : 0) +
                (stop.usesCamping ? 20 : 0),
          RoutePlanStyle.balanced =>
            distanceDelta * distanceDelta +
                (hasUnknownPrice ? 4 : 0) +
                (stop.costEur ?? 0) * 0.002,
          RoutePlanStyle.comfort =>
            distanceDelta * distanceDelta * 1.5 +
                stop.comfortPenalty +
                (hasUnknownPrice ? 35 : 0) +
                (stop.usesCamping ? 120 : 0),
        };
        final score = sourceState.score + legScore;
        final candidate = _PlannerState(
          score: score,
          knownCostEur: nextKnownCost,
          legs: [
            ...sourceState.legs,
            _PlannerLeg(
              start: routeStages[sourceIndex],
              finish: routeStages[destinationIndex],
              distanceKm: distance,
              ascentM: effort.ascentM,
              descentM: effort.descentM,
              estimatedWalkingMinutes: walkingMinutes,
              overnight: stop,
            ),
          ],
        );
        final destinationStates = states[destinationIndex];
        final isDominated = destinationStates.any(
          (existing) =>
              existing.score <= candidate.score &&
              existing.knownCostEur <= candidate.knownCostEur,
        );
        if (isDominated) continue;
        destinationStates.removeWhere(
          (existing) =>
              candidate.score <= existing.score &&
              candidate.knownCostEur <= existing.knownCostEur,
        );
        destinationStates.add(candidate);
      }
    }
  }

  if (states.last.isEmpty) return null;
  states.last.sort((left, right) => left.score.compareTo(right.score));
  final result = states.last.first;
  final days = <RoutePlanDay>[
    for (var index = 0; index < result.legs.length; index++)
      RoutePlanDay(
        dayNumber: index + 1,
        start: result.legs[index].start,
        finish: result.legs[index].finish,
        distanceKm: result.legs[index].distanceKm,
        ascentM: result.legs[index].ascentM,
        descentM: result.legs[index].descentM,
        estimatedWalkingMinutes: result.legs[index].estimatedWalkingMinutes,
        usesCamping: result.legs[index].overnight.usesCamping,
        accommodation: result.legs[index].overnight.lodging,
        estimatedCostEur: result.legs[index].overnight.costEur,
      ),
  ];
  final unknownPriceNights = days
      .where(
        (day) =>
            day.finish.id != request.finishStageId &&
            day.estimatedCostEur == null,
      )
      .length;
  return RoutePlan(
    days: List.unmodifiable(days),
    estimatedAccommodationCostEur: result.knownCostEur,
    unknownPriceNights: unknownPriceNights,
  );
}

double? _distanceBetween(TrailStage start, TrailStage finish) {
  final startDistance = start.accumulatedDistanceKm;
  final finishDistance = finish.accumulatedDistanceKm;
  if (startDistance == null || finishDistance == null) return null;
  return (finishDistance - startDistance).abs();
}

({double ascentM, double descentM}) _effortBetween({
  required List<TrailStage> orderedStages,
  required int sourceIndex,
  required int destinationIndex,
  required TrailDirection direction,
}) {
  var ascent = 0.0;
  var descent = 0.0;
  for (var index = sourceIndex + 1; index <= destinationIndex; index++) {
    final metricsStage = direction.isReversed
        ? orderedStages[index - 1]
        : orderedStages[index];
    ascent += direction.isReversed
        ? metricsStage.elevationDownM ?? 0
        : metricsStage.elevationUpM ?? 0;
    descent += direction.isReversed
        ? metricsStage.elevationUpM ?? 0
        : metricsStage.elevationDownM ?? 0;
  }
  return (ascentM: ascent, descentM: descent);
}

_OvernightStop? _resolveOvernightStop({
  required TrailStage stage,
  required List<Lodging> lodgings,
  required bool allowCamping,
  required bool isFinalDestination,
  required RoutePlanStyle style,
  required double? maximumCostEur,
}) {
  if (isFinalDestination) {
    return const _OvernightStop(
      lodging: null,
      usesCamping: false,
      costEur: 0,
      comfortPenalty: 0,
    );
  }

  final pricedLodgings =
      lodgings
          .where((lodging) {
            final price = _lodgingPrice(lodging);
            return price != null &&
                (maximumCostEur == null || price <= maximumCostEur + 0.0001);
          })
          .toList(growable: false)
        ..sort((left, right) {
          if (style == RoutePlanStyle.comfort) {
            final comfortComparison = _lodgingComfortScore(
              left,
            ).compareTo(_lodgingComfortScore(right));
            if (comfortComparison != 0) return comfortComparison;
          }
          return _lodgingPrice(left)!.compareTo(_lodgingPrice(right)!);
        });
  if (pricedLodgings.isNotEmpty) {
    final lodging = pricedLodgings.first;
    return _OvernightStop(
      lodging: lodging,
      usesCamping: false,
      costEur: _lodgingPrice(lodging),
      comfortPenalty: _lodgingComfortScore(lodging),
    );
  }
  final unpricedLodgings = lodgings
      .where((lodging) => _lodgingPrice(lodging) == null)
      .toList(growable: false);
  if (unpricedLodgings.isNotEmpty ||
      (stage.services['lodging'] == true && lodgings.isEmpty)) {
    return _OvernightStop(
      lodging: unpricedLodgings.firstOrNull,
      usesCamping: false,
      costEur: null,
      comfortPenalty: unpricedLodgings.isEmpty
          ? 18
          : _lodgingComfortScore(unpricedLodgings.first),
    );
  }
  if (allowCamping && stage.services['tent'] == true) {
    return const _OvernightStop(
      lodging: null,
      usesCamping: true,
      costEur: null,
      comfortPenalty: 80,
    );
  }
  return null;
}

double? _lodgingPrice(Lodging lodging) =>
    lodging.priceMinEur ?? lodging.priceMaxEur;

double _lodgingComfortScore(Lodging lodging) {
  final type = lodging.type?.toLowerCase() ?? '';
  final typePenalty = switch (type) {
    final value when value.contains('hotel') || value.contains('resort') => 0,
    final value
        when value.contains('guest') ||
            value.contains('apartment') ||
            value.contains('villa') =>
      4,
    final value when value.contains('hostel') => 12,
    final value when value.contains('camp') => 24,
    _ => 8,
  };
  return typePenalty + (lodging.distanceFromTrailKm ?? 1) * 4;
}

class _PlannerState {
  const _PlannerState({
    required this.score,
    required this.knownCostEur,
    required this.legs,
  });

  final double score;
  final double knownCostEur;
  final List<_PlannerLeg> legs;
}

class _PlannerLeg {
  const _PlannerLeg({
    required this.start,
    required this.finish,
    required this.distanceKm,
    required this.ascentM,
    required this.descentM,
    required this.estimatedWalkingMinutes,
    required this.overnight,
  });

  final TrailStage start;
  final TrailStage finish;
  final double distanceKm;
  final double ascentM;
  final double descentM;
  final int estimatedWalkingMinutes;
  final _OvernightStop overnight;
}

class _OvernightStop {
  const _OvernightStop({
    required this.lodging,
    required this.usesCamping,
    required this.costEur,
    required this.comfortPenalty,
  });

  final Lodging? lodging;
  final bool usesCamping;
  final double? costEur;
  final double comfortPenalty;
}
