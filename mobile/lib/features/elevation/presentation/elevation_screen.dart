import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../stages/domain/stage.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../stages/presentation/stages_screen.dart';
import '../../trail/domain/trail_direction.dart';
import '../../trail/presentation/trail_direction_controller.dart';
import '../domain/elevation_totals.dart';
import '../domain/route_point.dart';
import 'elevation_controller.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _red = Color(0xFFD14B45);
const _sand = Color(0xFFF4F2EC);
const _orange = Color(0xFFC57432);

class ElevationScreen extends ConsumerStatefulWidget {
  const ElevationScreen({this.initialStageIndex, super.key});

  final int? initialStageIndex;

  @override
  ConsumerState<ElevationScreen> createState() => _ElevationScreenState();
}

class _ElevationScreenState extends ConsumerState<ElevationScreen> {
  final TransformationController elevationTransformationController =
      TransformationController();
  bool showStages = false;
  bool stagesExplicitlyHidden = false;
  late int? selectedStageIndex = widget.initialStageIndex;
  bool initialStageFocusApplied = false;

  @override
  void dispose() {
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

  void _focusInitialStage(
    List<TrailStage> stages,
    TrailDirection direction,
    double totalDistance,
  ) {
    if (initialStageFocusApplied) return;
    final initialIndex = widget.initialStageIndex;
    if (initialIndex == null ||
        initialIndex < 0 ||
        initialIndex >= stages.length ||
        totalDistance <= 0) {
      initialStageFocusApplied = true;
      return;
    }
    final distance = stages[initialIndex].accumulatedDistanceKm;
    if (distance == null) {
      initialStageFocusApplied = true;
      return;
    }
    initialStageFocusApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const scale = 4.0;
      final width = MediaQuery.sizeOf(context).width - 32;
      final position = direction.distanceFromStart(distance, totalDistance);
      final fraction = (position / totalDistance).clamp(0.0, 1.0);
      final translation = (width / 2 - fraction * width * scale).clamp(
        width * (1 - scale),
        0.0,
      );
      final matrix = Matrix4.diagonal3Values(scale, 1, 1)
        ..storage[12] = translation;
      elevationTransformationController.value = matrix;
    });
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
    return Scaffold(
      backgroundColor: _sand,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Elevation'),
              style: const TextStyle(fontWeight: FontWeight.w800),
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
        actions: [
          IconButton(
            tooltip: l10n.t('Refresh elevation data'),
            onPressed: elevation.isLoading
                ? null
                : () => ref.read(elevationProvider.notifier).refresh(),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: elevation.when(
        data: (points) {
          if (points.isNotEmpty) {
            _focusInitialStage(stages, direction, points.last.distanceKm);
          }
          return points.isEmpty
              ? _ElevationError(
                  message: l10n.t('No elevation data is available.'),
                  onRetry: () => ref.read(elevationProvider.notifier).refresh(),
                )
              : _ElevationContent(
                  points: points,
                  stages: stages,
                  direction: direction,
                  formatter: formatter,
                  showStages: showStages,
                  stagesExplicitlyHidden: stagesExplicitlyHidden,
                  onToggleStages: stages.isEmpty
                      ? null
                      : () => setState(() {
                          showStages = !showStages;
                          stagesExplicitlyHidden = !showStages;
                        }),
                  selectedStageIndex: selectedStageIndex,
                  transformationController: elevationTransformationController,
                  onZoomIn: () => _zoomElevation(1.5),
                  onZoomOut: () => _zoomElevation(1 / 1.5),
                  onResetView: () => elevationTransformationController.value =
                      Matrix4.identity(),
                  onStageTap: (stageIndex) =>
                      setState(() => selectedStageIndex = stageIndex),
                  onStageSummaryTap: () {
                    final stageIndex = selectedStageIndex;
                    if (stageIndex == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StageDetailScreen(
                          stages: stages,
                          initialIndex: stageIndex,
                          direction: direction,
                        ),
                      ),
                    );
                  },
                  onStageSummaryClose: () =>
                      setState(() => selectedStageIndex = null),
                );
        },
        loading: () => const _ElevationLoading(),
        error: (error, _) => _ElevationError(
          message: l10n.t('Could not download the elevation profile.'),
          onRetry: () => ref.read(elevationProvider.notifier).refresh(),
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
    required this.showStages,
    required this.stagesExplicitlyHidden,
    required this.onToggleStages,
    required this.selectedStageIndex,
    required this.transformationController,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetView,
    required this.onStageTap,
    required this.onStageSummaryTap,
    required this.onStageSummaryClose,
  });

  final List<RoutePoint> points;
  final List<TrailStage> stages;
  final TrailDirection direction;
  final MeasurementFormatter formatter;
  final bool showStages;
  final bool stagesExplicitlyHidden;
  final VoidCallback? onToggleStages;
  final int? selectedStageIndex;
  final TransformationController transformationController;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetView;
  final ValueChanged<int> onStageTap;
  final VoidCallback onStageSummaryTap;
  final VoidCallback onStageSummaryClose;

  @override
  Widget build(BuildContext context) {
    final highest = points.reduce((a, b) => a.altitudeM > b.altitudeM ? a : b);
    final lowest = points.reduce((a, b) => a.altitudeM < b.altitudeM ? a : b);
    final elevationTotals = calculateElevationTotals(points);
    final totalAscentM = direction.isReversed
        ? elevationTotals.descentM
        : elevationTotals.ascentM;
    final totalDescentM = direction.isReversed
        ? elevationTotals.ascentM
        : elevationTotals.descentM;
    final totalDistance = points.last.distanceKm;
    final chartPoints = _downsample(points, 900);
    final stageMarks = <({TrailStage stage, int stageIndex})>[
      for (var index = 0; index < stages.length; index++)
        if (stages[index].accumulatedDistanceKm != null &&
            stages[index].altitudeM != null)
          (stage: stages[index], stageIndex: index),
    ];
    final selectedStage =
        selectedStageIndex != null &&
            selectedStageIndex! >= 0 &&
            selectedStageIndex! < stages.length
        ? stages[selectedStageIndex!]
        : null;
    final startStageMark = stageMarks.isEmpty ? null : stageMarks.first;
    final endStageMark = stageMarks.isEmpty ? null : stageMarks.last;
    final displayedStageMarks = showStages
        ? stageMarks
        : stagesExplicitlyHidden
        ? const <({TrailStage stage, int stageIndex})>[]
        : selectedStageIndex == null
        ? const <({TrailStage stage, int stageIndex})>[]
        : stageMarks
              .where((mark) => mark.stageIndex == selectedStageIndex)
              .toList(growable: false);
    final minAltitude = math.min(0.0, lowest.altitudeM).floorToDouble();
    final maxAltitude = (highest.altitudeM / 100).ceil() * 100.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _ElevationControl(
              key: const Key('elevation-zoom-out'),
              tooltip: context.l10n.t('Zoom out'),
              icon: Icons.remove_rounded,
              onPressed: onZoomOut,
            ),
            const SizedBox(width: 10),
            _ElevationControl(
              key: const Key('elevation-zoom-in'),
              tooltip: context.l10n.t('Zoom in'),
              icon: Icons.add_rounded,
              onPressed: onZoomIn,
            ),
            const SizedBox(width: 10),
            _ElevationControl(
              key: const Key('elevation-reset-view'),
              tooltip: context.l10n.t('Reset elevation view'),
              icon: Icons.fit_screen_rounded,
              onPressed: onResetView,
            ),
            const SizedBox(width: 10),
            _ElevationControl(
              key: const Key('elevation-stage-toggle'),
              tooltip: context.l10n.t(
                showStages ? 'Hide stages' : 'Show stages',
              ),
              icon: showStages
                  ? Icons.location_on_rounded
                  : Icons.location_on_outlined,
              onPressed: onToggleStages,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 22, 18, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 300,
            child: _ElevationGestureSurface(
              transformationController: transformationController,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: totalDistance,
                        minY: minAltitude,
                        maxY: maxAltitude,
                        clipData: const FlClipData.all(),
                        gridData: FlGridData(
                          drawVerticalLine: true,
                          horizontalInterval: 500,
                          verticalInterval: 100,
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
                              interval: 500,
                              getTitlesWidget: (value, meta) {
                                if ((value % 500).abs() > 0.01) {
                                  return const SizedBox.shrink();
                                }
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
                              interval: 100,
                              getTitlesWidget: (value, meta) {
                                if ((value % 100).abs() > 0.01) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Text(
                                    '${formatter.distanceValue(value).round()} ${formatter.distanceUnit}',
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
                            if (!showStages || event is! FlTapUpEvent) return;
                            final touched = response?.lineBarSpots;
                            if (touched == null) return;
                            for (final spot in touched) {
                              if (spot.barIndex == 1 &&
                                  spot.spotIndex < stageMarks.length) {
                                onStageTap(
                                  stageMarks[spot.spotIndex].stageIndex,
                                );
                                return;
                              }
                            }
                          },
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => _ink,
                            getTooltipItems: (spots) => spots.map((spot) {
                              if (showStages) return null;
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
                                      ? point.reverseDistanceKm
                                      : point.distanceKm,
                                  point.altitudeM,
                                ),
                            ],
                            isCurved: false,
                            color: _green,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _green.withValues(alpha: 0.34),
                                  _green.withValues(alpha: 0.03),
                                ],
                              ),
                            ),
                          ),
                          if (displayedStageMarks.isNotEmpty)
                            LineChartBarData(
                              spots: [
                                for (final mark in displayedStageMarks)
                                  FlSpot(
                                    direction.distanceFromStart(
                                      mark.stage.accumulatedDistanceKm!,
                                      totalDistance,
                                    ),
                                    mark.stage.altitudeM!,
                                  ),
                              ],
                              color: Colors.transparent,
                              barWidth: 0,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                      radius:
                                          displayedStageMarks[index]
                                                  .stageIndex ==
                                              selectedStageIndex
                                          ? 4.5
                                          : 2.5,
                                      color:
                                          displayedStageMarks[index]
                                                  .stageIndex ==
                                              selectedStageIndex
                                          ? const Color(0xFF1565C0)
                                          : displayedStageMarks[index]
                                                    .stageIndex ==
                                                startStageMark?.stageIndex
                                          ? _green
                                          : displayedStageMarks[index]
                                                    .stageIndex ==
                                                endStageMark?.stageIndex
                                          ? _red
                                          : const Color(0xFFF2C94C),
                                      strokeWidth:
                                          displayedStageMarks[index]
                                                  .stageIndex ==
                                              selectedStageIndex
                                          ? 2.4
                                          : 1.2,
                                      strokeColor:
                                          displayedStageMarks[index]
                                                  .stageIndex ==
                                              selectedStageIndex
                                          ? Colors.white
                                          : _ink,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 350),
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
                  if (selectedStage != null && !stagesExplicitlyHidden)
                    Align(
                      alignment: Alignment.topCenter,
                      child: _ElevationStageSummary(
                        stage: selectedStage,
                        formatter: formatter,
                        distanceKm: direction.distanceFromStart(
                          selectedStage.accumulatedDistanceKm!,
                          totalDistance,
                        ),
                        onTap: onStageSummaryTap,
                        onClose: onStageSummaryClose,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ElevationMetric(
                icon: Icons.route_rounded,
                value: formatter.distance(totalDistance),
                label: context.l10n.t('Trail distance'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ElevationMetric(
                icon: Icons.north_east_rounded,
                value: formatter.altitude(highest.altitudeM),
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
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2E6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.landscape_rounded, color: _orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.t(
                    'The Troodos section contains the route’s largest climbs. Plan water and daylight before entering long mountain stages.',
                  ),
                  style: const TextStyle(
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

class _ElevationStageSummary extends StatelessWidget {
  const _ElevationStageSummary({
    required this.stage,
    required this.distanceKm,
    required this.formatter,
    required this.onTap,
    required this.onClose,
  });

  final TrailStage stage;
  final double distanceKm;
  final MeasurementFormatter formatter;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      context.l10n.stage(stage.sequence),
      formatter.distance(distanceKm),
      if (stage.altitudeM != null) formatter.altitude(stage.altitudeM!),
    ].join(' · ');

    return SizedBox(
      width: 208,
      height: 68,
      child: Material(
        color: Colors.white,
        elevation: 5,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('elevation-stage-summary'),
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

class _ElevationControl extends StatelessWidget {
  const _ElevationControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: _ink),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _green, size: 21),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.l10n.t('Preparing the offline elevation profile…')),
        ],
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart_rounded, size: 52, color: _green),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.download_rounded),
              label: Text(context.l10n.t('Download profile')),
            ),
          ],
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
