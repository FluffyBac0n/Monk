import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/measurement_formatter.dart';
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
    var height = 48.0;
    for (final line in _statusLines(context)) {
      final painter = TextPainter(
        text: TextSpan(
          text: line.text,
          style: DefaultTextStyle.of(context).style.merge(line.style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      height += painter.height;
      painter.dispose();
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final route = controller.route;
    final failure = controller.failure;
    final straight = controller.straightLineDistanceM;
    final status = _statusLines(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('poi-directions-button'),
                onPressed: controller.busy
                    ? null
                    : () => onDirections(controller.mode),
                icon: controller.busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.directions_rounded),
                label: Text(
                  l10n.t(controller.busy ? 'Finding route…' : 'Directions'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<DirectionsMode>(
              key: const ValueKey('poi-directions-mode'),
              enabled: !controller.busy,
              tooltip: l10n.t('Travel mode'),
              initialValue: controller.mode,
              onSelected: onDirections,
              itemBuilder: (_) => [
                for (final mode in DirectionsMode.values)
                  PopupMenuItem(
                    value: mode,
                    child: Text(
                      l10n.t(
                        mode == DirectionsMode.walking ? 'Walking' : 'Driving',
                      ),
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      controller.mode == DirectionsMode.walking
                          ? Icons.directions_walk
                          : Icons.directions_car,
                      size: 20,
                    ),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
            if (route != null || controller.busy || failure != null)
              IconButton(
                key: const ValueKey('poi-directions-clear'),
                tooltip: l10n.t('Clear route'),
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        if (route != null)
          Text(
            status.first.text,
            key: const ValueKey('poi-directions-summary'),
            style: status.first.style,
          ),
        if (failure != null)
          Text(
            l10n.t(directionsFailureMessage(failure)),
            key: const ValueKey('poi-directions-error'),
            style: const TextStyle(fontSize: 14),
          ),
        if (route == null && straight != null)
          Text(
            '${formatter.proximityDistance(straight)} · ${l10n.t('Straight-line distance from you')}',
            key: const ValueKey('poi-straight-line-distance'),
            style: const TextStyle(fontSize: 14),
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
  Widget build(BuildContext context) => ExpansionTile(
    key: const ValueKey('poi-directions-instructions'),
    tilePadding: EdgeInsets.zero,
    title: Text(context.l10n.t('Route directions')),
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
