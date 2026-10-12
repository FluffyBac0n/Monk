import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../domain/poi_directions.dart';
import 'poi_directions_controller.dart';

class PoiDirectionsCard extends StatelessWidget {
  const PoiDirectionsCard({
    super.key,
    required this.controller,
    required this.formatter,
    required this.onDirections,
    required this.onClear,
  });
  final PoiDirectionsController controller;
  final MeasurementFormatter formatter;
  final ValueChanged<DirectionsMode> onDirections;
  final VoidCallback onClear;

  List<({String text, TextStyle style})> _statusLines(BuildContext context) {
    final l10n = context.l10n;
    final route = controller.route;
    return [
      if (route != null)
        (
          text:
              '${formatter.proximityDistance(route.distanceM)} · '
              '${directionsDuration(route.durationSeconds, l10n)} · '
              '${l10n.t(controller.mode == DirectionsMode.walking ? 'Walking' : 'Driving')}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      if (controller.failure case final failure?)
        (
          text: l10n.t(directionsFailureMessage(failure)),
          style: const TextStyle(fontSize: 14),
        ),
      if (route == null)
        if (controller.straightLineDistanceM case final distance?)
          (
            text:
                '${formatter.proximityDistance(distance)} · ${l10n.t('Straight-line distance from you')}',
            style: const TextStyle(fontSize: 14),
          ),
    ];
  }

  /// Fit the collapsed sheet to its actual status text, including larger text
  /// settings and wrapped offline messages, without revealing contact details.
  double compactHeight(BuildContext context, double width) {
    var height = 0.0;
    final canClear =
        controller.route != null ||
        controller.busy ||
        controller.failure != null;
    for (final line in _statusLines(context)) {
      final painter =
          TextPainter(
            text: TextSpan(
              text: line.text,
              style: DefaultTextStyle.of(context).style.merge(line.style),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(
            maxWidth:
                width -
                (canClear ? 48 : 0) -
                (controller.route != null ? 48 : 0),
          );
      height += painter.height;
      painter.dispose();
    }
    return canClear && height < 48 ? 48 : height;
  }

  bool get hasStatus =>
      controller.route != null ||
      controller.busy ||
      controller.failure != null ||
      controller.straightLineDistanceM != null;

  Widget headerActions(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('poi-directions-button'),
          tooltip: l10n.t(controller.busy ? 'Finding route…' : 'Directions'),
          color: Colors.white,
          disabledColor: Colors.white54,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: controller.busy
              ? null
              : () => onDirections(controller.mode),
          icon: controller.busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.directions_rounded),
        ),
        PopupMenuButton<DirectionsMode>(
          key: const ValueKey('poi-directions-mode'),
          enabled: !controller.busy,
          tooltip: l10n.t('Travel mode'),
          initialValue: controller.mode,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          position: PopupMenuPosition.over,
          constraints: const BoxConstraints(minWidth: 200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: EurotrexPalette.paleBlue),
          ),
          onSelected: onDirections,
          itemBuilder: (_) => [
            for (final mode in DirectionsMode.values)
              PopupMenuItem(
                value: mode,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: mode == controller.mode
                        ? EurotrexPalette.paleBlue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        mode == DirectionsMode.walking
                            ? Icons.directions_walk_rounded
                            : Icons.directions_car_rounded,
                        color: EurotrexPalette.navy,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.t(
                            mode == DirectionsMode.walking
                                ? 'Walking'
                                : 'Driving',
                          ),
                          style: const TextStyle(
                            color: EurotrexPalette.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        mode == controller.mode
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: mode == controller.mode
                            ? EurotrexPalette.blue
                            : EurotrexPalette.navy,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
          ],
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  controller.mode == DirectionsMode.walking
                      ? Icons.directions_walk_rounded
                      : Icons.directions_car_rounded,
                  color: controller.busy ? Colors.grey : Colors.white,
                  size: 20,
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => summary(context);

  Widget summary(
    BuildContext context, {
    bool expanded = false,
    VoidCallback? onToggle,
  }) {
    if (!hasStatus) return const SizedBox.shrink();
    final status = _statusLines(context);
    final canClear =
        controller.route != null ||
        controller.busy ||
        controller.failure != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < status.length; i++)
                    Text(
                      status[i].text,
                      key: ValueKey(
                        controller.route != null && i == 0
                            ? 'poi-directions-summary'
                            : controller.failure != null && i == 0
                            ? 'poi-directions-error'
                            : 'poi-straight-line-distance',
                      ),
                      style: status[i].style,
                    ),
                ],
              ),
            ),
            if (controller.route != null)
              IconButton(
                key: const ValueKey('poi-directions-expand'),
                tooltip: context.l10n.t('Route directions'),
                color: EurotrexPalette.navy,
                onPressed: onToggle,
                icon: Icon(
                  expanded
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                ),
              ),
            if (canClear)
              IconButton(
                key: const ValueKey('poi-directions-clear'),
                tooltip: context.l10n.t('Clear route'),
                color: EurotrexPalette.navy,
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        if (expanded && controller.route != null)
          PoiDirectionsInstructions(
            route: controller.route!,
            formatter: formatter,
          ),
      ],
    );
  }
}

String directionsDuration(double seconds, AppLocalizations l10n) {
  final minutes = (seconds / 60).ceil().clamp(1, 1000000);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$minutes ${l10n.t('min')}';
  return '$hours ${l10n.t('h')}${rest == 0 ? '' : ' $rest ${l10n.t('min')}'}';
}

class PoiDirectionsInstructions extends StatelessWidget {
  const PoiDirectionsInstructions({
    super.key,
    required this.route,
    required this.formatter,
  });
  final PoiDirections route;
  final MeasurementFormatter formatter;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('poi-directions-instructions'),
    children: [
      for (final step in route.steps)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(step.instruction),
          trailing: Text(formatter.proximityDistance(step.distanceM)),
        ),
    ],
  );
}

String directionsFailureMessage(DirectionsFailure failure) => switch (failure) {
  DirectionsFailure.offline => 'Connect to the internet to get directions.',
  DirectionsFailure.noRoute =>
    'No route found for this travel mode. Try another mode.',
  DirectionsFailure.locationDisabled =>
    'Turn on Location Services to get directions.',
  DirectionsFailure.permissionDenied =>
    'Allow location access to get directions.',
  DirectionsFailure.locationUnavailable =>
    'Your location could not be read. Try again.',
  DirectionsFailure.serviceUnavailable =>
    'Directions are unavailable right now. Try again.',
};
