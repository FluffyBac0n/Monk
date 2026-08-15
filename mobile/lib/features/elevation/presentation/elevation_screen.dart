import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/location/device_location.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../../core/theme/eurotrex_chrome_theme.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../../stages/domain/stage.dart';
import '../../stages/domain/trail_location_matcher.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../trail/domain/trail_direction.dart';
import '../../trail/presentation/trail_direction_controller.dart';
import '../domain/elevation_profile.dart';
import '../domain/elevation_totals.dart';
import '../domain/route_point.dart';
import 'elevation_controller.dart';

const _ink = EurotrexPalette.navy;
const _sand = Color(0xFFF4F2EC);
const _contourLowland = Color(0xFF3E9ED0);
const _contourFoothill = Color(0xFF61AF57);
const _contourUpland = Color(0xFFD8AA35);
const _contourPeak = Color(0xFFD66B35);
const _minimumElevationChangeM = 1.5;
const _stagesRouteName = '/trails/cyprus-e4/stages';

enum _ElevationScope { fullTrail, stage }

class ElevationScreen extends ConsumerStatefulWidget {
  const ElevationScreen({
    this.initialStageIndex,
    this.initialLocation,
    super.key,
  });

  final int? initialStageIndex;
  final DeviceLocation? initialLocation;

  @override
  ConsumerState<ElevationScreen> createState() => _ElevationScreenState();
}

class _ElevationScreenState extends ConsumerState<ElevationScreen> {
  final TransformationController elevationTransformationController =
      TransformationController();
  late int? selectedStageIndex = widget.initialStageIndex;
  late DeviceLocation? currentLocation = widget.initialLocation;
  late _ElevationScope scope = widget.initialStageIndex == null
      ? _ElevationScope.fullTrail
      : _ElevationScope.stage;
  bool isLocating = false;
  double? inspectedDistanceKm;
  List<RoutePoint>? _sourceProfile;
  List<RoutePoint>? _smoothedProfile;

  @override
  void initState() {
    super.initState();
    elevationTransformationController.addListener(_rebuildForChartTransform);
  }

  void _rebuildForChartTransform() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    elevationTransformationController.removeListener(_rebuildForChartTransform);
    elevationTransformationController.dispose();
    super.dispose();
  }

  void _zoomElevation(double factor) {
    final currentScale = elevationTransformationController.value
        .getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(1.0, 15.0);
    final appliedFactor = targetScale / currentScale;
    elevationTransformationController.value *= Matrix4.diagonal3Values(
      appliedFactor,
      appliedFactor,
      1,
    );
  }

  List<RoutePoint> _smoothedPoints(List<RoutePoint> points) {
    if (identical(points, _sourceProfile) && _smoothedProfile != null) {
      return _smoothedProfile!;
    }
    _sourceProfile = points;
    return _smoothedProfile = smoothElevationProfile(points);
  }

  void _changeScope(_ElevationScope nextScope) {
    if (nextScope == scope) return;
    setState(() => scope = nextScope);
    elevationTransformationController.value = Matrix4.identity();
  }

  Future<void> _toggleLocation(
    List<RoutePoint> routePoints,
    List<TrailStage> sourceStages,
    List<TrailStage> orderedStages,
    TrailDirection direction,
  ) async {
    if (currentLocation != null) {
      setState(() => currentLocation = null);
      return;
    }
    if (isLocating) return;
    setState(() => isLocating = true);
    try {
      final location = await ref.read(deviceLocationReaderProvider)();
      if (!mounted) return;
      if (!location.accuracyM.isFinite ||
          location.accuracyM < 0 ||
          location.accuracyM > maximumUsableLocationAccuracyM) {
        _showMessage('Your location could not be read right now.');
        return;
      }
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
      final stageIndex = orderedStages.indexWhere(
        (stage) => stage.id == match.stageId,
      );
      setState(() {
        currentLocation = location;
        if (stageIndex >= 0) selectedStageIndex = stageIndex;
      });
    } on LocationServicesDisabledException {
      _showMessage('Turn on Location Services to show your position.');
    } on LocationPermissionDeniedException {
      _showMessage('Location permission is needed to show your position.');
    } catch (_) {
      _showMessage('Your location could not be read right now.');
    } finally {
      if (mounted) setState(() => isLocating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.t(message))));
  }

  void _backToStages() {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == _stagesRouteName || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
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
    final elevationPoints = elevation.value ?? const <RoutePoint>[];
    final hasElevation = elevationPoints.isNotEmpty;
    final location = currentLocation;
    final locationMatch = location == null || !hasElevation
        ? null
        : findNearbyTrailStage(
            latitude: location.latitude,
            longitude: location.longitude,
            locationAccuracyM: location.accuracyM,
            routePoints: elevationPoints,
            stages: sourceStages,
            direction: direction,
          );
    return Scaffold(
      backgroundColor: _sand,
      appBar: EurotrexChromeTheme.appBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Elevation'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'CYPRUS E4 · ${l10n.routeDirection(direction.isReversed ? l10n.larnakaAirport : l10n.pafosAirport, direction.isReversed ? l10n.pafosAirport : l10n.larnakaAirport).toUpperCase()}',
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white60,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ElevationBottomNavigationBar(
        locationActive: currentLocation != null,
        isLocating: isLocating,
        onStages: _backToStages,
        onZoomOut: hasElevation ? () => _zoomElevation(1 / 1.5) : null,
        onLocationToggle: !hasElevation || isLocating
            ? null
            : () => _toggleLocation(
                elevationPoints,
                sourceStages,
                stages,
                direction,
              ),
        onZoomIn: hasElevation ? () => _zoomElevation(1.5) : null,
        onResetView: hasElevation
            ? () => elevationTransformationController.value = Matrix4.identity()
            : null,
      ),
      body: Theme(
        data: EurotrexPalette.controlsTheme(Theme.of(context)),
        child: elevation.when(
          data: (points) {
            final smoothedPoints = points.isEmpty
                ? const <RoutePoint>[]
                : _smoothedPoints(points);
            return points.isEmpty
                ? _ElevationError(
                    message: l10n.t('No elevation data is available.'),
                    onRetry: () =>
                        ref.read(elevationProvider.notifier).refresh(),
                  )
                : _ElevationContent(
                    points: smoothedPoints,
                    stages: stages,
                    direction: direction,
                    formatter: formatter,
                    scope: scope,
                    selectedStageIndex: selectedStageIndex,
                    transformationController: elevationTransformationController,
                    onScopeChanged: _changeScope,
                    gpsRouteDistanceKm: locationMatch?.projectedRouteDistanceKm,
                    inspectedDistanceKm: inspectedDistanceKm,
                    onInspectionChanged: (distanceKm) {
                      if (distanceKm == inspectedDistanceKm) return;
                      setState(() => inspectedDistanceKm = distanceKm);
                    },
                    onRefresh: () =>
                        ref.read(elevationProvider.notifier).refresh(),
                  );
          },
          loading: () => const _ElevationLoading(),
          error: (error, _) => _ElevationError(
            message: l10n.t('Could not download the elevation profile.'),
            onRetry: () => ref.read(elevationProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _ElevationContent extends StatelessWidget {
  const _ElevationContent({
    required this.points,
    required this.stages,
    required this.direction,
    required this.formatter,
    required this.scope,
    required this.selectedStageIndex,
    required this.transformationController,
    required this.onScopeChanged,
    required this.gpsRouteDistanceKm,
    required this.inspectedDistanceKm,
    required this.onInspectionChanged,
    required this.onRefresh,
  });

  final List<RoutePoint> points;
  final List<TrailStage> stages;
  final TrailDirection direction;
  final MeasurementFormatter formatter;
  final _ElevationScope scope;
  final int? selectedStageIndex;
  final TransformationController transformationController;
  final ValueChanged<_ElevationScope> onScopeChanged;
  final double? gpsRouteDistanceKm;
  final double? inspectedDistanceKm;
  final ValueChanged<double?> onInspectionChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final profileLowest = points.reduce(
      (a, b) => a.altitudeM < b.altitudeM ? a : b,
    );
    final totalDistance = points.last.distanceKm;
    final selectedRange = selectedStageIndex == null
        ? null
        : _stageRange(
            stages: stages,
            stageIndex: selectedStageIndex!,
            direction: direction,
            totalDistanceKm: totalDistance,
          );
    final stagePoints = selectedRange == null
        ? const <RoutePoint>[]
        : elevationSection(
            points,
            startDistanceKm: selectedRange.startCanonicalKm,
            endDistanceKm: selectedRange.endCanonicalKm,
          );
    final hasStageProfile =
        selectedRange != null &&
        selectedRange.distanceKm >= 0.01 &&
        stagePoints.length >= 2;
    final effectiveScope = scope == _ElevationScope.stage && hasStageProfile
        ? _ElevationScope.stage
        : _ElevationScope.fullTrail;
    final metricPoints = effectiveScope == _ElevationScope.stage
        ? stagePoints
        : points;
    final metricHighest = metricPoints.reduce(
      (a, b) => a.altitudeM > b.altitudeM ? a : b,
    );
    final metricDistance = effectiveScope == _ElevationScope.stage
        ? selectedRange!.distanceKm
        : totalDistance;
    final displayedProfilePoints = effectiveScope == _ElevationScope.stage
        ? stagePoints
        : points;
    final displayedHighest = displayedProfilePoints.reduce(
      (a, b) => a.altitudeM > b.altitudeM ? a : b,
    );
    final displayedLowest = displayedProfilePoints.reduce(
      (a, b) => a.altitudeM < b.altitudeM ? a : b,
    );
    final chartDistanceOffset = effectiveScope == _ElevationScope.stage
        ? selectedRange!.startChartKm
        : 0.0;
    final chartDistance = effectiveScope == _ElevationScope.stage
        ? selectedRange!.distanceKm
        : totalDistance;
    double chartDistanceForCanonical(double canonicalDistanceKm) =>
        direction.distanceFromStart(canonicalDistanceKm, totalDistance) -
        chartDistanceOffset;
    final elevationTotals = calculateElevationTotals(
      metricPoints,
      minimumChangeM: _minimumElevationChangeM,
    );
    final totalAscentM = direction.isReversed
        ? elevationTotals.descentM
        : elevationTotals.ascentM;
    final totalDescentM = direction.isReversed
        ? elevationTotals.ascentM
        : elevationTotals.descentM;
    final chartPoints = _downsample(displayedProfilePoints, 900);
    final selectedStage =
        selectedStageIndex != null &&
            selectedStageIndex! >= 0 &&
            selectedStageIndex! < stages.length
        ? stages[selectedStageIndex!]
        : null;
    final minAltitude = effectiveScope == _ElevationScope.stage
        ? math
              .max(
                0.0,
                ((displayedLowest.altitudeM - 100) / 100).floor() * 100.0,
              )
              .toDouble()
        : math.min(0.0, profileLowest.altitudeM).floorToDouble();
    final roundedMaximum = (displayedHighest.altitudeM / 100).ceil() * 100.0;
    final maxAltitude = math.max(roundedMaximum, minAltitude + 100.0);
    final gpsPoint = gpsRouteDistanceKm == null
        ? null
        : routePointAtDistance(points, gpsRouteDistanceKm!);
    final gpsChartDistance = gpsRouteDistanceKm == null
        ? null
        : chartDistanceForCanonical(gpsRouteDistanceKm!);
    final inspectedCanonicalDistance = inspectedDistanceKm == null
        ? null
        : direction.isReversed
        ? totalDistance - inspectedDistanceKm!
        : inspectedDistanceKm!;
    final inspectedPoint = inspectedCanonicalDistance == null
        ? null
        : routePointAtDistance(points, inspectedCanonicalDistance);
    final inspectedChartDistance = inspectedDistanceKm == null
        ? null
        : inspectedDistanceKm! - chartDistanceOffset;
    final horizontalScale = transformationController.value
        .getMaxScaleOnAxis()
        .clamp(1.0, 15.0);
    final distanceInterval = _niceAxisInterval(
      chartDistance / horizontalScale / 5,
    );
    final distanceRemainder = chartDistance % distanceInterval;
    final includeMaximumDistanceLabel =
        distanceRemainder < 0.000001 ||
        distanceRemainder / distanceInterval >= 0.35;
    final altitudeInterval = _niceAxisInterval((maxAltitude - minAltitude) / 4);

    return RefreshIndicator(
      key: const ValueKey('elevation-pull-to-refresh'),
      color: EurotrexPalette.blue,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          _ElevationScopeSelector(
            selected: effectiveScope,
            stageEnabled: hasStageProfile,
            onChanged: onScopeChanged,
          ),
          if (selectedStage != null) ...[
            const SizedBox(height: 8),
            _ElevationStageLabel(stageName: selectedStage.name),
          ],
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('elevation-chart-card'),
            padding: const EdgeInsets.fromLTRB(10, 22, 18, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: EurotrexPalette.paleBlue),
              boxShadow: [
                BoxShadow(
                  color: EurotrexPalette.navy.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SizedBox(
              height: 286,
              child: _ElevationGestureSurface(
                transformationController: transformationController,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: chartDistance,
                          minY: minAltitude,
                          maxY: maxAltitude,
                          clipData: const FlClipData.all(),
                          rangeAnnotations: RangeAnnotations(
                            verticalRangeAnnotations: [
                              if (selectedRange != null &&
                                  selectedRange.distanceKm >= 0.01)
                                VerticalRangeAnnotation(
                                  x1:
                                      selectedRange.startChartKm -
                                      chartDistanceOffset,
                                  x2:
                                      selectedRange.endChartKm -
                                      chartDistanceOffset,
                                  color: EurotrexPalette.blue.withValues(
                                    alpha: 0.09,
                                  ),
                                ),
                            ],
                          ),
                          extraLinesData: ExtraLinesData(
                            extraLinesOnTop: true,
                            verticalLines: [
                              if (selectedRange != null &&
                                  selectedRange.distanceKm >= 0.01) ...[
                                _stageBoundaryLine(
                                  selectedRange.startChartKm -
                                      chartDistanceOffset,
                                ),
                                _stageBoundaryLine(
                                  selectedRange.endChartKm -
                                      chartDistanceOffset,
                                ),
                              ],
                              if (inspectedChartDistance != null &&
                                  inspectedChartDistance >= 0 &&
                                  inspectedChartDistance <= chartDistance)
                                VerticalLine(
                                  x: inspectedChartDistance,
                                  color: EurotrexPalette.navy.withValues(
                                    alpha: 0.62,
                                  ),
                                  strokeWidth: 1.2,
                                  dashArray: const [4, 4],
                                ),
                            ],
                          ),
                          gridData: FlGridData(
                            drawVerticalLine: true,
                            horizontalInterval: altitudeInterval,
                            verticalInterval: distanceInterval,
                            getDrawingHorizontalLine: (_) => const FlLine(
                              color: Color(0xFFE2E5E1),
                              strokeWidth: 1,
                            ),
                            getDrawingVerticalLine: (_) => const FlLine(
                              color: Color(0xFFF0F1EF),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
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
                                reservedSize: 42,
                                interval: altitudeInterval,
                                minIncluded: false,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${formatter.altitudeValue(value).round()} ${formatter.altitudeUnit}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.black45,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: distanceInterval,
                                maxIncluded: includeMaximumDistanceLabel,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Text(
                                      '${formatter.distanceValue(value).toStringAsFixed(distanceInterval < 10 ? 1 : 0)} ${formatter.distanceUnit}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineTouchData: LineTouchData(
                            touchSpotThreshold: 16,
                            distanceCalculator: (touchPoint, spotPoint) =>
                                (touchPoint - spotPoint).distance,
                            touchCallback: (event, response) {
                              if (event is FlPanEndEvent ||
                                  event is FlPanCancelEvent ||
                                  event is FlLongPressEnd ||
                                  event is FlPointerExitEvent) {
                                onInspectionChanged(null);
                                return;
                              }
                              final touched = response?.lineBarSpots;
                              if (touched == null) return;
                              for (final spot in touched) {
                                if (spot.barIndex == 0) {
                                  onInspectionChanged(
                                    spot.x + chartDistanceOffset,
                                  );
                                  break;
                                }
                              }
                            },
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => _ink,
                              getTooltipItems: (spots) => spots.map((spot) {
                                if (spot.barIndex != 0) return null;
                                return LineTooltipItem(
                                  '${formatter.distance(spot.x)}\n${formatter.altitude(spot.y)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (final point
                                    in direction.isReversed
                                        ? chartPoints.reversed
                                        : chartPoints)
                                  FlSpot(
                                    direction.isReversed
                                        ? point.reverseDistanceKm -
                                              chartDistanceOffset
                                        : point.distanceKm -
                                              chartDistanceOffset,
                                    point.altitudeM,
                                  ),
                              ],
                              isCurved: false,
                              color: EurotrexPalette.navy,
                              barWidth: 1.5,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: _elevationContourGradient(
                                  minAltitude: minAltitude,
                                  maxAltitude: displayedHighest.altitudeM,
                                ),
                              ),
                            ),
                            if (gpsPoint != null && gpsChartDistance != null)
                              LineChartBarData(
                                spots: [
                                  FlSpot(gpsChartDistance, gpsPoint.altitudeM),
                                ],
                                color: Colors.transparent,
                                barWidth: 0,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (_, _, _, _) =>
                                      FlDotCirclePainter(
                                        radius: 6,
                                        color: EurotrexPalette.navy,
                                        strokeWidth: 3,
                                        strokeColor: Colors.white,
                                      ),
                                ),
                              ),
                            if (inspectedPoint != null &&
                                inspectedChartDistance != null &&
                                inspectedChartDistance >= 0 &&
                                inspectedChartDistance <= chartDistance)
                              LineChartBarData(
                                spots: [
                                  FlSpot(
                                    inspectedChartDistance,
                                    inspectedPoint.altitudeM,
                                  ),
                                ],
                                color: Colors.transparent,
                                barWidth: 0,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (_, _, _, _) =>
                                      FlDotCirclePainter(
                                        radius: 4.5,
                                        color: EurotrexPalette.blue,
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        duration: Duration.zero,
                        transformationConfig: FlTransformationConfig(
                          scaleAxis: FlScaleAxis.horizontal,
                          minScale: 1,
                          maxScale: 15,
                          panEnabled: false,
                          scaleEnabled: true,
                          trackpadScrollCausesScale: true,
                          transformationController: transformationController,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ContourLegend(formatter: formatter),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ElevationMetric(
                  key: const ValueKey('elevation-trail-distance'),
                  icon: Icons.hiking_rounded,
                  value: formatter.distance(metricDistance),
                  label: context.l10n.t(
                    effectiveScope == _ElevationScope.stage
                        ? 'Stage length'
                        : 'Trail distance',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ElevationMetric(
                  icon: Icons.north_east_rounded,
                  value: formatter.altitude(metricHighest.altitudeM),
                  label: context.l10n.t('Highest point'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ElevationMetric(
                  key: const Key('elevation-total-ascent'),
                  icon: Icons.trending_up_rounded,
                  value: formatter.altitude(totalAscentM),
                  label: context.l10n.t('Total ascent'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ElevationMetric(
                  key: const Key('elevation-total-descent'),
                  icon: Icons.trending_down_rounded,
                  value: formatter.altitude(totalDescentM),
                  label: context.l10n.t('Total descent'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _ElevationStageRange = ({
  double startCanonicalKm,
  double endCanonicalKm,
  double startChartKm,
  double endChartKm,
  double distanceKm,
});

_ElevationStageRange? _stageRange({
  required List<TrailStage> stages,
  required int stageIndex,
  required TrailDirection direction,
  required double totalDistanceKm,
}) {
  if (stageIndex < 0 ||
      stageIndex >= stages.length ||
      !totalDistanceKm.isFinite ||
      totalDistanceKm <= 0) {
    return null;
  }
  final endDistance = stages[stageIndex].accumulatedDistanceKm;
  if (endDistance == null || !endDistance.isFinite) return null;
  final startDistance = stageIndex == 0
      ? endDistance
      : stages[stageIndex - 1].accumulatedDistanceKm;
  if (startDistance == null || !startDistance.isFinite) return null;
  final startCanonical = math.min(startDistance, endDistance);
  final endCanonical = math.max(startDistance, endDistance);
  final firstChart = direction.distanceFromStart(
    startDistance,
    totalDistanceKm,
  );
  final secondChart = direction.distanceFromStart(endDistance, totalDistanceKm);
  return (
    startCanonicalKm: startCanonical,
    endCanonicalKm: endCanonical,
    startChartKm: math.min(firstChart, secondChart),
    endChartKm: math.max(firstChart, secondChart),
    distanceKm: endCanonical - startCanonical,
  );
}

double _niceAxisInterval(double rawInterval) {
  if (!rawInterval.isFinite || rawInterval <= 0) return 1;
  final magnitude = math.pow(10, (math.log(rawInterval) / math.ln10).floor());
  final normalized = rawInterval / magnitude;
  final niceNormalized = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return (niceNormalized * magnitude).toDouble();
}

VerticalLine _stageBoundaryLine(double distanceKm) => VerticalLine(
  x: distanceKm,
  color: EurotrexPalette.blue.withValues(alpha: 0.55),
  strokeWidth: 1.2,
  dashArray: const [5, 4],
);

LinearGradient _elevationContourGradient({
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

class _ElevationGestureSurface extends StatefulWidget {
  const _ElevationGestureSurface({
    required this.transformationController,
    required this.child,
  });

  final TransformationController transformationController;
  final Widget child;

  @override
  State<_ElevationGestureSurface> createState() =>
      _ElevationGestureSurfaceState();
}

class _ElevationGestureSurfaceState extends State<_ElevationGestureSurface> {
  final Map<int, Offset> _pointerPositions = {};

  void _onPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.localPosition;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final previous = _pointerPositions[event.pointer];
    _pointerPositions[event.pointer] = event.localPosition;
    if (previous == null || _pointerPositions.length != 1) return;

    final delta = event.localPosition - previous;
    if (delta.dx.abs() <= delta.dy.abs()) return;
    final scale = widget.transformationController.value.getMaxScaleOnAxis();
    if (scale <= 1) return;

    final width = context.size?.width;
    if (width == null || width <= 0) return;
    final matrix = widget.transformationController.value.clone();
    final minTranslation = width * (1 - scale);
    matrix.storage[12] = (matrix.storage[12] + delta.dx).clamp(
      minTranslation,
      0.0,
    );
    widget.transformationController.value = matrix;
  }

  void _removePointer(PointerEvent event) {
    _pointerPositions.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _removePointer,
      onPointerCancel: _removePointer,
      child: widget.child,
    );
  }
}

class _ElevationScopeSelector extends StatelessWidget {
  const _ElevationScopeSelector({
    required this.selected,
    required this.stageEnabled,
    required this.onChanged,
  });

  final _ElevationScope selected;
  final bool stageEnabled;
  final ValueChanged<_ElevationScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<_ElevationScope>(
        key: const ValueKey('elevation-scope-selector'),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 7),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.disabled)
                ? EurotrexPalette.navy.withValues(alpha: 0.28)
                : null,
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.disabled)
                ? const Color(0xFFE3E5E4)
                : null,
          ),
        ),
        segments: [
          ButtonSegment(
            value: _ElevationScope.fullTrail,
            icon: const Icon(Icons.alt_route_rounded, size: 15),
            label: Text(context.l10n.t('Full trail')),
          ),
          ButtonSegment(
            value: _ElevationScope.stage,
            icon: const Icon(Icons.hiking_rounded, size: 15),
            label: Text(context.l10n.t('Stage')),
            enabled: stageEnabled,
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}

class _ContourLegend extends StatelessWidget {
  const _ContourLegend({required this.formatter});

  final MeasurementFormatter formatter;

  @override
  Widget build(BuildContext context) {
    String value(double meters) =>
        formatter.altitudeValue(meters).round().toString();
    final unit = formatter.altitudeUnit;
    return Semantics(
      label: context.l10n.t('Altitude'),
      child: Container(
        key: const ValueKey('elevation-contour-legend'),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: BoxDecoration(
          color: EurotrexPalette.paleBlue.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EurotrexPalette.paleBlue),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('elevation-contour-gradient'),
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: EurotrexPalette.navy.withValues(alpha: 0.16),
                ),
                gradient: const LinearGradient(
                  colors: [
                    _contourLowland,
                    _contourFoothill,
                    _contourUpland,
                    _contourPeak,
                  ],
                  stops: [0, 0.3, 0.65, 1],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ContourLegendLabel('${value(0)} $unit'),
                _ContourLegendLabel('${value(300)} $unit'),
                _ContourLegendLabel('${value(700)} $unit'),
                _ContourLegendLabel('${value(1200)}+ $unit'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContourLegendLabel extends StatelessWidget {
  const _ContourLegendLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        color: EurotrexPalette.navy.withValues(alpha: 0.72),
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ElevationStageLabel extends StatelessWidget {
  const _ElevationStageLabel({required this.stageName});

  final String stageName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('elevation-stage-summary'),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: EurotrexPalette.paleBlue.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: EurotrexPalette.blue.withValues(alpha: 0.34),
          ),
        ),
        child: Text(
          stageName,
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
    );
  }
}

class _ElevationBottomNavigationBar extends StatelessWidget {
  const _ElevationBottomNavigationBar({
    required this.locationActive,
    required this.isLocating,
    required this.onStages,
    required this.onZoomOut,
    required this.onLocationToggle,
    required this.onZoomIn,
    required this.onResetView,
  });

  final bool locationActive;
  final bool isLocating;
  final VoidCallback onStages;
  final VoidCallback? onZoomOut;
  final VoidCallback? onLocationToggle;
  final VoidCallback? onZoomIn;
  final VoidCallback? onResetView;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EurotrexChromeTheme.navigationBar(
      surfaceKey: const ValueKey('elevation-bottom-navigation'),
      contentKey: const ValueKey('elevation-bottom-navigation-size'),
      child: Row(
        children: [
          _ElevationBottomAction(
            key: const Key('elevation-stages-shortcut'),
            icon: Icons.hiking_rounded,
            label: l10n.t('Back to stages'),
            visibleLabel: l10n.t('Stages'),
            onTap: onStages,
          ),
          _ElevationBottomAction(
            key: const Key('elevation-zoom-out'),
            icon: Icons.remove_rounded,
            label: l10n.t('Zoom out'),
            visibleLabel: l10n.t('Zoom out'),
            onTap: onZoomOut,
          ),
          _ElevationBottomAction(
            key: const Key('elevation-location-toggle'),
            icon: isLocating
                ? Icons.hourglass_top_rounded
                : locationActive
                ? Icons.gps_fixed_rounded
                : Icons.gps_not_fixed_rounded,
            label: l10n.t('My location'),
            visibleLabel: l10n.t('GPS'),
            isActive: locationActive,
            isToggle: true,
            isPrimary: true,
            onTap: onLocationToggle,
          ),
          _ElevationBottomAction(
            key: const Key('elevation-zoom-in'),
            icon: Icons.add_rounded,
            label: l10n.t('Zoom in'),
            visibleLabel: l10n.t('Zoom in'),
            onTap: onZoomIn,
          ),
          _ElevationBottomAction(
            key: const Key('elevation-reset-view'),
            icon: Icons.fit_screen_rounded,
            label: l10n.t('Reset elevation view'),
            visibleLabel: l10n.t('Reset'),
            onTap: onResetView,
          ),
        ],
      ),
    );
  }
}

class _ElevationBottomAction extends StatelessWidget {
  const _ElevationBottomAction({
    required this.icon,
    required this.label,
    required this.visibleLabel,
    required this.onTap,
    this.isActive = false,
    this.isToggle = false,
    this.isPrimary = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String visibleLabel;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isToggle;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final foreground = onTap == null ? Colors.white30 : Colors.white;
    void handleTap() {
      unawaited(HapticFeedback.selectionClick());
      onTap?.call();
    }

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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: isPrimary ? 36 : 32,
                        height: isPrimary ? 36 : 32,
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? isActive
                                    ? EurotrexPalette.blue
                                    : Colors.white.withValues(alpha: 0.055)
                              : isActive
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: foreground,
                          size: isPrimary ? 22 : 21,
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

class _ElevationMetric extends StatelessWidget {
  const _ElevationMetric({
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
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EurotrexPalette.paleBlue),
        boxShadow: [
          BoxShadow(
            color: EurotrexPalette.navy.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: EurotrexPalette.paleBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: EurotrexPalette.blue, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: EurotrexPalette.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: EurotrexPalette.navy.withValues(alpha: 0.68),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
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

class _ElevationLoading extends StatelessWidget {
  const _ElevationLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: EurotrexPalette.paleBlue),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              context.l10n.t('Preparing the offline elevation profile…'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EurotrexPalette.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElevationError extends StatelessWidget {
  const _ElevationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EurotrexPalette.paleBlue),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: EurotrexPalette.paleBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  size: 30,
                  color: EurotrexPalette.blue,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: EurotrexPalette.navy),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.download_rounded),
                label: Text(context.l10n.t('Download profile')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<RoutePoint> _downsample(List<RoutePoint> points, int targetCount) {
  if (points.length <= targetCount) return points;
  final step = (points.length / targetCount).ceil();
  final sampled = <RoutePoint>[
    for (var index = 0; index < points.length; index += step) points[index],
  ];
  if (sampled.last.pointIndex != points.last.pointIndex) {
    sampled.add(points.last);
  }
  return sampled;
}
