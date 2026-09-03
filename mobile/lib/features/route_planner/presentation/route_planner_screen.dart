import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

enum _TripGoal { customSection, wholeTrail, bestSection }

enum _StartPreference { automatic, pafos, larnaka }

enum _PaceUnit { hours, distance }

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

class _SectionCandidate {
  const _SectionCandidate({
    required this.startIndex,
    required this.finishIndex,
    required this.distanceDelta,
  });

  final int startIndex;
  final int finishIndex;
  final double distanceDelta;
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
  _TripGoal tripGoal = _TripGoal.customSection;
  _StartPreference startPreference = _StartPreference.automatic;
  _PaceUnit paceUnit = _PaceUnit.hours;
  double paceValue = 6;
  RouteOvernightPreference overnightPreference =
      RouteOvernightPreference.accommodation;
  RangeValues accommodationPriceRange = const RangeValues(40, 120);
  Map<RoutePlanStyle, _PlannedVariant?> variants = const {};
  RoutePlanStyle? selectedStyle;
  String? customStartStageId;
  String? customFinishStageId;
  String? draftRouteId;
  bool saving = false;

  void startNewRoute() => setState(() {
    showWizard = true;
    step = 0;
    walkingDays = 5;
    startDate = DateUtils.dateOnly(DateTime.now());
    tripGoal = _TripGoal.customSection;
    startPreference = _StartPreference.automatic;
    paceUnit = _PaceUnit.hours;
    paceValue = 6;
    overnightPreference = RouteOvernightPreference.accommodation;
    accommodationPriceRange = const RangeValues(40, 120);
    variants = const {};
    selectedStyle = null;
    customStartStageId = null;
    customFinishStageId = null;
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

  TrailStage defaultCustomFinish(List<TrailStage> stages) {
    final startDistance = stages.first.accumulatedDistanceKm ?? 0;
    final targetDistance = startDistance + walkingDays * 24;
    return stages
        .skip(1)
        .reduce(
          (left, right) =>
              ((left.accumulatedDistanceKm ?? 0) - targetDistance).abs() <=
                  ((right.accumulatedDistanceKm ?? 0) - targetDistance).abs()
              ? left
              : right,
        );
  }

  RoutePlanRequest requestFor(
    RoutePlanStyle style,
    TrailStage start,
    TrailStage finish,
    MeasurementSystem system,
  ) {
    final styleFactor = switch (style) {
      RoutePlanStyle.relaxed => 0.8,
      RoutePlanStyle.balanced => 1.0,
      RoutePlanStyle.adventurous => 1.15,
    };
    final enteredDistanceKm = system == MeasurementSystem.metric
        ? paceValue
        : paceValue / 0.621371;
    final dailyTargetKm =
        (paceUnit == _PaceUnit.hours ? paceValue * 5 : enteredDistanceKm) *
        styleFactor;
    final usesAccommodation =
        overnightPreference != RouteOvernightPreference.camping;
    return RoutePlanRequest(
      startStageId: start.id,
      finishStageId: finish.id,
      minimumDailyDistanceKm: dailyTargetKm * 0.45,
      maximumDailyDistanceKm: dailyTargetKm * 1.2,
      maximumDailyWalkingMinutes: paceUnit == _PaceUnit.hours
          ? (paceValue * 60 * styleFactor * 1.15).round()
          : null,
      walkingDays: walkingDays,
      startDate: startDate,
      overnightPreference: overnightPreference,
      minimumAccommodationPriceEur: usesAccommodation
          ? accommodationPriceRange.start
          : null,
      maximumAccommodationPriceEur: usesAccommodation
          ? accommodationPriceRange.end
          : null,
      style: style,
    );
  }

  void buildRoutes({
    required List<TrailStage> stages,
    required List<Lodging> lodgings,
    required MeasurementSystem system,
  }) {
    setState(() {
      variants = {
        for (final style in RoutePlanStyle.values)
          style: _buildVariant(
            style: style,
            stages: stages,
            lodgings: lodgings,
            system: system,
          ),
      };
      selectedStyle = null;
      step = 3;
    });
  }

  _PlannedVariant? _buildVariant({
    required RoutePlanStyle style,
    required List<TrailStage> stages,
    required List<Lodging> lodgings,
    required MeasurementSystem system,
  }) {
    final directions = switch (startPreference) {
      _StartPreference.automatic => TrailDirection.values,
      _StartPreference.pafos => const [TrailDirection.pafosToLarnaka],
      _StartPreference.larnaka => const [TrailDirection.larnakaToPafos],
    };
    _PlannedVariant? best;
    var bestScore = double.infinity;
    for (final direction in directions) {
      final ordered = orderedStages(stages, direction);
      if (ordered.length < 2) continue;
      if (tripGoal == _TripGoal.customSection) {
        final startId = customStartStageId;
        final finishId = customFinishStageId;
        if (startId == null || finishId == null) continue;
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
        continue;
      }
      if (tripGoal == _TripGoal.wholeTrail) {
        final request = requestFor(style, ordered.first, ordered.last, system);
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
        continue;
      }

      final previewRequest = requestFor(
        style,
        ordered.first,
        ordered.last,
        system,
      );
      final targetTotal =
          (previewRequest.minimumDailyDistanceKm +
              previewRequest.maximumDailyDistanceKm) /
          2 *
          walkingDays;
      final sectionCandidates = <_SectionCandidate>[];
      for (var startIndex = 0; startIndex < ordered.length - 1; startIndex++) {
        final startDistance = ordered[startIndex].accumulatedDistanceKm;
        if (startDistance == null) continue;
        var nearestFinish = startIndex + walkingDays;
        if (nearestFinish >= ordered.length) continue;
        var nearestDelta = double.infinity;
        for (
          var finishIndex = startIndex + walkingDays;
          finishIndex < ordered.length;
          finishIndex++
        ) {
          final finishDistance = ordered[finishIndex].accumulatedDistanceKm;
          if (finishDistance == null) continue;
          final delta = ((finishDistance - startDistance).abs() - targetTotal)
              .abs();
          if (delta < nearestDelta) {
            nearestDelta = delta;
            nearestFinish = finishIndex;
          }
        }
        for (var offset = -4; offset <= 4; offset++) {
          final finishIndex = nearestFinish + offset;
          if (finishIndex < startIndex + walkingDays ||
              finishIndex >= ordered.length) {
            continue;
          }
          final finishDistance = ordered[finishIndex].accumulatedDistanceKm;
          if (finishDistance == null) continue;
          sectionCandidates.add(
            _SectionCandidate(
              startIndex: startIndex,
              finishIndex: finishIndex,
              distanceDelta:
                  ((finishDistance - startDistance).abs() - targetTotal).abs(),
            ),
          );
        }
      }
      sectionCandidates.sort(
        (left, right) => left.distanceDelta.compareTo(right.distanceDelta),
      );
      for (final candidate in sectionCandidates.take(48)) {
        final request = requestFor(
          style,
          ordered[candidate.startIndex],
          ordered[candidate.finishIndex],
          system,
        );
        final plan = buildDeterministicRoutePlan(
          stages: stages,
          lodgings: lodgings,
          direction: direction,
          request: request,
        );
        if (plan == null) continue;
        final score = _planScore(plan, request) + candidate.distanceDelta;
        if (score < bestScore) {
          bestScore = score;
          best = _PlannedVariant(
            plan: plan,
            direction: direction,
            request: request,
          );
        }
      }
    }
    return best;
  }

  double _planScore(RoutePlan plan, RoutePlanRequest request) {
    final target =
        (request.minimumDailyDistanceKm + request.maximumDailyDistanceKm) / 2;
    return plan.days.fold<double>(
          0,
          (score, day) =>
              score + (day.distanceKm - target) * (day.distanceKm - target),
        ) +
        plan.unknownPriceNights * 100;
  }

  Future<void> selectRoute({
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
    setState(() => variants = {...variants, style: updated});
    await selectRoute(style: style, variant: updated);
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
      walkingDays: route.days.length,
      startDate: route.startDate,
      overnightPreference: route.overnightPreference,
      minimumAccommodationPriceEur: route.minimumAccommodationPriceEur,
      maximumAccommodationPriceEur: route.maximumAccommodationPriceEur,
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
      draftRouteId = route.id;
      startDate = route.startDate ?? DateUtils.dateOnly(DateTime.now());
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
                onAdd: startNewRoute,
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
    return ListView(
      key: const ValueKey('route-planner-content'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _Progress(step: step),
        const SizedBox(height: 14),
        if (step == 0)
          _TripStep(
            walkingDays: walkingDays,
            startDate: startDate,
            goal: tripGoal,
            startPreference: startPreference,
            stages: forwardStages,
            routePoints: routePoints,
            startStageId: customStartStageId ?? forwardStages.first.id,
            finishStageId:
                customFinishStageId ?? defaultCustomFinish(forwardStages).id,
            onDaysChanged: (value) => setState(() => walkingDays = value),
            onDateChanged: (value) => setState(() => startDate = value),
            onGoalChanged: (value) => setState(() => tripGoal = value),
            onStartChanged: (value) => setState(() => startPreference = value),
            onStartStageChanged: (value) =>
                setState(() => customStartStageId = value),
            onFinishStageChanged: (value) =>
                setState(() => customFinishStageId = value),
            onNext: () => setState(() {
              if (tripGoal == _TripGoal.customSection) {
                customStartStageId ??= forwardStages.first.id;
                customFinishStageId ??= defaultCustomFinish(forwardStages).id;
              }
              step = 1;
            }),
          )
        else if (step == 1)
          _PaceStep(
            unit: paceUnit,
            value: paceValue,
            distanceUnit: formatter.distanceUnit,
            onUnitChanged: (value) => setState(() {
              paceUnit = value;
              paceValue = value == _PaceUnit.hours ? 6 : 25;
            }),
            onValueChanged: (value) => setState(() => paceValue = value),
            onBack: () => setState(() => step = 0),
            onNext: () => setState(() => step = 2),
          )
        else if (step == 2)
          _StayStep(
            preference: overnightPreference,
            priceRange: accommodationPriceRange,
            onPreferenceChanged: (value) =>
                setState(() => overnightPreference = value),
            onPriceChanged: (value) =>
                setState(() => accommodationPriceRange = value),
            onBack: () => setState(() => step = 1),
            onBuild: () =>
                buildRoutes(stages: stages, lodgings: lodgings, system: system),
          )
        else
          _CompareStep(
            variants: variants,
            selected: selectedStyle,
            formatter: formatter,
            routePoints: routePoints,
            stages: stages,
            lodgings: lodgings,
            offlineMap: offlineMap,
            saving: saving,
            onBack: () => setState(() => step = 2),
            onDone: selectedStyle == null
                ? null
                : () => setState(() => showWizard = false),
            onSelect: (style, variant) =>
                selectRoute(style: style, variant: variant),
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

class _TripStep extends StatelessWidget {
  const _TripStep({
    required this.walkingDays,
    required this.startDate,
    required this.goal,
    required this.startPreference,
    required this.stages,
    required this.routePoints,
    required this.startStageId,
    required this.finishStageId,
    required this.onDaysChanged,
    required this.onDateChanged,
    required this.onGoalChanged,
    required this.onStartChanged,
    required this.onStartStageChanged,
    required this.onFinishStageChanged,
    required this.onNext,
  });
  final int walkingDays;
  final DateTime startDate;
  final _TripGoal goal;
  final _StartPreference startPreference;
  final List<TrailStage> stages;
  final List<RoutePoint> routePoints;
  final String? startStageId;
  final String? finishStageId;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<_TripGoal> onGoalChanged;
  final ValueChanged<_StartPreference> onStartChanged;
  final ValueChanged<String?> onStartStageChanged;
  final ValueChanged<String?> onFinishStageChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final start = stages.where((stage) => stage.id == startStageId).firstOrNull;
    final finish = stages
        .where((stage) => stage.id == finishStageId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: context.l10n.t('Choose your route'),
          icon: Icons.map_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RouteSelectionMap(
                points: routePoints,
                start: goal == _TripGoal.customSection ? start : null,
                finish: goal == _TripGoal.customSection ? finish : null,
              ),
              const SizedBox(height: 14),
              SegmentedButton<_TripGoal>(
                key: const ValueKey('route-planner-goal'),
                expandedInsets: EdgeInsets.zero,
                segments: [
                  ButtonSegment(
                    value: _TripGoal.customSection,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(context.l10n.t('Custom')),
                  ),
                  ButtonSegment(
                    value: _TripGoal.bestSection,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(context.l10n.t('Smart')),
                  ),
                  ButtonSegment(
                    value: _TripGoal.wholeTrail,
                    icon: const Icon(Icons.route_rounded),
                    label: Text(context.l10n.t('Whole E4')),
                  ),
                ],
                selected: {goal},
                onSelectionChanged: (values) => onGoalChanged(values.single),
              ),
              if (goal == _TripGoal.customSection && stages.length >= 2) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: const ValueKey('route-planner-start-stage'),
                  isExpanded: true,
                  initialValue: startStageId ?? stages.first.id,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('Start point'),
                    prefixIcon: const Icon(Icons.trip_origin_rounded),
                  ),
                  items: [
                    for (final stage in stages)
                      DropdownMenuItem(
                        value: stage.id,
                        child: Text(
                          context.l10n.t(stage.name),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onStartStageChanged,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const ValueKey('route-planner-finish-stage'),
                  isExpanded: true,
                  initialValue: finishStageId ?? stages.last.id,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('Finish point'),
                    prefixIcon: const Icon(Icons.flag_rounded),
                  ),
                  items: [
                    for (final stage in stages)
                      DropdownMenuItem(
                        value: stage.id,
                        child: Text(
                          context.l10n.t(stage.name),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onFinishStageChanged,
                ),
              ] else ...[
                const SizedBox(height: 14),
                SegmentedButton<_StartPreference>(
                  key: const ValueKey('route-planner-start-preference'),
                  expandedInsets: EdgeInsets.zero,
                  segments: [
                    ButtonSegment(
                      value: _StartPreference.automatic,
                      icon: const Icon(Icons.compare_arrows_rounded),
                      label: Text(context.l10n.t('Auto')),
                    ),
                    ButtonSegment(
                      value: _StartPreference.pafos,
                      label: Text(context.l10n.t('Pafos')),
                    ),
                    ButtonSegment(
                      value: _StartPreference.larnaka,
                      label: Text(context.l10n.t('Larnaka')),
                    ),
                  ],
                  selected: {startPreference},
                  onSelectionChanged: (values) => onStartChanged(values.single),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: context.l10n.t('Your trip'),
          icon: Icons.calendar_month_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.t('Walking days'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton.outlined(
                    key: const ValueKey('route-planner-days-minus'),
                    onPressed: walkingDays > 1
                        ? () => onDaysChanged(walkingDays - 1)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 82,
                    child: Text(
                      '$walkingDays ${context.l10n.t('days')}',
                      key: const ValueKey('route-planner-days'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: EurotrexPalette.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    key: const ValueKey('route-planner-days-plus'),
                    onPressed: walkingDays < 30
                        ? () => onDaysChanged(walkingDays + 1)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('route-planner-start-date'),
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  '${context.l10n.t('Start date')}: ${MaterialLocalizations.of(context).formatMediumDate(startDate)}',
                ),
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateUtils.dateOnly(DateTime.now()),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (value != null) onDateChanged(value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey('route-planner-route-next'),
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(context.l10n.t('Next')),
        ),
      ],
    );
  }
}

class _RouteSelectionMap extends StatelessWidget {
  const _RouteSelectionMap({
    required this.points,
    required this.start,
    required this.finish,
  });

  final List<RoutePoint> points;
  final TrailStage? start;
  final TrailStage? finish;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('route-planner-selection-map'),
    height: 190,
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0EA),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: points.length < 2
        ? Center(child: Text(context.l10n.t('Route map is loading…')))
        : Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _RouteSelectionPainter(
                  points: points,
                  startDistance: start?.accumulatedDistanceKm,
                  finishDistance: finish?.accumulatedDistanceKm,
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    start == null || finish == null
                        ? context.l10n.t(
                            'The planner will choose the best-fitting section.',
                          )
                        : '${context.l10n.t(start!.name)} → ${context.l10n.t(finish!.name)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: EurotrexPalette.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

class _RouteSelectionPainter extends CustomPainter {
  const _RouteSelectionPainter({
    required this.points,
    required this.startDistance,
    required this.finishDistance,
  });

  final List<RoutePoint> points;
  final double? startDistance;
  final double? finishDistance;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const horizontalPadding = 20.0;
    const topPadding = 14.0;
    const bottomPadding = 48.0;
    final minimumLat = points.map((point) => point.lat).reduce(math.min);
    final maximumLat = points.map((point) => point.lat).reduce(math.max);
    final minimumLng = points.map((point) => point.lng).reduce(math.min);
    final maximumLng = points.map((point) => point.lng).reduce(math.max);
    final latRange = math.max(0.000001, maximumLat - minimumLat);
    final lngRange = math.max(0.000001, maximumLng - minimumLng);
    final availableWidth = size.width - horizontalPadding * 2;
    final availableHeight = size.height - topPadding - bottomPadding;
    final scale = math.min(
      availableWidth / lngRange,
      availableHeight / latRange,
    );
    final offsetX = (size.width - lngRange * scale) / 2;
    final offsetY = topPadding + (availableHeight - latRange * scale) / 2;
    Offset project(RoutePoint point) => Offset(
      offsetX + (point.lng - minimumLng) * scale,
      offsetY + (maximumLat - point.lat) * scale,
    );
    Path pathFor(List<RoutePoint> source) {
      final first = project(source.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in source.skip(1)) {
        final offset = project(point);
        path.lineTo(offset.dx, offset.dy);
      }
      return path;
    }

    canvas.drawPath(
      pathFor(points),
      Paint()
        ..color = const Color(0xFF9CAB9F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final startValue = startDistance;
    final finishValue = finishDistance;
    if (startValue == null || finishValue == null) return;
    final minimumDistance = math.min(startValue, finishValue);
    final maximumDistance = math.max(startValue, finishValue);
    final selected = points
        .where(
          (point) =>
              point.distanceKm >= minimumDistance - 0.01 &&
              point.distanceKm <= maximumDistance + 0.01,
        )
        .toList(growable: false);
    if (selected.length < 2) return;
    canvas.drawPath(
      pathFor(selected),
      Paint()
        ..color = EurotrexPalette.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in [selected.first, selected.last]) {
      final center = project(point);
      canvas.drawCircle(center, 9, Paint()..color = Colors.white);
      canvas.drawCircle(center, 6, Paint()..color = _green);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteSelectionPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.startDistance != startDistance ||
      oldDelegate.finishDistance != finishDistance;
}

class _PaceStep extends StatelessWidget {
  const _PaceStep({
    required this.unit,
    required this.value,
    required this.distanceUnit,
    required this.onUnitChanged,
    required this.onValueChanged,
    required this.onBack,
    required this.onNext,
  });
  final _PaceUnit unit;
  final double value;
  final String distanceUnit;
  final ValueChanged<_PaceUnit> onUnitChanged;
  final ValueChanged<double> onValueChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isHours = unit == _PaceUnit.hours;
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
                context.l10n.t('How do you prefer to set your pace?'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SegmentedButton<_PaceUnit>(
                key: const ValueKey('route-planner-pace-unit'),
                expandedInsets: EdgeInsets.zero,
                segments: [
                  ButtonSegment(
                    value: _PaceUnit.hours,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(context.l10n.t('Hours')),
                  ),
                  ButtonSegment(
                    value: _PaceUnit.distance,
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
                  'Walking time includes an allowance for climbing. Each option adjusts the effort around this target.',
                ),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
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
    required this.onPreferenceChanged,
    required this.onPriceChanged,
    required this.onBack,
    required this.onBuild,
  });
  final RouteOvernightPreference preference;
  final RangeValues priceRange;
  final ValueChanged<RouteOvernightPreference> onPreferenceChanged;
  final ValueChanged<RangeValues> onPriceChanged;
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
            SegmentedButton<RouteOvernightPreference>(
              key: const ValueKey('route-planner-stay-type'),
              expandedInsets: EdgeInsets.zero,
              segments: [
                ButtonSegment(
                  value: RouteOvernightPreference.accommodation,
                  label: Text(context.l10n.t('Accommodation')),
                  icon: const Icon(Icons.bed_rounded),
                ),
                ButtonSegment(
                  value: RouteOvernightPreference.either,
                  label: Text(context.l10n.t('Either')),
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                ButtonSegment(
                  value: RouteOvernightPreference.camping,
                  label: Text(context.l10n.t('Camping')),
                  icon: const Icon(Icons.cabin_rounded),
                ),
              ],
              selected: {preference},
              onSelectionChanged: (values) =>
                  onPreferenceChanged(values.single),
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
                onChanged: onPriceChanged,
              ),
              Text(
                context.l10n.t(
                  'The range applies per room, per night, using listed prices.',
                ),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
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
    required this.selected,
    required this.formatter,
    required this.routePoints,
    required this.stages,
    required this.lodgings,
    required this.offlineMap,
    required this.saving,
    required this.onBack,
    required this.onDone,
    required this.onSelect,
    required this.onEditBoundary,
    required this.onChooseAccommodation,
    required this.onStartDay,
    required this.onOpenMap,
  });
  final Map<RoutePlanStyle, _PlannedVariant?> variants;
  final RoutePlanStyle? selected;
  final MeasurementFormatter formatter;
  final List<RoutePoint> routePoints;
  final List<TrailStage> stages;
  final List<Lodging> lodgings;
  final AsyncValue<OfflineMapState>? offlineMap;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback? onDone;
  final void Function(RoutePlanStyle, _PlannedVariant) onSelect;
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
            selected: selected == style,
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
            if (onDone != null) ...[
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
          const SizedBox(height: 12),
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
            title: context.l10n.t('No feasible route found'),
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
    required this.selected,
    required this.formatter,
    required this.onTap,
  });
  final RoutePlanStyle style;
  final _PlannedVariant? variant;
  final bool selected;
  final MeasurementFormatter formatter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = styleColor(style);
    final plan = variant?.plan;
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
                    Text(
                      context.l10n.t(styleLabel(style)),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      plan == null
                          ? context.l10n.t('Unavailable for these preferences')
                          : '${context.l10n.t(plan.days.first.start.name)} → ${context.l10n.t(plan.days.last.finish.name)}\n${plan.days.length} ${context.l10n.t('walking days')} · ${formatter.distance(plan.totalDistanceKm)} · €${plan.estimatedAccommodationCostEur.toStringAsFixed(0)}+',
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
