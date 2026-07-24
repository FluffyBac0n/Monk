import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
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

class MapScreen extends ConsumerWidget {
  const MapScreen({
    this.initialStageIndex,
    this.accessToken = mapboxAccessToken,
    super.key,
  });

  final int? initialStageIndex;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Trail map'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'CYPRUS E4 · ${l10n.routeDirection(direction.isReversed ? l10n.larnakaAirport : l10n.pafosAirport, direction.isReversed ? l10n.pafosAirport : l10n.larnakaAirport).toUpperCase()}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                letterSpacing: 1.2,
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
      OfflineMapPhase.failed => l10n.t('Offline map download failed'),
      _ => l10n.t('Download offline map'),
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
    required this.onDelete,
  });

  final OfflineMapState state;
  final bool canDownload;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = state.phase == OfflineMapPhase.ready;
    final downloading = state.phase == OfflineMapPhase.downloading;
    final failed = state.phase == OfflineMapPhase.failed;
    final title = ready
        ? l10n.t('Trail map available offline')
        : downloading
        ? l10n.t('Downloading offline map')
        : failed
        ? l10n.t('Download interrupted')
        : l10n.t('Take the map offline');
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
              ? l10n.t(
                  'The Mapbox Outdoors style and detailed tiles along the Cyprus E4 are stored on this device.',
                )
              : failed
              ? state.message ?? l10n.t('Please try the download again.')
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
          'The route, stages and elevation will remain offline. Only the Mapbox background tiles will be removed.',
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

class _RouteMap extends StatefulWidget {
  const _RouteMap({
    required this.points,
    required this.stages,
    required this.direction,
    required this.formatter,
    required this.initialStageIndex,
  });

  final List<RoutePoint> points;
  final List<TrailStage> stages;
  final TrailDirection direction;
  final MeasurementFormatter formatter;
  final int? initialStageIndex;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  late final CameraViewportState _initialViewport;
  MapboxMap? _map;
  CircleAnnotationManager? _stageManager;
  PointAnnotationManager? _stageLabelManager;
  Cancelable? _stageTapListener;
  final Map<String, int> _stageIndexByAnnotation = {};
  int? _selectedStageIndex;
  Point? _selectedStagePoint;
  ScreenCoordinate? _selectedStageScreenPosition;
  bool _locating = false;
  bool _stagesVisible = false;
  bool _stagesExplicitlyHidden = false;
  bool _changingStageVisibility = false;
  bool _initialCameraApplied = false;
  Size? _lastMapSize;

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
    _stageTapListener?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await _drawRoute(map);
    await _drawStages(map);
  }

  Future<void> _onMapLoaded(MapLoadedEventData _) async {
    if (_initialCameraApplied || !mounted) return;
    _initialCameraApplied = true;
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

  Future<void> _drawStages(MapboxMap map) async {
    final l10n = context.l10n;
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
      await _drawStages(map);
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
    setState(() {
      _selectedStageIndex = stageIndex;
      _selectedStagePoint = point;
      _selectedStageScreenPosition = null;
    });
    await _drawStages(map);
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

  void _openSelectedStage() {
    final stageIndex = _selectedStageIndex;
    if (stageIndex == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StageDetailScreen(
          stages: widget.stages,
          initialIndex: stageIndex,
          direction: widget.direction,
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

    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 48, left: 36, bottom: 96, right: 36),
      0,
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
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      );
      await map.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 14,
        ),
        MapAnimationOptions(duration: 700, startDelay: 0),
      );
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_lastMapSize != constraints.biggest) {
          _lastMapSize = constraints.biggest;
          final selectedStageIndex = _selectedStageIndex;
          if (selectedStageIndex != null && !_stagesExplicitlyHidden) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedStageIndex == selectedStageIndex) {
                _focusStage(selectedStageIndex);
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
              onMapIdleListener: (_) => _updateSelectedStagePosition(),
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
            Positioned(
              left: 12,
              bottom: 28,
              child: Container(
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
                        color: Colors.black,
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
            Positioned(
              right: 12,
              bottom: 28,
              child: Column(
                children: [
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

class _MapControl extends StatelessWidget {
  const _MapControl({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon == null
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(icon, color: _ink),
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
              context.l10n.t('Connect Mapbox'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.t(
                'Add a public Mapbox access token when running the app to load the map tiles.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SelectableText(
                '--dart-define=MAPBOX_ACCESS_TOKEN=pk…',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
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
