import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/links/external_url_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../accommodation/domain/lodging.dart';
import '../../accommodation/presentation/accommodation_controller.dart';
import '../../accommodation/presentation/lodging_type_icon.dart';
import '../../elevation/domain/route_point.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../stages/domain/stage.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../stages/presentation/stages_screen.dart';
import '../../trail/domain/trail_direction.dart';
import '../../trail/presentation/trail_direction_controller.dart';
import '../domain/offline_map_state.dart';
import 'offline_map_controller.dart';

const mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _red = Color(0xFFD14B45);
const _sand = Color(0xFFF4F2EC);
const _yellow = Color(0xFFF2C94C);
const _routeBlue = Color(0xFF1565C0);
const _accommodationBlue = Color(0xFF0288D1);
const _markerEntranceSteps = 10;
const _markerEntranceFrame = Duration(milliseconds: 24);
const _stageDropDistance = 20.0;
const _lodgingDropDistance = 28.0;

class MapScreen extends ConsumerWidget {
  const MapScreen({
    this.initialStageIndex,
    this.initialLodging,
    this.locationStageId,
    this.accessToken = mapboxAccessToken,
    super.key,
  }) : assert(initialStageIndex == null || initialLodging == null);

  final int? initialStageIndex;
  final Lodging? initialLodging;
  final String? locationStageId;
  final String accessToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elevation = ref.watch(elevationProvider);
    final stagesValue = ref.watch(stagesProvider);
    final direction = ref.watch(trailDirectionProvider);
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final l10n = context.l10n;
    final sourceStages = stagesValue.hasValue
        ? stagesValue.requireValue
        : const <TrailStage>[];
    final stages = direction.isReversed
        ? sourceStages.reversed.toList(growable: false)
        : sourceStages;
    final routePoints = elevation.hasValue
        ? elevation.requireValue
        : const <RoutePoint>[];
    final offlineMap = accessToken.isEmpty
        ? null
        : ref.watch(offlineMapProvider);

    return Scaffold(
      backgroundColor: _sand,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        toolbarHeight: 76,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Trail map'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              key: const ValueKey('map-route-direction'),
              'CYPRUS E4 · ${l10n.routeDirection(direction.isReversed ? l10n.larnakaAirport : l10n.pafosAirport, direction.isReversed ? l10n.pafosAirport : l10n.larnakaAirport).toUpperCase()}',
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                height: 1.2,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          if (offlineMap != null)
            _OfflineMapAppBarButton(
              state: offlineMap,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _OfflineMapSheet(points: routePoints),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: accessToken.isEmpty
          ? const _MapboxSetupState()
          : elevation.when(
              skipLoadingOnRefresh: true,
              data: (points) => points.isEmpty
                  ? _EmptyRouteState(
                      onRetry: () =>
                          ref.read(elevationProvider.notifier).refresh(),
                    )
                  : _RouteMap(
                      points: points,
                      stages: stages,
                      direction: direction,
                      formatter: formatter,
                      initialStageIndex: initialStageIndex,
                      initialLodging: initialLodging,
                      locationStageId: locationStageId,
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _EmptyRouteState(
                onRetry: () => ref.read(elevationProvider.notifier).refresh(),
              ),
            ),
    );
  }
}

class _OfflineMapAppBarButton extends StatelessWidget {
  const _OfflineMapAppBarButton({required this.state, required this.onPressed});

  final AsyncValue<OfflineMapState> state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = state.value;
    final tooltip = switch (value?.phase) {
      OfflineMapPhase.ready => l10n.t('Offline map downloaded'),
      OfflineMapPhase.downloading => l10n.t('Downloading offline map'),
      OfflineMapPhase.failed when value?.failure == OfflineMapFailure.removal =>
        l10n.t('Offline map removal failed'),
      OfflineMapPhase.failed => l10n.t('Offline map download failed'),
      _ when state.isLoading => l10n.t('Checking offline map…'),
      _ => l10n.t('Offline map not downloaded'),
    };
    final icon = switch (value?.phase) {
      OfflineMapPhase.ready => const Icon(Icons.offline_pin_rounded),
      OfflineMapPhase.downloading => SizedBox.square(
        dimension: 21,
        child: CircularProgressIndicator(
          value: value?.progress,
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      ),
      OfflineMapPhase.failed => const Icon(Icons.cloud_off_rounded),
      _ when state.isLoading => const SizedBox.square(
        dimension: 21,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      ),
      _ => const Icon(Icons.download_for_offline_outlined),
    };
    return IconButton(
      key: const ValueKey('offline-map-button'),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
    );
  }
}

class _OfflineMapSheet extends ConsumerWidget {
  const _OfflineMapSheet({required this.points});

  final List<RoutePoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(offlineMapProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: asyncState.when(
          loading: () => const SizedBox(
            height: 210,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _OfflineMapSheetError(
            message: context.l10n.t('Offline map status could not be read.'),
            onRetry: () => ref.read(offlineMapProvider.notifier).refresh(),
          ),
          data: (state) => _OfflineMapSheetContent(
            state: state,
            canDownload: points.isNotEmpty,
            onDownload: () =>
                ref.read(offlineMapProvider.notifier).download(points),
            onRefresh: () => ref.read(offlineMapProvider.notifier).refresh(),
            onDelete: () => _confirmOfflineMapDelete(context, ref),
          ),
        ),
      ),
    );
  }
}

class _OfflineMapSheetContent extends StatelessWidget {
  const _OfflineMapSheetContent({
    required this.state,
    required this.canDownload,
    required this.onDownload,
    required this.onRefresh,
    required this.onDelete,
  });

  final OfflineMapState state;
  final bool canDownload;
  final VoidCallback onDownload;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = state.phase == OfflineMapPhase.ready;
    final downloading = state.phase == OfflineMapPhase.downloading;
    final failed = state.phase == OfflineMapPhase.failed;
    final removalFailed = failed && state.failure == OfflineMapFailure.removal;
    final title = ready
        ? l10n.t('Offline map available')
        : downloading
        ? l10n.t('Downloading offline map')
        : removalFailed
        ? l10n.t('Offline map removal failed')
        : failed
        ? l10n.t('Offline map download failed')
        : l10n.t('Download offline map');
    final icon = ready
        ? Icons.offline_pin_rounded
        : downloading
        ? Icons.downloading_rounded
        : failed
        ? Icons.cloud_off_rounded
        : Icons.download_for_offline_outlined;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: ready ? _green : _ink),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          ready
              ? l10n.t('The detailed Cyprus E4 map is stored on this device.')
              : failed
              ? l10n.t(state.message ?? 'Please try the download again.')
              : l10n.t(
                  'Downloads a detailed corridor around the complete Cyprus E4 for use without a connection.',
                ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (downloading) ...[
          const SizedBox(height: 20),
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(state.progress * 100).round()}%'),
              Text(formatOfflineBytes(state.completedBytes)),
            ],
          ),
        ] else if (ready && state.completedBytes > 0) ...[
          const SizedBox(height: 12),
          Text(
            formatOfflineBytes(state.completedBytes),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 22),
        if (ready)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('delete-offline-map'),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
              ),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l10n.t('Remove offline map')),
            ),
          )
        else if (removalFailed)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('refresh-offline-map'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.t('Check again')),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('download-offline-map'),
              onPressed: downloading || !canDownload ? null : onDownload,
              icon: downloading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                l10n.t(failed ? 'Try again' : 'Download offline map'),
              ),
            ),
          ),
        if (!canDownload && !ready) ...[
          const SizedBox(height: 10),
          Text(
            l10n.t('Download the route data first.'),
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _OfflineMapSheetError extends StatelessWidget {
  const _OfflineMapSheetError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: _ink),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.l10n.t('Try again')),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmOfflineMapDelete(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.t('Remove offline map?')),
      content: Text(
        context.l10n.t(
          'The route, stages and elevation will remain offline. Only the offline map will be removed.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.t('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.l10n.t('Remove')),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(offlineMapProvider.notifier).delete();
  }
}

class _RouteMap extends ConsumerStatefulWidget {
  const _RouteMap({
    required this.points,
    required this.stages,
    required this.direction,
    required this.formatter,
    required this.initialStageIndex,
    required this.initialLodging,
    required this.locationStageId,
  });

  final List<RoutePoint> points;
  final List<TrailStage> stages;
  final TrailDirection direction;
  final MeasurementFormatter formatter;
  final int? initialStageIndex;
  final Lodging? initialLodging;
  final String? locationStageId;

  @override
  ConsumerState<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<_RouteMap> {
  late final CameraViewportState _initialViewport;
  MapboxMap? _map;
  CircleAnnotationManager? _stageManager;
  PointAnnotationManager? _stageLabelManager;
  Cancelable? _stageTapListener;
  final Map<String, int> _stageIndexByAnnotation = {};
  PointAnnotationManager? _lodgingManager;
  Cancelable? _lodgingTapListener;
  final Map<String, int> _lodgingIndexByAnnotation = {};
  final Map<String, String?> _lodgingStyleImages = {};
  List<Lodging> _mappedLodgings = const [];
  int? _selectedStageIndex;
  Point? _selectedStagePoint;
  ScreenCoordinate? _selectedStageScreenPosition;
  int? _selectedLodgingIndex;
  Point? _selectedLodgingPoint;
  ScreenCoordinate? _selectedLodgingScreenPosition;
  bool _locating = false;
  bool _stagesVisible = false;
  bool _stagesExplicitlyHidden = false;
  bool _changingStageVisibility = false;
  bool _lodgingsVisible = false;
  bool _changingLodgingVisibility = false;
  bool _lodgingsLoaded = false;
  bool _openingLodgingBooking = false;
  bool _initialCameraApplied = false;
  Size? _lastMapSize;
  int _stageAnimationGeneration = 0;
  int _lodgingAnimationGeneration = 0;

  @override
  void initState() {
    super.initState();
    final first = widget.points.first;
    final last = widget.points.last;
    _initialViewport = CameraViewportState(
      center: Point(
        coordinates: Position(
          (first.lng + last.lng) / 2,
          (first.lat + last.lat) / 2,
        ),
      ),
      zoom: 7,
    );
  }

  @override
  void dispose() {
    _stageAnimationGeneration++;
    _lodgingAnimationGeneration++;
    _stageTapListener?.cancel();
    _lodgingTapListener?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await _drawRoute(map);
    await _drawStages(map, animate: true);
  }

  Future<void> _onMapLoaded(MapLoadedEventData _) async {
    if (_initialCameraApplied || !mounted) return;
    _initialCameraApplied = true;
    if (widget.locationStageId != null) {
      try {
        await _enableLocationPuck();
      } catch (_) {
        // Keep the selected stage usable if location rendering is unavailable.
      }
    }
    final initialLodging = widget.initialLodging;
    if (initialLodging?.location != null) {
      await _showInitialLodging(initialLodging!);
      return;
    }
    final initialIndex = widget.initialStageIndex;
    if (initialIndex != null &&
        initialIndex >= 0 &&
        initialIndex < widget.stages.length) {
      await _focusStage(initialIndex);
      await _selectStage(initialIndex);
    } else {
      await _fitRoute();
    }
  }

  Future<void> _showInitialLodging(Lodging lodging) async {
    final map = _map;
    final location = lodging.location;
    if (map == null || location == null) return;
    final point = Point(
      coordinates: Position(location.longitude, location.latitude),
    );
    setState(() {
      _mappedLodgings = [lodging];
      _lodgingsVisible = true;
      _selectedLodgingIndex = 0;
      _selectedLodgingPoint = point;
      _selectedLodgingScreenPosition = null;
      _selectedStageIndex = null;
      _selectedStagePoint = null;
      _selectedStageScreenPosition = null;
    });
    await _drawLodgings(map, animate: true);
    await map.flyTo(
      CameraOptions(center: point, zoom: 15, bearing: 0),
      MapAnimationOptions(duration: 700, startDelay: 0),
    );
    await _updateSelectedLodgingPosition();
    await _hydrateInitialLodgingLayer(lodging);
  }

  Future<void> _hydrateInitialLodgingLayer(Lodging initialLodging) async {
    List<Lodging> lodgings;
    try {
      lodgings = await ref.read(lodgingsForTrailProvider.future);
    } catch (_) {
      if (mounted) ref.invalidate(lodgingsForTrailProvider);
      return;
    }
    if (!mounted) return;

    final lodgingsById = <String, Lodging>{
      for (final lodging in lodgings)
        if (lodging.location != null) lodging.id: lodging,
    };
    lodgingsById.putIfAbsent(initialLodging.id, () => initialLodging);
    final mappedLodgings = lodgingsById.values.toList(growable: false);
    final selectedId = switch (_selectedLodgingIndex) {
      final index? when index >= 0 && index < _mappedLodgings.length =>
        _mappedLodgings[index].id,
      _ => null,
    };
    final selectedIndex = selectedId == null
        ? -1
        : mappedLodgings.indexWhere((lodging) => lodging.id == selectedId);
    final selectedLocation = selectedIndex < 0
        ? null
        : mappedLodgings[selectedIndex].location;

    setState(() {
      _mappedLodgings = mappedLodgings;
      _lodgingsLoaded = true;
      _selectedLodgingIndex = selectedIndex < 0 ? null : selectedIndex;
      _selectedLodgingPoint = selectedLocation == null
          ? null
          : Point(
              coordinates: Position(
                selectedLocation.longitude,
                selectedLocation.latitude,
              ),
            );
      if (selectedIndex < 0) {
        _selectedLodgingScreenPosition = null;
      }
    });
    final map = _map;
    if (_lodgingsVisible && map != null) {
      await _drawLodgings(map);
      await _updateSelectedLodgingPosition();
    }
  }

  Future<void> _drawRoute(MapboxMap map) async {
    final manager = await map.annotations.createPolylineAnnotationManager();
    await manager.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: [
            for (final point in widget.points) Position(point.lng, point.lat),
          ],
        ),
        lineColor: _routeBlue.toARGB32(),
        lineWidth: 5,
        lineBorderColor: Colors.white.toARGB32(),
        lineBorderWidth: 1.5,
        lineOpacity: 0.95,
      ),
    );
  }

  Future<void> _drawStages(MapboxMap map, {bool animate = false}) async {
    final l10n = context.l10n;
    final animationGeneration = ++_stageAnimationGeneration;
    final shouldAnimate = animate && !MediaQuery.disableAnimationsOf(context);
    _stageTapListener?.cancel();
    _stageTapListener = null;
    final previousManager = _stageManager;
    if (previousManager != null) {
      await map.annotations.removeAnnotationManager(previousManager);
    }
    final previousLabelManager = _stageLabelManager;
    if (previousLabelManager != null) {
      await map.annotations.removeAnnotationManager(previousLabelManager);
    }
    _stageManager = null;
    _stageLabelManager = null;
    _stageIndexByAnnotation.clear();

    final locatedStages = <({int index, TrailStage stage, RoutePoint point})>[];
    for (var index = 0; index < widget.stages.length; index++) {
      final stage = widget.stages[index];
      final distance = stage.accumulatedDistanceKm;
      if (distance == null) continue;
      locatedStages.add((
        index: index,
        stage: stage,
        point: routePointNearestDistance(widget.points, distance),
      ));
    }
    if (locatedStages.isEmpty) return;
    final startStage = locatedStages.reduce((a, b) {
      final aDistance = a.stage.accumulatedDistanceKm!;
      final bDistance = b.stage.accumulatedDistanceKm!;
      return widget.direction.isReversed
          ? (aDistance > bDistance ? a : b)
          : (aDistance < bDistance ? a : b);
    });
    final endStage = locatedStages.reduce((a, b) {
      final aDistance = a.stage.accumulatedDistanceKm!;
      final bDistance = b.stage.accumulatedDistanceKm!;
      return widget.direction.isReversed
          ? (aDistance < bDistance ? a : b)
          : (aDistance > bDistance ? a : b);
    });
    final displayedStages = _stagesVisible
        ? locatedStages
        : _stagesExplicitlyHidden
        ? const <({int index, TrailStage stage, RoutePoint point})>[]
        : locatedStages
              .where(
                (item) =>
                    item.index == startStage.index ||
                    item.index == endStage.index ||
                    item.index == widget.initialStageIndex,
              )
              .toList(growable: false);
    if (displayedStages.isEmpty) return;

    final manager = await map.annotations.createCircleAnnotationManager();
    _stageManager = manager;
    if (shouldAnimate) {
      await Future.wait([
        manager.setCircleTranslateAnchor(CircleTranslateAnchor.VIEWPORT),
        manager.setCircleTranslate([0, -_stageDropDistance]),
        manager.setCircleOpacity(0),
        manager.setCircleStrokeOpacity(0),
      ]);
    }
    final annotations = await manager.createMulti([
      for (final item in displayedStages)
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.point.lng, item.point.lat),
          ),
          circleColor: item.index == _selectedStageIndex
              ? _routeBlue.toARGB32()
              : item.index == startStage.index
              ? _green.toARGB32()
              : item.index == endStage.index
              ? _red.toARGB32()
              : _yellow.toARGB32(),
          circleRadius: item.index == _selectedStageIndex
              ? 11
              : item.index == startStage.index || item.index == endStage.index
              ? 9
              : 8,
          circleStrokeColor: item.index == _selectedStageIndex
              ? Colors.white.toARGB32()
              : _ink.toARGB32(),
          circleStrokeWidth: item.index == _selectedStageIndex ? 3 : 1.5,
          customData: {'stageIndex': item.index, 'name': item.stage.name},
        ),
    ]);

    final labelManager = await map.annotations.createPointAnnotationManager();
    _stageLabelManager = labelManager;
    await labelManager.setTextAllowOverlap(true);
    await labelManager.setTextIgnorePlacement(true);
    if (shouldAnimate) {
      await Future.wait([
        labelManager.setTextTranslateAnchor(TextTranslateAnchor.VIEWPORT),
        labelManager.setTextTranslate([0, -_stageDropDistance]),
        labelManager.setTextOpacity(0),
      ]);
    }
    await labelManager.createMulti([
      for (final item in displayedStages)
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.point.lng, item.point.lat),
          ),
          textField: item.index == startStage.index
              ? l10n.t('Start').toUpperCase()
              : item.index == endStage.index
              ? l10n.t('Finish').toUpperCase()
              : '${item.stage.sequence}',
          textAnchor:
              item.index == startStage.index || item.index == endStage.index
              ? TextAnchor.TOP
              : TextAnchor.CENTER,
          textOffset:
              item.index == startStage.index || item.index == endStage.index
              ? [0, 1.1]
              : [0, 0],
          textSize:
              item.index == startStage.index || item.index == endStage.index
              ? 11
              : 10,
          textColor:
              item.index == startStage.index || item.index == endStage.index
              ? _ink.toARGB32()
              : item.index == _selectedStageIndex
              ? Colors.white.toARGB32()
              : _ink.toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth:
              item.index == startStage.index || item.index == endStage.index
              ? 1.5
              : 0,
        ),
    ]);

    for (var index = 0; index < annotations.length; index++) {
      final annotation = annotations[index];
      if (annotation != null) {
        _stageIndexByAnnotation[annotation.id] = displayedStages[index].index;
      }
    }
    _stageTapListener = manager.tapEvents(
      onTap: (annotation) {
        final stageIndex = _stageIndexByAnnotation[annotation.id];
        if (stageIndex == null || !mounted) return;
        _selectStage(stageIndex);
      },
    );
    if (shouldAnimate) {
      await _animateStageEntrance(manager, labelManager, animationGeneration);
    }
  }

  Future<void> _removeLodgingAnnotations(MapboxMap map) async {
    _lodgingAnimationGeneration++;
    _lodgingTapListener?.cancel();
    _lodgingTapListener = null;
    final previousManager = _lodgingManager;
    _lodgingManager = null;
    _lodgingIndexByAnnotation.clear();
    if (previousManager != null) {
      await map.annotations.removeAnnotationManager(previousManager);
    }
  }

  Future<void> _drawLodgings(MapboxMap map, {bool animate = false}) async {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    await _removeLodgingAnnotations(map);
    if (!_lodgingsVisible || _mappedLodgings.isEmpty) return;
    final animationGeneration = _lodgingAnimationGeneration;
    final shouldAnimate = animate && !animationsDisabled;

    final makiIconNames = {
      for (final lodging in _mappedLodgings) lodgingMakiIconName(lodging.type),
    };
    final styleImages = <String, String?>{};
    for (final iconName in makiIconNames) {
      styleImages[iconName] = await _resolveLodgingStyleImage(map, iconName);
    }

    final manager = await map.annotations.createPointAnnotationManager();
    _lodgingManager = manager;
    await manager.setIconAllowOverlap(true);
    await manager.setIconIgnorePlacement(true);
    await manager.setTextAllowOverlap(true);
    await manager.setTextIgnorePlacement(true);
    if (shouldAnimate) {
      await Future.wait([
        manager.setIconTranslateAnchor(IconTranslateAnchor.VIEWPORT),
        manager.setIconTranslate([0, -_lodgingDropDistance]),
        manager.setIconOpacity(0),
        manager.setTextTranslateAnchor(TextTranslateAnchor.VIEWPORT),
        manager.setTextTranslate([0, -_lodgingDropDistance]),
        manager.setTextOpacity(0),
      ]);
    }
    final annotations = await manager.createMulti([
      for (var index = 0; index < _mappedLodgings.length; index++) ...[
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _mappedLodgings[index].location!.longitude,
              _mappedLodgings[index].location!.latitude,
            ),
          ),
          iconImage:
              styleImages[lodgingMakiIconName(_mappedLodgings[index].type)],
          iconSize: index == _selectedLodgingIndex ? 1.65 : 1.4,
          iconColor: _accommodationBlue.toARGB32(),
          iconHaloColor: Colors.white.toARGB32(),
          iconHaloWidth: index == _selectedLodgingIndex ? 3.5 : 2,
          iconHaloBlur: 0.5,
          textField:
              styleImages[lodgingMakiIconName(_mappedLodgings[index].type)] ==
                  null
              ? '●'
              : null,
          textSize: index == _selectedLodgingIndex ? 25 : 21,
          textColor: _accommodationBlue.toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: index == _selectedLodgingIndex ? 3.5 : 2,
          symbolSortKey: index == _selectedLodgingIndex ? 2 : 1,
          customData: {
            'lodgingIndex': index,
            'name': _mappedLodgings[index].name ?? '',
            'maki': lodgingMakiIconName(_mappedLodgings[index].type),
          },
        ),
      ],
    ]);

    for (var index = 0; index < annotations.length; index++) {
      final annotation = annotations[index];
      if (annotation != null) {
        _lodgingIndexByAnnotation[annotation.id] = index;
      }
    }
    _lodgingTapListener = manager.tapEvents(
      onTap: (annotation) {
        final lodgingIndex = _lodgingIndexByAnnotation[annotation.id];
        if (lodgingIndex == null || !mounted) return;
        if (lodgingIndex == _selectedLodgingIndex) {
          _openSelectedLodgingBooking();
          return;
        }
        _selectLodging(lodgingIndex);
      },
    );
    if (shouldAnimate) {
      await _animateLodgingEntrance(manager, animationGeneration);
    }
  }

  Future<void> _animateStageEntrance(
    CircleAnnotationManager manager,
    PointAnnotationManager labelManager,
    int generation,
  ) async {
    for (var step = 1; step <= _markerEntranceSteps; step++) {
      if (!mounted ||
          generation != _stageAnimationGeneration ||
          _stageManager != manager ||
          _stageLabelManager != labelManager) {
        return;
      }
      final progress = step / _markerEntranceSteps;
      final opacity = Curves.easeOut.transform(progress);
      final drop = Curves.easeOutBack.transform(progress);
      final offset = -_stageDropDistance * (1 - drop);
      try {
        await Future.wait([
          manager.setCircleTranslate([0, offset]),
          manager.setCircleOpacity(opacity),
          manager.setCircleStrokeOpacity(opacity),
          labelManager.setTextTranslate([0, offset]),
          labelManager.setTextOpacity(opacity),
        ]);
      } catch (_) {
        return;
      }
      if (step < _markerEntranceSteps) {
        await Future<void>.delayed(_markerEntranceFrame);
      }
    }
  }

  Future<void> _animateLodgingEntrance(
    PointAnnotationManager manager,
    int generation,
  ) async {
    for (var step = 1; step <= _markerEntranceSteps; step++) {
      if (!mounted ||
          generation != _lodgingAnimationGeneration ||
          _lodgingManager != manager) {
        return;
      }
      final progress = step / _markerEntranceSteps;
      final opacity = Curves.easeOut.transform(progress);
      final drop = Curves.easeOutBack.transform(progress);
      final offset = -_lodgingDropDistance * (1 - drop);
      try {
        await Future.wait([
          manager.setIconTranslate([0, offset]),
          manager.setIconOpacity(opacity),
          manager.setTextTranslate([0, offset]),
          manager.setTextOpacity(opacity),
        ]);
      } catch (_) {
        return;
      }
      if (step < _markerEntranceSteps) {
        await Future<void>.delayed(_markerEntranceFrame);
      }
    }
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
    final fallback = makiIconName == 'lodging'
        ? null
        : await _resolveLodgingStyleImage(map, 'lodging');
    _lodgingStyleImages[makiIconName] = fallback;
    return fallback;
  }

  Future<void> _toggleLodgings() async {
    final map = _map;
    if (map == null || _changingLodgingVisibility) return;
    setState(() => _changingLodgingVisibility = true);
    try {
      if (_lodgingsVisible) {
        setState(() {
          _lodgingsVisible = false;
          _selectedLodgingIndex = null;
          _selectedLodgingPoint = null;
          _selectedLodgingScreenPosition = null;
        });
        await _removeLodgingAnnotations(map);
        return;
      }

      if (!_lodgingsLoaded) {
        final lodgings = await ref.read(lodgingsForTrailProvider.future);
        if (!mounted) return;
        _mappedLodgings = lodgings
            .where((lodging) => lodging.location != null)
            .toList(growable: false);
        _lodgingsLoaded = true;
      }
      if (_mappedLodgings.isEmpty) {
        _showMessage('No accommodation locations are available on the map.');
        return;
      }

      setState(() => _lodgingsVisible = true);
      await _drawLodgings(map, animate: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _lodgingsVisible = false;
          _selectedLodgingIndex = null;
          _selectedLodgingPoint = null;
          _selectedLodgingScreenPosition = null;
        });
        ref.invalidate(lodgingsForTrailProvider);
        try {
          await _removeLodgingAnnotations(map);
        } catch (_) {
          // The map layer may already have been removed by the native SDK.
        }
        _showMessage('Accommodation locations are currently unavailable.');
      }
    } finally {
      if (mounted) {
        setState(() => _changingLodgingVisibility = false);
      }
    }
  }

  Future<void> _toggleStages() async {
    final map = _map;
    if (map == null || _changingStageVisibility) return;
    setState(() => _changingStageVisibility = true);
    try {
      setState(() {
        _stagesVisible = !_stagesVisible;
        _stagesExplicitlyHidden = !_stagesVisible;
        if (!_stagesVisible) {
          _selectedStageScreenPosition = null;
        }
      });
      await _drawStages(map, animate: _stagesVisible);
      if (_stagesVisible && _selectedStageIndex != null) {
        await _updateSelectedStagePosition();
      }
    } finally {
      if (mounted) setState(() => _changingStageVisibility = false);
    }
  }

  Future<void> _selectStage(int stageIndex) async {
    final map = _map;
    final distance = widget.stages[stageIndex].accumulatedDistanceKm;
    if (map == null || distance == null) return;
    final routePoint = routePointNearestDistance(widget.points, distance);
    final point = Point(coordinates: Position(routePoint.lng, routePoint.lat));
    final lodgingWasSelected = _selectedLodgingIndex != null;
    setState(() {
      _selectedStageIndex = stageIndex;
      _selectedStagePoint = point;
      _selectedStageScreenPosition = null;
      _selectedLodgingIndex = null;
      _selectedLodgingPoint = null;
      _selectedLodgingScreenPosition = null;
    });
    await _drawStages(map);
    if (lodgingWasSelected && _lodgingsVisible) {
      await _drawLodgings(map);
    }
    await _updateSelectedStagePosition();
  }

  Future<void> _clearSelectedStage() async {
    setState(() {
      _selectedStageIndex = null;
      _selectedStagePoint = null;
      _selectedStageScreenPosition = null;
    });
    final map = _map;
    if (map != null) await _drawStages(map);
  }

  Future<void> _updateSelectedStagePosition() async {
    if (_stagesExplicitlyHidden) return;
    final map = _map;
    final point = _selectedStagePoint;
    if (map == null || point == null) return;
    final position = await map.pixelForCoordinate(point);
    if (!mounted || _stagesExplicitlyHidden || point != _selectedStagePoint) {
      return;
    }
    setState(() => _selectedStageScreenPosition = position);
  }

  Future<void> _selectLodging(int lodgingIndex) async {
    final map = _map;
    if (map == null ||
        lodgingIndex < 0 ||
        lodgingIndex >= _mappedLodgings.length) {
      return;
    }
    final location = _mappedLodgings[lodgingIndex].location;
    if (location == null) return;
    final stageWasSelected = _selectedStageIndex != null;
    final point = Point(
      coordinates: Position(location.longitude, location.latitude),
    );
    setState(() {
      _selectedLodgingIndex = lodgingIndex;
      _selectedLodgingPoint = point;
      _selectedLodgingScreenPosition = null;
      _selectedStageIndex = null;
      _selectedStagePoint = null;
      _selectedStageScreenPosition = null;
    });
    if (stageWasSelected) {
      await _drawStages(map);
    }
    await _drawLodgings(map);
    await _updateSelectedLodgingPosition();
  }

  Future<void> _clearSelectedLodging() async {
    setState(() {
      _selectedLodgingIndex = null;
      _selectedLodgingPoint = null;
      _selectedLodgingScreenPosition = null;
    });
    final map = _map;
    if (map != null && _lodgingsVisible) {
      await _drawLodgings(map);
    }
  }

  Future<void> _updateSelectedLodgingPosition() async {
    if (!_lodgingsVisible) return;
    final map = _map;
    final point = _selectedLodgingPoint;
    if (map == null || point == null) return;
    final position = await map.pixelForCoordinate(point);
    if (!mounted || !_lodgingsVisible || point != _selectedLodgingPoint) {
      return;
    }
    setState(() => _selectedLodgingScreenPosition = position);
  }

  Future<void> _openSelectedLodgingBooking() async {
    final lodgingIndex = _selectedLodgingIndex;
    if (lodgingIndex == null ||
        lodgingIndex < 0 ||
        lodgingIndex >= _mappedLodgings.length ||
        _openingLodgingBooking) {
      return;
    }
    final bookingUri = _mappedLodgings[lodgingIndex].bookingUri;
    if (bookingUri == null) {
      _showMessage('Booking link unavailable');
      return;
    }

    setState(() => _openingLodgingBooking = true);
    var launched = false;
    try {
      launched = await ref.read(externalUrlLauncherProvider)(bookingUri);
    } catch (_) {
      launched = false;
    } finally {
      if (mounted) setState(() => _openingLodgingBooking = false);
    }
    if (!launched) {
      _showMessage('Could not open this link.');
    }
  }

  void _openSelectedStage() {
    final stageIndex = _selectedStageIndex;
    if (stageIndex == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StageDetailScreen(
          stages: widget.stages,
          initialIndex: stageIndex,
          direction: widget.direction,
          locationStageId:
              widget.stages[stageIndex].id == widget.locationStageId
              ? widget.locationStageId
              : null,
        ),
      ),
    );
  }

  Future<void> _fitRoute() async {
    final map = _map;
    if (map == null || widget.points.isEmpty) return;

    var minLat = widget.points.first.lat;
    var maxLat = minLat;
    var minLng = widget.points.first.lng;
    var maxLng = minLng;
    for (final point in widget.points.skip(1)) {
      if (point.lat < minLat) minLat = point.lat;
      if (point.lat > maxLat) maxLat = point.lat;
      if (point.lng < minLng) minLng = point.lng;
      if (point.lng > maxLng) maxLng = point.lng;
    }

    final mapSize = _lastMapSize ?? MediaQuery.sizeOf(context);
    final portrait = mapSize.height > mapSize.width;
    final bearing = routeFitBearing(widget.points, mapSize);
    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      portrait
          ? MbxEdgeInsets(top: 76, left: 44, bottom: 102, right: 72)
          : MbxEdgeInsets(top: 48, left: 44, bottom: 82, right: 72),
      bearing,
      0,
      null,
      null,
    );
    await map.flyTo(camera, MapAnimationOptions(duration: 700, startDelay: 0));
  }

  Future<void> _focusStage(int stageIndex) async {
    final map = _map;
    final distance = widget.stages[stageIndex].accumulatedDistanceKm;
    if (map == null || distance == null) return;
    final point = routePointNearestDistance(widget.points, distance);
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(point.lng, point.lat)),
        zoom: 13,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 700, startDelay: 0),
    );
  }

  Future<void> _showCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        _showMessage('Turn on Location Services to show your position.');
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        _showMessage('Location permission is needed to show your position.');
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      final map = _map;
      if (map == null) return;
      await _enableLocationPuck();
      await map.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 14,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 700, startDelay: 0),
      );
    } catch (_) {
      _showMessage('Your location could not be read right now.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _enableLocationPuck() async {
    final map = _map;
    if (map == null) return;
    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        pulsingEnabled: true,
        showAccuracyRing: true,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.t(message))));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_lastMapSize != constraints.biggest) {
          _lastMapSize = constraints.biggest;
          final selectedStageIndex = _selectedStageIndex;
          final selectedLodgingIndex = _selectedLodgingIndex;
          if ((selectedStageIndex != null && !_stagesExplicitlyHidden) ||
              (selectedLodgingIndex != null && _lodgingsVisible)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedStageIndex == selectedStageIndex) {
                if (selectedStageIndex != null) {
                  _focusStage(selectedStageIndex);
                } else if (_selectedLodgingIndex == selectedLodgingIndex) {
                  _updateSelectedLodgingPosition();
                }
              }
            });
          }
        }
        return Stack(
          children: [
            MapWidget(
              key: const ValueKey('cyprus-e4-map'),
              styleUri: MapboxStyles.OUTDOORS,
              viewport: _initialViewport,
              onMapCreated: _onMapCreated,
              onMapLoadedListener: _onMapLoaded,
              onMapIdleListener: (_) {
                _updateSelectedStagePosition();
                _updateSelectedLodgingPosition();
              },
            ),
            if (_selectedStageIndex != null &&
                _selectedStageScreenPosition != null)
              _StageSummaryPopup(
                stage: widget.stages[_selectedStageIndex!],
                formatter: widget.formatter,
                distanceKm: widget.direction.distanceFromStart(
                  widget.stages[_selectedStageIndex!].accumulatedDistanceKm!,
                  widget.points.last.distanceKm,
                ),
                mapPosition: _selectedStageScreenPosition!,
                mapSize: constraints.biggest,
                onTap: _openSelectedStage,
                onClose: _clearSelectedStage,
              ),
            if (_selectedLodgingIndex != null &&
                _selectedLodgingScreenPosition != null)
              _LodgingSummaryPopup(
                lodging: _mappedLodgings[_selectedLodgingIndex!],
                formatter: widget.formatter,
                mapPosition: _selectedLodgingScreenPosition!,
                mapSize: constraints.biggest,
                onTap: _openSelectedLodgingBooking,
                onClose: _clearSelectedLodging,
              ),
            Positioned(
              left: 64,
              right: 64,
              bottom: 28,
              child: Center(
                child: Container(
                  key: const ValueKey('map-trail-summary'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _ink.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _routeBlue,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.white, width: 0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cyprus E4 · ${widget.formatter.distance(widget.points.last.distanceKm, decimals: 0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 28,
              child: Column(
                children: [
                  _MapControl(
                    key: const ValueKey('map-accommodation-toggle'),
                    tooltip: context.l10n.t(
                      _lodgingsVisible
                          ? 'Hide accommodation'
                          : 'Show accommodation',
                    ),
                    icon: _changingLodgingVisibility
                        ? null
                        : _lodgingsVisible
                        ? Icons.hotel_rounded
                        : Icons.hotel_outlined,
                    isSelected: _lodgingsVisible,
                    onPressed: _toggleLodgings,
                  ),
                  const SizedBox(height: 10),
                  _MapControl(
                    key: const ValueKey('map-stage-toggle'),
                    tooltip: context.l10n.t(
                      _stagesVisible ? 'Hide stages' : 'Show stages',
                    ),
                    icon: _changingStageVisibility
                        ? null
                        : _stagesVisible
                        ? Icons.location_on_rounded
                        : Icons.location_on_outlined,
                    onPressed: _toggleStages,
                  ),
                  const SizedBox(height: 10),
                  _MapControl(
                    tooltip: context.l10n.t('Show the whole trail'),
                    icon: Icons.route_rounded,
                    onPressed: _fitRoute,
                  ),
                  const SizedBox(height: 10),
                  _MapControl(
                    tooltip: context.l10n.t('My location'),
                    icon: _locating ? null : Icons.my_location_rounded,
                    onPressed: _showCurrentLocation,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StageSummaryPopup extends StatelessWidget {
  const _StageSummaryPopup({
    required this.stage,
    required this.distanceKm,
    required this.formatter,
    required this.mapPosition,
    required this.mapSize,
    required this.onTap,
    required this.onClose,
  });

  static const double _width = 208;
  static const double _height = 68;

  final TrailStage stage;
  final double distanceKm;
  final MeasurementFormatter formatter;
  final ScreenCoordinate mapPosition;
  final Size mapSize;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final left = (mapPosition.x - _width / 2).clamp(
      8.0,
      mapSize.width - _width - 8,
    );
    final top = (mapPosition.y - _height - 12).clamp(
      8.0,
      mapSize.height - _height - 8,
    );
    final details = <String>[
      context.l10n.stage(stage.sequence),
      formatter.distance(distanceKm),
      if (stage.altitudeM != null) formatter.altitude(stage.altitudeM!),
    ].join(' · ');

    return Positioned(
      left: left,
      top: top,
      width: _width,
      height: _height,
      child: Material(
        color: Colors.white,
        elevation: 5,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 7, 3, 7),
            child: Row(
              children: [
                const Icon(Icons.hiking_rounded, size: 18, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.t('Close stage summary'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 17),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LodgingSummaryPopup extends StatelessWidget {
  const _LodgingSummaryPopup({
    required this.lodging,
    required this.formatter,
    required this.mapPosition,
    required this.mapSize,
    required this.onTap,
    required this.onClose,
  });

  static const double _width = 244;
  static const double _height = 76;

  final Lodging lodging;
  final MeasurementFormatter formatter;
  final ScreenCoordinate mapPosition;
  final Size mapSize;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final left = (mapPosition.x - _width / 2).clamp(
      8.0,
      mapSize.width - _width - 8,
    );
    final top = (mapPosition.y - _height - 12).clamp(
      8.0,
      mapSize.height - _height - 8,
    );
    return Positioned(
      left: left,
      top: top,
      width: _width,
      height: _height,
      child: LodgingMapSummaryCard(
        lodging: lodging,
        formatter: formatter,
        onTap: onTap,
        onClose: onClose,
      ),
    );
  }
}

class LodgingMapSummaryCard extends StatelessWidget {
  const LodgingMapSummaryCard({
    required this.lodging,
    required this.formatter,
    required this.onTap,
    required this.onClose,
    super.key,
  });

  final Lodging lodging;
  final MeasurementFormatter formatter;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = lodging.name?.trim();
    final type = lodging.type?.trim();
    final village = lodging.village?.trim();
    final bookingAvailable = lodging.bookingUri != null;
    final details = <String>[
      if (type != null && type.isNotEmpty) l10n.t(type),
      if (village != null && village.isNotEmpty) l10n.t(village),
      if (lodging.distanceFromTrailKm case final distance?)
        formatter.distance(distance),
      if (!bookingAvailable) l10n.t('Booking link unavailable'),
    ].join(' · ');

    return Material(
      color: Colors.white,
      elevation: 5,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('lodging-map-summary-${lodging.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 7, 3, 7),
          child: Row(
            children: [
              const Icon(
                Icons.hotel_rounded,
                size: 19,
                color: _accommodationBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name == null || name.isEmpty
                          ? l10n.t('Accommodation')
                          : l10n.t(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                bookingAvailable
                    ? Icons.open_in_new_rounded
                    : Icons.link_off_rounded,
                size: 16,
                color: bookingAvailable ? _accommodationBlue : Colors.black38,
              ),
              IconButton(
                key: ValueKey('lodging-map-summary-close-${lodging.id}'),
                tooltip: l10n.t('Close accommodation summary'),
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
  });

  final String tooltip;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _accommodationBlue : Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon == null
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isSelected ? Colors.white : _ink,
                ),
              )
            : Icon(icon, color: isSelected ? Colors.white : _ink),
      ),
    );
  }
}

class _MapboxSetupState extends StatelessWidget {
  const _MapboxSetupState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 62, color: _green),
            const SizedBox(height: 18),
            Text(
              context.l10n.t('Map unavailable'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.t(
                'The map service is not configured for this build.',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRouteState extends StatelessWidget {
  const _EmptyRouteState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.route_outlined, size: 58, color: _green),
            const SizedBox(height: 16),
            Text(
              context.l10n.t('Route data is not on this device yet.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.download_rounded),
              label: Text(context.l10n.t('Download route')),
            ),
          ],
        ),
      ),
    );
  }
}

RoutePoint routePointNearestDistance(
  List<RoutePoint> points,
  double distanceKm,
) {
  if (points.length == 1 || distanceKm <= points.first.distanceKm) {
    return points.first;
  }
  if (distanceKm >= points.last.distanceKm) return points.last;

  var low = 0;
  var high = points.length - 1;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (points[middle].distanceKm < distanceKm) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  final after = points[low];
  final before = points[low - 1];
  return (after.distanceKm - distanceKm).abs() <
          (distanceKm - before.distanceKm).abs()
      ? after
      : before;
}

/// Keeps the full-route view north-up while Mapbox fits the route bounds.
double routeFitBearing(List<RoutePoint> points, Size viewportSize) => 0;
