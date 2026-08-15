import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/database/database_provider.dart';
import '../../../core/location/device_location.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../../core/theme/eurotrex_chrome_theme.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../../accommodation/domain/lodging.dart';
import '../../accommodation/presentation/accommodation_controller.dart';
import '../../accommodation/presentation/accommodation_screen.dart';
import '../../accommodation/presentation/lodging_type_icon.dart';
import '../../elevation/domain/elevation_profile.dart';
import '../../elevation/domain/route_point.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../elevation/presentation/elevation_screen.dart';
import '../../detours/domain/trail_detour.dart';
import '../../detours/presentation/detour_controller.dart';
import '../../excursions/domain/trail_excursion.dart';
import '../../excursions/presentation/excursion_controller.dart';
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
import 'trail_data_metadata_controller.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _red = Color(0xFFD14B45);
const _mint = Color(0xFFE1F1E8);
const _sand = Color(0xFFF4F2EC);
const _yellow = Color(0xFFF2C94C);
const _trailPulseBlue = Color(0xFF73BCE8);
const _bookingBlue = Color(0xFF1565C0);
const _selectedStageCardBackground = Color(0xFFDDEBFA);
const _stageCardOutline = Color(0xFFD8DDDA);
const _accommodationBlue = Color(0xFF0288D1);
const _excursionCardBackground = Color(0xFFE9F5FB);
const _excursionMapLightBlue = Color(0xFF76C7E5);
const _detourPurple = Color(0xFF75588A);
const _filterBlueTeal = Color(0xFF356F7A);
const _timelineLineColor = Color(0xFFB9BDB8);
const _timelineLeftInset = 12.0;
const _timelineGutterWidth = 108.0;
const _trailHeaderExpandedHeight = 128.0;

Future<void> _syncOfflineTrailData(
  WidgetRef ref, {
  required bool isInitialDownload,
}) async {
  final metadataReady = ref.read(trailDataLastUpdatedProvider.future);
  final controller = ref.read(trailDataLastUpdatedProvider.notifier);
  await metadataReady;
  if (isInitialDownload) {
    await controller.downloadTrailData();
  } else {
    await controller.refreshTrailData();
  }
}

const _trailHeaderCollapseThreshold = 82.0;
const _timelineLineColumnWidth = 28.0;
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
  required Set<String> filters,
}) {
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
      filtersBeach ||
      filtersViewpoint ||
      filtersReligiousSite ||
      filtersNaturalLandmark ||
      filtersForestPark;
  final matchesPoint =
      !hasPointFilter ||
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

class _DetourTimelineBranch {
  const _DetourTimelineBranch({
    required this.entersFromTop,
    required this.exitsToBottom,
    this.splitY,
    this.rejoinY,
  });

  final bool entersFromTop;
  final bool exitsToBottom;
  final double? splitY;
  final double? rejoinY;
}

typedef _DetourTimelineConnection = ({int rowIndex, double y});

class _DetourTimelineSpan {
  const _DetourTimelineSpan({
    required this.detour,
    required this.entry,
    required this.exit,
  });

  final TrailDetour detour;
  final _DetourTimelineConnection entry;
  final _DetourTimelineConnection exit;
}

_DetourTimelineSpan? _detourTimelineSpan({
  required TrailDetour detour,
  required List<TrailStage> orderedStages,
  required TrailDirection direction,
}) {
  final startDistance = detour.startMainTrailDistanceKm;
  final endDistance = detour.endMainTrailDistanceKm;
  if (startDistance == null || endDistance == null) return null;
  final entry = _detourTimelineConnection(
    orderedStages,
    direction.isReversed ? endDistance : startDistance,
  );
  final exit = _detourTimelineConnection(
    orderedStages,
    direction.isReversed ? startDistance : endDistance,
  );
  if (entry == null || exit == null || entry.rowIndex > exit.rowIndex) {
    return null;
  }
  return _DetourTimelineSpan(detour: detour, entry: entry, exit: exit);
}

_DetourTimelineBranch? _detourTimelineBranchForStage({
  required TrailStage stage,
  required List<TrailStage> orderedStages,
  required List<TrailStage> filteredStages,
  required List<TrailDetour> detours,
  required TrailDirection direction,
}) {
  final rowIndex = orderedStages.indexWhere(
    (candidate) => candidate.id == stage.id,
  );
  if (rowIndex < 0) return null;

  for (final detour in detours) {
    final span = _detourTimelineSpan(
      detour: detour,
      orderedStages: orderedStages,
      direction: direction,
    );
    if (span == null) continue;
    final entry = span.entry;
    final exit = span.exit;
    if (rowIndex < entry.rowIndex || rowIndex > exit.rowIndex) continue;

    final visibleIds = filteredStages.map((item) => item.id).toSet();
    final completeBranchIsVisible = [
      for (var index = entry.rowIndex; index <= exit.rowIndex; index++)
        orderedStages[index].id,
    ].every(visibleIds.contains);
    if (!completeBranchIsVisible) continue;

    return _DetourTimelineBranch(
      entersFromTop: rowIndex > entry.rowIndex,
      exitsToBottom: rowIndex < exit.rowIndex,
      splitY: rowIndex == entry.rowIndex ? entry.y : null,
      rejoinY: rowIndex == exit.rowIndex ? exit.y : null,
    );
  }
  return null;
}

_DetourTimelineConnection? _detourTimelineConnection(
  List<TrailStage> orderedStages,
  double distanceKm,
) {
  for (
    var destinationIndex = 1;
    destinationIndex < orderedStages.length;
    destinationIndex++
  ) {
    final sourceDistance =
        orderedStages[destinationIndex - 1].accumulatedDistanceKm;
    final destinationDistance =
        orderedStages[destinationIndex].accumulatedDistanceKm;
    if (sourceDistance == null || destinationDistance == null) continue;
    final minimum = math.min(sourceDistance, destinationDistance);
    final maximum = math.max(sourceDistance, destinationDistance);
    if (distanceKm < minimum || distanceKm > maximum) continue;
    final legDistance = destinationDistance - sourceDistance;
    if (legDistance.abs() < 0.000001) continue;
    final progress = ((distanceKm - sourceDistance) / legDistance)
        .clamp(0.0, 1.0)
        .toDouble();
    if (progress <= 0.5) {
      return (rowIndex: destinationIndex - 1, y: 0.5 + progress);
    }
    return (rowIndex: destinationIndex, y: progress - 0.5);
  }
  return null;
}

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
        scrollController.hasClients &&
        scrollController.offset >= _trailHeaderCollapseThreshold;
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
      builder: (_) => DraggableScrollableSheet(
        key: const ValueKey('stage-filter-draggable-sheet'),
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.18,
        maxChildSize: 0.96,
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) => _ServiceFilterSheet(
          selected: selectedServices,
          stages: orderedStages,
          scrollController: scrollController,
        ),
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
      context.l10n.offTrailDistance(formatter.proximityDistance(distanceM)),
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

  void _openStageDetails({
    required BuildContext context,
    required TrailStage stage,
    required List<TrailStage> orderedStages,
    required TrailDirection direction,
    bool dismissMetricsHint = false,
  }) {
    final orderedIndex = orderedStages.indexWhere(
      (candidate) => candidate.id == stage.id,
    );
    if (orderedIndex < 0) return;
    _markStageDetailsHintSeen();
    if (dismissMetricsHint) _markStageMetricsHintSeen();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StageDetailScreen(
          stages: orderedStages,
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
  }

  void _openDetourDetails({
    required BuildContext context,
    required TrailDetour detour,
    required List<TrailStage> orderedStages,
    required TrailDirection direction,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetourDetailScreen(
          detour: detour,
          stages: orderedStages,
          direction: direction,
        ),
      ),
    );
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
    required List<TrailExcursion> excursions,
    required List<TrailDetour> detours,
    required List<TrailDetour> trailDetours,
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
    final detourBranch = _detourTimelineBranchForStage(
      stage: stage,
      orderedStages: orderedItems,
      filteredStages: filteredItems,
      detours: trailDetours,
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
      totalDistanceKm: totalDistanceKm,
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
      excursions: excursions,
      detours: detours,
      detourBranch: detourBranch,
      onMetricsHintDismiss: _markStageMetricsHintSeen,
      onTap: () => _openStageDetails(
        context: context,
        stage: stage,
        orderedStages: orderedItems,
        direction: direction,
        dismissMetricsHint: showMetricsHint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stages = ref.watch(stagesProvider);
    final excursions = ref.watch(excursionsForTrailProvider);
    final detours = ref.watch(detoursForTrailProvider);
    final direction = ref.watch(trailDirectionProvider);
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final elevationStages = stages.hasValue
        ? (direction.isReversed
              ? stages.requireValue.reversed.toList(growable: false)
              : stages.requireValue)
        : const <TrailStage>[];
    final gpsElevationStageIndex = _gpsSelectedStageId == null
        ? null
        : elevationStages.indexWhere(
            (stage) => stage.id == _gpsSelectedStageId,
          );
    ref.listen(stagesProvider, (previous, next) {
      if (!next.hasError || next.isLoading) return;
      final message = next.error is FirebaseNotConfiguredException
          ? 'Firebase is not configured for this build.'
          : previous?.value?.isNotEmpty == true
          ? 'Could not update the trail. Your offline copy is unchanged.'
          : 'Could not download the trail';
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
          MaterialPageRoute<void>(
            builder: (_) => ElevationScreen(
              initialStageIndex:
                  gpsElevationStageIndex != null && gpsElevationStageIndex >= 0
                  ? gpsElevationStageIndex
                  : null,
              initialLocation: _gpsLocation,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        key: const ValueKey('stage-pull-to-refresh'),
        onRefresh: () async {
          await _syncOfflineTrailData(ref, isInitialDownload: false);
          if (!context.mounted) return;
          ref.invalidate(excursionRoutesForTrailProvider);
          try {
            await ref
                .refresh(excursionsForTrailProvider.future)
                .then<void>((_) {});
          } catch (_) {
            // Stage data remains usable when online excursion data is absent.
          }
          if (!context.mounted) return;
          try {
            await ref
                .refresh(detoursForTrailProvider.future)
                .then<void>((_) {});
          } catch (_) {
            // Stage data remains usable when online detour data is absent.
          }
        },
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _TrailAppBar(
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
                final excursionsByStageId = <String, List<TrailExcursion>>{};
                for (final excursion
                    in excursions.value ?? const <TrailExcursion>[]) {
                  final stageId = excursion.anchorStageId;
                  if (stageId == null) continue;
                  excursionsByStageId
                      .putIfAbsent(stageId, () => [])
                      .add(excursion);
                }
                final detoursByStageId = <String, List<TrailDetour>>{};
                final trailDetours = detours.value ?? const <TrailDetour>[];
                for (final detour in trailDetours) {
                  for (final stageId in detour.affectedStageIds) {
                    detoursByStageId.putIfAbsent(stageId, () => []).add(detour);
                  }
                }
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
                final timelineRows = <Widget>[];
                final suppressedBranchDetoursByStageId =
                    <String, Set<String>>{};
                var timelineIndex = 0;
                while (timelineIndex < filteredItems.length) {
                  final currentStage = filteredItems[timelineIndex];
                  final currentOrderedIndex = orderedItems.indexWhere(
                    (candidate) => candidate.id == currentStage.id,
                  );
                  _DetourTimelineSpan? choiceSpan;
                  for (final detour in trailDetours) {
                    final span = _detourTimelineSpan(
                      detour: detour,
                      orderedStages: orderedItems,
                      direction: direction,
                    );
                    if (span == null ||
                        span.entry.rowIndex != currentOrderedIndex ||
                        span.exit.rowIndex - span.entry.rowIndex < 2) {
                      continue;
                    }
                    final groupStages = orderedItems.sublist(
                      span.entry.rowIndex,
                      span.exit.rowIndex + 1,
                    );
                    if (timelineIndex + groupStages.length >
                        filteredItems.length) {
                      continue;
                    }
                    var groupIsVisible = true;
                    for (
                      var offset = 0;
                      offset < groupStages.length;
                      offset++
                    ) {
                      if (filteredItems[timelineIndex + offset].id !=
                          groupStages[offset].id) {
                        groupIsVisible = false;
                        break;
                      }
                    }
                    if (groupIsVisible) {
                      choiceSpan = span;
                      break;
                    }
                  }

                  if (choiceSpan case final span?) {
                    final groupStages = orderedItems.sublist(
                      span.entry.rowIndex,
                      span.exit.rowIndex + 1,
                    );
                    final bypassedStages = groupStages.sublist(
                      1,
                      groupStages.length - 1,
                    );
                    for (final groupStage in groupStages) {
                      suppressedBranchDetoursByStageId
                          .putIfAbsent(groupStage.id, () => <String>{})
                          .add(span.detour.id);
                    }
                    timelineRows.add(
                      _buildStageTimelineRow(
                        context: context,
                        stage: currentStage,
                        filteredIndex: timelineIndex,
                        filteredItems: filteredItems,
                        orderedItems: orderedItems,
                        connectsFirstFilteredStageToWaymark:
                            connectsSingleNamedStageToWaymark,
                        direction: direction,
                        formatter: formatter,
                        totalDistanceKm: totalDistanceKm,
                        showMetricsHint: currentStage.id == metricsHintStageId,
                        excursions:
                            excursionsByStageId[currentStage.id] ??
                            const <TrailExcursion>[],
                        detours:
                            detoursByStageId[currentStage.id] ??
                            const <TrailDetour>[],
                        trailDetours: trailDetours
                            .where((detour) => detour.id != span.detour.id)
                            .toList(growable: false),
                      ),
                    );
                    timelineRows.add(
                      _DetourRouteChoicePanel(
                        detour: span.detour,
                        mainStages: bypassedStages,
                        orderedStages: orderedItems,
                        direction: direction,
                        formatter: formatter,
                        totalDistanceKm: totalDistanceKm,
                        selectedStageId: _gpsSelectedStageId,
                        excursionsByStageId: excursionsByStageId,
                        onStageTap: (selectedStage) {
                          _openStageDetails(
                            context: context,
                            stage: selectedStage,
                            orderedStages: orderedItems,
                            direction: direction,
                          );
                        },
                        onDetourTap: () {
                          _openDetourDetails(
                            context: context,
                            detour: span.detour,
                            orderedStages: orderedItems,
                            direction: direction,
                          );
                        },
                      ),
                    );
                    timelineIndex += groupStages.length - 1;
                    continue;
                  }

                  final suppressedDetourIds =
                      suppressedBranchDetoursByStageId[currentStage.id] ??
                      const <String>{};
                  timelineRows.add(
                    _buildStageTimelineRow(
                      context: context,
                      stage: currentStage,
                      filteredIndex: timelineIndex,
                      filteredItems: filteredItems,
                      orderedItems: orderedItems,
                      connectsFirstFilteredStageToWaymark:
                          connectsSingleNamedStageToWaymark,
                      direction: direction,
                      formatter: formatter,
                      totalDistanceKm: totalDistanceKm,
                      showMetricsHint: currentStage.id == metricsHintStageId,
                      excursions:
                          excursionsByStageId[currentStage.id] ??
                          const <TrailExcursion>[],
                      detours:
                          (detoursByStageId[currentStage.id] ??
                                  const <TrailDetour>[])
                              .where(
                                (detour) =>
                                    !suppressedDetourIds.contains(detour.id),
                              )
                              .toList(growable: false),
                      trailDetours: trailDetours
                          .where(
                            (detour) =>
                                !suppressedDetourIds.contains(detour.id),
                          )
                          .toList(growable: false),
                    ),
                  );
                  timelineIndex++;
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
                              ...timelineRows,
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
                child: _EmptyState(downloadFailed: true),
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
    return EurotrexChromeTheme.navigationBar(
      surfaceKey: const ValueKey('stage-bottom-navigation'),
      contentKey: const ValueKey('stage-bottom-navigation-size'),
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
            visibleLabel: l10n.t('Reverse'),
            onTap: onReverse,
          ),
          _StageBottomAction(
            key: const ValueKey('stage-bottom-filter'),
            icon: Icons.filter_list_rounded,
            label: l10n.t('Filter'),
            visibleLabel: l10n.t('Filter'),
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
            visibleLabel: l10n.t('GPS'),
            isActive: hasGpsSelection,
            isToggle: true,
            isPrimary: true,
            onTap: isLocating ? null : onGps,
          ),
          _StageBottomAction(
            key: const ValueKey('stage-bottom-map'),
            icon: Icons.map_outlined,
            label: l10n.t('Map'),
            visibleLabel: l10n.t('Map'),
            onTap: onMap,
          ),
          _StageBottomAction(
            key: const ValueKey('stage-bottom-elevation'),
            icon: Icons.landscape_outlined,
            label: l10n.t('Elevation'),
            visibleLabel: l10n.t('Elevation'),
            onTap: onElevation,
          ),
        ],
      ),
    );
  }
}

class _StageBottomAction extends StatelessWidget {
  const _StageBottomAction({
    required this.icon,
    required this.label,
    required this.visibleLabel,
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
  final String visibleLabel;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isToggle;
  final bool isPrimary;
  final int badgeCount;
  final bool showReverseTrailIcon;

  @override
  Widget build(BuildContext context) {
    final foreground = onTap == null ? Colors.white30 : Colors.white;
    void handleTap() {
      unawaited(HapticFeedback.selectionClick());
      onTap?.call();
    }

    Widget buildIcon(double size) => showReverseTrailIcon
        ? _ReverseTrailIcon(color: foreground, size: size + 4)
        : Icon(icon, color: foreground, size: size);
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          excludeSemantics: true,
          selected: isToggle ? null : isActive,
          toggled: isToggle ? isActive : null,
          label: label,
          onTap: onTap == null ? null : handleTap,
          child: InkWell(
            splashColor: Colors.white12,
            highlightColor: Colors.white10,
            onTap: onTap == null ? null : handleTap,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 36,
                    child: Center(
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
                                      ? EurotrexPalette.blue
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
                  ),
                  const SizedBox(height: 1),
                  SizedBox(
                    width: double.infinity,
                    height: 11,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        visibleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
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
              color: color,
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
    required this.isCollapsed,
    required this.onTrailInformationHintReset,
    required this.onStageDetailsHintReset,
    required this.onStageMetricsHintReset,
  });

  final bool isCollapsed;
  final VoidCallback onTrailInformationHintReset;
  final VoidCallback onStageDetailsHintReset;
  final VoidCallback onStageMetricsHintReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasBackButton = Navigator.of(context).canPop();
    final headerContentLeft = hasBackButton ? kToolbarHeight : 20.0;
    return SliverAppBar(
      expandedHeight: _trailHeaderExpandedHeight,
      pinned: true,
      backgroundColor: EurotrexPalette.navy,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleSpacing: 0,
      title: Row(
        key: const ValueKey('trail-toolbar-actions'),
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: hasBackButton ? 0 : 20),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  IgnorePointer(
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
                  IgnorePointer(
                    child: AnimatedOpacity(
                      key: const ValueKey('trail-expanded-badges-opacity'),
                      opacity: isCollapsed ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: const _TrailHeaderBadges(),
                    ),
                  ),
                ],
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
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            key: ValueKey('stages-compact-header-gradient'),
            decoration: BoxDecoration(
              gradient: EurotrexChromeTheme.navigationGradient,
            ),
          ),
          FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
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
                      colors: [Color(0x80000000), Color(0x52000000)],
                      stops: [0.05, 1],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    key: const ValueKey('stages-header-content-padding'),
                    padding: EdgeInsets.fromLTRB(headerContentLeft, 52, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l10n.t('Cyprus E4'),
                          key: const ValueKey('stages-expanded-title'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
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

class _TrailHeaderBadges extends StatelessWidget {
  const _TrailHeaderBadges();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('stage-header-badges'),
      children: [
        Container(
          key: const ValueKey('stage-long-distance-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _yellow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            context.l10n.t('LONG DISTANCE'),
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

class _DetourRouteChoicePanel extends StatelessWidget {
  const _DetourRouteChoicePanel({
    required this.detour,
    required this.mainStages,
    required this.orderedStages,
    required this.direction,
    required this.formatter,
    required this.totalDistanceKm,
    required this.selectedStageId,
    required this.excursionsByStageId,
    required this.onStageTap,
    required this.onDetourTap,
  });

  final TrailDetour detour;
  final List<TrailStage> mainStages;
  final List<TrailStage> orderedStages;
  final TrailDirection direction;
  final MeasurementFormatter formatter;
  final double totalDistanceKm;
  final String? selectedStageId;
  final Map<String, List<TrailExcursion>> excursionsByStageId;
  final ValueChanged<TrailStage> onStageTap;
  final VoidCallback onDetourTap;

  @override
  Widget build(BuildContext context) {
    if (mainStages.isEmpty) return const SizedBox.shrink();
    const cardGap = 10.0;
    const connectorHeight = 34.0;
    const bottomInset = 12.0;
    const mainCardHeight = 140.0;
    final contentHeight =
        mainStages.length * mainCardHeight +
        math.max(0, mainStages.length - 1) * cardGap;
    final panelHeight = connectorHeight + contentHeight + bottomInset;

    return SizedBox(
      key: ValueKey('stage-detour-choice-${detour.id}'),
      height: panelHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const laneGap = 10.0;
          const contentLeft = _timelineGutterWidth;
          final laneWidth = (constraints.maxWidth - contentLeft - laneGap) / 2;
          final leftCenter = contentLeft + laneWidth / 2;
          final rightCenter = contentLeft + laneWidth + laneGap + laneWidth / 2;
          final timelineX =
              _timelineGutterWidth - (_timelineLineColumnWidth / 2);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: timelineX - 1,
                top: 0,
                bottom: 0,
                width: 2,
                child: ColoredBox(
                  key: ValueKey('stage-detour-timeline-axis-${detour.id}'),
                  color: _timelineLineColor,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  key: ValueKey('stage-detour-connectors-${detour.id}'),
                  painter: _DetourChoiceConnectorPainter(
                    leftCenterX: leftCenter,
                    rightCenterX: rightCenter,
                    cardTopY: connectorHeight,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: connectorHeight,
                width: _timelineGutterWidth - _timelineLineColumnWidth,
                height: contentHeight,
                child: Column(
                  children: [
                    for (var index = 0; index < mainStages.length; index++) ...[
                      SizedBox(
                        height: mainCardHeight,
                        child: Center(
                          child: _DetourMainStageSideMetrics(
                            stage: mainStages[index],
                            orderedStages: orderedStages,
                            direction: direction,
                            formatter: formatter,
                          ),
                        ),
                      ),
                      if (index < mainStages.length - 1)
                        const SizedBox(height: cardGap),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: contentLeft,
                top: connectorHeight,
                width: laneWidth,
                child: Column(
                  children: [
                    for (var index = 0; index < mainStages.length; index++) ...[
                      SizedBox(
                        height: mainCardHeight,
                        child: _DetourMainStageCard(
                          stage: mainStages[index],
                          direction: direction,
                          formatter: formatter,
                          totalDistanceKm: totalDistanceKm,
                          isSelected: mainStages[index].id == selectedStageId,
                          excursions:
                              excursionsByStageId[mainStages[index].id] ??
                              const <TrailExcursion>[],
                          onTap: () => onStageTap(mainStages[index]),
                        ),
                      ),
                      if (index < mainStages.length - 1)
                        const SizedBox(height: cardGap),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: connectorHeight,
                width: laneWidth,
                height: contentHeight,
                child: _DetourChoiceCard(
                  detour: detour,
                  formatter: formatter,
                  onTap: onDetourTap,
                  linkedStageId: mainStages.first.id,
                ),
              ),
              for (var index = 0; index < mainStages.length; index++)
                Positioned(
                  left: timelineX - 11.5,
                  top:
                      connectorHeight +
                      index * (mainCardHeight + cardGap) +
                      (mainCardHeight - 23) / 2,
                  child: SizedBox.square(
                    dimension: 23,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (mainStages[index].id == selectedStageId)
                          Container(
                            key: ValueKey(
                              'stage-marker-selection-${mainStages[index].id}',
                            ),
                            width: 23,
                            height: 23,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _bookingBlue, width: 2),
                            ),
                          ),
                        Container(
                          key: ValueKey(
                            'stage-detour-e4-path-marker-${mainStages[index].id}',
                          ),
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stageIsOnTrail(mainStages[index]) == false
                                ? _yellow
                                : _green,
                            border: Border.all(color: _sand, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetourChoiceCard extends StatelessWidget {
  const _DetourChoiceCard({
    required this.detour,
    required this.formatter,
    required this.onTap,
    required this.linkedStageId,
  });

  final TrailDetour detour;
  final MeasurementFormatter formatter;
  final VoidCallback onTap;
  final String linkedStageId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: '${l10n.t('Detour')}: ${detour.name}',
      child: Material(
        key: ValueKey('stage-detour-choice-card-${detour.id}'),
        color: const Color(0xFFF1ECF5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _detourPurple, width: 1.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      key: ValueKey('stage-detour-tab-$linkedStageId'),
                      width: 30,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _detourPurple, width: 1.5),
                      ),
                      child: Icon(
                        Icons.fork_right_rounded,
                        key: ValueKey('stage-detour-marker-$linkedStageId'),
                        color: _detourPurple,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        l10n.t('Detour').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _detourPurple,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  detour.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    _CompactRouteMetric(
                      icon: Icons.route_rounded,
                      label: formatter.distance(detour.routeDistanceKm),
                      color: _detourPurple,
                    ),
                    _CompactRouteMetric(
                      icon: Icons.schedule_rounded,
                      label: _formatWalkingTime(
                        Duration(minutes: detour.estimatedWalkingTimeMinutes),
                        l10n,
                      ),
                      color: _detourPurple,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetourMainStageCard extends StatelessWidget {
  const _DetourMainStageCard({
    required this.stage,
    required this.direction,
    required this.formatter,
    required this.totalDistanceKm,
    required this.isSelected,
    required this.excursions,
    required this.onTap,
  });

  final TrailStage stage;
  final TrailDirection direction;
  final MeasurementFormatter formatter;
  final double totalDistanceKm;
  final bool isSelected;
  final List<TrailExcursion> excursions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeServices = _activeStageServices(
      stage.services,
    ).take(7).toList(growable: false);
    final distanceFromStart = stage.accumulatedDistanceKm == null
        ? null
        : direction.distanceFromStart(
            stage.accumulatedDistanceKm!,
            totalDistanceKm,
          );

    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        key: ValueKey('stage-card-${stage.id}'),
        color: isSelected ? _selectedStageCardBackground : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? _bookingBlue : _stageCardOutline,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: ValueKey('stage-e4-badge-${stage.id}'),
                      width: 30,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _yellow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.l10n.t('E4'),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${stage.sequence}',
                      key: ValueKey('stage-number-${stage.id}'),
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  stage.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (activeServices.isNotEmpty || excursions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    key: ValueKey('stage-card-services-${stage.id}'),
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final service in activeServices)
                        Tooltip(
                          message: _serviceLabel(service.key, context.l10n),
                          child: Icon(
                            _serviceIcon(service.key),
                            size: 16,
                            color: _serviceColor(service.key),
                          ),
                        ),
                      if (excursions.isNotEmpty)
                        const Icon(
                          Icons.alt_route_rounded,
                          size: 16,
                          color: _filterBlueTeal,
                        ),
                    ],
                  ),
                ],
                const Spacer(),
                Container(
                  key: ValueKey('stage-card-footer-${stage.id}'),
                  padding: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x1A17201B))),
                  ),
                  child: Row(
                    key: ValueKey('stage-card-metrics-${stage.id}'),
                    children: [
                      if (distanceFromStart != null)
                        Expanded(
                          child: _StageCumulativeDistance(
                            key: ValueKey('stage-card-distance-${stage.id}'),
                            distanceKm: distanceFromStart,
                            totalDistanceKm: totalDistanceKm,
                            formatter: formatter,
                          ),
                        ),
                      if (distanceFromStart != null && stage.altitudeM != null)
                        const SizedBox(width: 8),
                      if (stage.altitudeM case final altitude?)
                        _MiniLabel(
                          key: ValueKey('stage-card-altitude-${stage.id}'),
                          icon: Icons.landscape_outlined,
                          label: formatter.altitude(altitude),
                        ),
                    ],
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

class _DetourMainStageSideMetrics extends StatelessWidget {
  const _DetourMainStageSideMetrics({
    required this.stage,
    required this.orderedStages,
    required this.direction,
    required this.formatter,
  });

  final TrailStage stage;
  final List<TrailStage> orderedStages;
  final TrailDirection direction;
  final MeasurementFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final stageIndex = orderedStages.indexWhere(
      (candidate) => candidate.id == stage.id,
    );
    final legMetrics = _stageLegMetrics(
      orderedStages: orderedStages,
      index: stageIndex,
      direction: direction,
    );
    final distanceFromPathKm = stage.distanceFromPathKm;
    return Column(
      key: ValueKey('stage-side-metrics-${stage.id}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _StageSideMetric(
          key: ValueKey('stage-ascent-${stage.id}'),
          icon: Icons.arrow_upward_rounded,
          value: legMetrics.ascentM == null
              ? '—'
              : _compactMeasurement(formatter.altitude(legMetrics.ascentM!)),
          tooltip: context.l10n.t('Ascent'),
          color: _green,
        ),
        _StageSideMetric(
          key: ValueKey('stage-descent-${stage.id}'),
          icon: Icons.arrow_downward_rounded,
          value: legMetrics.descentM == null
              ? '—'
              : _compactMeasurement(formatter.altitude(legMetrics.descentM!)),
          tooltip: context.l10n.t('Descent'),
          color: _red,
        ),
        _StageSideMetric(
          key: ValueKey('stage-length-${stage.id}'),
          icon: Icons.straighten_rounded,
          value: legMetrics.lengthKm == null
              ? '—'
              : _compactMeasurement(formatter.distance(legMetrics.lengthKm!)),
          tooltip: context.l10n.t('Stage length'),
          color: _filterBlueTeal,
        ),
        if (stageIsOnTrail(stage) == false) ...[
          const SizedBox(height: 2),
          _StageTrailDistanceLabel(
            stageId: stage.id,
            distance: _trimmedDistance(formatter, distanceFromPathKm!),
          ),
        ],
      ],
    );
  }
}

class _CompactRouteMetric extends StatelessWidget {
  const _CompactRouteMetric({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DetourChoiceConnectorPainter extends CustomPainter {
  const _DetourChoiceConnectorPainter({
    required this.leftCenterX,
    required this.rightCenterX,
    required this.cardTopY,
  });

  final double leftCenterX;
  final double rightCenterX;
  final double cardTopY;

  @override
  void paint(Canvas canvas, Size size) {
    final mainColor = _green.withValues(alpha: 0.82);
    final arrowTipY = cardTopY - 3;
    final arrowBaseY = arrowTipY - 7;
    final mainPaint = Paint()
      ..color = mainColor
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(leftCenterX, 0),
      Offset(leftCenterX, arrowBaseY),
      mainPaint,
    );
    _drawDownArrow(canvas, leftCenterX, arrowTipY, mainColor);

    final detourPaint = Paint()
      ..color = _detourPurple
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    const dashLength = 4.0;
    const dashGap = 4.0;
    var dashY = 0.0;
    while (dashY < arrowBaseY) {
      final dashEnd = math.min(dashY + dashLength, arrowBaseY);
      canvas.drawLine(
        Offset(rightCenterX, dashY),
        Offset(rightCenterX, dashEnd),
        detourPaint,
      );
      dashY = dashEnd + dashGap;
    }
    _drawDownArrow(canvas, rightCenterX, arrowTipY, _detourPurple);
  }

  void _drawDownArrow(Canvas canvas, double x, double tipY, Color color) {
    final arrow = Path()
      ..moveTo(x - 4.5, tipY - 7)
      ..lineTo(x + 4.5, tipY - 7)
      ..lineTo(x, tipY)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DetourChoiceConnectorPainter oldDelegate) {
    return oldDelegate.leftCenterX != leftCenterX ||
        oldDelegate.rightCenterX != rightCenterX ||
        oldDelegate.cardTopY != cardTopY;
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
    required this.totalDistanceKm,
    required this.connectsToPrevious,
    required this.connectsToNext,
    required this.isTrailStart,
    required this.isTrailEnd,
    required this.isSelected,
    required this.showDetailsHint,
    required this.showMetricsHint,
    required this.excursions,
    required this.detours,
    required this.detourBranch,
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
  final double totalDistanceKm;
  final bool connectsToPrevious;
  final bool connectsToNext;
  final bool isTrailStart;
  final bool isTrailEnd;
  final bool isSelected;
  final bool showDetailsHint;
  final bool showMetricsHint;
  final List<TrailExcursion> excursions;
  final List<TrailDetour> detours;
  final _DetourTimelineBranch? detourBranch;
  final VoidCallback onMetricsHintDismiss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeServices = _activeStageServices(stage.services);
    final hasExcursions = excursions.isNotEmpty;
    final hasDetours = detours.isNotEmpty;
    final showDistance = !isTrailStart && distanceKm != null;
    final distanceFromPathKm = stage.distanceFromPathKm;
    final isOnTrail = stageIsOnTrail(stage);
    final hasDistanceFromPath = isOnTrail == false;
    final dotColor = isOnTrail != null
        ? isOnTrail == true
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
                distance: _trimmedDistance(formatter, distanceFromPathKm!),
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
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      if (detourBranch case final branch?)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: ValueKey('stage-detour-branch-${stage.id}'),
                              painter: _DetourBranchPainter(branch: branch),
                            ),
                          ),
                        ),
                      Column(
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
                          SizedBox.square(
                            dimension: 23,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isSelected)
                                  Container(
                                    key: ValueKey(
                                      'stage-marker-selection-${stage.id}',
                                    ),
                                    width: 23,
                                    height: 23,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _bookingBlue,
                                        width: 2,
                                      ),
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
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: hasDetours ? 11 : 0, bottom: 7),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: isTrailEnd
                      ? hasDistanceFromPath
                            ? 118
                            : 104
                      : hasDistanceFromPath
                      ? 92
                      : 0,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Semantics(
                      selected: isSelected,
                      child: Material(
                        key: ValueKey('stage-card-${stage.id}'),
                        color: isSelected
                            ? _selectedStageCardBackground
                            : hasExcursions
                            ? _excursionCardBackground
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? _bookingBlue
                                : showDetailsHint || showMetricsHint
                                ? _trailPulseBlue
                                : hasExcursions
                                ? _filterBlueTeal
                                : _stageCardOutline,
                            width:
                                isSelected || showDetailsHint || showMetricsHint
                                ? 2
                                : hasExcursions
                                ? 1.6
                                : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onTap,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
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
                                      if (hasExcursions) ...[
                                        Row(
                                          children: [
                                            _StageLinkedRouteTab(
                                              containerKey: ValueKey(
                                                'stage-excursion-tab-${stage.id}',
                                              ),
                                              markerKey: ValueKey(
                                                'stage-excursion-marker-${stage.id}',
                                              ),
                                              tooltip: context.l10n.t(
                                                'Excursions',
                                              ),
                                              icon: Icons.alt_route_rounded,
                                              color: _filterBlueTeal,
                                              onTap: onTap,
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              context.l10n
                                                  .t('Excursion')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: _filterBlueTeal,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
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
                                                color: Colors.black38,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (activeServices.isNotEmpty) ...[
                                        const SizedBox(height: 6),
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
                                                message: _serviceLabel(
                                                  service.key,
                                                  context.l10n,
                                                ),
                                                child: Icon(
                                                  _serviceIcon(service.key),
                                                  size: 16,
                                                  color: _serviceColor(
                                                    service.key,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                      if (showDistance ||
                                          stage.altitudeM != null) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          key: ValueKey(
                                            'stage-card-footer-${stage.id}',
                                          ),
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: Color(0x1A17201B),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            key: ValueKey(
                                              'stage-card-metrics-${stage.id}',
                                            ),
                                            mainAxisAlignment: showDistance
                                                ? MainAxisAlignment.start
                                                : MainAxisAlignment.end,
                                            children: [
                                              if (showDistance)
                                                Expanded(
                                                  child: _StageCumulativeDistance(
                                                    key: ValueKey(
                                                      'stage-card-distance-${stage.id}',
                                                    ),
                                                    distanceKm: distanceKm!,
                                                    totalDistanceKm:
                                                        totalDistanceKm,
                                                    formatter: formatter,
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
                                                  icon:
                                                      Icons.landscape_outlined,
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
                    if (hasDetours)
                      Positioned(
                        top: -11,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StageLinkedRouteTab(
                                containerKey: ValueKey(
                                  'stage-detour-tab-${stage.id}',
                                ),
                                markerKey: ValueKey(
                                  'stage-detour-marker-${stage.id}',
                                ),
                                tooltip: context.l10n.t('Detours'),
                                icon: Icons.fork_right_rounded,
                                color: _detourPurple,
                                onTap: onTap,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageLinkedRouteTab extends StatelessWidget {
  const _StageLinkedRouteTab({
    required this.containerKey,
    required this.markerKey,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final Key containerKey;
  final Key markerKey;
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: containerKey,
          width: 42,
          height: 23,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, key: markerKey, size: 17, color: color),
        ),
      ),
    );
  }
}

class _DetourBranchPainter extends CustomPainter {
  const _DetourBranchPainter({required this.branch});

  final _DetourTimelineBranch branch;

  @override
  void paint(Canvas canvas, Size size) {
    final mainX = size.width / 2;
    final branchX = size.width - 3;
    final splitY = branch.splitY == null
        ? null
        : branch.splitY!.clamp(0.0, 1.0).toDouble() * size.height;
    final rejoinY = branch.rejoinY == null
        ? null
        : branch.rejoinY!.clamp(0.0, 1.0).toDouble() * size.height;
    final path = Path();
    var currentY = 0.0;

    if (branch.entersFromTop) {
      path.moveTo(branchX, 0);
    } else if (splitY != null) {
      final curveHeight = math.min(14.0, math.max(7.0, size.height - splitY));
      path.moveTo(mainX, splitY);
      path.cubicTo(
        mainX,
        splitY + curveHeight * 0.45,
        branchX,
        splitY + curveHeight * 0.55,
        branchX,
        splitY + curveHeight,
      );
      currentY = splitY + curveHeight;
    } else {
      return;
    }

    if (rejoinY != null) {
      final availableHeight = math.max(0.0, rejoinY - currentY);
      final curveHeight = math.min(14.0, math.max(7.0, availableHeight));
      final curveStartY = math.max(currentY, rejoinY - curveHeight);
      if (curveStartY > currentY) path.lineTo(branchX, curveStartY);
      path.cubicTo(
        branchX,
        curveStartY + curveHeight * 0.45,
        mainX,
        rejoinY - curveHeight * 0.45,
        mainX,
        rejoinY,
      );
    } else if (branch.exitsToBottom) {
      path.lineTo(branchX, size.height);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = _sand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _detourPurple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    final connectionPaint = Paint()..color = _detourPurple;
    final connectionHaloPaint = Paint()..color = _sand;
    for (final connectionY in [splitY, rejoinY].whereType<double>()) {
      canvas.drawCircle(Offset(mainX, connectionY), 4.5, connectionHaloPaint);
      canvas.drawCircle(Offset(mainX, connectionY), 2.4, connectionPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DetourBranchPainter oldDelegate) {
    return oldDelegate.branch.entersFromTop != branch.entersFromTop ||
        oldDelegate.branch.exitsToBottom != branch.exitsToBottom ||
        oldDelegate.branch.splitY != branch.splitY ||
        oldDelegate.branch.rejoinY != branch.rejoinY;
  }
}

String _compactMeasurement(String value) => value.replaceAll(' ', '');

String _trimmedDistance(MeasurementFormatter formatter, double distanceKm) {
  final value = formatter.distanceValue(distanceKm).toStringAsFixed(1);
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
        excludeSemantics: true,
        child: SizedBox(
          key: ValueKey('stage-distance-from-trail-$stageId'),
          width: 72,
          child: Row(
            children: [
              SizedBox(
                width: 15,
                child: Icon(
                  Icons.add_rounded,
                  key: ValueKey('stage-distance-from-trail-icon-$stageId'),
                  size: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  distance,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageCumulativeDistance extends StatelessWidget {
  const _StageCumulativeDistance({
    required this.distanceKm,
    required this.totalDistanceKm,
    required this.formatter,
    super.key,
  });

  final double distanceKm;
  final double totalDistanceKm;
  final MeasurementFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.t('From Start');
    final distance = formatter.distance(distanceKm);
    final totalDistance = formatter.distance(totalDistanceKm);
    final progress = totalDistanceKm.isFinite && totalDistanceKm > 0
        ? (distanceKm / totalDistanceKm).clamp(0.0, 1.0)
        : 0.0;
    final progressTrack = ClipRRect(
      key: const ValueKey('stage-progress-track'),
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFE0E4E1)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                key: const ValueKey('stage-progress-fill'),
                widthFactor: progress,
                heightFactor: 1,
                child: const ColoredBox(color: _green),
              ),
            ),
          ],
        ),
      ),
    );
    final distanceLabel = Text(
      distance,
      style: const TextStyle(
        color: _green,
        fontWeight: FontWeight.w800,
        fontSize: 10,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
    return Tooltip(
      message: label,
      child: Semantics(
        label: '$label: $distance / $totalDistance',
        excludeSemantics: true,
        child: Row(
          children: [
            Expanded(flex: 4, child: progressTrack),
            const SizedBox(width: 4),
            Flexible(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: distanceLabel,
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
      child: SizedBox(
        width: 72,
        child: Row(
          children: [
            SizedBox(
              width: 15,
              child: icon == null ? null : Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
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

class DetourDetailScreen extends ConsumerWidget {
  const DetourDetailScreen({
    required this.detour,
    required this.stages,
    required this.direction,
    super.key,
  });

  final TrailDetour detour;
  final List<TrailStage> stages;
  final TrailDirection direction;

  Future<void> _openMap(
    BuildContext context,
    WidgetRef ref,
    int? initialStageIndex,
    TrailDetourRoute? loadedRoute,
  ) async {
    var route = loadedRoute;
    if (route == null) {
      try {
        for (final candidate in await ref.read(
          detourRoutesForTrailProvider.future,
        )) {
          if (candidate.detour.id == detour.id) {
            route = candidate;
            break;
          }
        }
      } catch (_) {
        // The main trail map remains available if detour geometry cannot load.
      }
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          initialStageIndex: initialStageIndex,
          initialDetours: route == null ? const [] : [route],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final mainRoutePoints = ref.watch(elevationProvider).value ?? const [];
    TrailDetourRoute? detourRoute;
    for (final route
        in ref.watch(detourRoutesForTrailProvider).value ??
            const <TrailDetourRoute>[]) {
      if (route.detour.id == detour.id) {
        detourRoute = route;
        break;
      }
    }
    final detourAscent = direction.isReversed
        ? detour.elevationDownM
        : detour.elevationUpM;
    final detourDescent = direction.isReversed
        ? detour.elevationUpM
        : detour.elevationDownM;
    final walkingTime = estimateNaismithWalkingTime(
      distanceKm: detour.routeDistanceKm,
      ascentM: detourAscent,
    );
    final startDistanceKm = direction.isReversed
        ? detour.endMainTrailDistanceKm
        : detour.startMainTrailDistanceKm;
    final finishDistanceKm = direction.isReversed
        ? detour.startMainTrailDistanceKm
        : detour.endMainTrailDistanceKm;
    final initialStageIndex = startDistanceKm == null
        ? null
        : _detourTimelineConnection(stages, startDistanceKm)?.rowIndex;
    final mappedDetours = detourRoute == null
        ? const <TrailDetourRoute>[]
        : [detourRoute];

    return Scaffold(
      key: ValueKey('detour-detail-${detour.id}'),
      backgroundColor: _sand,
      appBar: EurotrexChromeTheme.appBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detour.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'CYPRUS E4 · ${l10n.t('Detour').toUpperCase()}',
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white60,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DetailMetric(
                    icon: Icons.fork_right_rounded,
                    iconColor: _detourPurple,
                    value: formatter.distance(detour.routeDistanceKm),
                    label: l10n.t('Detour route'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailMetric(
                    icon: Icons.schedule_rounded,
                    iconColor: _detourPurple,
                    value: _formatWalkingTime(walkingTime, l10n),
                    label: l10n.t('Estimated walking time'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CompactDetailMetrics(
            children: [
              _CompactDetailMetric(
                icon: Icons.trending_up_rounded,
                iconColor: _green,
                value: formatter.altitude(detourAscent),
                label: l10n.t('Ascent'),
              ),
              _CompactDetailMetric(
                icon: Icons.trending_down_rounded,
                iconColor: _red,
                value: formatter.altitude(detourDescent),
                label: l10n.t('Descent'),
              ),
              _CompactDetailMetric(
                icon: Icons.add_road_rounded,
                iconColor: _detourPurple,
                value: formatter.distance(detour.maximumDistanceFromTrailKm),
                label: l10n.t('Maximum distance from trail'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: l10n.t('Alternative route'),
            child: _DetourSummaryCard(
              detour: detour,
              direction: direction,
              formatter: formatter,
            ),
          ),
          const SizedBox(height: 12),
          _StageMapPreview(
            routePoints: mainRoutePoints,
            startDistanceKm: startDistanceKm,
            finishDistanceKm: finishDistanceKm,
            showRoute: true,
            showFinishFlag: true,
            lodgings: const [],
            excursions: const [],
            detours: mappedDetours,
            showUserLocation: false,
            userLocation: null,
            onTap: () => _openMap(context, ref, initialStageIndex, detourRoute),
          ),
        ],
      ),
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
  double? _gpsRouteDistanceKm;
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

  Future<void> _openMap({
    List<Lodging> lodgings = const [],
    List<TrailExcursionRoute> excursions = const [],
    List<TrailDetourRoute> detours = const [],
    bool loadStageExcursions = false,
    bool loadStageDetours = false,
  }) async {
    final selectedStage = stage;
    final selectedIndex = index;
    var mappedExcursions = excursions;
    if (loadStageExcursions && mappedExcursions.isEmpty) {
      try {
        mappedExcursions =
            (await ref.read(excursionRoutesForTrailProvider.future))
                .where(
                  (route) => route.excursion.anchorStageId == selectedStage.id,
                )
                .toList(growable: false);
      } catch (_) {
        // The main trail map still opens if excursion geometry is unavailable.
      }
    }
    var mappedDetours = detours;
    if (loadStageDetours && mappedDetours.isEmpty) {
      try {
        mappedDetours = (await ref.read(detourRoutesForTrailProvider.future))
            .where(
              (route) =>
                  route.detour.affectedStageIds.contains(selectedStage.id),
            )
            .toList(growable: false);
      } catch (_) {
        // The main trail map still opens if detour geometry is unavailable.
      }
    }
    if (!mounted) return;
    final locationStageId = selectedStage.id == _gpsStageId
        ? _gpsStageId
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          initialStageIndex: selectedIndex,
          initialLodgings: lodgings,
          initialExcursions: mappedExcursions,
          initialDetours: mappedDetours,
          locationStageId: locationStageId,
        ),
      ),
    );
  }

  void _openElevation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ElevationScreen(
          initialStageIndex: index,
          initialLocation: _gpsLocation,
        ),
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
        _gpsRouteDistanceKm = null;
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
        _gpsRouteDistanceKm = match.projectedRouteDistanceKm;
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
      context.l10n.offTrailDistance(formatter.proximityDistance(distanceM)),
    );
  }

  double? _projectedRouteDistanceForLocation({
    required DeviceLocation? location,
    required List<RoutePoint> routePoints,
  }) {
    if (location == null || routePoints.isEmpty || _gpsStageId == null) {
      return null;
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
    return match?.stageId == _gpsStageId
        ? match?.projectedRouteDistanceKm
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final showUserLocation = stage.id == _gpsStageId;
    final previewRoute = ref.watch(elevationProvider).value;
    final previewGpsRouteDistanceKm = showUserLocation
        ? _gpsRouteDistanceKm ??
              _projectedRouteDistanceForLocation(
                location: _gpsLocation,
                routePoints: previewRoute ?? const [],
              )
        : null;
    final previewStartDistanceKm = index == 0
        ? stage.accumulatedDistanceKm
        : widget.stages[index - 1].accumulatedDistanceKm;
    final previewFinishDistanceKm = index == 0 && widget.stages.length > 1
        ? widget.stages[1].accumulatedDistanceKm
        : stage.accumulatedDistanceKm;
    final lodgings = ref.watch(lodgingsForStageProvider(stage.id));
    final excursions = ref
        .watch(excursionsForTrailProvider)
        .value
        ?.where((excursion) => excursion.anchorStageId == stage.id)
        .toList(growable: false);
    final excursionRoutes = excursions?.isNotEmpty == true
        ? ref
                  .watch(excursionRoutesForTrailProvider)
                  .value
                  ?.where((route) => route.excursion.anchorStageId == stage.id)
                  .toList(growable: false) ??
              const <TrailExcursionRoute>[]
        : const <TrailExcursionRoute>[];
    final detours = ref
        .watch(detoursForTrailProvider)
        .value
        ?.where((detour) => detour.affectedStageIds.contains(stage.id))
        .toList(growable: false);
    final detourRoutes = detours?.isNotEmpty == true
        ? ref
                  .watch(detourRoutesForTrailProvider)
                  .value
                  ?.where(
                    (route) => route.detour.affectedStageIds.contains(stage.id),
                  )
                  .toList(growable: false) ??
              const <TrailDetourRoute>[]
        : const <TrailDetourRoute>[];
    final lodgingCount = lodgings.value?.length ?? 0;
    final mappedLodgings =
        lodgings.value
            ?.where((lodging) => lodging.location != null)
            .toList(growable: false) ??
        const <Lodging>[];
    final endpointLabel = index == 0
        ? l10n.t('Start')
        : index == widget.stages.length - 1
        ? l10n.t('Finish')
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
        onMap: () => _openMap(
          lodgings: mappedLodgings,
          excursions: excursionRoutes,
          detours: detourRoutes,
          loadStageExcursions: excursions?.isNotEmpty == true,
          loadStageDetours: detours?.isNotEmpty == true,
        ),
        onElevation: _openElevation,
      ),
      appBar: EurotrexChromeTheme.appBar(
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
              StageInfoCards(
                stage: stage,
                stages: widget.stages,
                index: index,
                direction: widget.direction,
                formatter: formatter,
                excursions: excursions ?? const [],
                detours: detours ?? const [],
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('stage-route-preview-panel'),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: EurotrexPalette.paleBlue),
                  boxShadow: [
                    BoxShadow(
                      color: EurotrexPalette.navy.withValues(alpha: 0.045),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StageMapPreview(
                      key: _mapPreviewKey,
                      routePoints: previewRoute ?? const [],
                      startDistanceKm: previewStartDistanceKm,
                      finishDistanceKm: previewFinishDistanceKm,
                      showRoute: stagePreviewShowsRoute(index),
                      showFinishFlag: stagePreviewShowsFinishFlag(index),
                      lodgings: mappedLodgings,
                      excursions: excursionRoutes,
                      detours: detourRoutes,
                      showUserLocation: showUserLocation,
                      userLocation: showUserLocation ? _gpsLocation : null,
                      embedded: true,
                      onTap: () => _openMap(
                        lodgings: mappedLodgings,
                        excursions: excursionRoutes,
                        detours: detourRoutes,
                        loadStageExcursions: excursions?.isNotEmpty == true,
                        loadStageDetours: detours?.isNotEmpty == true,
                      ),
                    ),
                    if (index > 0) ...[
                      Container(
                        key: const Key('stage-route-preview-divider'),
                        height: 1,
                        color: EurotrexPalette.blue.withValues(alpha: 0.55),
                      ),
                      _StageElevationPreview(
                        routePoints: previewRoute ?? const [],
                        startDistanceKm:
                            widget.stages[index - 1].accumulatedDistanceKm,
                        finishDistanceKm: stage.accumulatedDistanceKm,
                        reversed: widget.direction.isReversed,
                        formatter: formatter,
                        gpsRouteDistanceKm: previewGpsRouteDistanceKm,
                        embedded: true,
                        onTap: _openElevation,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StageInfoCards extends StatelessWidget {
  const StageInfoCards({
    required this.stage,
    required this.stages,
    required this.index,
    required this.direction,
    required this.formatter,
    this.excursions = const [],
    this.detours = const [],
    super.key,
  });

  final TrailStage stage;
  final List<TrailStage> stages;
  final int index;
  final TrailDirection direction;
  final MeasurementFormatter formatter;
  final List<TrailExcursion> excursions;
  final List<TrailDetour> detours;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = _activeStageServices(stage.services);
    final accumulatedDistance = stage.accumulatedDistanceKm;
    final totalDistanceKm = _trailDistanceKm(stages);
    final distanceFromStart = accumulatedDistance == null
        ? null
        : direction.distanceFromStart(accumulatedDistance, totalDistanceKm);
    final distanceToFinish = distanceFromStart == null
        ? null
        : (totalDistanceKm - distanceFromStart)
              .clamp(0, totalDistanceKm)
              .toDouble();
    final endpointLabel = index == 0
        ? l10n.t('Start')
        : index == stages.length - 1
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
      orderedStages: stages,
      index: index,
      direction: direction,
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

    return Column(
      key: const ValueKey('stage-info-cards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        if (services.isNotEmpty)
          _DetailSection(
            title: l10n.t('Services'),
            child: Wrap(
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
                    label: Text(_serviceLabel(service.key, l10n)),
                    backgroundColor: _sand,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),
        if (excursions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: l10n.t('Excursions'),
            child: Column(
              children: [
                for (
                  var excursionIndex = 0;
                  excursionIndex < excursions.length;
                  excursionIndex++
                ) ...[
                  _ExcursionSummaryCard(
                    excursion: excursions[excursionIndex],
                    formatter: formatter,
                  ),
                  if (excursionIndex < excursions.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
        if (detours.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: l10n.t('Detours'),
            child: Column(
              children: [
                for (
                  var detourIndex = 0;
                  detourIndex < detours.length;
                  detourIndex++
                ) ...[
                  _DetourSummaryCard(
                    detour: detours[detourIndex],
                    direction: direction,
                    formatter: formatter,
                  ),
                  if (detourIndex < detours.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ],
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
    return EurotrexChromeTheme.navigationBar(
      surfaceKey: const ValueKey('stage-detail-bottom-navigation'),
      contentKey: const ValueKey('stage-detail-bottom-navigation-size'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StageBottomAction(
            key: const Key('stage-detail-stages-shortcut'),
            icon: Icons.hiking_rounded,
            label: l10n.t('Back to stages'),
            visibleLabel: l10n.t('Stages'),
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
            visibleLabel: l10n.t('Lodging'),
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
            visibleLabel: l10n.t('GPS'),
            isActive: hasGpsLocation,
            isToggle: true,
            isPrimary: true,
            onTap: isLocating ? null : onGps,
          ),
          _StageBottomAction(
            key: const ValueKey('stage-detail-map'),
            icon: Icons.map_outlined,
            label: l10n.t('Show on map'),
            visibleLabel: l10n.t('Map'),
            onTap: onMap,
          ),
          _StageBottomAction(
            key: const ValueKey('stage-detail-elevation'),
            icon: Icons.landscape_outlined,
            label: l10n.t('Elevation'),
            visibleLabel: l10n.t('Elevation'),
            onTap: onElevation,
          ),
        ],
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

String _excursionRouteTypeLabel(ExcursionRouteType routeType) =>
    switch (routeType) {
      ExcursionRouteType.oneWay => 'One way',
      ExcursionRouteType.outAndBack => 'Out and back',
      ExcursionRouteType.loop => 'Loop',
    };

class _ExcursionSummaryCard extends StatelessWidget {
  const _ExcursionSummaryCard({
    required this.excursion,
    required this.formatter,
  });

  final TrailExcursion excursion;
  final MeasurementFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final walkingTime = Duration(
      minutes: excursion.estimatedWalkingTimeMinutes,
    );
    return Container(
      key: ValueKey('stage-excursion-${excursion.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _excursionCardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _filterBlueTeal, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                key: ValueKey('stage-excursion-icon-${excursion.id}'),
                width: 34,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _filterBlueTeal, width: 1.5),
                ),
                child: const Icon(
                  Icons.alt_route_rounded,
                  size: 19,
                  color: _filterBlueTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('Excursion').toUpperCase(),
                  style: const TextStyle(
                    color: _filterBlueTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.t(_excursionRouteTypeLabel(excursion.routeType)),
                style: const TextStyle(
                  color: _filterBlueTeal,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            excursion.displayName,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ExcursionMetric(
                icon: Icons.route_rounded,
                value: formatter.distance(excursion.totalDistanceKm),
                label: l10n.t('Distance'),
              ),
              _ExcursionMetric(
                icon: Icons.trending_up_rounded,
                value: formatter.altitude(excursion.elevationUpM),
                label: l10n.t('Ascent'),
              ),
              _ExcursionMetric(
                icon: Icons.schedule_rounded,
                value: _formatWalkingTime(walkingTime, l10n),
                label: l10n.t('Estimated walking time'),
              ),
              if (excursion.distanceFromTrailKm case final distance?)
                _ExcursionMetric(
                  icon: Icons.add_location_alt_outlined,
                  value: formatter.distance(distance),
                  label: l10n.t('Distance from trail'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExcursionMetric extends StatelessWidget {
  const _ExcursionMetric({
    required this.icon,
    required this.value,
    required this.label,
    this.color = _filterBlueTeal,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetourSummaryCard extends StatelessWidget {
  const _DetourSummaryCard({
    required this.detour,
    required this.direction,
    required this.formatter,
  });

  final TrailDetour detour;
  final TrailDirection direction;
  final MeasurementFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detourAscent = direction.isReversed
        ? detour.elevationDownM
        : detour.elevationUpM;
    final replacedAscent = direction.isReversed
        ? detour.replacedElevationDownM
        : detour.replacedElevationUpM;
    final walkingTime = estimateNaismithWalkingTime(
      distanceKm: detour.routeDistanceKm,
      ascentM: detourAscent,
    );
    final replacedWalkingTime = estimateNaismithWalkingTime(
      distanceKm: detour.replacedMainTrailDistanceKm,
      ascentM: replacedAscent,
    );
    final timeDifferenceMinutes =
        walkingTime.inMinutes - replacedWalkingTime.inMinutes;
    return Container(
      key: ValueKey('stage-detour-${detour.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _sand,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.fork_right_rounded,
                size: 21,
                color: _detourPurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detour.name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('Leaves and rejoins the E4.'),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.t('Alternative route'),
                style: const TextStyle(
                  color: _detourPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 9,
            children: [
              _ExcursionMetric(
                icon: Icons.fork_right_rounded,
                value: formatter.distance(detour.routeDistanceKm),
                label: l10n.t('Detour route'),
                color: _detourPurple,
              ),
              _ExcursionMetric(
                icon: Icons.route_outlined,
                value: formatter.distance(detour.replacedMainTrailDistanceKm),
                label: l10n.t('E4 section'),
                color: _detourPurple,
              ),
              _ExcursionMetric(
                icon: Icons.trending_up_rounded,
                value: formatter.altitude(detourAscent),
                label: l10n.t('Ascent'),
                color: _detourPurple,
              ),
              _ExcursionMetric(
                icon: Icons.schedule_rounded,
                value: _formatWalkingTime(walkingTime, l10n),
                label: l10n.t('Estimated walking time'),
                color: _detourPurple,
              ),
              _ExcursionMetric(
                icon: Icons.add_road_rounded,
                value: _signedDistance(formatter, detour.distanceDifferenceKm),
                label: l10n.t('Distance difference'),
                color: _detourPurple,
              ),
              _ExcursionMetric(
                icon: Icons.more_time_rounded,
                value: _signedWalkingTime(timeDifferenceMinutes, l10n),
                label: l10n.t('Time difference'),
                color: _detourPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _signedDistance(MeasurementFormatter formatter, double distanceKm) {
  final sign = distanceKm > 0
      ? '+'
      : distanceKm < 0
      ? '−'
      : '';
  return '$sign${formatter.distance(distanceKm.abs())}';
}

String _signedWalkingTime(int minutes, AppLocalizations l10n) {
  final sign = minutes > 0
      ? '+'
      : minutes < 0
      ? '−'
      : '';
  return '$sign${_formatWalkingTime(Duration(minutes: minutes.abs()), l10n)}';
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

class _StageElevationPreview extends StatelessWidget {
  const _StageElevationPreview({
    required this.routePoints,
    required this.startDistanceKm,
    required this.finishDistanceKm,
    required this.reversed,
    required this.formatter,
    this.gpsRouteDistanceKm,
    this.embedded = false,
    required this.onTap,
  });

  final List<RoutePoint> routePoints;
  final double? startDistanceKm;
  final double? finishDistanceKm;
  final bool reversed;
  final MeasurementFormatter formatter;
  final double? gpsRouteDistanceKm;
  final bool embedded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final points = _stageElevationPreviewPoints(
      routePoints: routePoints,
      startDistanceKm: startDistanceKm,
      finishDistanceKm: finishDistanceKm,
      reversed: reversed,
    );
    return Semantics(
      key: gpsRouteDistanceKm == null
          ? null
          : const Key('stage-elevation-user-location-enabled'),
      label: context.l10n.t('Elevation'),
      image: true,
      button: true,
      onTap: onTap,
      child: GestureDetector(
        key: const Key('stage-elevation-open'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: const Key('stage-elevation-preview'),
          height: 120,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: embedded
              ? const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(17),
                  ),
                )
              : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: EurotrexPalette.paleBlue),
                  boxShadow: [
                    BoxShadow(
                      color: EurotrexPalette.navy.withValues(alpha: 0.045),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
          child: points.length < 2
              ? Center(
                  child: Icon(
                    Icons.landscape_outlined,
                    size: 30,
                    color: EurotrexPalette.navy.withValues(alpha: 0.28),
                  ),
                )
              : IgnorePointer(
                  child: _StageElevationChart(
                    points: points,
                    formatter: formatter,
                    gpsRouteDistanceKm: gpsRouteDistanceKm,
                  ),
                ),
        ),
      ),
    );
  }
}

class _StageElevationChart extends StatelessWidget {
  const _StageElevationChart({
    required this.points,
    required this.formatter,
    this.gpsRouteDistanceKm,
  });

  final List<RoutePoint> points;
  final MeasurementFormatter formatter;
  final double? gpsRouteDistanceKm;

  @override
  Widget build(BuildContext context) {
    final firstDistance = points.first.distanceKm;
    final chartPoints = [
      for (final point in points)
        FlSpot((point.distanceKm - firstDistance).abs(), point.altitudeM),
    ];
    final lowest = points.reduce(
      (first, second) => first.altitudeM < second.altitudeM ? first : second,
    );
    final highest = points.reduce(
      (first, second) => first.altitudeM > second.altitudeM ? first : second,
    );
    final altitudeSpan = math.max(1.0, highest.altitudeM - lowest.altitudeM);
    final verticalPadding = math.max(8.0, altitudeSpan * 0.12);
    final minY = lowest.altitudeM - verticalPadding;
    final maxY = highest.altitudeM + verticalPadding;
    final maxX = math.max(0.01, chartPoints.last.x);
    final distanceInterval = _stageElevationAxisInterval(maxX / 4);
    final altitudeInterval = _stageElevationAxisInterval((maxY - minY) / 3);
    final gpsPoint = _stageElevationGpsPoint(
      points: points,
      routeDistanceKm: gpsRouteDistanceKm,
    );
    final gpsChartDistance = gpsPoint == null
        ? null
        : (gpsPoint.distanceKm - firstDistance).abs();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.vertical(),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(
              color: EurotrexPalette.navy.withValues(alpha: 0.22),
            ),
            bottom: BorderSide(
              color: EurotrexPalette.navy.withValues(alpha: 0.22),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: altitudeInterval,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, _) => Text(
                '${formatter.altitudeValue(value).round()} ${formatter.altitudeUnit}',
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: distanceInterval,
              minIncluded: true,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 4,
                fitInside: SideTitleFitInsideData.fromTitleMeta(
                  meta,
                  distanceFromEdge: 3,
                ),
                child: Text(
                  '${formatter.distanceValue(value).toStringAsFixed(value == 0 || maxX >= 10 ? 0 : 1)} ${formatter.distanceUnit}',
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          drawVerticalLine: true,
          horizontalInterval: altitudeInterval,
          verticalInterval: distanceInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: EurotrexPalette.navy.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: EurotrexPalette.navy.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (gpsChartDistance != null)
              VerticalLine(
                x: gpsChartDistance,
                color: _bookingBlue.withValues(alpha: 0.55),
                strokeWidth: 1.2,
                dashArray: const [3, 3],
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: chartPoints,
            isCurved: false,
            color: EurotrexPalette.navy,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: _stageElevationGradient(
                minAltitude: minY,
                maxAltitude: maxY,
              ),
            ),
          ),
          if (gpsPoint != null)
            LineChartBarData(
              spots: [
                FlSpot(
                  (gpsPoint.distanceKm - firstDistance).abs(),
                  gpsPoint.altitudeM,
                ),
              ],
              color: Colors.transparent,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 6.5,
                  color: _bookingBlue,
                  strokeWidth: 3,
                  strokeColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

double _stageElevationAxisInterval(double roughInterval) {
  if (!roughInterval.isFinite || roughInterval <= 0) return 1;
  final magnitude = math.pow(10, (math.log(roughInterval) / math.ln10).floor());
  final normalized = roughInterval / magnitude;
  final niceNormalized = normalized <= 1
      ? 1.0
      : normalized <= 2
      ? 2.0
      : normalized <= 5
      ? 5.0
      : 10.0;
  return niceNormalized * magnitude;
}

RoutePoint? _stageElevationGpsPoint({
  required List<RoutePoint> points,
  required double? routeDistanceKm,
}) {
  if (points.length < 2 ||
      routeDistanceKm == null ||
      !routeDistanceKm.isFinite) {
    return null;
  }
  final firstDistance = points.first.distanceKm;
  final lastDistance = points.last.distanceKm;
  final minimumDistance = math.min(firstDistance, lastDistance);
  final maximumDistance = math.max(firstDistance, lastDistance);
  if (routeDistanceKm < minimumDistance - 0.001 ||
      routeDistanceKm > maximumDistance + 0.001) {
    return null;
  }
  final ascendingPoints = firstDistance <= lastDistance
      ? points
      : points.reversed.toList(growable: false);
  return routePointAtDistance(
    ascendingPoints,
    routeDistanceKm.clamp(minimumDistance, maximumDistance),
  );
}

List<RoutePoint> _stageElevationPreviewPoints({
  required List<RoutePoint> routePoints,
  required double? startDistanceKm,
  required double? finishDistanceKm,
  required bool reversed,
}) {
  if (routePoints.length < 2 ||
      startDistanceKm == null ||
      finishDistanceKm == null ||
      (finishDistanceKm - startDistanceKm).abs() < 0.001) {
    return const [];
  }
  final section =
      elevationSection(
            smoothElevationProfile(routePoints),
            startDistanceKm: startDistanceKm,
            endDistanceKm: finishDistanceKm,
          )
          .where((point) {
            return point.distanceKm.isFinite && point.altitudeM.isFinite;
          })
          .toList(growable: false);
  if (section.length < 2) return const [];
  final ordered = reversed ? section.reversed.toList(growable: false) : section;
  return _downsampleStageElevation(ordered, 320);
}

List<RoutePoint> _downsampleStageElevation(
  List<RoutePoint> points,
  int maximumPoints,
) {
  if (points.length <= maximumPoints) return points;
  final scale = (points.length - 1) / (maximumPoints - 1);
  return [
    for (var index = 0; index < maximumPoints; index++)
      points[(index * scale).round().clamp(0, points.length - 1)],
  ];
}

LinearGradient _stageElevationGradient({
  required double minAltitude,
  required double maxAltitude,
}) {
  final effectiveMax = math.max(maxAltitude, minAltitude + 1);
  final altitudeRange = effectiveMax - minAltitude;
  const anchors = <({double altitude, Color color})>[
    (altitude: 0, color: Color(0x943E9ED0)),
    (altitude: 300, color: Color(0x9461AF57)),
    (altitude: 700, color: Color(0x94D8AA35)),
    (altitude: 1200, color: Color(0x94D66B35)),
  ];

  Color colorAt(double altitude) {
    if (altitude <= anchors.first.altitude) return anchors.first.color;
    for (var index = 1; index < anchors.length; index++) {
      final start = anchors[index - 1];
      final end = anchors[index];
      if (altitude <= end.altitude) {
        final progress =
            (altitude - start.altitude) / (end.altitude - start.altitude);
        return Color.lerp(start.color, end.color, progress)!;
      }
    }
    return anchors.last.color;
  }

  final colors = <Color>[colorAt(minAltitude)];
  final stops = <double>[0];
  for (final anchor in anchors) {
    if (anchor.altitude <= minAltitude || anchor.altitude >= effectiveMax) {
      continue;
    }
    colors.add(anchor.color);
    stops.add((anchor.altitude - minAltitude) / altitudeRange);
  }
  colors.add(colorAt(effectiveMax));
  stops.add(1);
  return LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: colors,
    stops: stops,
  );
}

class _StageMapPreview extends StatelessWidget {
  const _StageMapPreview({
    required this.routePoints,
    required this.startDistanceKm,
    required this.finishDistanceKm,
    required this.showRoute,
    required this.showFinishFlag,
    required this.lodgings,
    required this.excursions,
    required this.detours,
    required this.showUserLocation,
    required this.userLocation,
    this.embedded = false,
    required this.onTap,
    super.key,
  });

  final List<RoutePoint> routePoints;
  final double? startDistanceKm;
  final double? finishDistanceKm;
  final bool showRoute;
  final bool showFinishFlag;
  final List<Lodging> lodgings;
  final List<TrailExcursionRoute> excursions;
  final List<TrailDetourRoute> detours;
  final bool showUserLocation;
  final DeviceLocation? userLocation;
  final bool embedded;
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
        decoration: embedded
            ? const BoxDecoration(
                color: _mint,
                borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              )
            : BoxDecoration(
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
                  '${lodgings.map((lodging) => lodging.id).join(',')}-'
                  '${excursions.map((route) => '${route.excursion.id}:${route.points.length}').join(',')}-'
                  '${detours.map((route) => '${route.detour.id}:${route.points.length}').join(',')}',
                ),
                routePoints: preview.routePoints,
                startPoint: preview.startPoint,
                finishPoint: preview.finishPoint,
                showRoute: showRoute,
                showFinishFlag: showFinishFlag,
                lodgings: lodgings,
                excursions: excursions,
                detours: detours,
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
    required this.excursions,
    required this.detours,
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
  final List<TrailExcursionRoute> excursions;
  final List<TrailDetourRoute> detours;
  final bool showUserLocation;
  final DeviceLocation? userLocation;
  final VoidCallback onTap;

  @override
  State<_StageMapSnapshot> createState() => _StageMapSnapshotState();
}

class _StageMapSnapshotState extends State<_StageMapSnapshot> {
  static const _mapTapInteractionId = 'stage-preview-open-map';

  late final CameraOptions _initialCamera;
  late final ViewportState _initialViewport;
  MapboxMap? _map;
  Cancelable? _lodgingTapListener;
  final Map<String, String?> _lodgingStyleImages = {};
  bool _loadFailed = false;

  bool _isCurrentMap(MapboxMap map) => mounted && identical(_map, map);

  List<Position> get _viewportCoordinates => <Position>[
    if (widget.showRoute)
      for (final point in widget.routePoints) Position(point.lng, point.lat)
    else
      Position(widget.startPoint.lng, widget.startPoint.lat),
    for (final lodging in widget.lodgings)
      if (lodging.location case final location?)
        Position(location.longitude, location.latitude),
    for (final route in widget.excursions)
      for (final point in route.points) Position(point.lng, point.lat),
    for (final route in widget.detours)
      for (final point in route.points) Position(point.lng, point.lat),
    if (widget.userLocation case final DeviceLocation location)
      Position(location.longitude, location.latitude),
  ];

  @override
  void initState() {
    super.initState();
    final center = widget.showRoute
        ? widget.routePoints[widget.routePoints.length ~/ 2]
        : widget.startPoint;
    final centerPoint = Point(coordinates: Position(center.lng, center.lat));
    // Mapbox Flutter 2.26 applies `viewport` after Android creates the native
    // map. Supplying the same deprecated camera options as well is intentional:
    // those options are passed into MapInitOptions and prevent the native map's
    // default country from appearing for a frame before the viewport arrives.
    _initialCamera = CameraOptions(
      center: centerPoint,
      zoom: 13.5,
      bearing: 0,
      pitch: 0,
    );
    _initialViewport = CameraViewportState(
      center: centerPoint,
      zoom: 13.5,
      bearing: 0,
      pitch: 0,
    );
  }

  Future<void> _fitPreviewCamera(MapboxMap map) async {
    final coordinates = _viewportCoordinates;
    if (coordinates.length == 1) {
      await map.setCamera(
        CameraOptions(
          center: Point(coordinates: coordinates.single),
          zoom: 13.5,
          bearing: 0,
          pitch: 0,
        ),
      );
      return;
    }

    var minLat = coordinates.first.lat.toDouble();
    var maxLat = minLat;
    var minLng = coordinates.first.lng.toDouble();
    var maxLng = minLng;
    for (final coordinate in coordinates.skip(1)) {
      final lat = coordinate.lat.toDouble();
      final lng = coordinate.lng.toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    final stageDistanceKm = widget.showRoute
        ? (widget.finishPoint.distanceKm - widget.startPoint.distanceKm).abs()
        : 0.0;
    final padding = stageDistanceKm > 6
        ? MbxEdgeInsets(top: 50, left: 60, bottom: 64, right: 54)
        : MbxEdgeInsets(top: 44, left: 54, bottom: 54, right: 48);
    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      padding,
      0,
      0,
      16,
      null,
    );
    await map.setCamera(camera);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    try {
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
      if (!_isCurrentMap(map)) return;
      await map.compass.updateSettings(CompassSettings(enabled: false));
      await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      if (!_isCurrentMap(map)) return;
      if (widget.showUserLocation) {
        await map.location.updateSettings(
          LocationComponentSettings(
            enabled: true,
            puckBearingEnabled: true,
            pulsingEnabled: true,
            showAccuracyRing: true,
          ),
        );
        if (!_isCurrentMap(map)) return;
      }

      if (widget.showRoute && widget.routePoints.length > 1) {
        final routeManager = await map.annotations
            .createPolylineAnnotationManager();
        if (!_isCurrentMap(map)) return;
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
        if (!_isCurrentMap(map)) return;
      }

      if (widget.excursions.isNotEmpty) {
        final excursionManager = await map.annotations
            .createPolylineAnnotationManager();
        if (!_isCurrentMap(map)) return;
        for (final route in widget.excursions) {
          if (route.points.length < 2) continue;
          await excursionManager.create(
            PolylineAnnotationOptions(
              geometry: LineString(
                coordinates: [
                  for (final point in route.points)
                    Position(point.lng, point.lat),
                ],
              ),
              lineColor: _excursionMapLightBlue.toARGB32(),
              lineWidth: 5,
              lineBorderColor: Colors.white.toARGB32(),
              lineBorderWidth: 1.5,
              lineOpacity: 0.95,
            ),
          );
          if (!_isCurrentMap(map)) return;
        }
      }

      if (widget.detours.isNotEmpty) {
        final detourManager = await map.annotations
            .createPolylineAnnotationManager();
        if (!_isCurrentMap(map)) return;
        for (final route in widget.detours) {
          if (route.points.length < 2) continue;
          await detourManager.create(
            PolylineAnnotationOptions(
              geometry: LineString(
                coordinates: [
                  for (final point in route.points)
                    Position(point.lng, point.lat),
                ],
              ),
              lineColor: _detourPurple.toARGB32(),
              lineWidth: 5,
              lineBorderColor: Colors.white.toARGB32(),
              lineBorderWidth: 1.5,
              lineOpacity: 0.95,
            ),
          );
          if (!_isCurrentMap(map)) return;
        }
      }

      final flags = await Future.wait([
        mapFlagMarkerImage(_green),
        mapFlagMarkerImage(_red),
      ]);
      if (!_isCurrentMap(map)) return;
      final markerManager = await map.annotations
          .createPointAnnotationManager();
      if (!_isCurrentMap(map)) return;
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
    } on MissingPluginException {
      // Android may finish an in-flight annotation call after this preview's
      // platform view has been disposed. Navigation remains valid and a newly
      // opened preview creates its own managers.
      if (_isCurrentMap(map)) rethrow;
    } on PlatformException {
      // Native map teardown can race with the asynchronous preview setup.
      if (_isCurrentMap(map)) rethrow;
    }
  }

  Future<void> _onMapLoaded(MapLoadedEventData _) async {
    final map = _map;
    if (map == null || !_isCurrentMap(map)) return;
    try {
      await _loadMapContent(map);
    } on MissingPluginException {
      if (_isCurrentMap(map)) rethrow;
    } on PlatformException {
      if (_isCurrentMap(map)) rethrow;
    }
  }

  Future<void> _loadMapContent(MapboxMap map) async {
    // Camera fitting is visual polish; a native camera error must not prevent
    // the route, accommodation, excursion, and detour layers from loading.
    try {
      await _fitPreviewCamera(map);
    } catch (_) {
      // The deterministic initial camera already points at this stage, so it
      // remains a safe cross-platform fallback if fitting is unavailable.
    }
    if (!_isCurrentMap(map)) return;
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
      if (!_isCurrentMap(map)) return;
    }
    final manager = await map.annotations.createPointAnnotationManager();
    if (!_isCurrentMap(map)) return;
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
    _map = null;
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
      // ignore: deprecated_member_use
      cameraOptions: _initialCamera,
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
  const _ServiceFilterSheet({
    required this.selected,
    required this.stages,
    required this.scrollController,
  });

  final Set<String> selected;
  final List<TrailStage> stages;
  final ScrollController scrollController;

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
    return Theme(
      data: EurotrexPalette.controlsTheme(Theme.of(context)),
      child: SafeArea(
        child: SingleChildScrollView(
          controller: widget.scrollController,
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
              _StageFilterPanel(
                key: const ValueKey('stage-filter-name-panel'),
                icon: Icons.search_rounded,
                title: l10n.t('Stage name'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const ValueKey('stage-name-filter'),
                      controller: stageSearchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.t('Search by stage name or number'),
                        prefixIcon: const Icon(Icons.search_rounded),
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
                              key: ValueKey(
                                'selected-stage-filter-${stage.id}',
                              ),
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
                            color: EurotrexPalette.paleBlue.withValues(
                              alpha: 0.32,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: EurotrexPalette.paleBlue),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: stageSuggestions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final stage = stageSuggestions[index];
                              return ListTile(
                                key: ValueKey(
                                  'stage-name-suggestion-${stage.id}',
                                ),
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _StageFilterPanel(
                key: const ValueKey('stage-filter-services-panel'),
                icon: Icons.category_outlined,
                title: l10n.t('Services'),
                child: Wrap(
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
                        label: Text(_serviceLabel(service, l10n)),
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
              ),
              const SizedBox(height: 12),
              _StageFilterPanel(
                key: const ValueKey('stage-filter-poi-panel'),
                icon: Icons.place_outlined,
                title: l10n.t('Points of Interest'),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
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
                      selected: selected.contains(
                        _naturalLandmarkPointFilterKey,
                      ),
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
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('clear-service-filter-selection'),
                      onPressed: () =>
                          Navigator.of(context).pop(const <String>{}),
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                      label: Text(l10n.t('Clear')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('apply-service-filters'),
                      onPressed: () => Navigator.of(context).pop(selected),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(l10n.t('Apply')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageFilterPanel extends StatelessWidget {
  const _StageFilterPanel({
    required this.icon,
    required this.title,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EurotrexPalette.paleBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: EurotrexPalette.paleBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: EurotrexPalette.navy, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: EurotrexPalette.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
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
  const _EmptyState({this.downloadFailed = false});

  final bool downloadFailed;

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
              l10n.t(
                downloadFailed
                    ? 'Could not download the trail'
                    : 'Take the trail offline',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t(
                downloadFailed
                    ? 'Check your connection and try again.'
                    : 'Download Cyprus E4 to browse its stages without a connection.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  _syncOfflineTrailData(ref, isInitialDownload: true),
              icon: const Icon(Icons.download_rounded),
              label: Text(
                l10n.t(downloadFailed ? 'Try again' : 'Download trail'),
              ),
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

const _stageServiceDisplayOrder = <String>[
  'lodging',
  'drinkableWater',
  'atm',
  'tent',
  'toilets',
  'busStop',
  'grocery',
  'food',
  'nonDrinkableWater',
  'medical',
  'pharmacy',
];

List<MapEntry<String, bool>> _activeStageServices(Map<String, bool> services) {
  final rank = <String, int>{
    for (var index = 0; index < _stageServiceDisplayOrder.length; index++)
      _stageServiceDisplayOrder[index]: index,
  };
  final active = services.entries.where((entry) => entry.value).toList();
  active.sort((left, right) {
    final leftRank = rank[left.key] ?? _stageServiceDisplayOrder.length;
    final rightRank = rank[right.key] ?? _stageServiceDisplayOrder.length;
    final byRank = leftRank.compareTo(rightRank);
    return byRank != 0 ? byRank : left.key.compareTo(right.key);
  });
  return active;
}

String _serviceLabel(String value, AppLocalizations l10n) {
  return switch (value) {
    'lodging' => l10n.t('Lodging'),
    'tent' => l10n.t('Camping'),
    'food' => l10n.t('Food'),
    'grocery' => l10n.t('Groceries'),
    'drinkableWater' => l10n.t('Drinking water'),
    'nonDrinkableWater' => l10n.t('Non-drinking water'),
    'toilets' => l10n.t('Toilets'),
    'medical' => l10n.t('Medical'),
    'pharmacy' => l10n.t('Pharmacy'),
    'atm' => l10n.t('ATM'),
    'busStop' => l10n.t('Bus'),
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
