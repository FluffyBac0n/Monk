import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../data/stage_repository.dart';
import '../domain/stage.dart';
import '../domain/walking_time_estimator.dart';
import '../../elevation/presentation/elevation_screen.dart';
import '../../map/presentation/map_screen.dart';
import '../../map/presentation/offline_map_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../trail/domain/trail_direction.dart';
import '../../trail/presentation/trail_direction_controller.dart';
import '../../trail/presentation/trail_information_screen.dart';
import 'stages_controller.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _red = Color(0xFFD14B45);
const _mint = Color(0xFFE1F1E8);
const _sand = Color(0xFFF4F2EC);
const _yellow = Color(0xFFF2C94C);
const _bookingBlue = Color(0xFF1565C0);
const _filterBlueTeal = Color(0xFF356F7A);
const _filterServiceKeys = [
  'lodging',
  'tent',
  'food',
  'grocery',
  'drinkableWater',
  'nonDrinkableWater',
  'toilets',
  'medical',
  'pharmacy',
  'atm',
  'busStop',
];

double _trailDistanceKm(List<TrailStage> stages) {
  var total = 0.0;
  for (final stage in stages) {
    final distance = stage.accumulatedDistanceKm;
    if (distance != null && distance > total) total = distance;
  }
  return total;
}

String _formatWalkingTime(Duration duration, AppLocalizations l10n) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes ${l10n.t('min')}';
  if (minutes == 0) return '$hours ${l10n.t('h')}';
  return '$hours ${l10n.t('h')} $minutes ${l10n.t('min')}';
}

class StagesScreen extends ConsumerStatefulWidget {
  const StagesScreen({super.key});

  static const routeName = '/trails/cyprus-e4/stages';

  @override
  ConsumerState<StagesScreen> createState() => _StagesScreenState();
}

class _StagesScreenState extends ConsumerState<StagesScreen> {
  final ScrollController scrollController = ScrollController();
  Set<String> selectedServices = {};

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(double offset) async {
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openServiceFilters() async {
    final selection = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ServiceFilterSheet(selected: selectedServices),
    );
    if (selection != null && mounted) {
      setState(() => selectedServices = selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = ref.watch(stagesProvider);
    final direction = ref.watch(trailDirectionProvider);
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    ref.listen(stagesProvider, (previous, next) {
      if (!next.hasError || next.isLoading) return;
      final message = next.error is FirebaseNotConfiguredException
          ? 'Firebase is not configured for this build.'
          : 'Could not update the trail. Your offline copy is unchanged.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.t(message))));
    });

    return Scaffold(
      backgroundColor: _sand,
      floatingActionButton: _StageScrollControls(
        onTop: () => _scrollTo(scrollController.position.minScrollExtent),
        onEnd: () => _scrollTo(scrollController.position.maxScrollExtent),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(stagesProvider.notifier).sync(),
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _TrailAppBar(
              direction: direction,
              onReverse: () =>
                  ref.read(trailDirectionProvider.notifier).toggle(),
              onRefresh: stages.isLoading
                  ? null
                  : () => ref.read(stagesProvider.notifier).sync(),
            ),
            SliverToBoxAdapter(
              child: _TrailDashboard(
                selectedServiceCount: selectedServices.length,
                onFilterServices: _openServiceFilters,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            stages.when(
              skipLoadingOnRefresh: true,
              data: (items) {
                final orderedItems = direction.isReversed
                    ? items.reversed.toList(growable: false)
                    : items;
                final filteredItems = selectedServices.isEmpty
                    ? orderedItems
                    : orderedItems
                          .where(
                            (stage) => selectedServices.every(
                              (service) => stage.services[service] == true,
                            ),
                          )
                          .toList(growable: false);
                final totalDistanceKm = _trailDistanceKm(orderedItems);
                return orderedItems.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    : filteredItems.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoMatchingStages(
                          onClear: () => setState(selectedServices.clear),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 20, 40),
                        sliver: SliverList.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) => _StageTimelineRow(
                            stage: filteredItems[index],
                            formatter: formatter,
                            direction: direction,
                            distanceKm:
                                filteredItems[index].accumulatedDistanceKm ==
                                    null
                                ? null
                                : direction.distanceFromStart(
                                    filteredItems[index].accumulatedDistanceKm!,
                                    totalDistanceKm,
                                  ),
                            isFirst: index == 0,
                            isLast: index == filteredItems.length - 1,
                            isTrailStart:
                                filteredItems[index].id ==
                                orderedItems.first.id,
                            isTrailEnd:
                                filteredItems[index].id == orderedItems.last.id,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => StageDetailScreen(
                                  stages: orderedItems,
                                  initialIndex: orderedItems.indexWhere(
                                    (stage) =>
                                        stage.id == filteredItems[index].id,
                                  ),
                                  direction: direction,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageScrollControls extends StatelessWidget {
  const _StageScrollControls({required this.onTop, required this.onEnd});

  final VoidCallback onTop;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          key: const Key('stage-scroll-top'),
          heroTag: 'stage-scroll-top',
          tooltip: l10n.t('Go to top'),
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          onPressed: onTop,
          child: const Icon(Icons.keyboard_double_arrow_up_rounded),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.small(
          key: const Key('stage-scroll-end'),
          heroTag: 'stage-scroll-end',
          tooltip: l10n.t('Go to end'),
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          onPressed: onEnd,
          child: const Icon(Icons.keyboard_double_arrow_down_rounded),
        ),
      ],
    );
  }
}

class _TrailAppBar extends StatelessWidget {
  const _TrailAppBar({
    required this.direction,
    required this.onReverse,
    required this.onRefresh,
  });

  final TrailDirection direction;
  final VoidCallback onReverse;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = direction.isReversed
        ? l10n.larnakaAirport
        : l10n.pafosAirport;
    final end = direction.isReversed ? l10n.pafosAirport : l10n.larnakaAirport;
    return SliverAppBar(
      expandedHeight: 204,
      pinned: true,
      backgroundColor: _ink,
      foregroundColor: Colors.white,
      titleSpacing: 0,
      title: Row(
        key: const ValueKey('trail-toolbar-actions'),
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            key: const ValueKey('trail-information'),
            tooltip: l10n.t('Trail information'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TrailInformationScreen(),
              ),
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          IconButton(
            key: const ValueKey('reverse-trail-direction'),
            tooltip: l10n.t(
              direction.isReversed
                  ? 'Walk from Pafos to Larnaka'
                  : 'Walk from Larnaka to Pafos',
            ),
            onPressed: onReverse,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
          IconButton(
            key: const ValueKey('refresh-offline-trail'),
            tooltip: l10n.t('Refresh offline trail'),
            onPressed: onRefresh,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: l10n.t('Settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_ink, Color(0xFF274B3A)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    key: const ValueKey('stage-long-distance-badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _yellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.t('LONG DISTANCE'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('Cyprus E4'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.routeDirection(start, end),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrailDashboard extends ConsumerWidget {
  const _TrailDashboard({
    required this.selectedServiceCount,
    required this.onFilterServices,
  });

  final int selectedServiceCount;
  final VoidCallback onFilterServices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final offlineMap = ref.watch(offlineMapProvider);
    final isMapOffline = offlineMap.value?.isReady == true;
    final isDownloading = offlineMap.value?.isDownloading == true;
    final mapStatusFailed =
        offlineMap.hasError || offlineMap.value?.isFailed == true;
    final mapStatusChecking = offlineMap.isLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              _Stat(
                value: formatter.distance(558, decimals: 0),
                unit: '',
                label: l10n.t('Distance'),
              ),
              _Stat(value: '123', unit: '', label: l10n.t('Stages')),
              _Stat(
                value: formatter.altitude(1732),
                unit: '',
                label: l10n.t('High point'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DashboardAction(
                  icon: Icons.route_rounded,
                  label: l10n.t('Filter'),
                  color: _filterBlueTeal,
                  badgeCount: selectedServiceCount,
                  onTap: onFilterServices,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardAction(
                  icon: Icons.map_outlined,
                  label: l10n.t('Map'),
                  color: _green,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MapScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardAction(
                  icon: Icons.show_chart_rounded,
                  label: l10n.t('Elevation'),
                  color: const Color(0xFFB96C31),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ElevationScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('offline-map-status-banner'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isMapOffline ? _mint : const Color(0xFFE9ECEA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isMapOffline
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: isMapOffline ? _green : Colors.black54,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t(
                          isMapOffline
                              ? 'Trail data and map available offline'
                              : 'Trail data available offline',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (!isMapOffline) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.t(
                            mapStatusChecking
                                ? 'Checking offline map…'
                                : isDownloading
                                ? 'Downloading offline map'
                                : mapStatusFailed
                                ? 'Offline map download failed'
                                : 'Offline map not downloaded',
                          ),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit, required this.label});

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              children: [
                TextSpan(
                  text: unit.isEmpty ? '' : ' $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Column(
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text('$badgeCount'),
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageTimelineRow extends StatelessWidget {
  const _StageTimelineRow({
    required this.stage,
    required this.formatter,
    required this.direction,
    required this.distanceKm,
    required this.isFirst,
    required this.isLast,
    required this.isTrailStart,
    required this.isTrailEnd,
    required this.onTap,
  });

  final TrailStage stage;
  final MeasurementFormatter formatter;
  final TrailDirection direction;
  final double? distanceKm;
  final bool isFirst;
  final bool isLast;
  final bool isTrailStart;
  final bool isTrailEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeServices = stage.services.entries
        .where((entry) => entry.value)
        .toList();
    final ascentM = direction.isReversed
        ? stage.elevationDownM
        : stage.elevationUpM;
    final descentM = direction.isReversed
        ? stage.elevationUpM
        : stage.elevationDownM;
    final dotColor = isTrailStart
        ? _green
        : isTrailEnd
        ? _red
        : stage.services['lodging'] == true
        ? _green
        : _ink;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      key: ValueKey('stage-side-metrics-${stage.id}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StageSideMetric(
                          key: ValueKey('stage-ascent-${stage.id}'),
                          icon: Icons.arrow_upward_rounded,
                          value: ascentM == null
                              ? '—'
                              : _compactMeasurement(
                                  formatter.altitude(ascentM),
                                ),
                          tooltip: context.l10n.t('Ascent'),
                          color: _green,
                        ),
                        _StageSideMetric(
                          key: ValueKey('stage-descent-${stage.id}'),
                          icon: Icons.arrow_downward_rounded,
                          value: descentM == null
                              ? '—'
                              : _compactMeasurement(
                                  formatter.altitude(descentM),
                                ),
                          tooltip: context.l10n.t('Descent'),
                          color: _red,
                        ),
                        _StageSideMetric(
                          key: ValueKey('stage-length-${stage.id}'),
                          icon: Icons.straighten_rounded,
                          value: stage.segmentLengthKm == null
                              ? '—'
                              : _compactMeasurement(
                                  formatter.distance(stage.segmentLengthKm!),
                                ),
                          tooltip: context.l10n.t('Stage length'),
                          color: _filterBlueTeal,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isFirst
                              ? Colors.transparent
                              : const Color(0xFFB9BDB8),
                        ),
                      ),
                      Container(
                        key: ValueKey('stage-marker-${stage.id}'),
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          border: Border.all(color: _sand, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 2),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isLast
                              ? Colors.transparent
                              : const Color(0xFFB9BDB8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                key: ValueKey('stage-card-${stage.id}'),
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 13, 10, 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stage.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (distanceKm != null ||
                                      stage.altitudeM != null)
                                    Row(
                                      key: ValueKey(
                                        'stage-card-metrics-${stage.id}',
                                      ),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (distanceKm != null)
                                          Text(
                                            formatter.distance(distanceKm!),
                                            key: ValueKey(
                                              'stage-card-distance-${stage.id}',
                                            ),
                                            style: const TextStyle(
                                              color: _green,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (distanceKm != null &&
                                            stage.altitudeM != null)
                                          const SizedBox(width: 8),
                                        if (stage.altitudeM
                                            case final altitude?)
                                          _MiniLabel(
                                            key: ValueKey(
                                              'stage-card-altitude-${stage.id}',
                                            ),
                                            icon: Icons.landscape_outlined,
                                            label: formatter.altitude(altitude),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                key: ValueKey(
                                  'stage-card-services-${stage.id}',
                                ),
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (isTrailStart || isTrailEnd)
                                    _EndpointBadge(
                                      key: ValueKey(
                                        'stage-endpoint-${stage.id}',
                                      ),
                                      label: context.l10n.t(
                                        isTrailStart
                                            ? 'Start point'
                                            : 'Finish point',
                                      ),
                                      color: isTrailStart ? _green : _red,
                                    ),
                                  for (final service in activeServices.take(7))
                                    Tooltip(
                                      message: context.l10n.t(
                                        _serviceLabel(service.key),
                                      ),
                                      child: Icon(
                                        _serviceIcon(service.key),
                                        size: 16,
                                        color: _serviceColor(service.key),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _compactMeasurement(String value) => value.replaceAll(' ', '');

class _StageSideMetric extends StatelessWidget {
  const _StageSideMetric({
    required this.icon,
    required this.value,
    required this.tooltip,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String value;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointBadge extends StatelessWidget {
  const _EndpointBadge({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

class StageDetailScreen extends ConsumerStatefulWidget {
  const StageDetailScreen({
    required this.stages,
    required this.initialIndex,
    this.direction = TrailDirection.pafosToLarnaka,
    super.key,
  });

  final List<TrailStage> stages;
  final int initialIndex;
  final TrailDirection direction;

  @override
  ConsumerState<StageDetailScreen> createState() => _StageDetailScreenState();
}

class _StageDetailScreenState extends ConsumerState<StageDetailScreen> {
  late int index = widget.initialIndex;

  TrailStage get stage => widget.stages[index];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final isMapOffline = ref.watch(offlineMapProvider).value?.isReady == true;
    final services = stage.services.entries
        .where((entry) => entry.value)
        .toList();
    final accumulatedDistance = stage.accumulatedDistanceKm;
    final distanceFromStart = accumulatedDistance == null
        ? null
        : widget.direction.distanceFromStart(
            accumulatedDistance,
            _trailDistanceKm(widget.stages),
          );
    final endpointLabel = index == 0
        ? l10n.t('Start point')
        : index == widget.stages.length - 1
        ? l10n.t('Finish point')
        : null;
    final hasStageLength =
        stage.segmentLengthKm != null && stage.segmentLengthKm! > 0;
    final ascentM = widget.direction.isReversed
        ? stage.elevationDownM
        : stage.elevationUpM;
    final descentM = widget.direction.isReversed
        ? stage.elevationUpM
        : stage.elevationDownM;
    final hasStageEffort =
        hasStageLength &&
        ascentM != null &&
        ascentM.isFinite &&
        ascentM >= 0 &&
        descentM != null &&
        descentM.isFinite &&
        descentM >= 0;
    final walkingTime = hasStageEffort
        ? estimateNaismithWalkingTime(
            distanceKm: stage.segmentLengthKm!,
            ascentM: ascentM,
          )
        : null;
    return Scaffold(
      backgroundColor: _sand,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stage.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'CYPRUS E4 · ${(endpointLabel ?? l10n.stage(stage.sequence)).toUpperCase()}',
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white60,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('stage-detail-stages-shortcut'),
            tooltip: l10n.t('Back to stages'),
            onPressed: () => Navigator.of(context).popUntil(
              (route) =>
                  route.settings.name == StagesScreen.routeName ||
                  route.isFirst,
            ),
            icon: const Icon(Icons.route_rounded),
          ),
          IconButton(
            key: const ValueKey('stage-detail-map'),
            tooltip: l10n.t('Show on map'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MapScreen(initialStageIndex: index),
              ),
            ),
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            key: const ValueKey('stage-detail-elevation'),
            tooltip: l10n.t('Elevation'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ElevationScreen(initialStageIndex: index),
              ),
            ),
            icon: const Icon(Icons.show_chart_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  icon: Icons.route_rounded,
                  value: distanceFromStart == null
                      ? '—'
                      : formatter.distance(distanceFromStart),
                  label: l10n.from(
                    widget.direction.isReversed ? 'Larnaka' : 'Pafos',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailMetric(
                  key: const Key('stage-detail-position'),
                  icon: endpointLabel == null
                      ? Icons.straighten_rounded
                      : Icons.flag_rounded,
                  value:
                      endpointLabel ??
                      (hasStageLength
                          ? formatter.distance(stage.segmentLengthKm!)
                          : '—'),
                  label: endpointLabel != null
                      ? l10n.t('Trail position')
                      : l10n.t('Stage length'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailMetric(
                  icon: Icons.landscape_outlined,
                  value: stage.altitudeM == null
                      ? '—'
                      : formatter.altitude(stage.altitudeM!),
                  label: l10n.t('Altitude'),
                ),
              ),
            ],
          ),
          if (walkingTime != null) ...[
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _DetailMetric(
                      key: const Key('stage-detail-ascent'),
                      icon: Icons.trending_up_rounded,
                      value: formatter.altitude(ascentM!),
                      label: l10n.t('Ascent'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DetailMetric(
                      key: const Key('stage-detail-descent'),
                      icon: Icons.trending_down_rounded,
                      value: formatter.altitude(descentM!),
                      label: l10n.t('Descent'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DetailMetric(
                      key: const Key('stage-detail-walking-time'),
                      icon: Icons.schedule_rounded,
                      value: _formatWalkingTime(walkingTime, l10n),
                      label: l10n.t('Estimated walking time'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.black45,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.t(
                      'Naismith estimate based on distance and ascent. Breaks and terrain are not included.',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _DetailSection(
            title: l10n.t('Services'),
            child: services.isEmpty
                ? Text(l10n.t('No services recorded for this stage.'))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final service in services)
                        Chip(
                          avatar: Icon(
                            _serviceIcon(service.key),
                            size: 17,
                            color: _serviceColor(service.key),
                          ),
                          label: Text(l10n.t(_serviceLabel(service.key))),
                          backgroundColor: _sand,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
          ),
          if (stage.services['lodging'] == true) ...[
            const SizedBox(height: 12),
            _DetailSection(
              title: l10n.t('Lodging'),
              child: Semantics(
                label:
                    '${l10n.t('Accommodation booking')}. ${l10n.t('Coming soon')}',
                enabled: false,
                child: ExcludeSemantics(
                  child: Container(
                    key: ValueKey('book-accommodation-${stage.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _bookingBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _bookingBlue.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hotel_rounded, color: _bookingBlue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('Accommodation booking'),
                                style: const TextStyle(
                                  color: _bookingBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.t('Coming soon'),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.schedule_rounded,
                          color: Colors.black38,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _DetailSection(
            title: l10n.t('Trail position'),
            child: Column(
              children: [
                _PositionRow(
                  icon: Icons.hiking_rounded,
                  title: l10n.t('Following the Cyprus E4'),
                  subtitle: l10n.t(
                    isMapOffline
                        ? 'Trail data and background map are available offline.'
                        : 'Trail data is available offline. Download the offline map to see map details without a connection.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: index > 0 ? () => setState(() => index--) : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(l10n.t('Previous')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: index < widget.stages.length - 1
                      ? () => setState(() => index++)
                      : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(l10n.t('Next')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: _green),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceFilterSheet extends StatefulWidget {
  const _ServiceFilterSheet({required this.selected});

  final Set<String> selected;

  @override
  State<_ServiceFilterSheet> createState() => _ServiceFilterSheetState();
}

class _ServiceFilterSheetState extends State<_ServiceFilterSheet> {
  late final selected = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Filter by services'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('Stages must offer every selected service.'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in _filterServiceKeys)
                  FilterChip(
                    key: ValueKey('service-filter-$service'),
                    selected: selected.contains(service),
                    avatar: Icon(
                      _serviceIcon(service),
                      size: 18,
                      color: _serviceColor(service),
                    ),
                    label: Text(l10n.t(_serviceLabel(service))),
                    onSelected: (isSelected) => setState(() {
                      if (isSelected) {
                        selected.add(service);
                      } else {
                        selected.remove(service);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => setState(selected.clear),
                    child: Text(l10n.t('Clear')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    key: const Key('apply-service-filters'),
                    onPressed: () => Navigator.of(context).pop(selected),
                    icon: const Icon(Icons.filter_alt_rounded),
                    label: Text(l10n.t('Apply filters')),
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

class _NoMatchingStages extends StatelessWidget {
  const _NoMatchingStages({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_alt_off_rounded, size: 54, color: _green),
            const SizedBox(height: 14),
            Text(
              l10n.t('No stages match these services.'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('clear-service-filters'),
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: Text(l10n.t('Clear filters')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hiking_rounded, size: 58, color: _green),
            const SizedBox(height: 16),
            Text(
              l10n.t('Take the trail offline'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t(
                'Download Cyprus E4 to browse its stages without a connection.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => ref.read(stagesProvider.notifier).sync(),
              icon: const Icon(Icons.download_rounded),
              label: Text(l10n.t('Download trail')),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _serviceIcon(String value) {
  return switch (value) {
    'lodging' => Icons.bed_rounded,
    'tent' => Icons.cabin_rounded,
    'food' => Icons.restaurant_rounded,
    'grocery' => Icons.local_grocery_store_rounded,
    'drinkableWater' => Icons.water_drop_rounded,
    'nonDrinkableWater' => Icons.water_drop_outlined,
    'toilets' => Icons.wc_rounded,
    'medical' => Icons.medical_services_rounded,
    'pharmacy' => Icons.local_pharmacy_rounded,
    'atm' => Icons.account_balance_rounded,
    'busStop' => Icons.directions_bus_rounded,
    _ => Icons.check_circle_outline_rounded,
  };
}

String _serviceLabel(String value) {
  return switch (value) {
    'lodging' => 'Lodging',
    'tent' => 'Camping',
    'food' => 'Food',
    'grocery' => 'Groceries',
    'drinkableWater' => 'Drinking water',
    'nonDrinkableWater' => 'Non-drinking water',
    'toilets' => 'Toilets',
    'medical' => 'Medical',
    'pharmacy' => 'Pharmacy',
    'atm' => 'ATM',
    'busStop' => 'Bus',
    _ => value,
  };
}

Color _serviceColor(String value) {
  return switch (value) {
    'drinkableWater' || 'nonDrinkableWater' => const Color(0xFF237DB6),
    'medical' || 'pharmacy' => const Color(0xFFC94949),
    'food' || 'grocery' => const Color(0xFFB76E24),
    _ => _green,
  };
}
