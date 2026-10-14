import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/eurotrex_chrome_theme.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../../elevation/domain/route_point.dart';

class StagePreviewScreen extends StatefulWidget {
  const StagePreviewScreen({
    super.key,
    required this.stageName,
    required this.points,
  });
  final String stageName;
  final List<RoutePoint> points;

  @override
  State<StagePreviewScreen> createState() => _StagePreviewScreenState();
}

class _StagePreviewScreenState extends State<StagePreviewScreen> {
  MapboxMap? _map;
  Timer? _timeout;
  bool _preparing = false;
  bool _ready = false;
  bool _failed = false;
  bool _threeD = true;
  bool _moving = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    final map = _map;
    if (map == null || _preparing || _ready) return;
    _preparing = true;
    try {
      await map.style.addSource(
        RasterDemSource(
          id: 'stage-preview-dem',
          url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
          tileSize: 512,
          maxzoom: 14,
        ),
      );
      await map.style.setStyleTerrain(
        jsonEncode({'source': 'stage-preview-dem', 'exaggeration': 1.0}),
      );
      await map.style.addSource(
        GeoJsonSource(
          id: 'stage-preview-route',
          data: jsonEncode({
            'type': 'Feature',
            'properties': <String, Object>{},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (final p in widget.points) [p.lng, p.lat],
              ],
            },
          }),
        ),
      );
      await map.style.addLayer(
        LineLayer(
          id: 'stage-preview-route-halo',
          sourceId: 'stage-preview-route',
          lineColor: Colors.white.toARGB32(),
          lineWidth: 7,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );
      await map.style.addLayer(
        LineLayer(
          id: 'stage-preview-route-line',
          sourceId: 'stage-preview-route',
          lineColor: EurotrexPalette.blue.toARGB32(),
          lineWidth: 4,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );
      if (!mounted || !identical(map, _map)) return;
      await _fit(animate: false);
      if (mounted && identical(map, _map)) {
        setState(() {
          _ready = true;
          _failed = false;
        });
        _timeout?.cancel();
      }
    } catch (_) {
      if (mounted && identical(map, _map)) setState(() => _failed = true);
    } finally {
      if (identical(map, _map)) _preparing = false;
    }
  }

  Future<void> _fit({bool animate = true}) async {
    final map = _map;
    if (map == null || widget.points.isEmpty) return;
    final points = widget.points;
    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(
          coordinates: Position(
            points.map((p) => p.lng).reduce(math.min),
            points.map((p) => p.lat).reduce(math.min),
          ),
        ),
        northeast: Point(
          coordinates: Position(
            points.map((p) => p.lng).reduce(math.max),
            points.map((p) => p.lat).reduce(math.max),
          ),
        ),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 64, left: 40, bottom: 64, right: 40),
      -25,
      _threeD ? 55 : 0,
      15.5,
      null,
    );
    if (!mounted || !identical(map, _map)) return;
    if (animate) {
      await map.easeTo(camera, MapAnimationOptions(duration: 650));
    } else {
      await map.setCamera(camera);
    }
  }

  Future<void> _resetView() async {
    try {
      await _fit();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _changeView(bool threeD) async {
    if (_moving || !_ready || _map == null) return;
    final map = _map!;
    setState(() {
      _threeD = threeD;
      _moving = true;
    });
    try {
      await map.style.setStyleTerrainProperty(
        'exaggeration',
        threeD ? 1.0 : 0.0,
      );
      if (!mounted || !identical(map, _map)) return;
      await map.easeTo(
        CameraOptions(pitch: threeD ? 55 : 0),
        MapAnimationOptions(duration: 650),
      );
    } catch (_) {
      if (mounted && identical(map, _map)) setState(() => _failed = true);
    } finally {
      if (mounted && identical(map, _map)) setState(() => _moving = false);
    }
  }

  void _retry() {
    setState(() {
      _generation++;
      _map = null;
      _ready = false;
      _failed = false;
      _preparing = false;
      _threeD = true;
      _moving = false;
    });
    _startTimeout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final valid = widget.points.length >= 2;
    return Theme(
      data: EurotrexPalette.controlsTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F2EC),
        appBar: EurotrexChromeTheme.appBar(
          toolbarHeight: 72,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('3D stage preview'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                widget.stageName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        body: !valid
            ? Center(child: Text(l10n.t('No route data available.')))
            : Stack(
                children: [
                  MapWidget(
                    key: ValueKey('stage-preview-map-$_generation'),
                    styleUri: MapboxStyles.OUTDOORS,
                    viewport: const IdleViewportState(),
                    onMapCreated: (map) => _map = map,
                    onStyleLoadedListener: (_) => _prepare(),
                    onMapLoadErrorListener: (event) {
                      if (mounted &&
                          (event.type == MapLoadErrorType.STYLE ||
                              event.sourceId == 'stage-preview-dem')) {
                        setState(() => _failed = true);
                      }
                    },
                  ),
                  if (!_ready && !_failed)
                    const Center(child: CircularProgressIndicator()),
                  if (_failed)
                    Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.t(
                                  'Could not load this map layer. Check your connection and try again.',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _retry,
                                child: Text(l10n.t('Try again')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.t('2D view')),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.t('3D view')),
                        ),
                      ],
                      selected: {_threeD},
                      onSelectionChanged: _ready && !_moving
                          ? (value) => _changeView(value.single)
                          : null,
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('stage-preview-reset'),
                      onPressed: _ready && !_moving ? _resetView : null,
                      icon: const Icon(Icons.fit_screen_rounded),
                      label: Text(l10n.t('Reset view')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.t(
                    'Drag to explore. Pinch to zoom. Rotate with two fingers.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: EurotrexPalette.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('3D terrain needs an internet connection.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: EurotrexPalette.navy,
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
