import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/location/device_location.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../accommodation/domain/lodging.dart';
import '../../accommodation/presentation/accommodation_controller.dart';
import '../../accommodation/presentation/accommodation_screen.dart';
import '../../accommodation/presentation/lodging_type_icon.dart';
import '../../elevation/domain/route_point.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../elevation/presentation/elevation_screen.dart';
import '../../map/presentation/map_flag_marker.dart';
import '../../map/presentation/map_screen.dart';
import '../../map/presentation/offline_map_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../trail/domain/trail_direction.dart';
import '../../trail/presentation/trail_direction_controller.dart';
import '../../trail/presentation/trail_information_screen.dart';
import '../data/stage_repository.dart';
import '../domain/stage.dart';
import '../domain/trail_location_matcher.dart';
import '../domain/walking_time_estimator.dart';
import 'stages_controller.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _red = Color(0xFFD14B45);
const _mint = Color(0xFFE1F1E8);
const _sand = Color(0xFFF4F2EC);
const _yellow = Color(0xFFF2C94C);
const _bookingBlue = Color(0xFF1565C0);
const _accommodationBlue = Color(0xFF0288D1);
const _filterBlueTeal = Color(0xFF356F7A);
const _timelineLineColor = Color(0xFFB9BDB8);
const _timelineLeftInset = 12.0;
const _timelineGutterWidth = 84.0;
const _timelineLineColumnWidth = 20.0;
const _gpsButtonSize = 40.0;
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

typedef _StageLegMetrics = ({
  double? ascentM,
  double? descentM,
  double? lengthKm,
});

_StageLegMetrics _stageLegMetrics({
  required List<TrailStage> orderedStages,
  required int index,
  required TrailDirection direction,
}) {
  if (index == 0) {
    return (ascentM: 0, descentM: 0, lengthKm: 0);
  }

  final sourceStage = direction.isReversed
      ? orderedStages[index - 1]
      : orderedStages[index];
  return (
    ascentM: direction.isReversed
        ? sourceStage.elevationDownM
        : sourceStage.elevationUpM,
    descentM: direction.isReversed
        ? sourceStage.elevationUpM
        : sourceStage.elevationDownM,
    lengthKm: sourceStage.segmentLengthKm,
  );
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
  final Map<String, GlobalKey> _stageRowKeys = {};
  Set<String> selectedServices = {};
  String? _gpsSelectedStageId;
  bool _isLocatingStage = false;

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

  GlobalKey _stageRowKey(String stageId) =>
      _stageRowKeys.putIfAbsent(stageId, GlobalKey.new);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.t(message))));
  }

  Future<void> _toggleGpsStage() async {
    if (_gpsSelectedStageId != null) {
      setState(() => _gpsSelectedStageId = null);
      return;
    }
    await _findMyStage();
  }

  Future<void> _findMyStage() async {
    if (_isLocatingStage) return;
    setState(() {
      _isLocatingStage = true;
      _gpsSelectedStageId = null;
    });

    try {
      final routePointsFuture = ref.read(elevationProvider.future);
      final sourceStagesFuture = ref.read(stagesProvider.future);
      late final List<RoutePoint> routePoints;
      late final List<TrailStage> sourceStages;
      try {
        (routePoints, sourceStages) = await (
          routePointsFuture,
          sourceStagesFuture,
        ).wait;
      } catch (_) {
        _showMessage('Route data is not on this device yet.');
        return;
      }
      if (!mounted) return;
      if (routePoints.isEmpty || sourceStages.isEmpty) {
        _showMessage('Route data is not on this device yet.');
        return;
      }

      final locationReader = ref.read(deviceLocationReaderProvider);
      final location = await locationReader();
      if (!mounted) return;
      if (!location.accuracyM.isFinite ||
          location.accuracyM < 0 ||
          location.accuracyM > maximumUsableLocationAccuracyM) {
        _showMessage('Your location could not be read right now.');
        return;
      }

      final direction = ref.read(trailDirectionProvider);
      final orderedStages = direction.isReversed
          ? sourceStages.reversed.toList(growable: false)
          : sourceStages;
      final match = findNearbyTrailStage(
        latitude: location.latitude,
        longitude: location.longitude,
        locationAccuracyM: location.accuracyM,
        routePoints: routePoints,
        stages: sourceStages,
        direction: direction,
      );
      if (match == null) {
        _showMessage('You are not on the trail.');
        return;
      }

      final stage = orderedStages.firstWhere(
        (item) => item.id == match.stageId,
      );
      if (!mounted) return;
      setState(() {
        _gpsSelectedStageId = stage.id;
        selectedServices.clear();
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final targetContext = _stageRowKeys[stage.id]?.currentContext;
      if (targetContext != null &&
          targetContext.mounted &&
          !_isFullyVisible(targetContext)) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.16,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
        );
      }
    } on LocationServicesDisabledException {
      _showMessage('Turn on Location Services to show your position.');
    } on LocationPermissionDeniedException {
      _showMessage('Location permission is needed to show your position.');
    } catch (_) {
      _showMessage('Your location could not be read right now.');
    } finally {
      if (mounted) setState(() => _isLocatingStage = false);
    }
  }

  bool _isFullyVisible(BuildContext targetContext) {
    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final screenHeight = MediaQuery.sizeOf(context).height;
    return top >= kToolbarHeight + MediaQuery.paddingOf(context).top &&
        bottom <= screenHeight - 24;
  }

  Widget _buildStageTimelineRow({
    required BuildContext context,
    required TrailStage stage,
    required int filteredIndex,
    required List<TrailStage> filteredItems,
    required List<TrailStage> orderedItems,
    required TrailDirection direction,
    required MeasurementFormatter formatter,
    required double totalDistanceKm,
  }) {
    final orderedIndex = orderedItems.indexWhere((item) => item.id == stage.id);
    final legMetrics = _stageLegMetrics(
      orderedStages: orderedItems,
      index: orderedIndex,
      direction: direction,
    );
    return _StageTimelineRow(
      key: _stageRowKey(stage.id),
      stage: stage,
      formatter: formatter,
      ascentM: legMetrics.ascentM,
      descentM: legMetrics.descentM,
      segmentLengthKm: legMetrics.lengthKm,
      distanceKm: stage.accumulatedDistanceKm == null
          ? null
          : direction.distanceFromStart(
              stage.accumulatedDistanceKm!,
              totalDistanceKm,
            ),
      isLast: filteredIndex == filteredItems.length - 1,
      isTrailStart: orderedIndex == 0,
      isTrailEnd: orderedIndex == orderedItems.length - 1,
      isSelected: stage.id == _gpsSelectedStageId,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StageDetailScreen(
            stages: orderedItems,
            initialIndex: orderedIndex,
            direction: direction,
            locationStageId: stage.id == _gpsSelectedStageId
                ? _gpsSelectedStageId
                : null,
          ),
        ),
      ),
    );
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _timelineLeftInset,
                  16,
                  20,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: _timelineGutterWidth,
                    height: _gpsButtonSize + 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        SizedBox(
                          width: _timelineLineColumnWidth,
                          child: Column(
                            children: [
                              SizedBox(
                                width: _timelineLineColumnWidth,
                                height: _gpsButtonSize,
                                child: OverflowBox(
                                  minWidth: _gpsButtonSize,
                                  maxWidth: _gpsButtonSize,
                                  minHeight: _gpsButtonSize,
                                  maxHeight: _gpsButtonSize,
                                  child: _GpsStageButton(
                                    isLocating: _isLocatingStage,
                                    hasSelection: _gpsSelectedStageId != null,
                                    onPressed: _toggleGpsStage,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Center(
                                  child: SizedBox(
                                    width: 2,
                                    child: ColoredBox(
                                      color: _timelineLineColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                        padding: const EdgeInsets.fromLTRB(
                          _timelineLeftInset,
                          0,
                          20,
                          40,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < filteredItems.length;
                                index++
                              )
                                _buildStageTimelineRow(
                                  context: context,
                                  stage: filteredItems[index],
                                  filteredIndex: index,
                                  filteredItems: filteredItems,
                                  orderedItems: orderedItems,
                                  direction: direction,
                                  formatter: formatter,
                                  totalDistanceKm: totalDistanceKm,
                                ),
                            ],
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

class _GpsStageButton extends StatelessWidget {
  const _GpsStageButton({
    required this.isLocating,
    required this.hasSelection,
    required this.onPressed,
  });

  final bool isLocating;
  final bool hasSelection;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: hasSelection,
      child: IconButton.filled(
        key: const ValueKey('stage-gps-locate'),
        tooltip: context.l10n.t('Find my stage'),
        onPressed: isLocating ? null : onPressed,
        style: IconButton.styleFrom(
          backgroundColor: hasSelection ? _bookingBlue : _filterBlueTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _filterBlueTeal.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white70,
          fixedSize: const Size.square(_gpsButtonSize),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(
          isLocating ? Icons.hourglass_top_rounded : Icons.gps_fixed_rounded,
          size: 20,
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
            icon: const Icon(Icons.signpost_rounded),
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
                  Row(
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
                      const SizedBox(width: 8),
                      const Flexible(child: _OfflineMapStatusBadge()),
                    ],
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

class _OfflineMapStatusBadge extends ConsumerWidget {
  const _OfflineMapStatusBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineMap = ref.watch(offlineMapProvider);
    final isReady = offlineMap.value?.isReady == true;
    final isDownloading = offlineMap.value?.isDownloading == true;
    final isFailed = offlineMap.hasError || offlineMap.value?.isFailed == true;
    final isChecking = offlineMap.isLoading;
    final label = context.l10n.t(
      isReady
          ? 'Offline map available'
          : isChecking
          ? 'Checking offline map…'
          : isDownloading
          ? 'Downloading offline map'
          : isFailed
          ? 'Offline map download failed'
          : 'Offline map not downloaded',
    );
    final foreground = isReady
        ? _green
        : isFailed
        ? _red
        : Colors.white70;
    final background = isReady
        ? _mint
        : isFailed
        ? const Color(0xFF5A2928)
        : Colors.white.withValues(alpha: 0.12);

    return Tooltip(
      message: label,
      child: Container(
        key: const ValueKey('offline-map-status-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReady
                  ? Icons.check_circle_rounded
                  : isChecking
                  ? Icons.hourglass_top_rounded
                  : isDownloading
                  ? Icons.download_rounded
                  : isFailed
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: foreground,
              size: 14,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
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
                  icon: Icons.filter_alt_outlined,
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
    required this.ascentM,
    required this.descentM,
    required this.segmentLengthKm,
    required this.distanceKm,
    required this.isLast,
    required this.isTrailStart,
    required this.isTrailEnd,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final TrailStage stage;
  final MeasurementFormatter formatter;
  final double? ascentM;
  final double? descentM;
  final double? segmentLengthKm;
  final double? distanceKm;
  final bool isLast;
  final bool isTrailStart;
  final bool isTrailEnd;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeServices = stage.services.entries
        .where((entry) => entry.value)
        .toList();
    final showDistance = !isTrailStart && distanceKm != null;
    final dotColor = isSelected
        ? _bookingBlue
        : isTrailStart
        ? _green
        : isTrailEnd
        ? _red
        : stage.services['lodging'] == true
        ? _green
        : _ink;
    final sideMetrics = Column(
      key: ValueKey('stage-side-metrics-${stage.id}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _StageSideMetric(
          key: ValueKey('stage-ascent-${stage.id}'),
          icon: Icons.arrow_upward_rounded,
          value: ascentM == null
              ? '—'
              : _compactMeasurement(formatter.altitude(ascentM!)),
          tooltip: context.l10n.t('Ascent'),
          color: _green,
        ),
        _StageSideMetric(
          key: ValueKey('stage-descent-${stage.id}'),
          icon: Icons.arrow_downward_rounded,
          value: descentM == null
              ? '—'
              : _compactMeasurement(formatter.altitude(descentM!)),
          tooltip: context.l10n.t('Descent'),
          color: _red,
        ),
        _StageSideMetric(
          key: ValueKey('stage-length-${stage.id}'),
          icon: Icons.straighten_rounded,
          value: segmentLengthKm == null
              ? '—'
              : _compactMeasurement(formatter.distance(segmentLengthKm!)),
          tooltip: context.l10n.t('Stage length'),
          color: _filterBlueTeal,
        ),
      ],
    );
    final endpointBadge = Padding(
      padding: const EdgeInsets.only(right: 4),
      child: _EndpointBadge(
        key: ValueKey('stage-endpoint-${stage.id}'),
        label: context.l10n.t(isTrailStart ? 'Start point' : 'Finish point'),
        color: isTrailStart ? _green : _red,
      ),
    );
    final sideContent = isTrailStart
        ? endpointBadge
        : isTrailEnd
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [endpointBadge, const SizedBox(height: 3), sideMetrics],
          )
        : sideMetrics;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _timelineGutterWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Center(child: sideContent)),
                SizedBox(
                  width: _timelineLineColumnWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(width: 2, color: _timelineLineColor),
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
                              : _timelineLineColor,
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
              child: Semantics(
                selected: isSelected,
                child: Material(
                  key: ValueKey('stage-card-${stage.id}'),
                  color: isSelected ? const Color(0xFFE8F1FC) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected ? _bookingBlue : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
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
                                    if (showDistance || stage.altitudeM != null)
                                      Row(
                                        key: ValueKey(
                                          'stage-card-metrics-${stage.id}',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (showDistance)
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
                                          if (showDistance &&
                                              stage.altitudeM != null)
                                            const SizedBox(width: 8),
                                          if (stage.altitudeM
                                              case final altitude?)
                                            _MiniLabel(
                                              key: ValueKey(
                                                'stage-card-altitude-${stage.id}',
                                              ),
                                              icon: Icons.landscape_outlined,
                                              label: formatter.altitude(
                                                altitude,
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                                if (activeServices.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    key: ValueKey(
                                      'stage-card-services-${stage.id}',
                                    ),
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      for (final service in activeServices.take(
                                        7,
                                      ))
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
      constraints: const BoxConstraints(maxWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
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
    this.locationStageId,
    super.key,
  });

  final List<TrailStage> stages;
  final int initialIndex;
  final TrailDirection direction;
  final String? locationStageId;

  @override
  ConsumerState<StageDetailScreen> createState() => _StageDetailScreenState();
}

class _StageDetailScreenState extends ConsumerState<StageDetailScreen> {
  late int index = widget.initialIndex;

  TrailStage get stage => widget.stages[index];

  void _openMap({List<Lodging> lodgings = const []}) {
    final locationStageId = stage.id == widget.locationStageId
        ? widget.locationStageId
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          initialStageIndex: index,
          initialLodgings: lodgings,
          locationStageId: locationStageId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final showUserLocation = stage.id == widget.locationStageId;
    final previewRoute = ref.watch(elevationProvider).value;
    final previewStartDistanceKm = index == 0
        ? stage.accumulatedDistanceKm
        : widget.stages[index - 1].accumulatedDistanceKm;
    final previewFinishDistanceKm = index == 0 && widget.stages.length > 1
        ? widget.stages[1].accumulatedDistanceKm
        : stage.accumulatedDistanceKm;
    final lodgings = ref.watch(lodgingsForStageProvider(stage.id));
    final mappedLodgings =
        lodgings.value
            ?.where((lodging) => lodging.location != null)
            .toList(growable: false) ??
        const <Lodging>[];
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
    final legMetrics = _stageLegMetrics(
      orderedStages: widget.stages,
      index: index,
      direction: widget.direction,
    );
    final segmentLengthKm = legMetrics.lengthKm;
    final ascentM = legMetrics.ascentM;
    final descentM = legMetrics.descentM;
    final hasStageLength = segmentLengthKm != null && segmentLengthKm > 0;
    final hasStageEffort =
        index > 0 &&
        segmentLengthKm != null &&
        segmentLengthKm.isFinite &&
        segmentLengthKm >= 0 &&
        ascentM != null &&
        ascentM.isFinite &&
        ascentM >= 0 &&
        descentM != null &&
        descentM.isFinite &&
        descentM >= 0;
    final walkingTime = hasStageEffort
        ? estimateNaismithWalkingTime(
            distanceKm: segmentLengthKm,
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
            onPressed: () => _openMap(lodgings: mappedLodgings),
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
                          ? formatter.distance(segmentLengthKm)
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
          if (stage.services['lodging'] == true ||
              lodgings.value?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _StageAccommodationSection(
              stage: stage,
              lodgings: lodgings,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AccommodationScreen(stage: stage),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _StageMapPreview(
            routePoints: previewRoute ?? const [],
            startDistanceKm: previewStartDistanceKm,
            finishDistanceKm: previewFinishDistanceKm,
            showFinishFlag: stagePreviewShowsFinishFlag(index),
            lodgings: mappedLodgings,
            showUserLocation: showUserLocation,
            onTap: () => _openMap(lodgings: mappedLodgings),
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

class _StageAccommodationSection extends StatelessWidget {
  const _StageAccommodationSection({
    required this.stage,
    required this.lodgings,
    required this.onTap,
  });

  final TrailStage stage;
  final AsyncValue<List<Lodging>> lodgings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String? status = lodgings.isLoading
        ? l10n.t('Finding accommodation…')
        : lodgings.hasError
        ? l10n.t('Accommodation information is currently unavailable.')
        : lodgings.value?.isEmpty == true
        ? l10n.t('No accommodation is listed for this stage.')
        : null;

    return _DetailSection(
      title: l10n.t('Accommodation'),
      child: Material(
        color: _bookingBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('book-accommodation-${stage.id}'),
          onTap: onTap,
          child: Container(
            key: ValueKey('stage-accommodation-${stage.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _bookingBlue.withValues(alpha: 0.25)),
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
                        l10n.t('View places to stay'),
                        style: const TextStyle(
                          color: _bookingBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (lodgings.isLoading)
                  const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: _bookingBlue),
              ],
            ),
          ),
        ),
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

class _StageMapPreview extends StatelessWidget {
  const _StageMapPreview({
    required this.routePoints,
    required this.startDistanceKm,
    required this.finishDistanceKm,
    required this.showFinishFlag,
    required this.lodgings,
    required this.showUserLocation,
    required this.onTap,
  });

  final List<RoutePoint> routePoints;
  final double? startDistanceKm;
  final double? finishDistanceKm;
  final bool showFinishFlag;
  final List<Lodging> lodgings;
  final bool showUserLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = _stageMapPreviewData(
      routePoints: routePoints,
      startDistanceKm: startDistanceKm,
      finishDistanceKm: finishDistanceKm,
    );
    return Semantics(
      key: showUserLocation
          ? const Key('stage-map-user-location-enabled')
          : null,
      label: context.l10n.t('Trail map'),
      image: true,
      button: true,
      onTap: onTap,
      child: Container(
        key: const Key('stage-map-preview'),
        height: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _mint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _green.withValues(alpha: 0.16)),
        ),
        child: mapboxAccessToken.isEmpty || preview == null
            ? GestureDetector(
                key: const Key('stage-map-open'),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: const Center(
                  child: Icon(Icons.map_outlined, color: _green, size: 36),
                ),
              )
            : _StageMapSnapshot(
                key: ValueKey(
                  'stage-map-${preview.startPoint.pointIndex}-'
                  '${preview.finishPoint.pointIndex}-'
                  'finish-$showFinishFlag-'
                  '${lodgings.map((lodging) => lodging.id).join(',')}',
                ),
                routePoints: preview.routePoints,
                startPoint: preview.startPoint,
                finishPoint: preview.finishPoint,
                showFinishFlag: showFinishFlag,
                lodgings: lodgings,
                showUserLocation: showUserLocation,
                onTap: onTap,
              ),
      ),
    );
  }
}

typedef _StageMapPreviewData = ({
  List<RoutePoint> routePoints,
  RoutePoint startPoint,
  RoutePoint finishPoint,
});

({int startIndex, int finishIndex}) stageMapEndpointIndexes({
  required List<RoutePoint> routePoints,
  required double startDistanceKm,
  required double finishDistanceKm,
}) {
  return (
    startIndex: _nearestRoutePointIndex(routePoints, startDistanceKm),
    finishIndex: _nearestRoutePointIndex(routePoints, finishDistanceKm),
  );
}

bool stagePreviewShowsFinishFlag(int stageIndex) => stageIndex > 0;

_StageMapPreviewData? _stageMapPreviewData({
  required List<RoutePoint> routePoints,
  required double? startDistanceKm,
  required double? finishDistanceKm,
}) {
  if (routePoints.isEmpty ||
      startDistanceKm == null ||
      finishDistanceKm == null) {
    return null;
  }

  final endpointIndexes = stageMapEndpointIndexes(
    routePoints: routePoints,
    startDistanceKm: startDistanceKm,
    finishDistanceKm: finishDistanceKm,
  );
  final startIndex = endpointIndexes.startIndex;
  final finishIndex = endpointIndexes.finishIndex;
  final lowerIndex = startIndex < finishIndex ? startIndex : finishIndex;
  final upperIndex = startIndex > finishIndex ? startIndex : finishIndex;
  final segment = routePoints.sublist(lowerIndex, upperIndex + 1);
  return (
    routePoints: segment,
    startPoint: routePoints[startIndex],
    finishPoint: routePoints[finishIndex],
  );
}

int _nearestRoutePointIndex(List<RoutePoint> routePoints, double distanceKm) {
  var nearestIndex = 0;
  var nearestDifference = (routePoints.first.distanceKm - distanceKm).abs();
  for (var index = 1; index < routePoints.length; index++) {
    final difference = (routePoints[index].distanceKm - distanceKm).abs();
    if (difference < nearestDifference) {
      nearestIndex = index;
      nearestDifference = difference;
    }
  }
  return nearestIndex;
}

class _StageMapSnapshot extends StatefulWidget {
  const _StageMapSnapshot({
    required this.routePoints,
    required this.startPoint,
    required this.finishPoint,
    required this.showFinishFlag,
    required this.lodgings,
    required this.showUserLocation,
    required this.onTap,
    super.key,
  });

  final List<RoutePoint> routePoints;
  final RoutePoint startPoint;
  final RoutePoint finishPoint;
  final bool showFinishFlag;
  final List<Lodging> lodgings;
  final bool showUserLocation;
  final VoidCallback onTap;

  @override
  State<_StageMapSnapshot> createState() => _StageMapSnapshotState();
}

class _StageMapSnapshotState extends State<_StageMapSnapshot> {
  static const _mapTapInteractionId = 'stage-preview-open-map';

  late final ViewportState _initialViewport;
  MapboxMap? _map;
  Cancelable? _lodgingTapListener;
  final Map<String, String?> _lodgingStyleImages = {};
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    final center = widget.routePoints[widget.routePoints.length ~/ 2];
    final stageDistanceKm =
        (widget.finishPoint.distanceKm - widget.startPoint.distanceKm).abs();
    final viewportCoordinates = <Position>[
      for (final point in widget.routePoints) Position(point.lng, point.lat),
      for (final lodging in widget.lodgings)
        if (lodging.location case final location?)
          Position(location.longitude, location.latitude),
    ];
    _initialViewport = viewportCoordinates.length == 1
        ? CameraViewportState(
            center: Point(coordinates: Position(center.lng, center.lat)),
            zoom: 12.5,
            bearing: 0,
            pitch: 0,
          )
        : OverviewViewportState(
            geometry: LineString(coordinates: viewportCoordinates),
            geometryPadding: stageDistanceKm > 6
                ? const EdgeInsets.fromLTRB(82, 68, 74, 92)
                : const EdgeInsets.fromLTRB(72, 58, 64, 80),
            bearing: 0,
            pitch: 0,
            maxZoom: 14,
            animationDuration: Duration.zero,
          );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    map.addInteraction(
      TapInteraction.onMap((_) {
        if (mounted) widget.onTap();
      }),
      interactionID: _mapTapInteractionId,
    );
    await map.gestures.updateSettings(
      GesturesSettings(
        rotateEnabled: false,
        pinchToZoomEnabled: false,
        scrollEnabled: false,
        simultaneousRotateAndPinchToZoomEnabled: false,
        pitchEnabled: false,
        doubleTapToZoomInEnabled: false,
        doubleTouchToZoomOutEnabled: false,
        quickZoomEnabled: false,
        pinchPanEnabled: false,
      ),
    );
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    if (widget.showUserLocation) {
      try {
        await map.location.updateSettings(
          LocationComponentSettings(
            enabled: true,
            puckBearingEnabled: true,
            pulsingEnabled: true,
            showAccuracyRing: true,
          ),
        );
      } catch (_) {
        // The stage preview remains useful if location rendering is unavailable.
      }
    }

    if (widget.routePoints.length > 1) {
      final routeManager = await map.annotations
          .createPolylineAnnotationManager();
      await routeManager.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: [
              for (final point in widget.routePoints)
                Position(point.lng, point.lat),
            ],
          ),
          lineColor: _bookingBlue.toARGB32(),
          lineWidth: 5,
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 1.5,
          lineOpacity: 0.95,
        ),
      );
    }

    final flags = await Future.wait([
      mapFlagMarkerImage(_green),
      mapFlagMarkerImage(_red),
    ]);
    final markerManager = await map.annotations.createPointAnnotationManager();
    await markerManager.setIconAllowOverlap(true);
    await markerManager.setIconIgnorePlacement(true);
    await markerManager.createMulti([
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.startPoint.lng, widget.startPoint.lat),
        ),
        image: flags[0],
        iconAnchor: IconAnchor.BOTTOM,
        iconSize: 1.75,
        customData: {
          'role': 'start',
          'distanceKm': widget.startPoint.distanceKm,
        },
      ),
      if (widget.showFinishFlag &&
          widget.finishPoint.pointIndex != widget.startPoint.pointIndex)
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              widget.finishPoint.lng,
              widget.finishPoint.lat,
            ),
          ),
          image: flags[1],
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: 1.75,
          customData: {
            'role': 'finish',
            'distanceKm': widget.finishPoint.distanceKm,
          },
        ),
    ]);
  }

  Future<void> _onMapLoaded(MapLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    final mappedLodgings = widget.lodgings
        .where((lodging) => lodging.location != null)
        .toList(growable: false);
    if (mappedLodgings.isEmpty) return;

    final iconNames = {
      for (final lodging in mappedLodgings) lodgingMakiIconName(lodging.type),
    };
    final styleImages = <String, String?>{};
    for (final iconName in iconNames) {
      styleImages[iconName] = await _resolveLodgingStyleImage(map, iconName);
    }
    final manager = await map.annotations.createPointAnnotationManager();
    await manager.setIconAllowOverlap(true);
    await manager.setIconIgnorePlacement(true);
    await manager.setTextAllowOverlap(true);
    await manager.setTextIgnorePlacement(true);
    final annotations = await manager.createMulti([
      for (var index = 0; index < mappedLodgings.length; index++)
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              mappedLodgings[index].location!.longitude,
              mappedLodgings[index].location!.latitude,
            ),
          ),
          iconImage:
              styleImages[lodgingMakiIconName(mappedLodgings[index].type)],
          iconSize: 1.25,
          iconColor: _accommodationBlue.toARGB32(),
          iconHaloColor: Colors.white.toARGB32(),
          iconHaloWidth: 2,
          iconHaloBlur: 0.5,
          textField:
              styleImages[lodgingMakiIconName(mappedLodgings[index].type)] ==
                  null
              ? '●'
              : null,
          textSize: 20,
          textColor: _accommodationBlue.toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: 2,
          customData: {
            'lodgingIndex': index,
            'name': mappedLodgings[index].name ?? '',
          },
        ),
    ]);
    if (!mounted || annotations.isEmpty) return;
    _lodgingTapListener = manager.tapEvents(
      onTap: (_) {
        if (mounted) widget.onTap();
      },
    );
  }

  Future<String?> _resolveLodgingStyleImage(
    MapboxMap map,
    String makiIconName,
  ) async {
    if (_lodgingStyleImages.containsKey(makiIconName)) {
      return _lodgingStyleImages[makiIconName];
    }
    for (final candidate in [
      '$makiIconName-15',
      makiIconName,
      '$makiIconName-11',
    ]) {
      try {
        if (await map.style.getStyleImage(candidate) != null) {
          _lodgingStyleImages[makiIconName] = candidate;
          return candidate;
        }
      } catch (_) {
        // Try the next sprite naming convention.
      }
    }
    if (makiIconName != 'lodging') {
      final fallback = await _resolveLodgingStyleImage(map, 'lodging');
      _lodgingStyleImages[makiIconName] = fallback;
      return fallback;
    }
    _lodgingStyleImages[makiIconName] = null;
    return null;
  }

  @override
  void dispose() {
    _lodgingTapListener?.cancel();
    _map?.removeInteraction(_mapTapInteractionId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return const Center(
        child: Icon(Icons.map_outlined, color: _green, size: 36),
      );
    }
    return MapWidget(
      key: const ValueKey('stage-map-widget'),
      styleUri: MapboxStyles.OUTDOORS,
      viewport: _initialViewport,
      onMapCreated: _onMapCreated,
      onMapLoadedListener: _onMapLoaded,
      onMapLoadErrorListener: (_) {
        if (mounted) setState(() => _loadFailed = true);
      },
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
