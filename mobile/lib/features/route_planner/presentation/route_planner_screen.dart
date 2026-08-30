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
import '../../stages/domain/stage.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../trail/domain/trail_direction.dart';
import '../domain/route_plan.dart';
import '../domain/saved_route.dart';
import 'saved_routes_controller.dart';

const _sand = Color(0xFFF4F2EC);
const _green = Color(0xFF277653);
const _outline = Color(0xFFD8DDDA);
const _comfort = Color(0xFF75588A);

enum _TripGoal { wholeTrail, bestSection }

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
  _TripGoal tripGoal = _TripGoal.bestSection;
  _StartPreference startPreference = _StartPreference.automatic;
  _PaceUnit paceUnit = _PaceUnit.hours;
  double paceValue = 6;
  RouteOvernightPreference overnightPreference =
      RouteOvernightPreference.accommodation;
  RangeValues accommodationPriceRange = const RangeValues(40, 120);
  Map<RoutePlanStyle, _PlannedVariant?> variants = const {};
  RoutePlanStyle? selectedStyle;
  String? draftRouteId;
  bool saving = false;

  void startNewRoute() => setState(() {
    showWizard = true;
    step = 0;
    walkingDays = 5;
    tripGoal = _TripGoal.bestSection;
    startPreference = _StartPreference.automatic;
    paceUnit = _PaceUnit.hours;
    paceValue = 6;
    overnightPreference = RouteOvernightPreference.accommodation;
    accommodationPriceRange = const RangeValues(40, 120);
    variants = const {};
    selectedStyle = null;
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
        data: (lodgings) => buildWizard(stages, lodgings, formatter, system),
      ),
    );
  }

  Widget buildWizard(
    List<TrailStage> stages,
    List<Lodging> lodgings,
    MeasurementFormatter formatter,
    MeasurementSystem system,
  ) {
    if (orderedStages(stages, TrailDirection.pafosToLarnaka).length < 2) {
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
            goal: tripGoal,
            startPreference: startPreference,
            onDaysChanged: (value) => setState(() => walkingDays = value),
            onGoalChanged: (value) => setState(() => tripGoal = value),
            onStartChanged: (value) => setState(() => startPreference = value),
            onNext: () => setState(() => step = 1),
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
            saving: saving,
            onBack: () => setState(() => step = 2),
            onDone: selectedStyle == null
                ? null
                : () => setState(() => showWizard = false),
            onSelect: (style, variant) =>
                selectRoute(style: style, variant: variant),
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
  });
  final AsyncValue<List<SavedRoute>> routes;
  final MeasurementFormatter formatter;
  final VoidCallback onAdd;
  final ValueChanged<SavedRoute> onDelete;

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
  });
  final SavedRoute route;
  final MeasurementFormatter formatter;
  final VoidCallback onDelete;

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
    required this.goal,
    required this.startPreference,
    required this.onDaysChanged,
    required this.onGoalChanged,
    required this.onStartChanged,
    required this.onNext,
  });
  final int walkingDays;
  final _TripGoal goal;
  final _StartPreference startPreference;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<_TripGoal> onGoalChanged;
  final ValueChanged<_StartPreference> onStartChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        title: context.l10n.t('Your trip'),
        icon: Icons.calendar_month_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.t('How many walking days do you have?'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  key: const ValueKey('route-planner-days-minus'),
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
                      fontSize: 20,
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
            const SizedBox(height: 18),
            Text(
              context.l10n.t('What would you like to walk?'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_TripGoal>(
              key: const ValueKey('route-planner-goal'),
              expandedInsets: EdgeInsets.zero,
              segments: [
                ButtonSegment(
                  value: _TripGoal.bestSection,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(context.l10n.t('Best section')),
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
            const SizedBox(height: 18),
            Text(
              context.l10n.t('Where would you prefer to start?'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_StartPreference>(
              key: const ValueKey('route-planner-start-preference'),
              expandedInsets: EdgeInsets.zero,
              segments: [
                ButtonSegment(
                  value: _StartPreference.automatic,
                  label: Text(context.l10n.t('Best direction')),
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
            if (startPreference == _StartPreference.automatic) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.t(
                  'We will compare both trail directions and choose the better fit.',
                ),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
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
    required this.saving,
    required this.onBack,
    required this.onDone,
    required this.onSelect,
  });
  final Map<RoutePlanStyle, _PlannedVariant?> variants;
  final RoutePlanStyle? selected;
  final MeasurementFormatter formatter;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback? onDone;
  final void Function(RoutePlanStyle, _PlannedVariant) onSelect;

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
  });
  final RoutePlan plan;
  final RoutePlanStyle style;
  final MeasurementFormatter formatter;

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
      Text(
        context.l10n.t('Day-by-day itinerary'),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      for (final day in plan.days) ...[
        _DayCard.plan(day, formatter),
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
    super.key,
  });

  factory _DayCard.plan(RoutePlanDay day, MeasurementFormatter formatter) =>
      _DayCard(
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
      child: Row(
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
