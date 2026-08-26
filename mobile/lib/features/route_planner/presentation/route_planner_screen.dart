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
import '../../trail/presentation/trail_direction_controller.dart';
import '../domain/route_plan.dart';
import '../domain/saved_route.dart';
import 'saved_routes_controller.dart';

const _sand = Color(0xFFF4F2EC);
const _green = Color(0xFF277653);
const _outline = Color(0xFFD8DDDA);
const _comfort = Color(0xFF75588A);

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final routeFormKey = GlobalKey<FormState>();
  final preferencesFormKey = GlobalKey<FormState>();
  final minimumController = TextEditingController(text: '20');
  final maximumController = TextEditingController(text: '30');
  final budgetController = TextEditingController(text: '1000');
  bool showWizard = false;
  int step = 0;
  String? startStageId;
  String? finishStageId;
  String? routeError;
  bool allowCamping = false;
  Map<RoutePlanStyle, RoutePlan?> variants = const {};
  RoutePlanStyle? selectedStyle;
  String? draftRouteId;
  bool saving = false;

  @override
  void dispose() {
    minimumController.dispose();
    maximumController.dispose();
    budgetController.dispose();
    super.dispose();
  }

  void startNewRoute() => setState(() {
    showWizard = true;
    step = 0;
    startStageId = null;
    finishStageId = null;
    routeError = null;
    allowCamping = false;
    minimumController.text = '20';
    maximumController.text = '30';
    budgetController.text = '1000';
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

  double distanceKm(String value, MeasurementSystem system) {
    final parsed = double.parse(value);
    return system == MeasurementSystem.metric ? parsed : parsed / 0.621371;
  }

  String? positiveValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || !parsed.isFinite || parsed <= 0
        ? context.l10n.t('Enter a positive number.')
        : null;
  }

  String? maximumValidator(String? value) {
    final error = positiveValidator(value);
    if (error != null) return error;
    final minimum = double.tryParse(minimumController.text.trim());
    return minimum != null && double.parse(value!.trim()) < minimum
        ? context.l10n.t('Maximum must be at least the minimum.')
        : null;
  }

  String? budgetValidator(String? value) =>
      value == null || value.trim().isEmpty ? null : positiveValidator(value);

  RoutePlanRequest requestFor(
    RoutePlanStyle style,
    List<TrailStage> ordered,
    MeasurementSystem system,
  ) {
    final budget = budgetController.text.trim();
    return RoutePlanRequest(
      startStageId: startStageId ?? ordered.first.id,
      finishStageId: finishStageId ?? ordered.last.id,
      minimumDailyDistanceKm: distanceKm(minimumController.text, system),
      maximumDailyDistanceKm: distanceKm(maximumController.text, system),
      accommodationBudgetEur: budget.isEmpty ? null : double.parse(budget),
      allowCamping: allowCamping,
      style: style,
    );
  }

  void continueRoute(List<TrailStage> stages) {
    if (!routeFormKey.currentState!.validate()) return;
    final start = stages.indexWhere(
      (stage) => stage.id == (startStageId ?? stages.first.id),
    );
    final finish = stages.indexWhere(
      (stage) => stage.id == (finishStageId ?? stages.last.id),
    );
    if (finish <= start) {
      setState(
        () => routeError = context.l10n.t(
          'Finish must come after the start in the current direction.',
        ),
      );
      return;
    }
    setState(() {
      routeError = null;
      step = 1;
    });
  }

  void compareRoutes({
    required List<TrailStage> stages,
    required List<Lodging> lodgings,
    required TrailDirection direction,
    required MeasurementSystem system,
  }) {
    if (!preferencesFormKey.currentState!.validate()) return;
    final ordered = orderedStages(stages, direction);
    setState(() {
      variants = {
        for (final style in RoutePlanStyle.values)
          style: buildDeterministicRoutePlan(
            stages: stages,
            lodgings: lodgings,
            direction: direction,
            request: requestFor(style, ordered, system),
          ),
      };
      selectedStyle = null;
      step = 2;
    });
  }

  Future<void> selectRoute({
    required RoutePlanStyle style,
    required RoutePlan plan,
    required List<TrailStage> stages,
    required TrailDirection direction,
    required MeasurementSystem system,
  }) async {
    if (saving) return;
    final id = draftRouteId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final saved = SavedRoute.fromPlan(
      id: id,
      createdAt: DateTime.now(),
      style: style,
      direction: direction,
      request: requestFor(style, stages, system),
      plan: plan,
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
    final direction = ref.watch(trailDirectionProvider);
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
                  ? context.l10n.routeDirection(
                      context.l10n.t(direction.startName),
                      context.l10n.t(direction.endName),
                    )
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
            ? buildWizardData(direction, formatter, system)
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
    TrailDirection direction,
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
        data: (lodgings) =>
            buildWizard(stages, lodgings, direction, formatter, system),
      ),
    );
  }

  Widget buildWizard(
    List<TrailStage> stages,
    List<Lodging> lodgings,
    TrailDirection direction,
    MeasurementFormatter formatter,
    MeasurementSystem system,
  ) {
    final ordered = orderedStages(stages, direction);
    if (ordered.length < 2) {
      return _Message(
        icon: Icons.route_outlined,
        title: context.l10n.t('Trail data is unavailable.'),
      );
    }
    final start = ordered.any((stage) => stage.id == startStageId)
        ? startStageId!
        : ordered.first.id;
    final finish = ordered.any((stage) => stage.id == finishStageId)
        ? finishStageId!
        : ordered.last.id;
    return ListView(
      key: const ValueKey('route-planner-content'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _Progress(step: step),
        const SizedBox(height: 14),
        if (step == 0)
          Form(
            key: routeFormKey,
            child: _RouteStep(
              stages: ordered,
              start: start,
              finish: finish,
              error: routeError,
              onStart: (value) => setState(() {
                startStageId = value;
                routeError = null;
              }),
              onFinish: (value) => setState(() {
                finishStageId = value;
                routeError = null;
              }),
              onNext: () => continueRoute(ordered),
            ),
          )
        else if (step == 1)
          Form(
            key: preferencesFormKey,
            child: _PreferencesStep(
              minimum: minimumController,
              maximum: maximumController,
              budget: budgetController,
              distanceUnit: formatter.distanceUnit,
              allowCamping: allowCamping,
              minimumValidator: positiveValidator,
              maximumValidator: maximumValidator,
              budgetValidator: budgetValidator,
              onCamping: (value) => setState(() => allowCamping = value),
              onBack: () => setState(() => step = 0),
              onCompare: () => compareRoutes(
                stages: stages,
                lodgings: lodgings,
                direction: direction,
                system: system,
              ),
            ),
          )
        else
          _CompareStep(
            variants: variants,
            selected: selectedStyle,
            formatter: formatter,
            saving: saving,
            onBack: () => setState(() => step = 1),
            onDone: selectedStyle == null
                ? null
                : () => setState(() => showWizard = false),
            onSelect: (style, plan) => selectRoute(
              style: style,
              plan: plan,
              stages: ordered,
              direction: direction,
              system: system,
            ),
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
    final labels = ['Route', 'Preferences', 'Itinerary'];
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
                child: index < step
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

class _RouteStep extends StatelessWidget {
  const _RouteStep({
    required this.stages,
    required this.start,
    required this.finish,
    required this.error,
    required this.onStart,
    required this.onFinish,
    required this.onNext,
  });
  final List<TrailStage> stages;
  final String start;
  final String finish;
  final String? error;
  final ValueChanged<String?> onStart;
  final ValueChanged<String?> onFinish;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        title: context.l10n.t('Choose your route'),
        icon: Icons.alt_route_rounded,
        child: Column(
          children: [
            _StageDropdown(
              key: const ValueKey('route-planner-start'),
              label: context.l10n.t('Start'),
              value: start,
              stages: stages,
              onChanged: onStart,
            ),
            const SizedBox(height: 12),
            _StageDropdown(
              key: const ValueKey('route-planner-finish'),
              label: context.l10n.t('Finish'),
              value: finish,
              stages: stages,
              onChanged: onFinish,
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Colors.red)),
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

class _StageDropdown extends StatelessWidget {
  const _StageDropdown({
    required this.label,
    required this.value,
    required this.stages,
    required this.onChanged,
    super.key,
  });
  final String label;
  final String value;
  final List<TrailStage> stages;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final stage in stages)
        DropdownMenuItem(
          value: stage.id,
          child: Text(
            '${context.l10n.stage(stage.sequence)} · ${context.l10n.t(stage.name)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: onChanged,
  );
}

class _PreferencesStep extends StatelessWidget {
  const _PreferencesStep({
    required this.minimum,
    required this.maximum,
    required this.budget,
    required this.distanceUnit,
    required this.allowCamping,
    required this.minimumValidator,
    required this.maximumValidator,
    required this.budgetValidator,
    required this.onCamping,
    required this.onBack,
    required this.onCompare,
  });
  final TextEditingController minimum;
  final TextEditingController maximum;
  final TextEditingController budget;
  final String distanceUnit;
  final bool allowCamping;
  final FormFieldValidator<String> minimumValidator;
  final FormFieldValidator<String> maximumValidator;
  final FormFieldValidator<String> budgetValidator;
  final ValueChanged<bool> onCamping;
  final VoidCallback onBack;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        title: context.l10n.t('Daily walking limits'),
        icon: Icons.hiking_rounded,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('route-planner-minimum-distance'),
                controller: minimum,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.t('Minimum'),
                  suffixText: distanceUnit,
                ),
                validator: minimumValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: const ValueKey('route-planner-maximum-distance'),
                controller: maximum,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.t('Maximum'),
                  suffixText: distanceUnit,
                ),
                validator: maximumValidator,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Panel(
        title: context.l10n.t('Overnight stops'),
        icon: Icons.hotel_rounded,
        child: Column(
          children: [
            TextFormField(
              key: const ValueKey('route-planner-budget'),
              controller: budget,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.t('Accommodation budget'),
                prefixText: '€ ',
              ),
              validator: budgetValidator,
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('route-planner-allow-camping'),
              contentPadding: EdgeInsets.zero,
              value: allowCamping,
              title: Text(context.l10n.t('Allow camping stages')),
              onChanged: onCamping,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('route-planner-preferences-back'),
              onPressed: onBack,
              child: Text(context.l10n.t('Back')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('route-planner-compare'),
              onPressed: onCompare,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text(context.l10n.t('Compare')),
            ),
          ),
        ],
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
  final Map<RoutePlanStyle, RoutePlan?> variants;
  final RoutePlanStyle? selected;
  final MeasurementFormatter formatter;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback? onDone;
  final void Function(RoutePlanStyle, RoutePlan) onSelect;

  @override
  Widget build(BuildContext context) {
    final selectedPlan = selected == null ? null : variants[selected];
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
            plan: variants[style],
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
        if (selectedPlan != null && selected != null) ...[
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
            plan: selectedPlan,
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
    required this.plan,
    required this.selected,
    required this.formatter,
    required this.onTap,
  });
  final RoutePlanStyle style;
  final RoutePlan? plan;
  final bool selected;
  final MeasurementFormatter formatter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = styleColor(style);
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
                          : '${plan!.days.length} ${context.l10n.t('walking days')} · ${formatter.distance(plan!.totalDistanceKm)} · €${plan!.estimatedAccommodationCostEur.toStringAsFixed(0)}+',
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
          '${context.l10n.t(styleLabel(style))} · ${plan.days.length} ${context.l10n.t('walking days')} · ${formatter.distance(plan.totalDistanceKm)} · €${plan.estimatedAccommodationCostEur.toStringAsFixed(0)}+',
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
  RoutePlanStyle.budget => 'Budget',
  RoutePlanStyle.balanced => 'Balanced',
  RoutePlanStyle.comfort => 'Comfort',
};

Color styleColor(RoutePlanStyle style) => switch (style) {
  RoutePlanStyle.budget => _green,
  RoutePlanStyle.balanced => EurotrexPalette.blue,
  RoutePlanStyle.comfort => _comfort,
};

IconData styleIcon(RoutePlanStyle style) => switch (style) {
  RoutePlanStyle.budget => Icons.savings_outlined,
  RoutePlanStyle.balanced => Icons.balance_rounded,
  RoutePlanStyle.comfort => Icons.hotel_class_outlined,
};
