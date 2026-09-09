import '../../accommodation/domain/lodging.dart';
import '../../stages/domain/stage.dart';
import '../../trail/domain/trail_direction.dart';

enum RoutePlanStyle { relaxed, balanced, adventurous }

enum RouteOvernightPreference { accommodation, camping, either }

enum RoutePlanConstraint { fixedDays, dailyPace }

enum RoutePaceUnit { hours, distance }

enum RoutePlanFailure {
  invalidEndpoints,
  tooFarForSelectedDays,
  tooManySelectedDays,
  dailyPaceExceeded,
  unknownPricesExcluded,
  accommodationBudget,
  overnightPreference,
  exactDayCount,
  noOvernightStops,
}

class RoutePlanRequest {
  const RoutePlanRequest({
    required this.startStageId,
    required this.finishStageId,
    required this.minimumDailyDistanceKm,
    required this.maximumDailyDistanceKm,
    this.maximumDailyWalkingMinutes,
    this.walkingDays,
    this.startDate,
    this.overnightPreference = RouteOvernightPreference.accommodation,
    this.minimumAccommodationPriceEur,
    this.maximumAccommodationPriceEur,
    this.preferredDailyDistanceKm,
    this.constraint = RoutePlanConstraint.fixedDays,
    this.paceUnit = RoutePaceUnit.hours,
    this.paceValue = 6,
    this.includeUnknownAccommodationPrices = true,
    this.style = RoutePlanStyle.balanced,
  });

  final String startStageId;
  final String finishStageId;
  final double minimumDailyDistanceKm;
  final double maximumDailyDistanceKm;
  final int? maximumDailyWalkingMinutes;
  final int? walkingDays;
  final DateTime? startDate;
  final RouteOvernightPreference overnightPreference;
  final double? minimumAccommodationPriceEur;
  final double? maximumAccommodationPriceEur;
  final double? preferredDailyDistanceKm;
  final RoutePlanConstraint constraint;
  final RoutePaceUnit paceUnit;
  final double paceValue;
  final bool includeUnknownAccommodationPrices;
  final RoutePlanStyle style;

  bool get allowsAccommodation =>
      overnightPreference != RouteOvernightPreference.camping;

  bool get allowsCamping =>
      overnightPreference != RouteOvernightPreference.accommodation;

  RoutePlanRequest copyWith({
    int? walkingDays,
    bool clearWalkingDays = false,
    int? maximumDailyWalkingMinutes,
    bool clearMaximumDailyWalkingMinutes = false,
    RouteOvernightPreference? overnightPreference,
    double? minimumAccommodationPriceEur,
    double? maximumAccommodationPriceEur,
    bool clearAccommodationPriceRange = false,
    double? preferredDailyDistanceKm,
    RoutePlanConstraint? constraint,
    RoutePaceUnit? paceUnit,
    double? paceValue,
    bool? includeUnknownAccommodationPrices,
    RoutePlanStyle? style,
  }) => RoutePlanRequest(
    startStageId: startStageId,
    finishStageId: finishStageId,
    minimumDailyDistanceKm: minimumDailyDistanceKm,
    maximumDailyDistanceKm: maximumDailyDistanceKm,
    maximumDailyWalkingMinutes: clearMaximumDailyWalkingMinutes
        ? null
        : maximumDailyWalkingMinutes ?? this.maximumDailyWalkingMinutes,
    walkingDays: clearWalkingDays ? null : walkingDays ?? this.walkingDays,
    startDate: startDate,
    overnightPreference: overnightPreference ?? this.overnightPreference,
    minimumAccommodationPriceEur: clearAccommodationPriceRange
        ? null
        : minimumAccommodationPriceEur ?? this.minimumAccommodationPriceEur,
    maximumAccommodationPriceEur: clearAccommodationPriceRange
        ? null
        : maximumAccommodationPriceEur ?? this.maximumAccommodationPriceEur,
    preferredDailyDistanceKm:
        preferredDailyDistanceKm ?? this.preferredDailyDistanceKm,
    constraint: constraint ?? this.constraint,
    paceUnit: paceUnit ?? this.paceUnit,
    paceValue: paceValue ?? this.paceValue,
    includeUnknownAccommodationPrices:
        includeUnknownAccommodationPrices ??
        this.includeUnknownAccommodationPrices,
    style: style ?? this.style,
  );
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

  RoutePlanDay copyWith({
    int? dayNumber,
    TrailStage? start,
    TrailStage? finish,
    double? distanceKm,
    double? ascentM,
    double? descentM,
    int? estimatedWalkingMinutes,
    bool? usesCamping,
    Lodging? accommodation,
    bool clearAccommodation = false,
    double? estimatedCostEur,
    bool clearEstimatedCost = false,
  }) => RoutePlanDay(
    dayNumber: dayNumber ?? this.dayNumber,
    start: start ?? this.start,
    finish: finish ?? this.finish,
    distanceKm: distanceKm ?? this.distanceKm,
    ascentM: ascentM ?? this.ascentM,
    descentM: descentM ?? this.descentM,
    estimatedWalkingMinutes:
        estimatedWalkingMinutes ?? this.estimatedWalkingMinutes,
    usesCamping: usesCamping ?? this.usesCamping,
    accommodation: clearAccommodation
        ? null
        : accommodation ?? this.accommodation,
    estimatedCostEur: clearEstimatedCost
        ? null
        : estimatedCostEur ?? this.estimatedCostEur,
  );
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

  factory RoutePlan.fromDays(List<RoutePlanDay> days) {
    final immutableDays = List<RoutePlanDay>.unmodifiable(days);
    return RoutePlan(
      days: immutableDays,
      estimatedAccommodationCostEur: immutableDays.fold(
        0,
        (total, day) => total + (day.estimatedCostEur ?? 0),
      ),
      unknownPriceNights: immutableDays
          .take(immutableDays.isEmpty ? 0 : immutableDays.length - 1)
          .where((day) => day.estimatedCostEur == null)
          .length,
    );
  }
}

/// Rebuilds an itinerary around user-selected overnight boundaries.
///
/// [stopStageIds] contains only intermediate stops; the request start and
/// finish are always retained. Explicit accommodation choices take precedence
/// over the automatic preference and price ranking.
RoutePlan? buildRoutePlanFromStops({
  required List<TrailStage> stages,
  required List<Lodging> lodgings,
  required TrailDirection direction,
  required RoutePlanRequest request,
  required List<String> stopStageIds,
  Map<String, String> accommodationIdsByStage = const {},
  Set<String> campingStageIds = const {},
}) {
  final ordered = direction.isReversed
      ? stages.reversed.toList(growable: false)
      : stages.toList(growable: false);
  final routeStages = ordered
      .where(
        (stage) =>
            stage.accumulatedDistanceKm != null &&
            stageIsOnTrail(stage) != false,
      )
      .toList(growable: false);
  final indexes = <String, int>{
    for (var index = 0; index < routeStages.length; index++)
      routeStages[index].id: index,
  };
  final startIndex = indexes[request.startStageId];
  final finishIndex = indexes[request.finishStageId];
  if (startIndex == null || finishIndex == null || finishIndex <= startIndex) {
    return null;
  }

  final requestedStops =
      stopStageIds
          .where((id) {
            final index = indexes[id];
            return index != null && index > startIndex && index < finishIndex;
          })
          .toSet()
          .toList(growable: false)
        ..sort((left, right) => indexes[left]!.compareTo(indexes[right]!));
  final boundaryIndexes = <int>[
    startIndex,
    for (final id in requestedStops) indexes[id]!,
    finishIndex,
  ];
  final lodgingById = {for (final lodging in lodgings) lodging.id: lodging};
  final lodgingsByStage = <String, List<Lodging>>{};
  for (final lodging in lodgings) {
    final stageId = lodging.stageId;
    if (stageId != null) {
      lodgingsByStage.putIfAbsent(stageId, () => []).add(lodging);
    }
  }

  final days = <RoutePlanDay>[];
  for (var dayIndex = 0; dayIndex < boundaryIndexes.length - 1; dayIndex++) {
    final sourceIndex = boundaryIndexes[dayIndex];
    final destinationIndex = boundaryIndexes[dayIndex + 1];
    final start = routeStages[sourceIndex];
    final finish = routeStages[destinationIndex];
    final distance = _distanceBetween(start, finish);
    if (distance == null) return null;
    final effort = _effortBetween(
      orderedStages: routeStages,
      sourceIndex: sourceIndex,
      destinationIndex: destinationIndex,
      direction: direction,
    );
    final isFinalDestination = dayIndex == boundaryIndexes.length - 2;
    final explicitLodging = lodgingById[accommodationIdsByStage[finish.id]];
    final _OvernightStop? overnight;
    if (isFinalDestination) {
      overnight = const _OvernightStop(
        lodging: null,
        usesCamping: false,
        costEur: 0,
        comfortPenalty: 0,
      );
    } else if (campingStageIds.contains(finish.id) &&
        finish.services['tent'] == true) {
      overnight = const _OvernightStop(
        lodging: null,
        usesCamping: true,
        costEur: null,
        comfortPenalty: 80,
      );
    } else if (explicitLodging != null &&
        explicitLodging.stageId == finish.id) {
      overnight = _OvernightStop(
        lodging: explicitLodging,
        usesCamping: false,
        costEur: _lodgingPrice(explicitLodging),
        comfortPenalty: _lodgingComfortScore(explicitLodging),
      );
    } else {
      overnight = _resolveOvernightStop(
        stage: finish,
        lodgings: lodgingsByStage[finish.id] ?? const [],
        preference: request.overnightPreference,
        isFinalDestination: false,
        style: request.style,
        minimumPriceEur: request.minimumAccommodationPriceEur,
        maximumPriceEur: request.maximumAccommodationPriceEur,
        includeUnknownPrices: request.includeUnknownAccommodationPrices,
      );
    }
    if (overnight == null) return null;
    days.add(
      RoutePlanDay(
        dayNumber: dayIndex + 1,
        start: start,
        finish: finish,
        distanceKm: distance,
        ascentM: effort.ascentM,
        descentM: effort.descentM,
        estimatedWalkingMinutes: (distance * 12 + effort.ascentM / 10).round(),
        usesCamping: overnight.usesCamping,
        accommodation: overnight.lodging,
        estimatedCostEur: overnight.costEur,
      ),
    );
  }
  return RoutePlan.fromDays(days);
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
  final preferredDistance =
      (request.preferredDailyDistanceKm ??
              (request.minimumDailyDistanceKm +
                      request.maximumDailyDistanceKm) /
                  2)
          .clamp(
            request.minimumDailyDistanceKm,
            request.maximumDailyDistanceKm,
          );
  final targetDistance = switch (request.style) {
    RoutePlanStyle.relaxed => (preferredDistance * 0.85).clamp(
      request.minimumDailyDistanceKm,
      request.maximumDailyDistanceKm,
    ),
    RoutePlanStyle.balanced => preferredDistance,
    RoutePlanStyle.adventurous => (preferredDistance * 1.15).clamp(
      request.minimumDailyDistanceKm,
      request.maximumDailyDistanceKm,
    ),
  };
  final exactWalkingDays = request.constraint == RoutePlanConstraint.fixedDays
      ? request.walkingDays
      : null;

  for (
    var sourceIndex = 0;
    sourceIndex < routeStages.length - 1;
    sourceIndex++
  ) {
    for (final sourceState in states[sourceIndex]) {
      if (exactWalkingDays case final walkingDays?) {
        if (sourceState.legs.length >= walkingDays) continue;
      }
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
        final effort = _effortBetween(
          orderedStages: routeStages,
          sourceIndex: sourceIndex,
          destinationIndex: destinationIndex,
          direction: direction,
        );
        final walkingMinutes = (distance * 12 + effort.ascentM / 10).round();
        final maximumWalkingMinutes = request.maximumDailyWalkingMinutes;
        if (maximumWalkingMinutes != null &&
            walkingMinutes > maximumWalkingMinutes) {
          continue;
        }
        final stop = _resolveOvernightStop(
          stage: routeStages[destinationIndex],
          lodgings:
              lodgingsByStage[routeStages[destinationIndex].id] ?? const [],
          preference: request.overnightPreference,
          isFinalDestination: isFinalDestination,
          style: request.style,
          minimumPriceEur: request.minimumAccommodationPriceEur,
          maximumPriceEur: request.maximumAccommodationPriceEur,
          includeUnknownPrices: request.includeUnknownAccommodationPrices,
        );
        if (stop == null) continue;

        final nextKnownCost = sourceState.knownCostEur + (stop.costEur ?? 0);
        final distanceDelta = distance - targetDistance;
        final hasUnknownPrice = stop.costEur == null && !isFinalDestination;
        final legScore = switch (request.style) {
          RoutePlanStyle.relaxed =>
            distanceDelta * distanceDelta * 1.5 +
                stop.comfortPenalty +
                (hasUnknownPrice ? 35 : 0) +
                (stop.usesCamping ? 120 : 0),
          RoutePlanStyle.balanced =>
            distanceDelta * distanceDelta +
                (hasUnknownPrice ? 4 : 0) +
                (stop.costEur ?? 0) * 0.002,
          RoutePlanStyle.adventurous =>
            distanceDelta * distanceDelta * 0.7 +
                (hasUnknownPrice ? 12 : 0) +
                (stop.usesCamping ? -8 : 0),
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
              (exactWalkingDays == null ||
                  existing.legs.length == candidate.legs.length) &&
              existing.score <= candidate.score &&
              existing.knownCostEur <= candidate.knownCostEur,
        );
        if (isDominated) continue;
        destinationStates.removeWhere(
          (existing) =>
              (exactWalkingDays == null ||
                  existing.legs.length == candidate.legs.length) &&
              candidate.score <= existing.score &&
              candidate.knownCostEur <= existing.knownCostEur,
        );
        destinationStates.add(candidate);
      }
    }
  }

  final completedStates = exactWalkingDays == null
      ? states.last
      : states.last
            .where((state) => state.legs.length == exactWalkingDays)
            .toList(growable: false);
  if (completedStates.isEmpty) return null;
  completedStates.sort((left, right) => left.score.compareTo(right.score));
  final result = completedStates.first;
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

/// Explains the most actionable reason why a request cannot be planned.
RoutePlanFailure diagnoseRoutePlanFailure({
  required List<TrailStage> stages,
  required List<Lodging> lodgings,
  required TrailDirection direction,
  required RoutePlanRequest request,
}) {
  final ordered = direction.isReversed
      ? stages.reversed.toList(growable: false)
      : stages.toList(growable: false);
  final startIndex = ordered.indexWhere(
    (stage) => stage.id == request.startStageId,
  );
  final finishIndex = ordered.indexWhere(
    (stage) => stage.id == request.finishStageId,
  );
  if (startIndex < 0 || finishIndex <= startIndex) {
    return RoutePlanFailure.invalidEndpoints;
  }

  final distance = _distanceBetween(ordered[startIndex], ordered[finishIndex]);
  if (distance == null) return RoutePlanFailure.invalidEndpoints;
  final exactDays = request.constraint == RoutePlanConstraint.fixedDays
      ? request.walkingDays
      : null;
  if (exactDays != null) {
    if (distance > request.maximumDailyDistanceKm * exactDays + 0.0001) {
      return RoutePlanFailure.tooFarForSelectedDays;
    }
    if (distance + 0.0001 < request.minimumDailyDistanceKm * exactDays) {
      return RoutePlanFailure.tooManySelectedDays;
    }
  }

  if (!request.includeUnknownAccommodationPrices &&
      buildDeterministicRoutePlan(
            stages: stages,
            lodgings: lodgings,
            direction: direction,
            request: request.copyWith(includeUnknownAccommodationPrices: true),
          ) !=
          null) {
    return RoutePlanFailure.unknownPricesExcluded;
  }

  final withoutPriceRange = request.copyWith(
    clearAccommodationPriceRange: true,
  );
  if (buildDeterministicRoutePlan(
        stages: stages,
        lodgings: lodgings,
        direction: direction,
        request: withoutPriceRange,
      ) !=
      null) {
    return RoutePlanFailure.accommodationBudget;
  }

  final flexibleStay = withoutPriceRange.copyWith(
    overnightPreference: RouteOvernightPreference.either,
    includeUnknownAccommodationPrices: true,
  );
  if (buildDeterministicRoutePlan(
        stages: stages,
        lodgings: lodgings,
        direction: direction,
        request: flexibleStay,
      ) !=
      null) {
    return RoutePlanFailure.overnightPreference;
  }

  if (exactDays != null &&
      buildDeterministicRoutePlan(
            stages: stages,
            lodgings: lodgings,
            direction: direction,
            request: flexibleStay.copyWith(
              clearWalkingDays: true,
              constraint: RoutePlanConstraint.dailyPace,
            ),
          ) !=
          null) {
    return RoutePlanFailure.exactDayCount;
  }

  if (request.maximumDailyWalkingMinutes != null &&
      buildDeterministicRoutePlan(
            stages: stages,
            lodgings: lodgings,
            direction: direction,
            request: flexibleStay.copyWith(
              clearMaximumDailyWalkingMinutes: true,
              clearWalkingDays: true,
              constraint: RoutePlanConstraint.dailyPace,
            ),
          ) !=
          null) {
    return RoutePlanFailure.dailyPaceExceeded;
  }

  return RoutePlanFailure.noOvernightStops;
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
  required RouteOvernightPreference preference,
  required bool isFinalDestination,
  required RoutePlanStyle style,
  required double? minimumPriceEur,
  required double? maximumPriceEur,
  required bool includeUnknownPrices,
}) {
  if (isFinalDestination) {
    return const _OvernightStop(
      lodging: null,
      usesCamping: false,
      costEur: 0,
      comfortPenalty: 0,
    );
  }

  final matchingLodgings =
      preference == RouteOvernightPreference.camping
            ? <Lodging>[]
            : lodgings
                  .where((lodging) {
                    return _lodgingMatchesPriceRange(
                      lodging,
                      minimumPriceEur: minimumPriceEur,
                      maximumPriceEur: maximumPriceEur,
                      includeUnknownPrices: includeUnknownPrices,
                    );
                  })
                  .toList(growable: false)
        ..sort((left, right) {
          if (style == RoutePlanStyle.relaxed) {
            final comfortComparison = _lodgingComfortScore(
              left,
            ).compareTo(_lodgingComfortScore(right));
            if (comfortComparison != 0) return comfortComparison;
          }
          final leftPrice = _lodgingPrice(left);
          final rightPrice = _lodgingPrice(right);
          if (leftPrice == null) return rightPrice == null ? 0 : 1;
          if (rightPrice == null) return -1;
          return leftPrice.compareTo(rightPrice);
        });
  if (matchingLodgings.isNotEmpty) {
    final lodging = matchingLodgings.first;
    return _OvernightStop(
      lodging: lodging,
      usesCamping: false,
      costEur: _lodgingPrice(lodging),
      comfortPenalty: _lodgingComfortScore(lodging),
    );
  }
  final unpricedLodgings =
      preference == RouteOvernightPreference.camping || !includeUnknownPrices
      ? <Lodging>[]
      : lodgings
            .where((lodging) => _lodgingPrice(lodging) == null)
            .toList(growable: false);
  if (unpricedLodgings.isNotEmpty ||
      (includeUnknownPrices &&
          stage.services['lodging'] == true &&
          lodgings.isEmpty)) {
    return _OvernightStop(
      lodging: unpricedLodgings.firstOrNull,
      usesCamping: false,
      costEur: null,
      comfortPenalty: unpricedLodgings.isEmpty
          ? 18
          : _lodgingComfortScore(unpricedLodgings.first),
    );
  }
  if (preference != RouteOvernightPreference.accommodation &&
      stage.services['tent'] == true) {
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

bool _lodgingMatchesPriceRange(
  Lodging lodging, {
  required double? minimumPriceEur,
  required double? maximumPriceEur,
  required bool includeUnknownPrices,
}) {
  final lodgingMinimum = lodging.priceMinEur ?? lodging.priceMaxEur;
  final lodgingMaximum = lodging.priceMaxEur ?? lodging.priceMinEur;
  if (lodgingMinimum == null || lodgingMaximum == null) {
    return includeUnknownPrices;
  }
  return (minimumPriceEur == null ||
          lodgingMaximum >= minimumPriceEur - 0.0001) &&
      (maximumPriceEur == null || lodgingMinimum <= maximumPriceEur + 0.0001);
}

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
