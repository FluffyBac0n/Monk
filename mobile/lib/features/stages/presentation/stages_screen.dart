import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/database/database_provider.dart';
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
import '../../trail/domain/trail_preferences.dart';
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
const _trailPulseBlue = Color(0xFF73BCE8);
const _bookingBlue = Color(0xFF1565C0);
const _accommodationBlue = Color(0xFF0288D1);
const _filterBlueTeal = Color(0xFF356F7A);
const _timelineLineColor = Color(0xFFB9BDB8);
const _timelineLeftInset = 12.0;
const _timelineGutterWidth = 108.0;
const _timelineLineColumnWidth = 20.0;
const _startPointFilterKey = 'trailStart';
const _finishPointFilterKey = 'trailFinish';
const _beachPointFilterKey = 'trailBeach';
const _viewpointPointFilterKey = 'trailViewpoint';
const _religiousSitePointFilterKey = 'trailReligiousSite';
const _naturalLandmarkPointFilterKey = 'trailNaturalLandmark';
const _forestParkPointFilterKey = 'trailForestPark';
const _stageNameFilterPrefix = 'stage:';
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

bool _stageNameHasBeach(String stageName) =>
    RegExp(r'\bbeach(?:es)?\b', caseSensitive: false).hasMatch(stageName);

bool _stageNameHasViewpoint(String stageName) => RegExp(
  r'\bview[\s-]*points?\b|\blook[\s-]*out\b',
  caseSensitive: false,
).hasMatch(stageName);

bool _stageNameHasReligiousSite(String stageName) => RegExp(
  r'\bmonaster(?:y|ies)\b|\bchurch(?:es)?\b|\bchruch\b|\btekke\b|\biera\s+moni\b',
  caseSensitive: false,
).hasMatch(stageName);

bool _stageNameHasNaturalLandmark(String stageName) => RegExp(
  r'\bbaths?\b|\bgorges?\b|\bcaves?\b|\boaks?\b|\bcape\b',
  caseSensitive: false,
).hasMatch(stageName);

bool _stageNameHasForestOrPark(String stageName) => RegExp(
  r'\bforests?\b|\bparks?\b|\bvalleys?\b',
  caseSensitive: false,
).hasMatch(stageName);

bool _stageMatchesFilters({
  required TrailStage stage,
  required int stageIndex,
  required int stageCount,
  required Set<String> filters,
}) {
  final filtersStart = filters.contains(_startPointFilterKey);
  final filtersFinish = filters.contains(_finishPointFilterKey);
  final filtersBeach = filters.contains(_beachPointFilterKey);
  final filtersViewpoint = filters.contains(_viewpointPointFilterKey);
  final filtersReligiousSite = filters.contains(_religiousSitePointFilterKey);
  final filtersNaturalLandmark = filters.contains(
    _naturalLandmarkPointFilterKey,
  );
  final filtersForestPark = filters.contains(_forestParkPointFilterKey);
  final selectedStageIds = filters
      .where((filter) => filter.startsWith(_stageNameFilterPrefix))
      .map((filter) => filter.substring(_stageNameFilterPrefix.length))
      .toSet();
  if (selectedStageIds.isNotEmpty && !selectedStageIds.contains(stage.id)) {
    return false;
  }
  final hasPointFilter =
      filtersStart ||
      filtersFinish ||
      filtersBeach ||
      filtersViewpoint ||
      filtersReligiousSite ||
      filtersNaturalLandmark ||
      filtersForestPark;
  final matchesPoint =
      !hasPointFilter ||
      (filtersStart && stageIndex == 0) ||
      (filtersFinish && stageIndex == stageCount - 1) ||
      (filtersBeach && _stageNameHasBeach(stage.name)) ||
      (filtersViewpoint && _stageNameHasViewpoint(stage.name)) ||
      (filtersReligiousSite && _stageNameHasReligiousSite(stage.name)) ||
      (filtersNaturalLandmark && _stageNameHasNaturalLandmark(stage.name)) ||
      (filtersForestPark && _stageNameHasForestOrPark(stage.name));
  if (!matchesPoint) return false;
  return _filterServiceKeys
      .where(filters.contains)
      .every((service) => stage.services[service] == true);
}

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
  DeviceLocation? _gpsLocation;
  bool _isLocatingStage = false;
  bool _isHeaderCollapsed = false;
  bool? _hasSeenTrailInformation;
  bool? _hasSeenStageDetailsHint;
  bool? _hasSeenStageMetricsHint;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_updateHeaderCollapseState);
    unawaited(_restoreGuidanceSeen());
  }

  @override
  void dispose() {
    scrollController.removeListener(_updateHeaderCollapseState);
    scrollController.dispose();
    super.dispose();
  }

  void _updateHeaderCollapseState() {
    final isCollapsed =
        scrollController.hasClients && scrollController.offset >= 116;
    if (isCollapsed == _isHeaderCollapsed || !mounted) return;
    setState(() => _isHeaderCollapsed = isCollapsed);
  }

  Future<void> _openServiceFilters() async {
    List<TrailStage> sourceStages;
    try {
      sourceStages = await ref.read(stagesProvider.future);
    } catch (_) {
      sourceStages = const <TrailStage>[];
    }
    if (!mounted) return;
    final direction = ref.read(trailDirectionProvider);
    final orderedStages = direction.isReversed
        ? sourceStages.reversed.toList(growable: false)
        : sourceStages;
    final selection = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _sand,
      builder: (_) => _ServiceFilterSheet(
        selected: selectedServices,
        stages: orderedStages,
      ),
    );
    if (selection != null && mounted) {
      setState(() => selectedServices = selection);
    }
  }

  Future<void> _restoreGuidanceSeen() async {
    var hasSeenTrailInformation = false;
    var hasSeenStageDetailsHint = false;
    var hasSeenStageMetricsHint = false;
    try {
      final settings = await ref.read(appDatabaseProvider).readSettings();
      hasSeenTrailInformation =
          settings[cyprusE4TrailInformationSeenSetting] == 'true';
      hasSeenStageDetailsHint =
          settings[cyprusE4StageDetailsHintSeenSetting] == 'true';
      hasSeenStageMetricsHint =
          settings[cyprusE4StageMetricsHintSeenSetting] == 'true';
    } catch (_) {
      // Keep the guidance available when persistence cannot be read.
    }
    if (!mounted) return;
    setState(() {
      if (_hasSeenTrailInformation != true) {
        _hasSeenTrailInformation = hasSeenTrailInformation;
      }
      if (_hasSeenStageDetailsHint != true) {
        _hasSeenStageDetailsHint = hasSeenStageDetailsHint;
      }
      if (_hasSeenStageMetricsHint != true) {
        _hasSeenStageMetricsHint = hasSeenStageMetricsHint;
      }
    });
  }

  void _openTrailInformation() {
    if (_hasSeenTrailInformation != true) {
      setState(() => _hasSeenTrailInformation = true);
      unawaited(_persistTrailInformationSeen());
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TrailInformationScreen()),
    );
  }

  Future<void> _persistTrailInformationSeen() async {
    try {
      await ref
          .read(appDatabaseProvider)
          .writeSetting(cyprusE4TrailInformationSeenSetting, 'true');
    } catch (_) {
      // The prompt still stops for the current session if persistence fails.
    }
  }

  void _markStageDetailsHintSeen() {
    if (_hasSeenStageDetailsHint == true) return;
    setState(() => _hasSeenStageDetailsHint = true);
    unawaited(_persistStageDetailsHintSeen());
  }

  Future<void> _persistStageDetailsHintSeen() async {
    try {
      await ref
          .read(appDatabaseProvider)
          .writeSetting(cyprusE4StageDetailsHintSeenSetting, 'true');
    } catch (_) {
      // The helper still stays dismissed for the current session.
    }
  }

  void _markStageMetricsHintSeen() {
    if (_hasSeenStageMetricsHint == true) return;
    setState(() => _hasSeenStageMetricsHint = true);
    unawaited(_persistStageMetricsHintSeen());
  }

  Future<void> _persistStageMetricsHintSeen() async {
    try {
      await ref
          .read(appDatabaseProvider)
          .writeSetting(cyprusE4StageMetricsHintSeenSetting, 'true');
    } catch (_) {
      // The helper still stays dismissed for the current session.
    }
  }

  GlobalKey _stageRowKey(String stageId) =>
      _stageRowKeys.putIfAbsent(stageId, GlobalKey.new);

  void _showMessage(String message) {
    if (!mounted) return;
    _showLocalizedMessage(context.l10n.t(message));
  }

  void _showLocalizedMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showOffTrailDistance(
    DeviceLocation location,
    List<RoutePoint> routePoints,
  ) {
    final distanceM = distanceFromTrailM(
      latitude: location.latitude,
      longitude: location.longitude,
      routePoints: routePoints,
    );
    if (distanceM == null) {
      _showMessage('You are not on the trail.');
      return;
    }
    final formatter = MeasurementFormatter(
      ref.read(appSettingsProvider).measurementSystem,
    );
    _showLocalizedMessage(
      context.l10n.offTrailDistance(formatter.altitude(distanceM)),
    );
  }

  Future<void> _toggleGpsStage() async {
    if (_gpsSelectedStageId != null) {
      setState(() {
        _gpsSelectedStageId = null;
        _gpsLocation = null;
      });
      return;
    }
    await _findMyStage();
  }

  Future<void> _findMyStage() async {
    if (_isLocatingStage) return;
    setState(() {
      _isLocatingStage = true;
      _gpsSelectedStageId = null;
      _gpsLocation = null;
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
        _showOffTrailDistance(location, routePoints);
        return;
      }

      final stage = orderedStages.firstWhere(
        (item) => item.id == match.stageId,
      );
      if (!mounted) return;
      setState(() {
        _gpsSelectedStageId = stage.id;
        _gpsLocation = location;
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
    required bool connectsFirstFilteredStageToWaymark,
    required TrailDirection direction,
    required MeasurementFormatter formatter,
    required double totalDistanceKm,
    required bool showMetricsHint,
  }) {
    final orderedIndex = orderedItems.indexWhere((item) => item.id == stage.id);
    final previousOrderedIndex = filteredIndex == 0
        ? null
        : orderedItems.indexWhere(
            (item) => item.id == filteredItems[filteredIndex - 1].id,
          );
    final nextOrderedIndex = filteredIndex == filteredItems.length - 1
        ? null
        : orderedItems.indexWhere(
            (item) => item.id == filteredItems[filteredIndex + 1].id,
          );
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
      connectsToPrevious:
          orderedIndex == 0 ||
          (filteredIndex == 0 && connectsFirstFilteredStageToWaymark) ||
          previousOrderedIndex == orderedIndex - 1,
      connectsToNext: nextOrderedIndex == orderedIndex + 1,
      isTrailStart: orderedIndex == 0,
      isTrailEnd: orderedIndex == orderedItems.length - 1,
      isSelected: stage.id == _gpsSelectedStageId,
      showDetailsHint:
          filteredIndex == 0 &&
          _hasSeenTrailInformation == true &&
          _hasSeenStageDetailsHint == false,
      showMetricsHint: showMetricsHint,
      onMetricsHintDismiss: _markStageMetricsHintSeen,
      onTap: () {
        _markStageDetailsHintSeen();
        if (showMetricsHint) _markStageMetricsHintSeen();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StageDetailScreen(
              stages: orderedItems,
              initialIndex: orderedIndex,
              direction: direction,
              locationStageId: stage.id == _gpsSelectedStageId
                  ? _gpsSelectedStageId
                  : null,
              initialLocation: stage.id == _gpsSelectedStageId
                  ? _gpsLocation
                  : null,
            ),
          ),
        );
      },
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
      bottomNavigationBar: _StageBottomNavigationBar(
        isReversed: direction.isReversed,
        selectedServiceCount: selectedServices.length,
        hasGpsSelection: _gpsSelectedStageId != null,
        isLocating: _isLocatingStage,
        onFilter: _openServiceFilters,
        onReverse: () => ref.read(trailDirectionProvider.notifier).toggle(),
        onGps: _toggleGpsStage,
        onMap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const MapScreen())),
        onElevation: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ElevationScreen()),
        ),
      ),
      body: RefreshIndicator(
        key: const ValueKey('stage-pull-to-refresh'),
        onRefresh: () => ref.read(stagesProvider.notifier).sync(),
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _TrailAppBar(
              direction: direction,
              isCollapsed: _isHeaderCollapsed,
              onTrailInformationHintReset: () =>
                  setState(() => _hasSeenTrailInformation = false),
              onStageDetailsHintReset: () =>
                  setState(() => _hasSeenStageDetailsHint = false),
              onStageMetricsHintReset: () =>
                  setState(() => _hasSeenStageMetricsHint = false),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            stages.when(
              skipLoadingOnRefresh: true,
              data: (items) {
                final orderedItems = direction.isReversed
                    ? items.reversed.toList(growable: false)
                    : items;
                final filteredItems = selectedServices.isEmpty
                    ? orderedItems
                    : [
                        for (
                          var stageIndex = 0;
                          stageIndex < orderedItems.length;
                          stageIndex++
                        )
                          if (_stageMatchesFilters(
                            stage: orderedItems[stageIndex],
                            stageIndex: stageIndex,
                            stageCount: orderedItems.length,
                            filters: selectedServices,
                          ))
                            orderedItems[stageIndex],
                      ];
                final totalDistanceKm = _trailDistanceKm(orderedItems);
                final selectedStageNameCount = selectedServices
                    .where(
                      (filter) => filter.startsWith(_stageNameFilterPrefix),
                    )
                    .length;
                final connectsSingleNamedStageToWaymark =
                    filteredItems.length == 1 && selectedStageNameCount == 1;
                String? metricsHintStageId;
                if (_hasSeenTrailInformation == true &&
                    _hasSeenStageMetricsHint == false &&
                    _hasSeenStageDetailsHint == true) {
                  for (final candidate in filteredItems) {
                    final candidateIndex = orderedItems.indexWhere(
                      (stage) => stage.id == candidate.id,
                    );
                    if (candidateIndex > 0) {
                      metricsHintStageId = candidate.id;
                      break;
                    }
                  }
                }
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
                              _TrailTimelineWaymark(
                                shouldPulse: _hasSeenTrailInformation == false,
                                connectsToTimeline:
                                    connectsSingleNamedStageToWaymark ||
                                    orderedItems.indexWhere(
                                          (item) =>
                                              item.id == filteredItems.first.id,
                                        ) ==
                                        0,
                                onTap: _openTrailInformation,
                              ),
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
                                  connectsFirstFilteredStageToWaymark:
                                      connectsSingleNamedStageToWaymark,
                                  direction: direction,
                                  formatter: formatter,
                                  totalDistanceKm: totalDistanceKm,
                                  showMetricsHint:
                                      filteredItems[index].id ==
                                      metricsHintStageId,
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

class _StageBottomNavigationBar extends StatelessWidget {
  const _StageBottomNavigationBar({
    required this.isReversed,
    required this.selectedServiceCount,
    required this.hasGpsSelection,
    required this.isLocating,
    required this.onFilter,
    required this.onReverse,
    required this.onGps,
    required this.onMap,
    required this.onElevation,
  });

  final bool isReversed;
  final int selectedServiceCount;
  final bool hasGpsSelection;
  final bool isLocating;
  final VoidCallback onFilter;
  final VoidCallback onReverse;
  final VoidCallback onGps;
  final VoidCallback onMap;
  final VoidCallback onElevation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      key: const ValueKey('stage-bottom-navigation'),
      color: _ink,
      child: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('stage-bottom-navigation-size'),
          height: 48,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StageBottomAction(
                key: const ValueKey('reverse-trail-direction'),
                icon: Icons.swap_horiz_rounded,
                showReverseTrailIcon: true,
                label: l10n.t(
                  isReversed
                      ? 'Walk from Pafos to Larnaka'
                      : 'Walk from Larnaka to Pafos',
                ),
                onTap: onReverse,
              ),
              _StageBottomAction(
                key: const ValueKey('stage-bottom-filter'),
                icon: Icons.filter_list_rounded,
                label: l10n.t('Filter'),
                isActive: selectedServiceCount > 0,
                badgeCount: selectedServiceCount,
                onTap: onFilter,
              ),
              _StageBottomAction(
                key: const ValueKey('stage-bottom-gps'),
                icon: isLocating
                    ? Icons.hourglass_top_rounded
                    : hasGpsSelection
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                label: l10n.t('Find my stage'),
                isActive: hasGpsSelection,
                isToggle: true,
                isPrimary: true,
                onTap: isLocating ? null : onGps,
              ),
              _StageBottomAction(
                key: const ValueKey('stage-bottom-map'),
                icon: Icons.map_outlined,
                label: l10n.t('Map'),
                onTap: onMap,
              ),
              _StageBottomAction(
                key: const ValueKey('stage-bottom-elevation'),
                icon: Icons.landscape_outlined,
                label: l10n.t('Elevation'),
                onTap: onElevation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageBottomAction extends StatelessWidget {
  const _StageBottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isToggle = false,
    this.isPrimary = false,
    this.badgeCount = 0,
    this.showReverseTrailIcon = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isToggle;
  final bool isPrimary;
  final int badgeCount;
  final bool showReverseTrailIcon;

  @override
  Widget build(BuildContext context) {
    final foreground = onTap == null
        ? Colors.white30
        : isActive
        ? Colors.white
        : Colors.white70;
    Widget buildIcon(double size) => showReverseTrailIcon
        ? _ReverseTrailIcon(color: foreground, size: size + 4)
        : Icon(icon, color: foreground, size: size);
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: isToggle ? null : isActive,
          toggled: isToggle ? isActive : null,
          label: label,
          child: InkWell(
            splashColor: Colors.white12,
            highlightColor: Colors.white10,
            onTap: onTap == null
                ? null
                : () {
                    unawaited(HapticFeedback.selectionClick());
                    onTap!();
                  },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Badge(
                    isLabelVisible: badgeCount > 0,
                    backgroundColor: _yellow,
                    textColor: _ink,
                    label: Text('$badgeCount'),
                    child: isPrimary
                        ? AnimatedContainer(
                            key: const ValueKey('stage-bottom-gps-surface'),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _green
                                  : Colors.white.withValues(alpha: 0.055),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: buildIcon(22)),
                          )
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: buildIcon(22)),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReverseTrailIcon extends StatelessWidget {
  const _ReverseTrailIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey('reverse-trail-combined-icon'),
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -10,
            top: size * 0.13,
            child: Icon(
              Icons.swap_horiz_rounded,
              color: color.withValues(alpha: 0.48),
              size: size * 0.77,
            ),
          ),
          Positioned(
            left: -1,
            top: size * 0.11,
            child: Icon(Icons.hiking_rounded, color: color, size: size * 0.78),
          ),
        ],
      ),
    );
  }
}

class _TrailAppBar extends StatelessWidget {
  const _TrailAppBar({
    required this.direction,
    required this.isCollapsed,
    required this.onTrailInformationHintReset,
    required this.onStageDetailsHintReset,
    required this.onStageMetricsHintReset,
  });

  final TrailDirection direction;
  final bool isCollapsed;
  final VoidCallback onTrailInformationHintReset;
  final VoidCallback onStageDetailsHintReset;
  final VoidCallback onStageMetricsHintReset;

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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: IgnorePointer(
              child: AnimatedOpacity(
                key: const ValueKey('trail-compact-title-opacity'),
                opacity: isCollapsed ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  l10n.t('Cyprus E4'),
                  key: const ValueKey('trail-compact-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('trail-settings'),
            tooltip: l10n.t('Settings'),
            onPressed: () async {
              final reset = await Navigator.of(context).push<DebugHintReset>(
                MaterialPageRoute<DebugHintReset>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              if (reset == DebugHintReset.e4Information) {
                onTrailInformationHintReset();
              } else if (reset == DebugHintReset.stageDetails) {
                onStageDetailsHintReset();
              } else if (reset == DebugHintReset.stageMetrics) {
                onStageMetricsHintReset();
              }
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_ink, Color(0xFF274B3A)],
                ),
              ),
            ),
            ExcludeSemantics(
              child: Image.asset(
                'assets/branding/cyprus_e4_forest.jpg',
                key: const ValueKey('stages-header-watermark-cyprus-e4'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const DecoratedBox(
              key: ValueKey('stages-header-watermark-fade-cyprus-e4'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE6275F45), Color(0x66183226)],
                  stops: [0.05, 1],
                ),
              ),
            ),
            SafeArea(
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
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
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
          ],
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
          ? 'OFFLINE TRAIL'
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

class _TrailTimelineWaymark extends StatefulWidget {
  const _TrailTimelineWaymark({
    required this.shouldPulse,
    required this.connectsToTimeline,
    required this.onTap,
  });

  final bool shouldPulse;
  final bool connectsToTimeline;
  final VoidCallback onTap;

  @override
  State<_TrailTimelineWaymark> createState() => _TrailTimelineWaymarkState();
}

class _TrailTimelineWaymarkState extends State<_TrailTimelineWaymark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scale;
  Timer? _pulseTimer;
  bool _isPulsing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 55,
      ),
    ]).animate(_pulseController);
    if (widget.shouldPulse) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runPulse());
    }
  }

  @override
  void didUpdateWidget(covariant _TrailTimelineWaymark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shouldPulse == widget.shouldPulse) return;
    if (widget.shouldPulse) {
      _runPulse();
    } else {
      _pulseTimer?.cancel();
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  Future<void> _runPulse() async {
    if (!mounted || !widget.shouldPulse || _isPulsing) return;
    _isPulsing = true;
    try {
      await _pulseController.forward(from: 0).orCancel;
    } on TickerCanceled {
      // The widget stopped pulsing or was disposed.
    } finally {
      _isPulsing = false;
    }
    if (!mounted || !widget.shouldPulse) return;
    _pulseTimer = Timer(const Duration(milliseconds: 1400), _runPulse);
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.shouldPulse ? 72 : 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _timelineGutterWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(
                  width: _timelineLineColumnWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: OverflowBox(
                          maxWidth: 48,
                          maxHeight: 40,
                          child: SizedBox(
                            width: 44,
                            height: 40,
                            child: Tooltip(
                              message: context.l10n.t('Trail information'),
                              child: Semantics(
                                button: true,
                                label: context.l10n.t('Trail information'),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    key: const ValueKey('stage-e4-waymark'),
                                    onTap: widget.onTap,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Center(
                                      child: KeyedSubtree(
                                        key: ValueKey(
                                          widget.shouldPulse
                                              ? 'stage-e4-waymark-pulsing'
                                              : 'stage-e4-waymark-seen',
                                        ),
                                        child: AnimatedBuilder(
                                          animation: _pulseController,
                                          builder: (context, child) {
                                            final progress =
                                                _pulseController.value;
                                            return SizedBox(
                                              width: 44,
                                              height: 36,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                alignment: Alignment.center,
                                                children: [
                                                  if (widget.shouldPulse)
                                                    Opacity(
                                                      key: const ValueKey(
                                                        'stage-e4-waymark-halo',
                                                      ),
                                                      opacity: 1 - progress,
                                                      child: Transform.scale(
                                                        scale:
                                                            1 +
                                                            (progress * 0.38),
                                                        child: Container(
                                                          width: 34,
                                                          height: 26,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                _trailPulseBlue
                                                                    .withValues(
                                                                      alpha:
                                                                          0.28,
                                                                    ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  7,
                                                                ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: _trailPulseBlue
                                                                    .withValues(
                                                                      alpha:
                                                                          0.42,
                                                                    ),
                                                                blurRadius: 9,
                                                                spreadRadius: 2,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ScaleTransition(
                                                    scale: _scale,
                                                    child: Container(
                                                      width: 34,
                                                      height: 26,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: _yellow,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color: _ink,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        context.l10n.t('E4'),
                                                        style: const TextStyle(
                                                          color: _ink,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          letterSpacing: 0.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          key: const ValueKey('stage-waymark-line'),
                          width: 2,
                          color: widget.connectsToTimeline
                              ? _timelineLineColor
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.shouldPulse
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 0, 10),
                    child: Material(
                      key: const ValueKey('e4-trail-information-helper'),
                      color: _trailPulseBlue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const ValueKey('open-e4-trail-information-helper'),
                        onTap: widget.onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_back_rounded,
                                color: _bookingBlue,
                                size: 17,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  context.l10n.t(
                                    'Tap the E4 sign to open trail information.',
                                  ),
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
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
    required this.connectsToPrevious,
    required this.connectsToNext,
    required this.isTrailStart,
    required this.isTrailEnd,
    required this.isSelected,
    required this.showDetailsHint,
    required this.showMetricsHint,
    required this.onMetricsHintDismiss,
    required this.onTap,
    super.key,
  });

  final TrailStage stage;
  final MeasurementFormatter formatter;
  final double? ascentM;
  final double? descentM;
  final double? segmentLengthKm;
  final double? distanceKm;
  final bool connectsToPrevious;
  final bool connectsToNext;
  final bool isTrailStart;
  final bool isTrailEnd;
  final bool isSelected;
  final bool showDetailsHint;
  final bool showMetricsHint;
  final VoidCallback onMetricsHintDismiss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeServices = stage.services.entries
        .where((entry) => entry.value)
        .toList();
    final showDistance = !isTrailStart && distanceKm != null;
    final distanceFromPathKm = stage.distanceFromPathKm;
    final hasDistanceFromPath =
        distanceFromPathKm != null &&
        distanceFromPathKm.isFinite &&
        distanceFromPathKm >= 0;
    final dotColor = isSelected
        ? _bookingBlue
        : hasDistanceFromPath
        ? distanceFromPathKm < 0.5
              ? _green
              : _yellow
        : isTrailStart
        ? _green
        : isTrailEnd
        ? _red
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
          icon: null,
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
        label: context.l10n.t(isTrailStart ? 'Start' : 'Finish'),
        color: isTrailStart ? _green : _red,
      ),
    );
    final primarySideContent = isTrailStart
        ? endpointBadge
        : isTrailEnd
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [endpointBadge, const SizedBox(height: 3), sideMetrics],
          )
        : sideMetrics;
    final sideContent = hasDistanceFromPath
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              primarySideContent,
              const SizedBox(height: 2),
              _StageTrailDistanceLabel(
                stageId: stage.id,
                distance: _trimmedDistance(formatter, distanceFromPathKm),
              ),
            ],
          )
        : primarySideContent;

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
                        child: Container(
                          key: ValueKey('stage-line-before-${stage.id}'),
                          width: 2,
                          color: connectsToPrevious
                              ? _timelineLineColor
                              : Colors.transparent,
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
                          key: ValueKey('stage-line-after-${stage.id}'),
                          width: 2,
                          color: connectsToNext
                              ? _timelineLineColor
                              : Colors.transparent,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: hasDistanceFromPath ? 92 : 0,
                ),
                child: Semantics(
                  selected: isSelected,
                  child: Material(
                    key: ValueKey('stage-card-${stage.id}'),
                    color: isSelected ? const Color(0xFFE8F1FC) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? _bookingBlue
                            : showDetailsHint || showMetricsHint
                            ? _trailPulseBlue
                            : Colors.transparent,
                        width: isSelected || showDetailsHint || showMetricsHint
                            ? 2
                            : 0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showDetailsHint) ...[
                                    Container(
                                      key: const ValueKey(
                                        'stage-details-helper',
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _trailPulseBlue.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.touch_app_outlined,
                                            color: _bookingBlue,
                                            size: 17,
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              context.l10n.t(
                                                'Tap a stage to see its details.',
                                              ),
                                              style: const TextStyle(
                                                color: _ink,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (showMetricsHint) ...[
                                    _StageMetricsHint(
                                      onDismiss: onMetricsHintDismiss,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      const SizedBox(width: 8),
                                      Semantics(
                                        label: context.l10n.stage(
                                          stage.sequence,
                                        ),
                                        excludeSemantics: true,
                                        child: Text(
                                          '${stage.sequence}',
                                          key: ValueKey(
                                            'stage-number-${stage.id}',
                                          ),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
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
                                        for (final service
                                            in activeServices.take(7))
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
                                  if (showDistance ||
                                      stage.altitudeM != null) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Row(
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
                                                fontSize: 10.5,
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
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
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

String _trimmedDistance(MeasurementFormatter formatter, double distanceKm) {
  final value = formatter
      .distanceValue(distanceKm)
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  return '$value${formatter.distanceUnit}';
}

class _StageTrailDistanceLabel extends StatelessWidget {
  const _StageTrailDistanceLabel({
    required this.stageId,
    required this.distance,
  });

  final String stageId;
  final String distance;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.t('Distance from trail');
    return Tooltip(
      message: label,
      child: Semantics(
        label: '$label: $distance',
        child: Row(
          key: ValueKey('stage-distance-from-trail-$stageId'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_rounded,
              key: ValueKey('stage-distance-from-trail-icon-$stageId'),
              size: 11,
              color: Colors.black54,
            ),
            const SizedBox(width: 1),
            Text(
              distance,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageMetricsHint extends StatelessWidget {
  const _StageMetricsHint({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('stage-metrics-helper'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 7, 4, 7),
      decoration: BoxDecoration(
        color: _trailPulseBlue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_back_rounded, color: _bookingBlue, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              context.l10n.t(
                'The numbers on the left show ascent, descent, stage length, and + distance from the trail.',
              ),
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('dismiss-stage-metrics-hint'),
            tooltip: context.l10n.t('Close'),
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _StageSideMetric extends StatelessWidget {
  const _StageSideMetric({
    required this.icon,
    required this.value,
    required this.tooltip,
    required this.color,
    super.key,
  });

  final IconData? icon;
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
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            value,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
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
      constraints: const BoxConstraints(maxWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
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
          style: const TextStyle(fontSize: 10, color: Colors.black54),
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
    this.initialLocation,
    super.key,
  });

  final List<TrailStage> stages;
  final int initialIndex;
  final TrailDirection direction;
  final String? locationStageId;
  final DeviceLocation? initialLocation;

  @override
  ConsumerState<StageDetailScreen> createState() => _StageDetailScreenState();
}

class _StageDetailScreenState extends ConsumerState<StageDetailScreen>
    with SingleTickerProviderStateMixin {
  late int index = widget.initialIndex;
  final GlobalKey _mapPreviewKey = GlobalKey();
  final ScrollController _detailScrollController = ScrollController();
  late final AnimationController _stageTransitionController;
  int _stageTransitionDirection = 1;
  String? _gpsStageId;
  DeviceLocation? _gpsLocation;
  bool _isLocating = false;
  bool _isOpeningAccommodation = false;

  TrailStage get stage => widget.stages[index];

  @override
  void initState() {
    super.initState();
    _stageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    _gpsStageId = widget.locationStageId;
    _gpsLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _stageTransitionController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  void _showAdjacentStage(int nextIndex) {
    if (nextIndex < 0 ||
        nextIndex >= widget.stages.length ||
        nextIndex == index) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _stageTransitionDirection = nextIndex > index ? 1 : -1;
      index = nextIndex;
    });
    _stageTransitionController.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_detailScrollController.hasClients) return;
      _detailScrollController.jumpTo(0);
    });
  }

  void _handleStageSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;
    _showAdjacentStage(velocity < 0 ? index + 1 : index - 1);
  }

  void _openMap({List<Lodging> lodgings = const []}) {
    final locationStageId = stage.id == _gpsStageId ? _gpsStageId : null;
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

  void _openElevation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ElevationScreen(initialStageIndex: index),
      ),
    );
  }

  void _backToStages() {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == StagesScreen.routeName || route.isFirst,
    );
  }

  Future<void> _toggleGpsLocation() async {
    if (_gpsStageId != null) {
      setState(() {
        _gpsStageId = null;
        _gpsLocation = null;
      });
      return;
    }
    await _locateCurrentStage();
  }

  Future<void> _locateCurrentStage() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      late final List<RoutePoint> routePoints;
      try {
        routePoints = await ref.read(elevationProvider.future);
      } catch (_) {
        _showMessage('Route data is not on this device yet.');
        return;
      }
      if (!mounted) return;
      if (routePoints.isEmpty || widget.stages.isEmpty) {
        _showMessage('Route data is not on this device yet.');
        return;
      }

      final location = await ref.read(deviceLocationReaderProvider)();
      if (!mounted) return;
      if (!location.accuracyM.isFinite ||
          location.accuracyM < 0 ||
          location.accuracyM > maximumUsableLocationAccuracyM) {
        _showMessage('Your location could not be read right now.');
        return;
      }

      final canonicalStages = widget.stages.toList(growable: false)
        ..sort(
          (first, second) => (first.accumulatedDistanceKm ?? double.infinity)
              .compareTo(second.accumulatedDistanceKm ?? double.infinity),
        );
      final match = findNearbyTrailStage(
        latitude: location.latitude,
        longitude: location.longitude,
        locationAccuracyM: location.accuracyM,
        routePoints: routePoints,
        stages: canonicalStages,
        direction: widget.direction,
      );
      if (match == null) {
        _showOffTrailDistance(location, routePoints);
        return;
      }
      final matchedIndex = widget.stages.indexWhere(
        (candidate) => candidate.id == match.stageId,
      );
      if (matchedIndex < 0) {
        _showMessage('You are not on the trail.');
        return;
      }

      setState(() {
        index = matchedIndex;
        _gpsStageId = match.stageId;
        _gpsLocation = location;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final previewContext = _mapPreviewKey.currentContext;
      if (previewContext != null && previewContext.mounted) {
        await Scrollable.ensureVisible(
          previewContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 500),
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
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openAccommodation() async {
    if (_isOpeningAccommodation) return;
    final selectedStage = stage;
    setState(() => _isOpeningAccommodation = true);
    List<Lodging>? availableLodgings;
    var loadFailed = false;
    try {
      availableLodgings = await ref.read(
        lodgingsForStageProvider(selectedStage.id).future,
      );
    } catch (_) {
      loadFailed = true;
    } finally {
      if (mounted) setState(() => _isOpeningAccommodation = false);
    }
    if (!mounted || stage.id != selectedStage.id) return;
    if (loadFailed) {
      await _showAccommodationMessage(
        'Accommodation information is currently unavailable.',
      );
      return;
    }
    if (availableLodgings == null || availableLodgings.isEmpty) {
      await _showAccommodationMessage(
        'No accommodation is listed for this stage.',
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccommodationScreen(stage: selectedStage),
      ),
    );
  }

  Future<void> _showAccommodationMessage(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('stage-accommodation-message'),
        title: Text(context.l10n.t('Accommodation')),
        content: Text(context.l10n.t(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.t('Close')),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    _showLocalizedMessage(context.l10n.t(message));
  }

  void _showLocalizedMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showOffTrailDistance(
    DeviceLocation location,
    List<RoutePoint> routePoints,
  ) {
    final distanceM = distanceFromTrailM(
      latitude: location.latitude,
      longitude: location.longitude,
      routePoints: routePoints,
    );
    if (distanceM == null) {
      _showMessage('You are not on the trail.');
      return;
    }
    final formatter = MeasurementFormatter(
      ref.read(appSettingsProvider).measurementSystem,
    );
    _showLocalizedMessage(
      context.l10n.offTrailDistance(formatter.altitude(distanceM)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final showUserLocation = stage.id == _gpsStageId;
    final previewRoute = ref.watch(elevationProvider).value;
    final previewStartDistanceKm = index == 0
        ? stage.accumulatedDistanceKm
        : widget.stages[index - 1].accumulatedDistanceKm;
    final previewFinishDistanceKm = index == 0 && widget.stages.length > 1
        ? widget.stages[1].accumulatedDistanceKm
        : stage.accumulatedDistanceKm;
    final lodgings = ref.watch(lodgingsForStageProvider(stage.id));
    final lodgingCount = lodgings.value?.length ?? 0;
    final mappedLodgings =
        lodgings.value
            ?.where((lodging) => lodging.location != null)
            .toList(growable: false) ??
        const <Lodging>[];
    final services = stage.services.entries
        .where((entry) => entry.value)
        .toList();
    final accumulatedDistance = stage.accumulatedDistanceKm;
    final totalDistanceKm = _trailDistanceKm(widget.stages);
    final distanceFromStart = accumulatedDistance == null
        ? null
        : widget.direction.distanceFromStart(
            accumulatedDistance,
            totalDistanceKm,
          );
    final distanceToFinish = distanceFromStart == null
        ? null
        : (totalDistanceKm - distanceFromStart)
              .clamp(0, totalDistanceKm)
              .toDouble();
    final endpointLabel = index == 0
        ? l10n.t('Start')
        : index == widget.stages.length - 1
        ? l10n.t('Finish')
        : null;
    final endpointDistanceKm = index == 0
        ? distanceToFinish
        : distanceFromStart;
    final hasEndpointDistance =
        endpointLabel != null &&
        endpointDistanceKm != null &&
        endpointDistanceKm > 0;
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
    final stageTransition = CurvedAnimation(
      parent: _stageTransitionController,
      curve: Curves.easeOutCubic,
    );
    return Scaffold(
      backgroundColor: _sand,
      bottomNavigationBar: _StageDetailBottomNavigationBar(
        hasGpsLocation: _gpsStageId != null,
        isLocating: _isLocating,
        isLoadingAccommodation: lodgings.isLoading || _isOpeningAccommodation,
        accommodationCount: lodgingCount,
        onStages: _backToStages,
        onAccommodation: lodgingCount > 0 ? _openAccommodation : null,
        onGps: _toggleGpsLocation,
        onMap: () => _openMap(lodgings: mappedLodgings),
        onElevation: _openElevation,
      ),
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
              'CYPRUS E4 · ${(endpointLabel ?? l10n.stage(stage.sequence)).toUpperCase()} · ${index + 1}/${widget.stages.length}',
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white60,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        key: const ValueKey('stage-detail-swipe-area'),
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _handleStageSwipe,
        child: SlideTransition(
          key: const ValueKey('stage-detail-slide-transition'),
          position: Tween<Offset>(
            begin: Offset(0.18 * _stageTransitionDirection, 0),
            end: Offset.zero,
          ).animate(stageTransition),
          child: ListView(
            controller: _detailScrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DetailMetric(
                        key: const Key('stage-detail-position'),
                        icon: endpointLabel == null ? null : Icons.flag_rounded,
                        iconWidget: endpointLabel == null
                            ? const _StageLengthRouteIcon()
                            : null,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: endpointLabel != null
                          ? _DetailMetric(
                              key: const Key('stage-detail-endpoint-distance'),
                              icon: hasEndpointDistance
                                  ? index == 0
                                        ? Icons.hiking_rounded
                                        : Icons.route_rounded
                                  : Icons.landscape_outlined,
                              value: hasEndpointDistance
                                  ? formatter.distance(endpointDistanceKm)
                                  : stage.altitudeM == null
                                  ? '—'
                                  : formatter.altitude(stage.altitudeM!),
                              label: l10n.t(
                                hasEndpointDistance
                                    ? index == 0
                                          ? 'To Finish'
                                          : 'From Start'
                                    : 'Altitude',
                              ),
                            )
                          : _DetailMetric(
                              key: const Key('stage-detail-walking-time'),
                              icon: Icons.schedule_rounded,
                              iconColor: _bookingBlue,
                              value: walkingTime == null
                                  ? '—'
                                  : _formatWalkingTime(walkingTime, l10n),
                              label: l10n.t('Estimated walking time'),
                              showFootnoteMarker: true,
                            ),
                    ),
                  ],
                ),
              ),
              if (walkingTime != null) ...[
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: '* ',
                        style: TextStyle(
                          color: _bookingBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: l10n.t(
                          'Naismith estimate based on distance and ascent. Breaks and terrain are not included.',
                        ),
                      ),
                    ],
                  ),
                  key: const ValueKey('walking-time-footnote-note'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
              if (endpointLabel == null || hasEndpointDistance) ...[
                const SizedBox(height: 12),
                _CompactDetailMetrics(
                  children: endpointLabel != null
                      ? [
                          _CompactDetailMetric(
                            key: const Key('stage-detail-altitude'),
                            icon: Icons.landscape_outlined,
                            iconColor: Colors.black54,
                            value: stage.altitudeM == null
                                ? '—'
                                : formatter.altitude(stage.altitudeM!),
                            label: l10n.t('Altitude'),
                          ),
                        ]
                      : [
                          _CompactDetailMetric(
                            key: const Key('stage-detail-distance-from-start'),
                            icon: Icons.hiking_rounded,
                            value: distanceFromStart == null
                                ? '—'
                                : formatter.distance(distanceFromStart),
                            label: l10n.t('From Start'),
                          ),
                          _CompactDetailMetric(
                            key: const Key('stage-detail-altitude'),
                            icon: Icons.landscape_outlined,
                            iconColor: Colors.black54,
                            value: stage.altitudeM == null
                                ? '—'
                                : formatter.altitude(stage.altitudeM!),
                            label: l10n.t('Altitude'),
                          ),
                          _CompactDetailMetric(
                            key: const Key('stage-detail-ascent'),
                            icon: Icons.trending_up_rounded,
                            value: ascentM == null
                                ? '—'
                                : formatter.altitude(ascentM),
                            label: l10n.t('Ascent'),
                          ),
                          _CompactDetailMetric(
                            key: const Key('stage-detail-descent'),
                            icon: Icons.trending_down_rounded,
                            iconColor: _red,
                            value: descentM == null
                                ? '—'
                                : formatter.altitude(descentM),
                            label: l10n.t('Descent'),
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
              const SizedBox(height: 12),
              _StageMapPreview(
                key: _mapPreviewKey,
                routePoints: previewRoute ?? const [],
                startDistanceKm: previewStartDistanceKm,
                finishDistanceKm: previewFinishDistanceKm,
                showRoute: stagePreviewShowsRoute(index),
                showFinishFlag: stagePreviewShowsFinishFlag(index),
                lodgings: mappedLodgings,
                showUserLocation: showUserLocation,
                userLocation: showUserLocation ? _gpsLocation : null,
                onTap: () => _openMap(lodgings: mappedLodgings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageDetailBottomNavigationBar extends StatelessWidget {
  const _StageDetailBottomNavigationBar({
    required this.hasGpsLocation,
    required this.isLocating,
    required this.isLoadingAccommodation,
    required this.accommodationCount,
    required this.onStages,
    required this.onAccommodation,
    required this.onGps,
    required this.onMap,
    required this.onElevation,
  });

  final bool hasGpsLocation;
  final bool isLocating;
  final bool isLoadingAccommodation;
  final int accommodationCount;
  final VoidCallback onStages;
  final VoidCallback? onAccommodation;
  final VoidCallback onGps;
  final VoidCallback onMap;
  final VoidCallback onElevation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      key: const ValueKey('stage-detail-bottom-navigation'),
      color: _ink,
      child: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('stage-detail-bottom-navigation-size'),
          height: 48,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StageBottomAction(
                key: const Key('stage-detail-stages-shortcut'),
                icon: Icons.hiking_rounded,
                label: l10n.t('Back to stages'),
                onTap: onStages,
              ),
              _StageBottomAction(
                key: const ValueKey('stage-detail-accommodation'),
                icon: isLoadingAccommodation
                    ? Icons.hourglass_top_rounded
                    : Icons.hotel_outlined,
                label: l10n.t(
                  !isLoadingAccommodation && accommodationCount == 0
                      ? 'No accommodation is listed for this stage.'
                      : 'Accommodation',
                ),
                badgeCount: accommodationCount,
                onTap: isLoadingAccommodation ? null : onAccommodation,
              ),
              _StageBottomAction(
                key: const ValueKey('stage-detail-gps'),
                icon: isLocating
                    ? Icons.hourglass_top_rounded
                    : hasGpsLocation
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                label: l10n.t('Find my stage'),
                isActive: hasGpsLocation,
                isToggle: true,
                isPrimary: true,
                onTap: isLocating ? null : onGps,
              ),
              _StageBottomAction(
                key: const ValueKey('stage-detail-map'),
                icon: Icons.map_outlined,
                label: l10n.t('Show on map'),
                onTap: onMap,
              ),
              _StageBottomAction(
                key: const ValueKey('stage-detail-elevation'),
                icon: Icons.landscape_outlined,
                label: l10n.t('Elevation'),
                onTap: onElevation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    this.icon,
    this.iconWidget,
    this.iconColor = _green,
    this.showFootnoteMarker = false,
    required this.value,
    required this.label,
    super.key,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final Color iconColor;
  final bool showFootnoteMarker;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget ?? Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          if (showFootnoteMarker)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: label),
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: _bookingBlue,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              key: const ValueKey('walking-time-footnote-label'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            )
          else
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _CompactDetailMetrics extends StatelessWidget {
  const _CompactDetailMetrics({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('stage-detail-secondary-metrics'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            Expanded(child: children[index]),
            if (index < children.length - 1)
              Container(width: 1, height: 52, color: Colors.black12),
          ],
        ],
      ),
    );
  }
}

class _CompactDetailMetric extends StatelessWidget {
  const _CompactDetailMetric({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = _green,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 19),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _StageLengthRouteIcon extends StatelessWidget {
  const _StageLengthRouteIcon();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.t('Stage length'),
      image: true,
      child: const SizedBox(
        key: ValueKey('stage-length-route-icon'),
        width: 64,
        height: 24,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _DashedStageRoutePainter()),
            ),
            Positioned(
              left: 0,
              top: 5.5,
              child: Icon(
                Icons.flag_rounded,
                key: ValueKey('stage-length-start-flag'),
                size: 13,
                color: _green,
              ),
            ),
            Positioned(
              right: 0,
              top: 5.5,
              child: Icon(
                Icons.flag_rounded,
                key: ValueKey('stage-length-finish-flag'),
                size: 13,
                color: _red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedStageRoutePainter extends CustomPainter {
  const _DashedStageRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final route = Path()
      ..moveTo(10, size.height / 2)
      ..lineTo(size.width - 10, size.height / 2);
    final paint = Paint()
      ..color = _green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (final metric in route.computeMetrics()) {
      const endpointClearance = 6.0;
      var offset = endpointClearance;
      final paintedEnd = metric.length - endpointClearance;
      while (offset < paintedEnd) {
        final dashEnd = offset + 2.4;
        canvas.drawPath(
          metric.extractPath(
            offset,
            dashEnd > paintedEnd ? paintedEnd : dashEnd,
          ),
          paint,
        );
        offset += 4.4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedStageRoutePainter oldDelegate) => false;
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
    required this.showRoute,
    required this.showFinishFlag,
    required this.lodgings,
    required this.showUserLocation,
    required this.userLocation,
    required this.onTap,
    super.key,
  });

  final List<RoutePoint> routePoints;
  final double? startDistanceKm;
  final double? finishDistanceKm;
  final bool showRoute;
  final bool showFinishFlag;
  final List<Lodging> lodgings;
  final bool showUserLocation;
  final DeviceLocation? userLocation;
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
                  'route-$showRoute-'
                  'finish-$showFinishFlag-'
                  'user-$showUserLocation-'
                  '${userLocation?.latitude}-${userLocation?.longitude}-'
                  '${lodgings.map((lodging) => lodging.id).join(',')}',
                ),
                routePoints: preview.routePoints,
                startPoint: preview.startPoint,
                finishPoint: preview.finishPoint,
                showRoute: showRoute,
                showFinishFlag: showFinishFlag,
                lodgings: lodgings,
                showUserLocation: showUserLocation,
                userLocation: userLocation,
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

bool stagePreviewShowsRoute(int stageIndex) => stageIndex > 0;

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
    required this.showRoute,
    required this.showFinishFlag,
    required this.lodgings,
    required this.showUserLocation,
    required this.userLocation,
    required this.onTap,
    super.key,
  });

  final List<RoutePoint> routePoints;
  final RoutePoint startPoint;
  final RoutePoint finishPoint;
  final bool showRoute;
  final bool showFinishFlag;
  final List<Lodging> lodgings;
  final bool showUserLocation;
  final DeviceLocation? userLocation;
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
    final center = widget.showRoute
        ? widget.routePoints[widget.routePoints.length ~/ 2]
        : widget.startPoint;
    final stageDistanceKm = widget.showRoute
        ? (widget.finishPoint.distanceKm - widget.startPoint.distanceKm).abs()
        : 0.0;
    final viewportCoordinates = <Position>[
      if (widget.showRoute)
        for (final point in widget.routePoints) Position(point.lng, point.lat)
      else
        Position(widget.startPoint.lng, widget.startPoint.lat),
      for (final lodging in widget.lodgings)
        if (lodging.location case final location?)
          Position(location.longitude, location.latitude),
      if (widget.userLocation case final DeviceLocation location)
        Position(location.longitude, location.latitude),
    ];
    _initialViewport = viewportCoordinates.length == 1
        ? CameraViewportState(
            center: Point(coordinates: Position(center.lng, center.lat)),
            zoom: 13.5,
            bearing: 0,
            pitch: 0,
          )
        : OverviewViewportState(
            geometry: LineString(coordinates: viewportCoordinates),
            geometryPadding: stageDistanceKm > 6
                ? const EdgeInsets.fromLTRB(60, 50, 54, 64)
                : const EdgeInsets.fromLTRB(54, 44, 48, 54),
            bearing: 0,
            pitch: 0,
            maxZoom: 16,
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

    if (widget.showRoute && widget.routePoints.length > 1) {
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
  const _ServiceFilterSheet({required this.selected, required this.stages});

  final Set<String> selected;
  final List<TrailStage> stages;

  @override
  State<_ServiceFilterSheet> createState() => _ServiceFilterSheetState();
}

class _ServiceFilterSheetState extends State<_ServiceFilterSheet> {
  late final selected = widget.selected.toSet();
  final stageSearchController = TextEditingController();
  var stageQuery = '';

  String _stageFilterKey(TrailStage stage) =>
      '$_stageNameFilterPrefix${stage.id}';

  void _selectStage(TrailStage stage) {
    setState(() {
      selected.add(_stageFilterKey(stage));
      stageQuery = '';
      stageSearchController.clear();
    });
  }

  @override
  void dispose() {
    stageSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final normalizedQuery = stageQuery.trim().toLowerCase();
    final stageIdMatch = RegExp(r'^#?\s*(\d+)$').firstMatch(normalizedQuery);
    final exactStageSequence = int.tryParse(stageIdMatch?.group(1) ?? '');
    final selectedStages = widget.stages
        .where((stage) => selected.contains(_stageFilterKey(stage)))
        .toList(growable: false);
    final stageSuggestions = normalizedQuery.isEmpty
        ? const <TrailStage>[]
        : widget.stages
              .where(
                (stage) =>
                    !selected.contains(_stageFilterKey(stage)) &&
                    (exactStageSequence != null
                        ? stage.sequence == exactStageSequence
                        : stage.name.toLowerCase().contains(normalizedQuery) ||
                              l10n
                                  .t(stage.name)
                                  .toLowerCase()
                                  .contains(normalizedQuery)),
              )
              .take(6)
              .toList(growable: false);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Stage name'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('stage-name-filter'),
              controller: stageSearchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.t('Search by stage name or number'),
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => stageQuery = value),
            ),
            if (selectedStages.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final stage in selectedStages)
                    InputChip(
                      key: ValueKey('selected-stage-filter-${stage.id}'),
                      avatar: const Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: _filterBlueTeal,
                      ),
                      label: Text(l10n.t(stage.name)),
                      onDeleted: () => setState(
                        () => selected.remove(_stageFilterKey(stage)),
                      ),
                    ),
                ],
              ),
            ],
            if (normalizedQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (stageSuggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    l10n.t('No stages found.'),
                    key: const ValueKey('stage-name-no-results'),
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 184),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: stageSuggestions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final stage = stageSuggestions[index];
                      return ListTile(
                        key: ValueKey('stage-name-suggestion-${stage.id}'),
                        dense: true,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: _filterBlueTeal,
                        ),
                        title: Text(l10n.t(stage.name)),
                        subtitle: Text(l10n.stage(stage.sequence)),
                        onTap: () => _selectStage(stage),
                      );
                    },
                  ),
                ),
            ],
            const Divider(height: 28),
            Text(
              l10n.t('Points of Interest'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  key: const ValueKey('stage-filter-start'),
                  selected: selected.contains(_startPointFilterKey),
                  avatar: const Icon(
                    Icons.flag_rounded,
                    size: 18,
                    color: _green,
                  ),
                  label: Text(l10n.t('Start')),
                  onSelected: (isSelected) => setState(() {
                    if (isSelected) {
                      selected.add(_startPointFilterKey);
                    } else {
                      selected.remove(_startPointFilterKey);
                    }
                  }),
                ),
                FilterChip(
                  key: const ValueKey('stage-filter-finish'),
                  selected: selected.contains(_finishPointFilterKey),
                  avatar: const Icon(Icons.flag_rounded, size: 18, color: _red),
                  label: Text(l10n.t('Finish')),
                  onSelected: (isSelected) => setState(() {
                    if (isSelected) {
                      selected.add(_finishPointFilterKey);
                    } else {
                      selected.remove(_finishPointFilterKey);
                    }
                  }),
                ),
                FilterChip(
                  key: const ValueKey('stage-filter-beach'),
                  selected: selected.contains(_beachPointFilterKey),
                  avatar: const Icon(
                    Icons.beach_access_rounded,
                    size: 18,
                    color: _bookingBlue,
                  ),
                  label: Text(l10n.t('Beach')),
                  onSelected: (isSelected) => setState(() {
                    if (isSelected) {
                      selected.add(_beachPointFilterKey);
                    } else {
                      selected.remove(_beachPointFilterKey);
                    }
                  }),
                ),
                FilterChip(
                  key: const ValueKey('stage-filter-viewpoint'),
                  selected: selected.contains(_viewpointPointFilterKey),
                  avatar: const Icon(
                    Icons.visibility_rounded,
                    size: 18,
                    color: _filterBlueTeal,
                  ),
                  label: Text(l10n.t('Viewpoint')),
                  onSelected: (isSelected) => setState(() {
                    if (isSelected) {
                      selected.add(_viewpointPointFilterKey);
                    } else {
                      selected.remove(_viewpointPointFilterKey);
                    }
                  }),
                ),
                FilterChip(
                  key: const ValueKey('stage-filter-religious-site'),
                  selected: selected.contains(_religiousSitePointFilterKey),
                  avatar: const Icon(
                    Icons.account_balance_rounded,
                    size: 18,
                    color: _filterBlueTeal,
                  ),
                  label: Text(l10n.t('Religious Sites')),
                  onSelected: (isSelected) => setState(() {
                    if (isSelected) {
                      selected.add(_religiousSitePointFilterKey);
                    } else {
                      selected.remove(_religiousSitePointFilterKey);
                    }
                  }),
                ),
                FilterChip(
                  key: const ValueKey('stage-filter-natural-landmark'),
                  selected: selected.contains(_naturalLandmarkPointFilterKey),
                  avatar: const Icon(
                    Icons.landscape_outlined,
                    size: 18,
                    color: _accommodationBlue,
                  ),
                  label: Text(l10n.t('Natural Landmarks')),
                  onSelected: (isSelected) => setState(() {
                    if (isSelected) {
                      selected.add(_naturalLandmarkPointFilterKey);
                    } else {
                      selected.remove(_naturalLandmarkPointFilterKey);
                    }
                  }),
                ),
                FilterChip(
                  key: const ValueKey('stage-filter-forest-park'),
                  selected: selected.contains(_forestParkPointFilterKey),
                  avatar: const Icon(
                    Icons.park_outlined,
                    size: 18,
                    color: _green,
                  ),
                  label: Text(l10n.t('Forests/Parks')),
                  onSelected: (isSelected) => setState(() {
                    if (isSelected) {
                      selected.add(_forestParkPointFilterKey);
                    } else {
                      selected.remove(_forestParkPointFilterKey);
                    }
                  }),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              l10n.t('Services'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
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
                  child: OutlinedButton(
                    key: const Key('clear-service-filter-selection'),
                    onPressed: () =>
                        Navigator.of(context).pop(const <String>{}),
                    child: Text(l10n.t('Clear')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('apply-service-filters'),
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: Text(l10n.t('Apply')),
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
              l10n.t('No stages match these filters.'),
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
