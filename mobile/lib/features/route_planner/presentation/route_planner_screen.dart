import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/location/device_location.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../../core/theme/eurotrex_chrome_theme.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../../accommodation/domain/lodging.dart';
import '../../accommodation/presentation/accommodation_controller.dart';
import '../../elevation/domain/route_point.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../map/domain/offline_map_state.dart';
import '../../map/presentation/map_screen.dart';
import '../../map/presentation/offline_map_controller.dart';
import '../../stages/domain/stage.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../trail/domain/trail_direction.dart';
import '../../trail/presentation/trail_direction_controller.dart';
import '../domain/route_plan.dart';
import '../domain/saved_route.dart';
import 'saved_routes_controller.dart';

const _sand = Color(0xFFF4F2EC);
const _green = Color(0xFF277653);
const _outline = Color(0xFFD8DDDA);
const _comfort = Color(0xFF75588A);

class _PlannedVariant {
  const _PlannedVariant({
    required this.plan,
    required this.direction,
    required this.request,
  });

  final RoutePlan plan;
  final TrailDirection direction;
  final RoutePlanRequest request;
}

class _SectionEstimate {
  const _SectionEstimate({
    required this.distanceKm,
    required this.ascentM,
    required this.estimatedWalkingMinutes,
    required this.suggestedDays,
  });

  final double distanceKm;
  final double ascentM;
  final int estimatedWalkingMinutes;
  final int suggestedDays;
}

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  bool showWizard = false;
  int step = 0;
  int walkingDays = 5;
  DateTime startDate = DateUtils.dateOnly(DateTime.now());
  RoutePaceUnit paceUnit = RoutePaceUnit.hours;
  double paceValue = 6;
  RoutePlanConstraint planConstraint = RoutePlanConstraint.fixedDays;
  RouteOvernightPreference overnightPreference =
      RouteOvernightPreference.accommodation;
  RangeValues accommodationPriceRange = const RangeValues(40, 120);
  bool includeUnknownPrices = true;
  Map<RoutePlanStyle, _PlannedVariant?> variants = const {};
  Map<RoutePlanStyle, RoutePlanFailure?> variantFailures = const {};
  RoutePlanStyle? selectedStyle;
  String? customStartStageId;
  String? customFinishStageId;
  String? draftRouteId;
  bool saving = false;
  bool selectedRouteSaved = false;

  void startNewRoute(List<TrailStage> stages, MeasurementSystem system) =>
      setState(() {
        final forward = orderedStages(stages, TrailDirection.pafosToLarnaka);
        final start = forward.firstOrNull;
        TrailStage? finish;
        if (start?.accumulatedDistanceKm case final startDistance?
            when forward.length > 1) {
          const targetDistance = 100.0;
          finish = forward
              .skip(1)
              .reduce(
                (left, right) =>
                    ((left.accumulatedDistanceKm ?? startDistance) -
                                startDistance -
                                targetDistance)
                            .abs() <=
                        ((right.accumulatedDistanceKm ?? startDistance) -
                                startDistance -
                                targetDistance)
                            .abs()
                    ? left
                    : right,
              );
        }
        showWizard = true;
        step = 0;
        walkingDays = 5;
        startDate = DateUtils.dateOnly(DateTime.now());
        paceUnit = RoutePaceUnit.hours;
        paceValue = 6;
        planConstraint = RoutePlanConstraint.fixedDays;
        overnightPreference = RouteOvernightPreference.accommodation;
        accommodationPriceRange = const RangeValues(40, 120);
        includeUnknownPrices = true;
        variants = const {};
        variantFailures = const {};
        selectedStyle = null;
        selectedRouteSaved = false;
        customStartStageId = start?.id;
        customFinishStageId = finish?.id ?? forward.lastOrNull?.id;
        draftRouteId = null;
      });

  List<TrailStage> orderedStages(
    List<TrailStage> stages,
    TrailDirection direction,
  ) {
    final ordered = direction.isReversed ? stages.reversed : stages;
    return ordered
        .where(
          (stage) =>
              stage.accumulatedDistanceKm != null &&
              stageIsOnTrail(stage) != false,
        )
        .toList(growable: false);
  }

  RoutePlanRequest requestFor(
    RoutePlanStyle style,
    TrailStage start,
    TrailStage finish,
    MeasurementSystem system,
  ) {
    final enteredDistanceKm = system == MeasurementSystem.metric
        ? paceValue
        : paceValue / 0.621371;
    final dailyTargetKm = paceUnit == RoutePaceUnit.hours
        ? paceValue * 5
        : enteredDistanceKm;
    final sectionDistance =
        ((finish.accumulatedDistanceKm ?? 0) -
                (start.accumulatedDistanceKm ?? 0))
            .abs();
    final requiredDailyKm = sectionDistance / math.max(1, walkingDays);
    final maximumDistance = planConstraint == RoutePlanConstraint.fixedDays
        ? math.max(dailyTargetKm * 1.75, requiredDailyKm * 1.2)
        : paceUnit == RoutePaceUnit.distance
        ? dailyTargetKm
        : dailyTargetKm * 1.65;
    final usesAccommodation =
        overnightPreference != RouteOvernightPreference.camping;
    return RoutePlanRequest(
      startStageId: start.id,
      finishStageId: finish.id,
      minimumDailyDistanceKm: 1,
      maximumDailyDistanceKm: maximumDistance,
      preferredDailyDistanceKm: dailyTargetKm,
      maximumDailyWalkingMinutes:
          planConstraint == RoutePlanConstraint.dailyPace &&
              paceUnit == RoutePaceUnit.hours
          ? (paceValue * 60).round()
          : null,
      walkingDays: planConstraint == RoutePlanConstraint.fixedDays
          ? walkingDays
          : null,
      startDate: startDate,
      constraint: planConstraint,
      paceUnit: paceUnit,
      paceValue: paceValue,
      overnightPreference: overnightPreference,
      minimumAccommodationPriceEur: usesAccommodation
          ? accommodationPriceRange.start
          : null,
      maximumAccommodationPriceEur: usesAccommodation
          ? accommodationPriceRange.end
          : null,
      includeUnknownAccommodationPrices: includeUnknownPrices,
      style: style,
    );
  }

  void buildRoutes({
    required List<TrailStage> stages,
    required List<Lodging> lodgings,
    required MeasurementSystem system,
  }) {
    setState(() {
      final built = {
        for (final style in RoutePlanStyle.values)
          style: _buildVariant(
            style: style,
            stages: stages,
            lodgings: lodgings,
            system: system,
          ),
      };
      variants = built;
      variantFailures = {
        for (final style in RoutePlanStyle.values)
          style: built[style] == null
              ? _diagnoseFailure(
                  style: style,
                  stages: stages,
                  lodgings: lodgings,
                  system: system,
                )
              : null,
      };
      selectedStyle = built[RoutePlanStyle.balanced] != null
          ? RoutePlanStyle.balanced
          : RoutePlanStyle.values
                .where((style) => built[style] != null)
                .firstOrNull;
      selectedRouteSaved = false;
      step = 3;
    });
  }

  RoutePlanFailure _diagnoseFailure({
    required RoutePlanStyle style,
    required List<TrailStage> stages,
    required List<Lodging> lodgings,
    required MeasurementSystem system,
  }) {
    for (final direction in TrailDirection.values) {
      final ordered = orderedStages(stages, direction);
      final startIndex = ordered.indexWhere(
        (stage) => stage.id == customStartStageId,
      );
      final finishIndex = ordered.indexWhere(
        (stage) => stage.id == customFinishStageId,
      );
      if (startIndex >= 0 && finishIndex > startIndex) {
        return diagnoseRoutePlanFailure(
          stages: stages,
          lodgings: lodgings,
          direction: direction,
          request: requestFor(
            style,
            ordered[startIndex],
            ordered[finishIndex],
            system,
          ),
        );
      }
    }
    return RoutePlanFailure.invalidEndpoints;
  }

  _PlannedVariant? _buildVariant({
    required RoutePlanStyle style,
    required List<TrailStage> stages,
    required List<Lodging> lodgings,
    required MeasurementSystem system,
  }) {
    _PlannedVariant? best;
    var bestScore = double.infinity;
    for (final direction in TrailDirection.values) {
      final ordered = orderedStages(stages, direction);
      if (ordered.length < 2) continue;
      final startId = customStartStageId;
      final finishId = customFinishStageId;
      if (startId == null || finishId == null || startId == finishId) continue;
      final startIndex = ordered.indexWhere((stage) => stage.id == startId);
      final finishIndex = ordered.indexWhere((stage) => stage.id == finishId);
      if (startIndex < 0 || finishIndex <= startIndex) continue;
      final request = requestFor(
        style,
        ordered[startIndex],
        ordered[finishIndex],
        system,
      );
      final plan = buildDeterministicRoutePlan(
        stages: stages,
        lodgings: lodgings,
        direction: direction,
        request: request,
      );
      if (plan == null) continue;
      final score = _planScore(plan, request);
      if (score < bestScore) {
        bestScore = score;
        best = _PlannedVariant(
          plan: plan,
          direction: direction,
          request: request,
        );
      }
    }
    return best;
  }

  double _planScore(RoutePlan plan, RoutePlanRequest request) {
    final target =
        request.preferredDailyDistanceKm ??
        (request.minimumDailyDistanceKm + request.maximumDailyDistanceKm) / 2;
    return plan.days.fold<double>(
          0,
          (score, day) =>
              score + (day.distanceKm - target) * (day.distanceKm - target),
        ) +
        plan.unknownPriceNights * 100;
  }

  _SectionEstimate sectionEstimate(
    List<TrailStage> stages,
    TrailStage start,
    TrailStage finish,
    MeasurementSystem system,
  ) {
    final startIndex = stages.indexWhere((stage) => stage.id == start.id);
    final finishIndex = stages.indexWhere((stage) => stage.id == finish.id);
    final lower = math.min(startIndex, finishIndex);
    final upper = math.max(startIndex, finishIndex);
    var ascent = 0.0;
    if (lower >= 0) {
      for (final stage in stages.sublist(lower + 1, upper + 1)) {
        ascent += stage.elevationUpM ?? 0;
      }
    }
    final distance =
        ((finish.accumulatedDistanceKm ?? 0) -
                (start.accumulatedDistanceKm ?? 0))
            .abs();
    final minutes = (distance * 12 + ascent / 10).round();
    final targetDistance = paceUnit == RoutePaceUnit.hours
        ? paceValue * 5
        : system == MeasurementSystem.metric
        ? paceValue
        : paceValue / 0.621371;
    final daysByDistance = (distance / math.max(1, targetDistance)).ceil();
    final daysByTime = paceUnit == RoutePaceUnit.hours
        ? (minutes / math.max(60, paceValue * 60)).ceil()
        : 1;
    return _SectionEstimate(
      distanceKm: distance,
      ascentM: ascent,
      estimatedWalkingMinutes: minutes,
      suggestedDays: math.max(1, math.max(daysByDistance, daysByTime)),
    );
  }

  void chooseRoute(RoutePlanStyle style) => setState(() {
    selectedStyle = style;
    selectedRouteSaved = false;
  });

  Future<void> saveSelectedRoute() async {
    final style = selectedStyle;
    final variant = style == null ? null : variants[style];
    if (style == null || variant == null) return;
    await _saveRoute(style: style, variant: variant);
  }

  Future<void> _saveRoute({
    required RoutePlanStyle style,
    required _PlannedVariant variant,
  }) async {
    if (saving) return;
    final id = draftRouteId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final saved = SavedRoute.fromPlan(
      id: id,
      createdAt: DateTime.now(),
      style: style,
      direction: variant.direction,
      request: variant.request,
      plan: variant.plan,
    );
    setState(() => saving = true);
    try {
      await ref.read(savedRoutesProvider.notifier).save(saved);
      if (mounted) {
        setState(() {
          draftRouteId = id;
          selectedStyle = style;
          selectedRouteSaved = true;
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> replaceSelectedPlan(RoutePlan plan) async {
    final style = selectedStyle;
    if (style == null) return;
    final current = variants[style];
    if (current == null) return;
    final updated = _PlannedVariant(
      plan: plan,
      direction: current.direction,
      request: current.request,
    );
    setState(() {
      variants = {...variants, style: updated};
      selectedRouteSaved = false;
    });
  }

  Future<void> editBoundary({
    required int dayIndex,
    required List<TrailStage> stages,
    required List<Lodging> lodgings,
  }) async {
    final style = selectedStyle;
    final variant = style == null ? null : variants[style];
    if (variant == null || dayIndex >= variant.plan.days.length - 1) return;
    final ordered = orderedStages(stages, variant.direction);
    final previousId = variant.plan.days[dayIndex].start.id;
    final nextId = variant.plan.days[dayIndex + 1].finish.id;
    final previousIndex = ordered.indexWhere((stage) => stage.id == previousId);
    final nextIndex = ordered.indexWhere((stage) => stage.id == nextId);
    if (previousIndex < 0 || nextIndex <= previousIndex + 1) return;
    final lodgingStageIds = {for (final lodging in lodgings) lodging.stageId};
    final candidates = ordered
        .sublist(previousIndex + 1, nextIndex)
        .where(
          (stage) =>
              lodgingStageIds.contains(stage.id) ||
              stage.services['lodging'] == true ||
              stage.services['tent'] == true,
        )
        .toList(growable: false);
    if (candidates.isEmpty) return;
    final selected = await showModalBottomSheet<TrailStage>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: math.min(520, MediaQuery.sizeOf(context).height * 0.72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  context.l10n.t('Move overnight stop'),
                  style: const TextStyle(
                    color: EurotrexPalette.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final stage = candidates[index];
                    final distance =
                        (stage.accumulatedDistanceKm! -
                                variant
                                    .plan
                                    .days[dayIndex]
                                    .start
                                    .accumulatedDistanceKm!)
                            .abs();
                    return ListTile(
                      leading: CircleAvatar(child: Text('${dayIndex + 1}')),
                      title: Text(context.l10n.t(stage.name)),
                      subtitle: Text(
                        '${MeasurementFormatter(ref.read(appSettingsProvider).measurementSystem).distance(distance)} · ${context.l10n.t(lodgingStageIds.contains(stage.id) || stage.services['lodging'] == true ? 'Accommodation' : 'Camping')}',
                      ),
                      trailing:
                          stage.id == variant.plan.days[dayIndex].finish.id
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: _green,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, stage),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    final stops = [
      for (var index = 0; index < variant.plan.days.length - 1; index++)
        index == dayIndex ? selected.id : variant.plan.days[index].finish.id,
    ];
    final accommodationIds = <String, String>{
      for (final day in variant.plan.days)
        if (day.accommodation != null) day.finish.id: day.accommodation!.id,
    };
    final campingIds = {
      for (final day in variant.plan.days)
        if (day.usesCamping) day.finish.id,
    };
    final plan = buildRoutePlanFromStops(
      stages: stages,
      lodgings: lodgings,
      direction: variant.direction,
      request: variant.request,
      stopStageIds: stops,
      accommodationIdsByStage: accommodationIds,
      campingStageIds: campingIds,
    );
    if (plan != null) await replaceSelectedPlan(plan);
  }

  Future<void> chooseAccommodation({
    required int dayIndex,
    required List<Lodging> lodgings,
  }) async {
    final style = selectedStyle;
    final variant = style == null ? null : variants[style];
    if (variant == null || dayIndex >= variant.plan.days.length - 1) return;
    final day = variant.plan.days[dayIndex];
    final choices =
        lodgings
            .where((lodging) => lodging.stageId == day.finish.id)
            .toList(growable: false)
          ..sort(
            (left, right) => (left.distanceFromTrailKm ?? 999).compareTo(
              right.distanceFromTrailKm ?? 999,
            ),
          );
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Text(
                context.l10n.t('Choose where to stay'),
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(context.l10n.t(day.finish.name)),
              const SizedBox(height: 12),
              for (final lodging in choices)
                _LodgingChoiceTile(
                  lodging: lodging,
                  selected: lodging.id == day.accommodation?.id,
                  plannedDate: variant.request.startDate?.add(
                    Duration(days: day.dayNumber - 1),
                  ),
                  onTap: () => Navigator.pop(context, lodging.id),
                ),
              if (day.finish.services['tent'] == true)
                ListTile(
                  leading: const Icon(Icons.cabin_rounded),
                  title: Text(context.l10n.t('Camping stage')),
                  trailing: day.usesCamping
                      ? const Icon(Icons.check_circle_rounded, color: _green)
                      : null,
                  onTap: () => Navigator.pop(context, '__camping__'),
                ),
              if (choices.isEmpty && day.finish.services['tent'] != true)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    context.l10n.t('No accommodation is listed at this stop.'),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    final isCamping = result == '__camping__';
    final lodging = isCamping
        ? null
        : choices.where((item) => item.id == result).firstOrNull;
    final updatedDays = [...variant.plan.days];
    updatedDays[dayIndex] = day.copyWith(
      usesCamping: isCamping,
      accommodation: lodging,
      clearAccommodation: isCamping,
      estimatedCostEur: lodging?.priceMinEur ?? lodging?.priceMaxEur,
      clearEstimatedCost:
          isCamping ||
          (lodging?.priceMinEur == null && lodging?.priceMaxEur == null),
    );
    await replaceSelectedPlan(RoutePlan.fromDays(updatedDays));
  }

  Future<void> openSavedRoute({
    required SavedRoute route,
    required List<TrailStage> stages,
    required List<Lodging> lodgings,
  }) async {
    final request = RoutePlanRequest(
      startStageId: route.startStageId,
      finishStageId: route.finishStageId,
      minimumDailyDistanceKm: route.minimumDailyDistanceKm,
      maximumDailyDistanceKm: route.maximumDailyDistanceKm,
      maximumDailyWalkingMinutes: route.maximumDailyWalkingMinutes,
      preferredDailyDistanceKm: route.preferredDailyDistanceKm,
      walkingDays: route.constraint == RoutePlanConstraint.fixedDays
          ? route.days.length
          : null,
      startDate: route.startDate,
      constraint: route.constraint,
      paceUnit: route.paceUnit,
      paceValue: route.paceValue,
      overnightPreference: route.overnightPreference,
      minimumAccommodationPriceEur: route.minimumAccommodationPriceEur,
      maximumAccommodationPriceEur: route.maximumAccommodationPriceEur,
      includeUnknownAccommodationPrices:
          route.includeUnknownAccommodationPrices,
      style: route.style,
    );
    final plan = buildRoutePlanFromStops(
      stages: stages,
      lodgings: lodgings,
      direction: route.direction,
      request: request,
      stopStageIds: [
        for (final day in route.days.take(route.days.length - 1))
          day.finishStageId,
      ],
      accommodationIdsByStage: {
        for (final day in route.days)
          if (day.accommodationId != null)
            day.finishStageId: day.accommodationId!,
      },
      campingStageIds: {
        for (final day in route.days)
          if (day.usesCamping) day.finishStageId,
      },
    );
    if (plan == null) return;
    setState(() {
      showWizard = true;
      step = 3;
      selectedStyle = route.style;
      selectedRouteSaved = true;
      draftRouteId = route.id;
      walkingDays = route.days.length;
      startDate = route.startDate ?? DateUtils.dateOnly(DateTime.now());
      planConstraint = route.constraint;
      paceUnit = route.paceUnit;
      paceValue = route.paceValue;
      overnightPreference = route.overnightPreference;
      accommodationPriceRange = RangeValues(
        route.minimumAccommodationPriceEur ?? 0,
        route.maximumAccommodationPriceEur ?? 300,
      );
      includeUnknownPrices = route.includeUnknownAccommodationPrices;
      customStartStageId = route.startStageId;
      customFinishStageId = route.finishStageId;
      variants = {
        route.style: _PlannedVariant(
          plan: plan,
          direction: route.direction,
          request: request,
        ),
      };
    });
  }

  void startDay(RoutePlanDay day, TrailDirection direction) {
    final currentDirection = ref.read(trailDirectionProvider);
    if (currentDirection != direction) {
      ref.read(trailDirectionProvider.notifier).toggle();
    }
    final sourceStages = ref.read(stagesProvider).value ?? const <TrailStage>[];
    final displayedStages = direction.isReversed
        ? sourceStages.reversed.toList(growable: false)
        : sourceStages;
    final index = displayedStages.indexWhere(
      (stage) => stage.id == day.start.id,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          initialStageIndex: index < 0 ? null : index,
          initialLodgings: day.accommodation == null
              ? const []
              : [day.accommodation!],
          locationStageId: day.start.id,
          plannedStartDistanceKm: day.start.accumulatedDistanceKm,
          plannedFinishDistanceKm: day.finish.accumulatedDistanceKm,
        ),
      ),
    );
  }

  Future<void> deleteRoute(SavedRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('Delete route')),
        content: Text(context.l10n.t('Delete this saved route?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.t('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-saved-route'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.t('Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(savedRoutesProvider.notifier).delete(route.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(
      appSettingsProvider.select((settings) => settings.measurementSystem),
    );
    final formatter = MeasurementFormatter(system);
    final availableStages =
        ref.watch(stagesProvider).value ?? const <TrailStage>[];
    final availableLodgings =
        ref.watch(lodgingsForTrailProvider).value ?? const <Lodging>[];
    return Scaffold(
      key: const ValueKey('route-planner-screen'),
      backgroundColor: _sand,
      appBar: EurotrexChromeTheme.appBar(
        automaticallyImplyLeading: !showWizard,
        leading: showWizard
            ? IconButton(
                key: const ValueKey('route-planner-close-wizard'),
                tooltip: context.l10n.t('My routes'),
                onPressed: () => setState(() => showWizard = false),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.t(showWizard ? 'New route' : 'Route planner'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              showWizard
                  ? context.l10n.t('Tailored E4 plan')
                  : context.l10n.t('My routes'),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
      body: Theme(
        data: EurotrexPalette.controlsTheme(Theme.of(context)),
        child: showWizard
            ? buildWizardData(formatter, system)
            : _SavedRoutesView(
                routes: ref.watch(savedRoutesProvider),
                formatter: formatter,
                onAdd: () => startNewRoute(availableStages, system),
                onDelete: deleteRoute,
                onOpen: (route) => openSavedRoute(
                  route: route,
                  stages: availableStages,
                  lodgings: availableLodgings,
                ),
              ),
      ),
    );
  }

  Widget buildWizardData(
    MeasurementFormatter formatter,
    MeasurementSystem system,
  ) {
    final stagesValue = ref.watch(stagesProvider);
    final lodgingsValue = ref.watch(lodgingsForTrailProvider);
    final routePoints =
        ref.watch(elevationProvider).value ?? const <RoutePoint>[];
    final offlineMap = mapboxAccessToken.isEmpty
        ? null
        : ref.watch(offlineMapProvider);
    return stagesValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(
        icon: Icons.route_outlined,
        title: context.l10n.t('Trail data is unavailable.'),
      ),
      data: (stages) => lodgingsValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(
          icon: Icons.hotel_outlined,
          title: context.l10n.t(
            'Accommodation information is currently unavailable.',
          ),
        ),
        data: (lodgings) => buildWizard(
          stages,
          lodgings,
          routePoints,
          offlineMap,
          formatter,
          system,
        ),
      ),
    );
  }

  Widget buildWizard(
    List<TrailStage> stages,
    List<Lodging> lodgings,
    List<RoutePoint> routePoints,
    AsyncValue<OfflineMapState>? offlineMap,
    MeasurementFormatter formatter,
    MeasurementSystem system,
  ) {
    final forwardStages = orderedStages(stages, TrailDirection.pafosToLarnaka);
    if (forwardStages.length < 2) {
      return _Message(
        icon: Icons.route_outlined,
        title: context.l10n.t('Trail data is unavailable.'),
      );
    }
    final selectedStartStageId = customStartStageId ?? forwardStages.first.id;
    final selectedFinishStageId = customFinishStageId ?? forwardStages.last.id;
    final start = forwardStages
        .where((stage) => stage.id == selectedStartStageId)
        .firstOrNull;
    final finish = forwardStages
        .where((stage) => stage.id == selectedFinishStageId)
        .firstOrNull;
    final estimate = start == null || finish == null
        ? null
        : sectionEstimate(forwardStages, start, finish, system);
    if (step == 0) {
      return _TripStep(
        startDate: startDate,
        stages: forwardStages,
        routePoints: routePoints,
        startStageId: selectedStartStageId,
        finishStageId: selectedFinishStageId,
        formatter: formatter,
        onDateChanged: (value) => setState(() => startDate = value),
        onStartStageChanged: (value) =>
            setState(() => customStartStageId = value),
        onFinishStageChanged: (value) =>
            setState(() => customFinishStageId = value),
        onSwap: () => setState(() {
          customStartStageId = selectedFinishStageId;
          customFinishStageId = selectedStartStageId;
        }),
        onNext: () => setState(() {
          customStartStageId = selectedStartStageId;
          customFinishStageId = selectedFinishStageId;
          step = 1;
        }),
      );
    }
    return ListView(
      key: const ValueKey('route-planner-content'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _Progress(step: step),
        const SizedBox(height: 14),
        if (step == 1)
          _PaceStep(
            walkingDays: walkingDays,
            constraint: planConstraint,
            unit: paceUnit,
            value: paceValue,
            distanceUnit: formatter.distanceUnit,
            estimate: estimate,
            formatter: formatter,
            startDate: startDate,
            onDaysChanged: (value) => setState(() => walkingDays = value),
            onConstraintChanged: (value) =>
                setState(() => planConstraint = value),
            onUnitChanged: (value) => setState(() {
              paceUnit = value;
              paceValue = value == RoutePaceUnit.hours
                  ? 6
                  : system == MeasurementSystem.metric
                  ? 25
                  : 15.5;
            }),
            onValueChanged: (value) => setState(() => paceValue = value),
            onBack: () => setState(() => step = 0),
            onNext: () => setState(() => step = 2),
          )
        else if (step == 2)
          _StayStep(
            preference: overnightPreference,
            priceRange: accommodationPriceRange,
            includeUnknownPrices: includeUnknownPrices,
            onPreferenceChanged: (value) =>
                setState(() => overnightPreference = value),
            onPriceChanged: (value) =>
                setState(() => accommodationPriceRange = value),
            onIncludeUnknownChanged: (value) =>
                setState(() => includeUnknownPrices = value),
            onBack: () => setState(() => step = 1),
            onBuild: () =>
                buildRoutes(stages: stages, lodgings: lodgings, system: system),
          )
        else
          _CompareStep(
            variants: variants,
            failures: variantFailures,
            selected: selectedStyle,
            saved: selectedRouteSaved,
            formatter: formatter,
            routePoints: routePoints,
            stages: stages,
            lodgings: lodgings,
            offlineMap: offlineMap,
            saving: saving,
            onBack: () => setState(() => step = 2),
            onDone: !selectedRouteSaved
                ? null
                : () => setState(() => showWizard = false),
            onSelect: (style, variant) => chooseRoute(style),
            onSave: saveSelectedRoute,
            onReviewPace: () => setState(() => step = 1),
            onReviewStay: () => setState(() => step = 2),
            onUseSuggestedDays: estimate == null
                ? null
                : () => setState(() {
                    walkingDays = estimate.suggestedDays;
                    planConstraint = RoutePlanConstraint.fixedDays;
                    step = 1;
                  }),
            onEditBoundary: (dayIndex) => editBoundary(
              dayIndex: dayIndex,
              stages: stages,
              lodgings: lodgings,
            ),
            onChooseAccommodation: (dayIndex) =>
                chooseAccommodation(dayIndex: dayIndex, lodgings: lodgings),
            onStartDay: (day) {
              final style = selectedStyle;
              final variant = style == null ? null : variants[style];
              if (variant != null) startDay(day, variant.direction);
            },
            onOpenMap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const MapScreen())),
          ),
      ],
    );
  }
}

class _SavedRoutesView extends StatelessWidget {
  const _SavedRoutesView({
    required this.routes,
    required this.formatter,
    required this.onAdd,
    required this.onDelete,
    required this.onOpen,
  });
  final AsyncValue<List<SavedRoute>> routes;
  final MeasurementFormatter formatter;
  final VoidCallback onAdd;
  final ValueChanged<SavedRoute> onDelete;
  final ValueChanged<SavedRoute> onOpen;

  @override
  Widget build(BuildContext context) => routes.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, _) => _Message(
      icon: Icons.route_outlined,
      title: context.l10n.t('Saved routes are unavailable.'),
    ),
    data: (items) => ListView(
      key: const ValueKey('saved-routes-list'),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.t('My routes'),
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('route-planner-add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.t('Add route')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          _Panel(
            key: const ValueKey('saved-routes-empty'),
            title: context.l10n.t('No routes saved yet'),
            icon: Icons.route_outlined,
            child: Text(
              context.l10n.t(
                'Create a route to keep its itinerary and use it in Stage filters.',
              ),
            ),
          )
        else
          for (final route in items) ...[
            _SavedRouteCard(
              route: route,
              formatter: formatter,
              onDelete: () => onDelete(route),
              onOpen: () => onOpen(route),
            ),
            const SizedBox(height: 10),
          ],
      ],
    ),
  );
}

class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({
    required this.route,
    required this.formatter,
    required this.onDelete,
    required this.onOpen,
  });
  final SavedRoute route;
  final MeasurementFormatter formatter;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = styleColor(route.style);
    return Material(
      key: ValueKey('saved-route-${route.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(styleIcon(route.style), color: color),
        ),
        title: Text(
          '${context.l10n.t(route.startStageName)} → ${context.l10n.t(route.finishStageName)}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${context.l10n.t(styleLabel(route.style))} · ${route.days.length} ${context.l10n.t('walking days')} · ${formatter.distance(route.totalDistanceKm)}',
        ),
        trailing: IconButton(
          key: ValueKey('delete-saved-route-${route.id}'),
          tooltip: context.l10n.t('Delete route'),
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          const Divider(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              key: ValueKey('open-saved-route-${route.id}'),
              onPressed: onOpen,
              icon: const Icon(Icons.edit_road_rounded),
              label: Text(context.l10n.t('Open and edit')),
            ),
          ),
          const SizedBox(height: 10),
          for (final day in route.days) ...[
            _DayCard.saved(day, formatter),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final labels = ['Trip', 'Pace', 'Stay'];
    return Row(
      key: const ValueKey('route-planner-progress'),
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Column(
            children: [
              CircleAvatar(
                key: ValueKey('route-planner-step-${index + 1}'),
                radius: 15,
                backgroundColor: index <= step
                    ? EurotrexPalette.blue
                    : Colors.white,
                child: index < step || step >= labels.length
                    ? const Icon(Icons.check_rounded, size: 18)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index <= step
                              ? Colors.white
                              : EurotrexPalette.blue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.t(labels[index]),
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (index < 2)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 18),
                height: 2,
                color: index < step ? EurotrexPalette.blue : _outline,
              ),
            ),
        ],
      ],
    );
  }
}

class _TripStep extends StatefulWidget {
  const _TripStep({
    required this.startDate,
    required this.stages,
    required this.routePoints,
    required this.startStageId,
    required this.finishStageId,
    required this.formatter,
    required this.onDateChanged,
    required this.onStartStageChanged,
    required this.onFinishStageChanged,
    required this.onSwap,
    required this.onNext,
  });
  final DateTime startDate;
  final List<TrailStage> stages;
  final List<RoutePoint> routePoints;
  final String? startStageId;
  final String? finishStageId;
  final MeasurementFormatter formatter;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String?> onStartStageChanged;
  final ValueChanged<String?> onFinishStageChanged;
  final VoidCallback onSwap;
  final VoidCallback onNext;

  @override
  State<_TripStep> createState() => _TripStepState();
}

class _TripStepState extends State<_TripStep> {
  TrailStage? inspectedStage;

  @override
  Widget build(BuildContext context) {
    final start = widget.stages
        .where((stage) => stage.id == widget.startStageId)
        .firstOrNull;
    final finish = widget.stages
        .where((stage) => stage.id == widget.finishStageId)
        .firstOrNull;
    final distance =
        start?.accumulatedDistanceKm == null ||
            finish?.accumulatedDistanceKm == null
        ? null
        : (start!.accumulatedDistanceKm! - finish!.accumulatedDistanceKm!)
              .abs();
    return Stack(
      key: const ValueKey('route-planner-content'),
      fit: StackFit.expand,
      children: [
        _RouteSelectionMap(
          points: widget.routePoints,
          stages: widget.stages,
          start: start,
          finish: finish,
          onStageInspected: (stage) => setState(() => inspectedStage = stage),
        ),
        Positioned(
          left: 14,
          right: 70,
          top: 12,
          child: Material(
            color: Colors.white.withValues(alpha: 0.96),
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 7),
              child: _Progress(step: 0),
            ),
          ),
        ),
        DraggableScrollableSheet(
          minChildSize: 0.28,
          initialChildSize: 0.42,
          maxChildSize: 0.78,
          snap: true,
          snapSizes: const [0.42, 0.78],
          builder: (context, controller) => Material(
            color: _sand,
            elevation: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 26),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.t('Choose your route'),
                  style: const TextStyle(
                    color: EurotrexPalette.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  start == null || finish == null
                      ? context.l10n.t('Choose a start and finish stage.')
                      : '${context.l10n.t(start.name)} → ${context.l10n.t(finish.name)}${distance == null ? '' : ' · ${widget.formatter.distance(distance)}'}',
                  key: const ValueKey('route-planner-selection-summary'),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (inspectedStage case final stage?) ...[
                  const SizedBox(height: 12),
                  _StageMapCallout(
                    stage: stage,
                    stageNumber: widget.stages.indexOf(stage) + 1,
                    formatter: widget.formatter,
                    onStart: () {
                      widget.onStartStageChanged(stage.id);
                      setState(() => inspectedStage = null);
                    },
                    onFinish: () {
                      widget.onFinishStageChanged(stage.id);
                      setState(() => inspectedStage = null);
                    },
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StageComboBox(
                        key: const ValueKey('route-planner-start-stage'),
                        label: context.l10n.t('Start point'),
                        icon: Icons.trip_origin_rounded,
                        stages: widget.stages,
                        selectedStageId: widget.startStageId,
                        unavailableStageId: widget.finishStageId,
                        formatter: widget.formatter,
                        onChanged: widget.onStartStageChanged,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('route-planner-swap-stages'),
                      tooltip: context.l10n.t('Swap start and finish'),
                      onPressed: widget.onSwap,
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                    Expanded(
                      child: _StageComboBox(
                        key: const ValueKey('route-planner-finish-stage'),
                        label: context.l10n.t('Finish point'),
                        icon: Icons.flag_rounded,
                        stages: widget.stages,
                        selectedStageId: widget.finishStageId,
                        unavailableStageId: widget.startStageId,
                        formatter: widget.formatter,
                        onChanged: widget.onFinishStageChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('route-planner-start-date'),
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    '${context.l10n.t('Start date')}: ${MaterialLocalizations.of(context).formatMediumDate(widget.startDate)}',
                  ),
                  onPressed: () async {
                    final defaultFirst = DateTime(2000);
                    final defaultLast = DateTime.now().add(
                      const Duration(days: 730),
                    );
                    final value = await showDatePicker(
                      context: context,
                      initialDate: widget.startDate,
                      firstDate: widget.startDate.isBefore(defaultFirst)
                          ? widget.startDate
                          : defaultFirst,
                      lastDate: widget.startDate.isAfter(defaultLast)
                          ? widget.startDate.add(const Duration(days: 1))
                          : defaultLast,
                    );
                    if (value != null) widget.onDateChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey('route-planner-route-next'),
                  onPressed:
                      widget.startStageId == null ||
                          widget.finishStageId == null ||
                          widget.startStageId == widget.finishStageId
                      ? null
                      : widget.onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(context.l10n.t('Next')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageMapCallout extends StatelessWidget {
  const _StageMapCallout({
    required this.stage,
    required this.stageNumber,
    required this.formatter,
    required this.onStart,
    required this.onFinish,
  });

  final TrailStage stage;
  final int stageNumber;
  final MeasurementFormatter formatter;
  final VoidCallback onStart;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final services = <String>[
      if (stage.services['lodging'] == true) context.l10n.t('Lodging'),
      if (stage.services['tent'] == true) context.l10n.t('Camping'),
      if (stage.services['water'] == true) context.l10n.t('Water'),
    ];
    return Semantics(
      label:
          '${context.l10n.t('Stage')} $stageNumber, ${context.l10n.t(stage.name)}',
      child: Container(
        key: const ValueKey('route-planner-stage-callout'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: EurotrexPalette.blue),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${context.l10n.t('Stage')} $stageNumber · ${context.l10n.t(stage.name)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              [
                if (stage.accumulatedDistanceKm != null)
                  formatter.distance(stage.accumulatedDistanceKm!),
                ...services,
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('route-planner-callout-start'),
                    onPressed: onStart,
                    child: Text(context.l10n.t('Set as start')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('route-planner-callout-finish'),
                    onPressed: onFinish,
                    child: Text(context.l10n.t('Set as finish')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StageComboBox extends StatelessWidget {
  const _StageComboBox({
    super.key,
    required this.label,
    required this.icon,
    required this.stages,
    required this.selectedStageId,
    required this.unavailableStageId,
    required this.formatter,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final List<TrailStage> stages;
  final String? selectedStageId;
  final String? unavailableStageId;
  final MeasurementFormatter formatter;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = stages
        .where((stage) => stage.id == selectedStageId)
        .firstOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final value = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => _StagePickerSheet(
            label: label,
            stages: stages,
            selectedStageId: selectedStageId,
            unavailableStageId: unavailableStageId,
            formatter: formatter,
          ),
        );
        if (value != null) onChanged(value);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.search_rounded),
        ),
        child: Text(
          selected == null
              ? context.l10n.t('Choose stage')
              : context.l10n.t(selected.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _StagePickerSheet extends StatefulWidget {
  const _StagePickerSheet({
    required this.label,
    required this.stages,
    required this.selectedStageId,
    required this.unavailableStageId,
    required this.formatter,
  });

  final String label;
  final List<TrailStage> stages;
  final String? selectedStageId;
  final String? unavailableStageId;
  final MeasurementFormatter formatter;

  @override
  State<_StagePickerSheet> createState() => _StagePickerSheetState();
}

class _StagePickerSheetState extends State<_StagePickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = [
      for (var index = 0; index < widget.stages.length; index++)
        if (query.isEmpty ||
            widget.stages[index].name.toLowerCase().contains(
              query.toLowerCase(),
            ) ||
            '${index + 1}'.contains(query))
          (index: index, stage: widget.stages[index]),
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.76,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                key: const ValueKey('route-planner-stage-search'),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: context.l10n.t('Search by stage or place'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final disabled = item.stage.id == widget.unavailableStageId;
                  return ListTile(
                    enabled: !disabled,
                    leading: CircleAvatar(child: Text('${item.index + 1}')),
                    title: Text(context.l10n.t(item.stage.name)),
                    subtitle: item.stage.accumulatedDistanceKm == null
                        ? null
                        : Text(
                            widget.formatter.distance(
                              item.stage.accumulatedDistanceKm!,
                            ),
                          ),
                    trailing: item.stage.id == widget.selectedStageId
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: EurotrexPalette.blue,
                          )
                        : null,
                    onTap: disabled
                        ? null
                        : () => Navigator.pop(context, item.stage.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerLocatedStage {
  const _PlannerLocatedStage({
    required this.index,
    required this.stage,
    required this.point,
  });

  final int index;
  final TrailStage stage;
  final RoutePoint point;
}

List<Position> _plannerLineCoordinates(
  List<RoutePoint> points, {
  int maximumPoints = 5000,
}) {
  return [
    for (final point in _plannerDisplayPoints(
      points,
      maximumPoints: maximumPoints,
    ))
      Position(point.lng, point.lat),
  ];
}

List<RoutePoint> _plannerDisplayPoints(
  List<RoutePoint> points, {
  int maximumPoints = 5000,
}) {
  if (points.length <= maximumPoints) return points;
  final stride = (points.length / maximumPoints).ceil();
  final simplified = <RoutePoint>[
    for (var index = 0; index < points.length; index += stride) points[index],
  ];
  if (!identical(simplified.last, points.last)) simplified.add(points.last);
  return simplified;
}

class _RouteSelectionMap extends ConsumerStatefulWidget {
  const _RouteSelectionMap({
    required this.points,
    required this.stages,
    required this.start,
    required this.finish,
    required this.onStageInspected,
  });

  final List<RoutePoint> points;
  final List<TrailStage> stages;
  final TrailStage? start;
  final TrailStage? finish;
  final ValueChanged<TrailStage> onStageInspected;

  @override
  ConsumerState<_RouteSelectionMap> createState() => _RouteSelectionMapState();
}

class _RouteSelectionMapState extends ConsumerState<_RouteSelectionMap> {
  MapboxMap? _map;
  PolylineAnnotationManager? _baseRouteManager;
  PolylineAnnotationManager? _selectionRouteManager;
  PointAnnotationManager? _stageManager;
  Cancelable? _stageTapListener;
  final Map<String, int> _stageIndexByAnnotation = {};
  bool _stagesVisible = false;
  bool _locating = false;
  bool _gpsVisible = false;
  bool _mapLoaded = false;
  double _currentZoom = 7;
  int _currentStageVisibilityStride = mapStageVisibilityStride(7);
  bool _updatingZoomLayers = false;

  List<_PlannerLocatedStage> get _locatedStages => [
    for (var index = 0; index < widget.stages.length; index++)
      if (widget.stages[index].accumulatedDistanceKm case final distance?)
        _PlannerLocatedStage(
          index: index,
          stage: widget.stages[index],
          point: routePointNearestDistance(widget.points, distance),
        ),
  ];

  CameraViewportState get _initialViewport {
    final first = widget.points.firstOrNull;
    final last = widget.points.lastOrNull;
    return CameraViewportState(
      center: Point(
        coordinates: Position(
          first == null || last == null ? 33.2 : (first.lng + last.lng) / 2,
          first == null || last == null ? 35.0 : (first.lat + last.lat) / 2,
        ),
      ),
      zoom: 7,
    );
  }

  @override
  void didUpdateWidget(covariant _RouteSelectionMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapLoaded) return;
    final map = _map;
    if (map == null) return;
    if (oldWidget.points != widget.points) {
      unawaited(_redrawMap());
    } else if (oldWidget.start?.id != widget.start?.id ||
        oldWidget.finish?.id != widget.finish?.id) {
      unawaited(_drawSelectedRoute(map));
      unawaited(_drawStages(map));
    } else if (oldWidget.stages != widget.stages) {
      unawaited(_drawStages(map));
    }
  }

  @override
  void dispose() {
    _stageTapListener?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(
      CompassSettings(
        position: OrnamentPosition.TOP_LEFT,
        marginTop: 142,
        marginLeft: 12,
      ),
    );
    await map.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.TOP_LEFT,
        marginTop: 86,
        marginLeft: 12,
      ),
    );
    await map.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.TOP_LEFT,
        marginTop: 116,
        marginLeft: 12,
      ),
    );
  }

  Future<void> _handleMapIdle() async {
    if (_updatingZoomLayers) return;
    final map = _map;
    if (map == null) return;
    _updatingZoomLayers = true;
    try {
      final camera = await map.getCameraState();
      final nextStride = mapStageVisibilityStride(camera.zoom);
      _currentZoom = camera.zoom;
      if (_stagesVisible && nextStride != _currentStageVisibilityStride) {
        _currentStageVisibilityStride = nextStride;
        await _drawStages(map);
      } else {
        _currentStageVisibilityStride = nextStride;
      }
    } finally {
      _updatingZoomLayers = false;
    }
  }

  Future<void> _onMapLoaded(MapLoadedEventData _) async {
    _mapLoaded = true;
    await _redrawMap();
    await _fitTrail();
  }

  Future<void> _redrawMap() async {
    final map = _map;
    if (map == null || widget.points.length < 2) return;
    await _drawBaseRoute(map);
    await _drawSelectedRoute(map);
    await _drawStages(map);
  }

  Future<void> _drawBaseRoute(MapboxMap map) async {
    final previous = _baseRouteManager;
    _baseRouteManager = null;
    if (previous != null) {
      await map.annotations.removeAnnotationManager(previous);
    }
    final manager = await map.annotations.createPolylineAnnotationManager();
    _baseRouteManager = manager;
    await manager.setLineCap(LineCap.ROUND);
    await manager.setLineJoin(LineJoin.ROUND);
    await manager.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: _plannerLineCoordinates(widget.points),
        ),
        lineColor: EurotrexPalette.navy.withValues(alpha: 0.55).toARGB32(),
        lineWidth: 5,
        lineBorderColor: Colors.white.toARGB32(),
        lineBorderWidth: 1.5,
      ),
    );
  }

  Future<void> _drawSelectedRoute(MapboxMap map) async {
    final previous = _selectionRouteManager;
    _selectionRouteManager = null;
    if (previous != null) {
      await map.annotations.removeAnnotationManager(previous);
    }
    final startDistance = widget.start?.accumulatedDistanceKm;
    final finishDistance = widget.finish?.accumulatedDistanceKm;
    if (startDistance == null || finishDistance == null) return;
    final minimumDistance = math.min(startDistance, finishDistance);
    final maximumDistance = math.max(startDistance, finishDistance);
    final selectedPoints = widget.points
        .where(
          (point) =>
              point.distanceKm >= minimumDistance - 0.01 &&
              point.distanceKm <= maximumDistance + 0.01,
        )
        .toList(growable: false);
    if (selectedPoints.length < 2) return;
    final manager = await map.annotations.createPolylineAnnotationManager();
    _selectionRouteManager = manager;
    await manager.setLineCap(LineCap.ROUND);
    await manager.setLineJoin(LineJoin.ROUND);
    await manager.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: _plannerLineCoordinates(selectedPoints),
        ),
        lineColor: EurotrexPalette.blue.toARGB32(),
        lineWidth: 8,
        lineBorderColor: Colors.white.toARGB32(),
        lineBorderWidth: 2,
      ),
    );
  }

  Future<void> _drawStages(MapboxMap map) async {
    _stageTapListener?.cancel();
    _stageTapListener = null;
    final previous = _stageManager;
    _stageManager = null;
    _stageIndexByAnnotation.clear();
    if (previous != null) {
      await map.annotations.removeAnnotationManager(previous);
    }
    final progressiveIndexes = _stagesVisible
        ? mapProgressiveStageIndexes(
            stageIndexes: [for (final item in _locatedStages) item.index],
            zoom: _currentZoom,
          ).toSet()
        : const <int>{};
    final located = _locatedStages
        .where(
          (item) =>
              progressiveIndexes.contains(item.index) ||
              item.stage.id == widget.start?.id ||
              item.stage.id == widget.finish?.id,
        )
        .toList(growable: false);
    if (located.isEmpty) return;
    final manager = await map.annotations.createPointAnnotationManager();
    _stageManager = manager;
    await manager.setTextAllowOverlap(false);
    await manager.setTextIgnorePlacement(false);
    final annotations = await manager.createMulti([
      for (final item in located)
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.point.lng, item.point.lat),
          ),
          textField: item.stage.id == widget.start?.id
              ? 'S'
              : item.stage.id == widget.finish?.id
              ? 'F'
              : '${item.index + 1}',
          textSize:
              item.stage.id == widget.start?.id ||
                  item.stage.id == widget.finish?.id
              ? 14
              : 11,
          textColor:
              item.stage.id == widget.start?.id ||
                  item.stage.id == widget.finish?.id
              ? Colors.white.toARGB32()
              : EurotrexPalette.navy.toARGB32(),
          textHaloColor: item.stage.id == widget.finish?.id
              ? _comfort.toARGB32()
              : item.stage.id == widget.start?.id
              ? EurotrexPalette.blue.toARGB32()
              : Colors.white.toARGB32(),
          textHaloWidth:
              item.stage.id == widget.start?.id ||
                  item.stage.id == widget.finish?.id
              ? 6
              : 4,
          symbolSortKey:
              item.stage.id == widget.start?.id ||
                  item.stage.id == widget.finish?.id
              ? 2
              : 1,
          customData: {'stageIndex': item.index, 'name': item.stage.name},
        ),
    ]);
    for (var index = 0; index < annotations.length; index++) {
      final annotation = annotations[index];
      if (annotation != null) {
        _stageIndexByAnnotation[annotation.id] = located[index].index;
      }
    }
    _stageTapListener = manager.tapEvents(
      onTap: (annotation) {
        final index = _stageIndexByAnnotation[annotation.id];
        if (index != null && mounted) _inspectStage(index);
      },
    );
  }

  void _inspectStage(int index) {
    if (index < 0 || index >= widget.stages.length) return;
    widget.onStageInspected(widget.stages[index]);
  }

  Future<void> _toggleStages() async {
    setState(() => _stagesVisible = !_stagesVisible);
    final map = _map;
    if (map != null && _mapLoaded) await _drawStages(map);
  }

  Future<void> _fitTrail() async {
    final map = _map;
    if (map == null || widget.points.length < 2) return;
    var minLat = widget.points.first.lat;
    var maxLat = minLat;
    var minLng = widget.points.first.lng;
    var maxLng = minLng;
    for (final point in widget.points.skip(1)) {
      minLat = math.min(minLat, point.lat);
      maxLat = math.max(maxLat, point.lat);
      minLng = math.min(minLng, point.lng);
      maxLng = math.max(maxLng, point.lng);
    }
    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 58, left: 30, bottom: 76, right: 66),
      0,
      0,
      null,
      null,
    );
    await map.flyTo(camera, MapAnimationOptions(duration: 650, startDelay: 0));
  }

  Future<void> _showGps() async {
    final map = _map;
    if (_locating || map == null) return;
    setState(() => _locating = true);
    try {
      final location = await ref.read(deviceLocationReaderProvider)();
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      );
      await map.easeTo(
        CameraOptions(
          center: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          zoom: 14,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 650, startDelay: 0),
      );
      if (mounted) setState(() => _gpsVisible = true);
    } on LocationServicesDisabledException {
      _showMessage('Turn on Location Services to show your position.');
    } on LocationPermissionDeniedException {
      _showMessage('Location permission is needed to show your position.');
    } catch (_) {
      _showMessage('Your location could not be read right now.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.t(message))));
  }

  void _selectFallbackStage(Offset tap, Size size) {
    if (widget.points.length < 2) return;
    final projection = _RouteProjection(widget.points, size);
    _PlannerLocatedStage? nearest;
    var nearestDistance = 30.0;
    for (final item in _locatedStages) {
      final projected = projection.project(item.point);
      final distance = (projected - tap).distance;
      if (distance < nearestDistance) {
        nearest = item;
        nearestDistance = distance;
      }
    }
    if (nearest != null) _inspectStage(nearest.index);
  }

  @override
  Widget build(BuildContext context) {
    final mapAvailable =
        mapboxAccessToken.isNotEmpty && widget.points.length > 1;
    return Container(
      key: const ValueKey('route-planner-selection-map'),
      decoration: BoxDecoration(
        color: EurotrexPalette.paleBlue.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mapAvailable)
            MapWidget(
              key: const ValueKey('route-planner-mapbox-map'),
              styleUri: MapboxStyles.OUTDOORS,
              viewport: _initialViewport,
              onMapCreated: _onMapCreated,
              onMapLoadedListener: _onMapLoaded,
              onMapIdleListener: (_) => _handleMapIdle(),
            )
          else if (widget.points.length < 2)
            Center(child: Text(context.l10n.t('Route map is loading…')))
          else
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _selectFallbackStage(
                  details.localPosition,
                  constraints.biggest,
                ),
                child: CustomPaint(
                  painter: _RouteSelectionPainter(
                    points: widget.points,
                    stages: widget.stages,
                    showAllStages: _stagesVisible,
                    startDistance: widget.start?.accumulatedDistanceKm,
                    finishDistance: widget.finish?.accumulatedDistanceKm,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 84,
            child: Column(
              children: [
                _PlannerMapButton(
                  key: const ValueKey('route-planner-map-stages'),
                  tooltip: context.l10n.t(
                    _stagesVisible ? 'Hide stages' : 'Show all stages',
                  ),
                  active: _stagesVisible,
                  onPressed: _toggleStages,
                  child: const Icon(Icons.signpost_outlined),
                ),
                const SizedBox(height: 8),
                _PlannerMapButton(
                  key: const ValueKey('route-planner-map-gps'),
                  tooltip: context.l10n.t('Show my location'),
                  active: _gpsVisible,
                  onPressed: mapAvailable && !_locating ? _showGps : null,
                  child: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                _PlannerMapButton(
                  key: const ValueKey('route-planner-map-center'),
                  tooltip: context.l10n.t('Center trail'),
                  onPressed: mapAvailable ? _fitTrail : null,
                  child: const Icon(Icons.center_focus_strong_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerMapButton extends StatelessWidget {
  const _PlannerMapButton({
    super.key,
    required this.tooltip,
    required this.child,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => Material(
    color: active ? EurotrexPalette.blue : Colors.white.withValues(alpha: 0.95),
    shape: const CircleBorder(),
    elevation: 2,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: active ? Colors.white : EurotrexPalette.navy,
      disabledColor: EurotrexPalette.navy.withValues(alpha: 0.35),
      iconSize: 21,
      icon: child,
    ),
  );
}

class _RouteSelectionPainter extends CustomPainter {
  const _RouteSelectionPainter({
    required this.points,
    required this.stages,
    required this.showAllStages,
    required this.startDistance,
    required this.finishDistance,
  });

  final List<RoutePoint> points;
  final List<TrailStage> stages;
  final bool showAllStages;
  final double? startDistance;
  final double? finishDistance;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final projection = _RouteProjection(points, size);
    Offset projectPoint(RoutePoint point) => projection.project(point);
    Path pathFor(List<RoutePoint> source) {
      final displayed = _plannerDisplayPoints(source);
      final first = projectPoint(displayed.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in displayed.skip(1)) {
        final offset = projectPoint(point);
        path.lineTo(offset.dx, offset.dy);
      }
      return path;
    }

    canvas.drawPath(
      pathFor(points),
      Paint()
        ..color = EurotrexPalette.navy.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final startValue = startDistance;
    final finishValue = finishDistance;
    if (startValue != null && finishValue != null) {
      final minimumDistance = math.min(startValue, finishValue);
      final maximumDistance = math.max(startValue, finishValue);
      final selected = points
          .where(
            (point) =>
                point.distanceKm >= minimumDistance - 0.01 &&
                point.distanceKm <= maximumDistance + 0.01,
          )
          .toList(growable: false);
      if (selected.length >= 2) {
        canvas.drawPath(
          pathFor(selected),
          Paint()
            ..color = EurotrexPalette.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
    for (final stage in stages) {
      final distance = stage.accumulatedDistanceKm;
      if (distance == null) continue;
      final isStart = distance == startValue;
      final isFinish = distance == finishValue;
      if (!showAllStages && !isStart && !isFinish) continue;
      final point = routePointNearestDistance(points, distance);
      final center = projectPoint(point);
      canvas.drawCircle(
        center,
        isStart || isFinish ? 9 : 7,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        center,
        isStart || isFinish ? 6 : 4,
        Paint()..color = isFinish ? _comfort : EurotrexPalette.blue,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RouteSelectionPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.stages != stages ||
      oldDelegate.showAllStages != showAllStages ||
      oldDelegate.startDistance != startDistance ||
      oldDelegate.finishDistance != finishDistance;
}

class _RouteProjection {
  _RouteProjection(List<RoutePoint> points, Size size)
    : _size = size,
      _minimumLat = points.map((item) => item.lat).reduce(math.min),
      _maximumLat = points.map((item) => item.lat).reduce(math.max),
      _minimumLng = points.map((item) => item.lng).reduce(math.min),
      _maximumLng = points.map((item) => item.lng).reduce(math.max);

  final Size _size;
  final double _minimumLat;
  final double _maximumLat;
  final double _minimumLng;
  final double _maximumLng;

  Offset project(RoutePoint point) {
    const horizontalPadding = 20.0;
    const topPadding = 14.0;
    const bottomPadding = 48.0;
    final latRange = math.max(0.000001, _maximumLat - _minimumLat);
    final lngRange = math.max(0.000001, _maximumLng - _minimumLng);
    final availableWidth = _size.width - horizontalPadding * 2;
    final availableHeight = _size.height - topPadding - bottomPadding;
    final scale = math.min(
      availableWidth / lngRange,
      availableHeight / latRange,
    );
    final offsetX = (_size.width - lngRange * scale) / 2;
    final offsetY = topPadding + (availableHeight - latRange * scale) / 2;
    return Offset(
      offsetX + (point.lng - _minimumLng) * scale,
      offsetY + (_maximumLat - point.lat) * scale,
    );
  }
}

class _PaceStep extends StatelessWidget {
  const _PaceStep({
    required this.walkingDays,
    required this.constraint,
    required this.unit,
    required this.value,
    required this.distanceUnit,
    required this.estimate,
    required this.formatter,
    required this.startDate,
    required this.onDaysChanged,
    required this.onConstraintChanged,
    required this.onUnitChanged,
    required this.onValueChanged,
    required this.onBack,
    required this.onNext,
  });
  final int walkingDays;
  final RoutePlanConstraint constraint;
  final RoutePaceUnit unit;
  final double value;
  final String distanceUnit;
  final _SectionEstimate? estimate;
  final MeasurementFormatter formatter;
  final DateTime startDate;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<RoutePlanConstraint> onConstraintChanged;
  final ValueChanged<RoutePaceUnit> onUnitChanged;
  final ValueChanged<double> onValueChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isHours = unit == RoutePaceUnit.hours;
    final minimum = isHours ? 2.0 : 5.0;
    final maximum = isHours ? 10.0 : 45.0;
    final divisions = isHours ? 16 : 40;
    final suffix = isHours ? context.l10n.t('hours') : distanceUnit;
    final valueLabel = isHours
        ? value.toStringAsFixed(value % 1 == 0 ? 0 : 1)
        : value.toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: context.l10n.t('Your daily pace'),
          icon: Icons.hiking_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.t('What should the planner hold fixed?'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SegmentedButton<RoutePlanConstraint>(
                key: const ValueKey('route-planner-constraint'),
                expandedInsets: EdgeInsets.zero,
                segments: [
                  ButtonSegment(
                    value: RoutePlanConstraint.fixedDays,
                    icon: const Icon(Icons.calendar_view_week_rounded),
                    label: Text(context.l10n.t('Fit my days')),
                  ),
                  ButtonSegment(
                    value: RoutePlanConstraint.dailyPace,
                    icon: const Icon(Icons.speed_rounded),
                    label: Text(context.l10n.t('Limit effort')),
                  ),
                ],
                selected: {constraint},
                onSelectionChanged: (values) =>
                    onConstraintChanged(values.single),
              ),
              if (constraint == RoutePlanConstraint.fixedDays) ...[
                const SizedBox(height: 18),
                Text(
                  context.l10n.t('Walking days'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(
                      key: const ValueKey('route-planner-days-minus'),
                      tooltip: context.l10n.t('Remove walking day'),
                      onPressed: walkingDays > 1
                          ? () => onDaysChanged(walkingDays - 1)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        '$walkingDays ${context.l10n.t('days')}',
                        key: const ValueKey('route-planner-days'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: EurotrexPalette.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton.outlined(
                      key: const ValueKey('route-planner-days-plus'),
                      tooltip: context.l10n.t('Add walking day'),
                      onPressed: walkingDays < 90
                          ? () => onDaysChanged(walkingDays + 1)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 14),
                Text(
                  context.l10n.t(
                    'We will choose the number of days that stays within your daily limit.',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 18),
              Text(
                context.l10n.t('How do you prefer to set your pace?'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SegmentedButton<RoutePaceUnit>(
                key: const ValueKey('route-planner-pace-unit'),
                expandedInsets: EdgeInsets.zero,
                segments: [
                  ButtonSegment(
                    value: RoutePaceUnit.hours,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(context.l10n.t('Hours')),
                  ),
                  ButtonSegment(
                    value: RoutePaceUnit.distance,
                    icon: const Icon(Icons.straighten_rounded),
                    label: Text(distanceUnit),
                  ),
                ],
                selected: {unit},
                onSelectionChanged: (values) => onUnitChanged(values.single),
              ),
              const SizedBox(height: 20),
              Text(
                '$valueLabel $suffix ${context.l10n.t('per day')}',
                key: const ValueKey('route-planner-pace-value'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Slider(
                key: const ValueKey('route-planner-pace-slider'),
                min: minimum,
                max: maximum,
                divisions: divisions,
                value: value.clamp(minimum, maximum),
                label: '$valueLabel $suffix',
                onChanged: onValueChanged,
              ),
              Text(
                context.l10n.t(
                  'Walking time includes an allowance for climbing. Route styles rank alternatives without changing this limit.',
                ),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              if (estimate case final details?) ...[
                const SizedBox(height: 16),
                Container(
                  key: const ValueKey('route-planner-feasibility'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        details.suggestedDays > walkingDays &&
                            constraint == RoutePlanConstraint.fixedDays
                        ? const Color(0xFFFFF3E0)
                        : EurotrexPalette.paleBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${formatter.distance(details.distanceKm)} · ↑ ${formatter.altitude(details.ascentM)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${context.l10n.t('Required average')}: ${formatter.distance(details.distanceKm / math.max(1, constraint == RoutePlanConstraint.fixedDays ? walkingDays : details.suggestedDays))} ${context.l10n.t('per day')} · ${context.l10n.t('Suggested')}: ${details.suggestedDays} ${context.l10n.t('days')}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        '${context.l10n.t('Projected finish')}: ${MaterialLocalizations.of(context).formatMediumDate(startDate.add(Duration(days: (constraint == RoutePlanConstraint.fixedDays ? walkingDays : details.suggestedDays) - 1)))}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (details.suggestedDays > walkingDays &&
                          constraint == RoutePlanConstraint.fixedDays)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const ValueKey(
                              'route-planner-use-suggested-days',
                            ),
                            onPressed: () =>
                                onDaysChanged(details.suggestedDays),
                            child: Text(context.l10n.t('Use suggested days')),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _WizardButtons(
          backKey: const ValueKey('route-planner-pace-back'),
          nextKey: const ValueKey('route-planner-pace-next'),
          onBack: onBack,
          onNext: onNext,
          nextLabel: context.l10n.t('Next'),
        ),
      ],
    );
  }
}

class _StayStep extends StatelessWidget {
  const _StayStep({
    required this.preference,
    required this.priceRange,
    required this.includeUnknownPrices,
    required this.onPreferenceChanged,
    required this.onPriceChanged,
    required this.onIncludeUnknownChanged,
    required this.onBack,
    required this.onBuild,
  });
  final RouteOvernightPreference preference;
  final RangeValues priceRange;
  final bool includeUnknownPrices;
  final ValueChanged<RouteOvernightPreference> onPreferenceChanged;
  final ValueChanged<RangeValues> onPriceChanged;
  final ValueChanged<bool> onIncludeUnknownChanged;
  final VoidCallback onBack;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        title: context.l10n.t('Overnight stays'),
        icon: Icons.hotel_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const ValueKey('route-planner-stay-type'),
              children: [
                Expanded(
                  child: _StayChoice(
                    label: context.l10n.t('Lodging'),
                    icon: Icons.bed_rounded,
                    selected:
                        preference == RouteOvernightPreference.accommodation,
                    onTap: () => onPreferenceChanged(
                      RouteOvernightPreference.accommodation,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _StayChoice(
                    label: context.l10n.t('Flexible'),
                    icon: Icons.swap_horiz_rounded,
                    selected: preference == RouteOvernightPreference.either,
                    onTap: () =>
                        onPreferenceChanged(RouteOvernightPreference.either),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _StayChoice(
                    label: context.l10n.t('Camping'),
                    icon: Icons.cabin_rounded,
                    selected: preference == RouteOvernightPreference.camping,
                    onTap: () =>
                        onPreferenceChanged(RouteOvernightPreference.camping),
                  ),
                ),
              ],
            ),
            if (preference != RouteOvernightPreference.camping) ...[
              const SizedBox(height: 20),
              Text(
                context.l10n.t('Price per night'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '€${priceRange.start.toStringAsFixed(0)} – €${priceRange.end.toStringAsFixed(0)}',
                key: const ValueKey('route-planner-price-range-value'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              RangeSlider(
                key: const ValueKey('route-planner-price-range'),
                min: 0,
                max: 300,
                divisions: 30,
                values: priceRange,
                labels: RangeLabels(
                  '€${priceRange.start.toStringAsFixed(0)}',
                  '€${priceRange.end.toStringAsFixed(0)}',
                ),
                semanticFormatterCallback: (value) =>
                    '€${value.round()} ${context.l10n.t('per night')}',
                onChanged: onPriceChanged,
              ),
              Text(
                context.l10n.t(
                  'The range applies per room, per night, using listed prices.',
                ),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('route-planner-unknown-prices'),
                contentPadding: EdgeInsets.zero,
                value: includeUnknownPrices,
                onChanged: onIncludeUnknownChanged,
                title: Text(
                  context.l10n.t('Include stays without a listed price'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  context.l10n.t('You can confirm their price before booking.'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      _WizardButtons(
        backKey: const ValueKey('route-planner-stay-back'),
        nextKey: const ValueKey('route-planner-build'),
        onBack: onBack,
        onNext: onBuild,
        nextLabel: context.l10n.t('Build my plans'),
      ),
    ],
  );
}

class _StayChoice extends StatelessWidget {
  const _StayChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? EurotrexPalette.paleBlue : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? EurotrexPalette.blue : _outline),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? EurotrexPalette.blue : EurotrexPalette.navy,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WizardButtons extends StatelessWidget {
  const _WizardButtons({
    required this.backKey,
    required this.nextKey,
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });
  final Key backKey;
  final Key nextKey;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          key: backKey,
          onPressed: onBack,
          child: Text(context.l10n.t('Back')),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.icon(
          key: nextKey,
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(nextLabel),
        ),
      ),
    ],
  );
}

class _CompareStep extends StatelessWidget {
  const _CompareStep({
    required this.variants,
    required this.failures,
    required this.selected,
    required this.saved,
    required this.formatter,
    required this.routePoints,
    required this.stages,
    required this.lodgings,
    required this.offlineMap,
    required this.saving,
    required this.onBack,
    required this.onDone,
    required this.onSelect,
    required this.onSave,
    required this.onReviewPace,
    required this.onReviewStay,
    required this.onUseSuggestedDays,
    required this.onEditBoundary,
    required this.onChooseAccommodation,
    required this.onStartDay,
    required this.onOpenMap,
  });
  final Map<RoutePlanStyle, _PlannedVariant?> variants;
  final Map<RoutePlanStyle, RoutePlanFailure?> failures;
  final RoutePlanStyle? selected;
  final bool saved;
  final MeasurementFormatter formatter;
  final List<RoutePoint> routePoints;
  final List<TrailStage> stages;
  final List<Lodging> lodgings;
  final AsyncValue<OfflineMapState>? offlineMap;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback? onDone;
  final void Function(RoutePlanStyle, _PlannedVariant) onSelect;
  final VoidCallback onSave;
  final VoidCallback onReviewPace;
  final VoidCallback onReviewStay;
  final VoidCallback? onUseSuggestedDays;
  final ValueChanged<int> onEditBoundary;
  final ValueChanged<int> onChooseAccommodation;
  final ValueChanged<RoutePlanDay> onStartDay;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final selectedVariant = selected == null ? null : variants[selected];
    return Column(
      key: const ValueKey('route-planner-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.t('Choose an itinerary'),
          style: const TextStyle(
            color: EurotrexPalette.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        for (final style in RoutePlanStyle.values) ...[
          _VariantCard(
            style: style,
            variant: variants[style],
            failure: failures[style],
            selected: selected == style,
            recommended:
                style == RoutePlanStyle.balanced &&
                variants[RoutePlanStyle.balanced] != null,
            formatter: formatter,
            onTap: saving || variants[style] == null
                ? null
                : () => onSelect(style, variants[style]!),
          ),
          const SizedBox(height: 9),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('route-planner-results-back'),
                onPressed: onBack,
                child: Text(context.l10n.t('Back')),
              ),
            ),
            if (selectedVariant != null && !saved) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('route-planner-save'),
                  onPressed: saving ? null : onSave,
                  icon: const Icon(Icons.bookmark_add_rounded),
                  label: Text(context.l10n.t('Save route')),
                ),
              ),
            ] else if (onDone != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('route-planner-done'),
                  onPressed: onDone,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(context.l10n.t('Done')),
                ),
              ),
            ],
          ],
        ),
        if (saving) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
        if (selectedVariant != null && selected != null) ...[
          const SizedBox(height: 14),
          if (saved)
            Material(
              key: const ValueKey('route-saved-confirmation'),
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.l10n.t('Saved to My routes and Stage filters.'),
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          if (saved) const SizedBox(height: 12),
          _PlanResult(
            plan: selectedVariant.plan,
            style: selected!,
            formatter: formatter,
            routePoints: routePoints,
            stages: stages,
            lodgings: lodgings,
            direction: selectedVariant.direction,
            request: selectedVariant.request,
            offlineMap: offlineMap,
            onEditBoundary: onEditBoundary,
            onChooseAccommodation: onChooseAccommodation,
            onStartDay: onStartDay,
            onOpenMap: onOpenMap,
          ),
        ] else if (variants.values.every((plan) => plan == null)) ...[
          const SizedBox(height: 12),
          _Message(
            key: const ValueKey('route-planner-no-result'),
            icon: Icons.wrong_location_outlined,
            title: context.l10n.t(
              routeFailureLabel(
                failures.values.whereType<RoutePlanFailure>().firstOrNull ??
                    RoutePlanFailure.noOvernightStops,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const ValueKey('route-planner-review-pace'),
                onPressed: onReviewPace,
                child: Text(context.l10n.t('Review pace')),
              ),
              OutlinedButton(
                key: const ValueKey('route-planner-review-stays'),
                onPressed: onReviewStay,
                child: Text(context.l10n.t('Review stays')),
              ),
              if (onUseSuggestedDays != null)
                FilledButton(
                  key: const ValueKey('route-planner-recovery-days'),
                  onPressed: onUseSuggestedDays,
                  child: Text(context.l10n.t('Use suggested days')),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.style,
    required this.variant,
    required this.failure,
    required this.selected,
    required this.recommended,
    required this.formatter,
    required this.onTap,
  });
  final RoutePlanStyle style;
  final _PlannedVariant? variant;
  final RoutePlanFailure? failure;
  final bool selected;
  final bool recommended;
  final MeasurementFormatter formatter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = styleColor(style);
    final plan = variant?.plan;
    final longestDay = plan?.days.fold<RoutePlanDay?>(
      null,
      (current, day) => current == null || day.distanceKm > current.distanceKm
          ? day
          : current,
    );
    final averageMinutes = plan == null || plan.days.isEmpty
        ? 0
        : plan.days.fold<int>(
                0,
                (total, day) => total + day.estimatedWalkingMinutes,
              ) ~/
              plan.days.length;
    final campingNights =
        plan?.days.where((day) => day.usesCamping).length ?? 0;
    return Material(
      key: ValueKey('route-option-${style.name}'),
      color: selected ? color.withValues(alpha: 0.1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: selected ? color : _outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(styleIcon(style), color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.t(styleLabel(style)),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (recommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: EurotrexPalette.blue,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              context.l10n.t('Recommended'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      plan == null
                          ? context.l10n.t(
                              routeFailureLabel(
                                failure ?? RoutePlanFailure.noOvernightStops,
                              ),
                            )
                          : '${plan.days.length} ${context.l10n.t('walking days')} · ${formatter.distance(plan.totalDistanceKm)} · ${_formatMinutes(context, averageMinutes)} ${context.l10n.t('average')}\n${context.l10n.t('Longest day')}: ${formatter.distance(longestDay!.distanceKm)} · ${context.l10n.t('Camping nights')}: $campingNights · €${plan.estimatedAccommodationCostEur.toStringAsFixed(0)}${plan.unknownPriceNights > 0 ? '+' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: plan == null ? Colors.black26 : color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanResult extends StatelessWidget {
  const _PlanResult({
    required this.plan,
    required this.style,
    required this.formatter,
    required this.routePoints,
    required this.stages,
    required this.lodgings,
    required this.direction,
    required this.request,
    required this.offlineMap,
    required this.onEditBoundary,
    required this.onChooseAccommodation,
    required this.onStartDay,
    required this.onOpenMap,
  });
  final RoutePlan plan;
  final RoutePlanStyle style;
  final MeasurementFormatter formatter;
  final List<RoutePoint> routePoints;
  final List<TrailStage> stages;
  final List<Lodging> lodgings;
  final TrailDirection direction;
  final RoutePlanRequest request;
  final AsyncValue<OfflineMapState>? offlineMap;
  final ValueChanged<int> onEditBoundary;
  final ValueChanged<int> onChooseAccommodation;
  final ValueChanged<RoutePlanDay> onStartDay;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('route-planner-result'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: styleColor(style),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          '${context.l10n.t(styleLabel(style))} · ${context.l10n.t(plan.days.first.start.name)} → ${context.l10n.t(plan.days.last.finish.name)}\n${plan.days.length} ${context.l10n.t('walking days')} · ${formatter.distance(plan.totalDistanceKm)} · €${plan.estimatedAccommodationCostEur.toStringAsFixed(0)}+',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _RouteOverview(
        plan: plan,
        points: routePoints,
        direction: direction,
        onOpenMap: onOpenMap,
      ),
      const SizedBox(height: 12),
      _OfflineReadinessCard(state: offlineMap, onOpenMap: onOpenMap),
      const SizedBox(height: 14),
      Text(
        context.l10n.t('Day-by-day itinerary'),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      for (final day in plan.days) ...[
        _DayCard.plan(
          day,
          formatter,
          isFinalDay: day.dayNumber == plan.days.length,
          onEditBoundary: day.dayNumber == plan.days.length
              ? null
              : () => onEditBoundary(day.dayNumber - 1),
          onChooseAccommodation: day.dayNumber == plan.days.length
              ? null
              : () => onChooseAccommodation(day.dayNumber - 1),
          onStartDay: () => onStartDay(day),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.number,
    required this.start,
    required this.finish,
    required this.distance,
    required this.ascent,
    required this.descent,
    required this.minutes,
    required this.camping,
    required this.accommodation,
    required this.cost,
    required this.formatter,
    this.isFinalDay = false,
    this.onEditBoundary,
    this.onChooseAccommodation,
    this.onStartDay,
    super.key,
  });

  factory _DayCard.plan(
    RoutePlanDay day,
    MeasurementFormatter formatter, {
    required bool isFinalDay,
    VoidCallback? onEditBoundary,
    VoidCallback? onChooseAccommodation,
    VoidCallback? onStartDay,
  }) => _DayCard(
    key: ValueKey('route-plan-day-${day.dayNumber}'),
    number: day.dayNumber,
    start: day.start.name,
    finish: day.finish.name,
    distance: day.distanceKm,
    ascent: day.ascentM,
    descent: day.descentM,
    minutes: day.estimatedWalkingMinutes,
    camping: day.usesCamping,
    accommodation: day.accommodation?.name,
    cost: day.estimatedCostEur,
    formatter: formatter,
    isFinalDay: isFinalDay,
    onEditBoundary: onEditBoundary,
    onChooseAccommodation: onChooseAccommodation,
    onStartDay: onStartDay,
  );

  factory _DayCard.saved(SavedRouteDay day, MeasurementFormatter formatter) =>
      _DayCard(
        number: day.dayNumber,
        start: day.startStageName,
        finish: day.finishStageName,
        distance: day.distanceKm,
        ascent: day.ascentM,
        descent: day.descentM,
        minutes: day.estimatedWalkingMinutes,
        camping: day.usesCamping,
        accommodation: day.accommodationName,
        cost: day.estimatedCostEur,
        formatter: formatter,
      );

  final int number;
  final String start;
  final String finish;
  final double distance;
  final double ascent;
  final double descent;
  final int minutes;
  final bool camping;
  final String? accommodation;
  final double? cost;
  final MeasurementFormatter formatter;
  final bool isFinalDay;
  final VoidCallback? onEditBoundary;
  final VoidCallback? onChooseAccommodation;
  final VoidCallback? onStartDay;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final remaining = minutes.remainder(60);
    final time =
        '$hours ${context.l10n.t('h')} $remaining ${context.l10n.t('min')}';
    final overnight = camping ? context.l10n.t('Camping stage') : accommodation;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: EurotrexPalette.paleBlue,
                child: Text('$number'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.l10n.t(start)} → ${context.l10n.t(finish)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${formatter.distance(distance)} · $time · ↑ ${formatter.altitude(ascent)} · ↓ ${formatter.altitude(descent)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (overnight != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${context.l10n.t(overnight)}${cost == null ? '' : ' · €${cost!.toStringAsFixed(0)}'}',
                        style: const TextStyle(
                          color: EurotrexPalette.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onEditBoundary != null ||
              onChooseAccommodation != null ||
              onStartDay != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: [
                if (onEditBoundary != null)
                  TextButton.icon(
                    key: ValueKey('edit-day-boundary-$number'),
                    onPressed: onEditBoundary,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: Text(context.l10n.t('Move stop')),
                  ),
                if (onChooseAccommodation != null)
                  TextButton.icon(
                    key: ValueKey('choose-stay-$number'),
                    onPressed: onChooseAccommodation,
                    icon: const Icon(Icons.bed_outlined),
                    label: Text(context.l10n.t('Choose stay')),
                  ),
                if (onStartDay != null)
                  FilledButton.tonalIcon(
                    key: ValueKey('start-route-day-$number'),
                    onPressed: onStartDay,
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text(context.l10n.t('Start this day')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteOverview extends StatelessWidget {
  const _RouteOverview({
    required this.plan,
    required this.points,
    required this.direction,
    required this.onOpenMap,
  });

  final RoutePlan plan;
  final List<RoutePoint> points;
  final TrailDirection direction;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final startDistance = plan.days.first.start.accumulatedDistanceKm;
    final finishDistance = plan.days.last.finish.accumulatedDistanceKm;
    final minimum = math.min(startDistance ?? 0, finishDistance ?? 0);
    final maximum = math.max(startDistance ?? 0, finishDistance ?? 0);
    final visiblePoints = points
        .where(
          (point) =>
              point.distanceKm >= minimum - 0.01 &&
              point.distanceKm <= maximum + 0.01,
        )
        .toList(growable: false);
    return Container(
      key: const ValueKey('route-plan-overview-map'),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: EurotrexPalette.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.t('Your route at a glance'),
                    style: const TextStyle(
                      color: EurotrexPalette.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  context.l10n.t(
                    direction.isReversed
                        ? 'Larnaka to Pafos'
                        : 'Pafos to Larnaka',
                  ),
                  style: const TextStyle(fontSize: 10),
                ),
                IconButton(
                  tooltip: context.l10n.t('Open map'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: visiblePoints.length < 2
                ? Center(child: Text(context.l10n.t('Route map is loading…')))
                : CustomPaint(
                    painter: _RouteOverviewPainter(
                      points: visiblePoints,
                      days: plan.days,
                    ),
                  ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                for (final day in plan.days) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _dayColor(day.dayNumber - 1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${context.l10n.t('Day')} ${day.dayNumber}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOverviewPainter extends CustomPainter {
  const _RouteOverviewPainter({required this.points, required this.days});

  final List<RoutePoint> points;
  final List<RoutePlanDay> days;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const padding = 24.0;
    final latitudes = points.map((point) => point.lat);
    final longitudes = points.map((point) => point.lng);
    final minimumLat = latitudes.reduce(math.min);
    final maximumLat = latitudes.reduce(math.max);
    final minimumLng = longitudes.reduce(math.min);
    final maximumLng = longitudes.reduce(math.max);
    final latRange = math.max(0.000001, maximumLat - minimumLat);
    final lngRange = math.max(0.000001, maximumLng - minimumLng);
    final scale = math.min(
      (size.width - padding * 2) / lngRange,
      (size.height - padding * 2) / latRange,
    );
    final drawingWidth = lngRange * scale;
    final drawingHeight = latRange * scale;
    final offsetX = (size.width - drawingWidth) / 2;
    final offsetY = (size.height - drawingHeight) / 2;
    Offset project(RoutePoint point) => Offset(
      offsetX + (point.lng - minimumLng) * scale,
      offsetY + (maximumLat - point.lat) * scale,
    );

    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      final minimumDistance = math.min(
        day.start.accumulatedDistanceKm ?? 0,
        day.finish.accumulatedDistanceKm ?? 0,
      );
      final maximumDistance = math.max(
        day.start.accumulatedDistanceKm ?? 0,
        day.finish.accumulatedDistanceKm ?? 0,
      );
      final segment = points
          .where(
            (point) =>
                point.distanceKm >= minimumDistance - 0.01 &&
                point.distanceKm <= maximumDistance + 0.01,
          )
          .toList(growable: false);
      if (segment.length < 2) continue;
      final path = Path()
        ..moveTo(project(segment.first).dx, project(segment.first).dy);
      for (final point in segment.skip(1)) {
        final offset = project(point);
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _dayColor(dayIndex)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (var index = 0; index <= days.length; index++) {
      final distance = index == 0
          ? days.first.start.accumulatedDistanceKm
          : days[index - 1].finish.accumulatedDistanceKm;
      if (distance == null) continue;
      final point = points.reduce(
        (left, right) =>
            (left.distanceKm - distance).abs() <
                (right.distanceKm - distance).abs()
            ? left
            : right,
      );
      final center = project(point);
      canvas.drawCircle(center, 10, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        8,
        Paint()
          ..color = index == 0 ? EurotrexPalette.navy : _dayColor(index - 1),
      );
      final painter = TextPainter(
        text: TextSpan(
          text: index == 0 ? 'S' : '$index',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RouteOverviewPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.days != days;
}

Color _dayColor(int index) => const [
  Color(0xFF1565C0),
  Color(0xFF277653),
  Color(0xFFD47B28),
  Color(0xFF75588A),
  Color(0xFFC33D67),
  Color(0xFF00838F),
][index % 6];

class _OfflineReadinessCard extends StatelessWidget {
  const _OfflineReadinessCard({required this.state, required this.onOpenMap});

  final AsyncValue<OfflineMapState>? state;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final value = state?.value;
    final ready = value?.isReady == true;
    final downloading = value?.isDownloading == true;
    return Container(
      key: const ValueKey('route-plan-offline-readiness'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ready ? _green : _outline),
      ),
      child: Row(
        children: [
          Icon(
            ready
                ? Icons.offline_pin_rounded
                : Icons.download_for_offline_outlined,
            color: ready ? _green : EurotrexPalette.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('Offline readiness'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  context.l10n.t(
                    ready
                        ? 'Offline map downloaded'
                        : downloading
                        ? 'Offline map download in progress'
                        : 'Download the trail map before you leave coverage.',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpenMap,
            child: Text(context.l10n.t(ready ? 'Open map' : 'Manage')),
          ),
        ],
      ),
    );
  }
}

class _LodgingChoiceTile extends StatelessWidget {
  const _LodgingChoiceTile({
    required this.lodging,
    required this.selected,
    required this.plannedDate,
    required this.onTap,
  });

  final Lodging lodging;
  final bool selected;
  final DateTime? plannedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = lodging.priceMinEur ?? lodging.priceMaxEur;
    final details = <String>[
      if (lodging.type != null) context.l10n.t(lodging.type!),
      if (price != null) '€${price.toStringAsFixed(0)}+',
      if (lodging.distanceFromTrailKm != null)
        '${lodging.distanceFromTrailKm!.toStringAsFixed(1)} km ${context.l10n.t('from trail')}',
    ];
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.hotel_rounded),
        title: Text(
          lodging.name ?? context.l10n.t('Accommodation'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty) Text(details.join(' · ')),
            if (lodging.monthsOpen != null)
              Text('${context.l10n.t('Open')}: ${lodging.monthsOpen}'),
            if (plannedDate != null && lodging.monthsOpen != null)
              Text(
                context.l10n.t('Confirm availability for your planned date.'),
                style: const TextStyle(
                  color: Color(0xFF9A5A12),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: _green)
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: EurotrexPalette.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, super.key});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: EurotrexPalette.blue),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

String styleLabel(RoutePlanStyle style) => switch (style) {
  RoutePlanStyle.relaxed => 'Relaxed',
  RoutePlanStyle.balanced => 'Balanced',
  RoutePlanStyle.adventurous => 'Adventurous',
};

String routeFailureLabel(RoutePlanFailure failure) => switch (failure) {
  RoutePlanFailure.invalidEndpoints => 'Choose two stages in trail order.',
  RoutePlanFailure.tooFarForSelectedDays =>
    'This section is too far for the selected number of days.',
  RoutePlanFailure.tooManySelectedDays =>
    'This short section has fewer useful stops than selected days.',
  RoutePlanFailure.dailyPaceExceeded =>
    'One or more trail sections exceed your daily effort limit.',
  RoutePlanFailure.unknownPricesExcluded =>
    'A suitable stay is available, but its price is not listed.',
  RoutePlanFailure.accommodationBudget =>
    'No listed stays fit the selected price range.',
  RoutePlanFailure.overnightPreference =>
    'The selected stay type is not available at the required stops.',
  RoutePlanFailure.exactDayCount =>
    'The available overnight stops cannot make this exact day count.',
  RoutePlanFailure.noOvernightStops =>
    'There are not enough suitable overnight stops for this section.',
};

String _formatMinutes(BuildContext context, int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes.remainder(60);
  return '$hours ${context.l10n.t('h')} $remainder ${context.l10n.t('min')}';
}

Color styleColor(RoutePlanStyle style) => switch (style) {
  RoutePlanStyle.relaxed => _green,
  RoutePlanStyle.balanced => EurotrexPalette.blue,
  RoutePlanStyle.adventurous => _comfort,
};

IconData styleIcon(RoutePlanStyle style) => switch (style) {
  RoutePlanStyle.relaxed => Icons.spa_outlined,
  RoutePlanStyle.balanced => Icons.balance_rounded,
  RoutePlanStyle.adventurous => Icons.terrain_rounded,
};
