import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/eurotrex_palette.dart';
import 'report_status_badge.dart';

IconData reportDamageIcon(String category) => switch (category) {
  'signpost' => Icons.signpost_outlined,
  'vegetation' => Icons.grass_rounded,
  'obstruction' => Icons.landscape_outlined,
  'path_damage' => Icons.route_outlined,
  _ => Icons.warning_amber_rounded,
};

class ReportCardHeader extends StatelessWidget {
  const ReportCardHeader({
    super.key,
    required this.category,
    required this.title,
    required this.uploadState,
    this.remoteStatus,
  });

  final String category, title, uploadState;
  final String? remoteStatus;

  @override
  Widget build(BuildContext context) {
    final badge = ReportStatusBadge(
      uploadState: uploadState,
      remoteStatus: remoteStatus,
    );
    final titleStyle = Theme.of(context).textTheme.titleMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final badgeMeasure = TextPainter(
          text: TextSpan(
            text: badge.localizedLabel(context),
            style: ReportStatusBadge.textStyle,
          ),
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        final titleMeasure = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        final badgeWidth = badgeMeasure.width + 24;
        // Reserve readable title space; wrap the badge for narrow cards, long
        // translated statuses or accessibility text sizes rather than truncate.
        final inline =
            constraints.maxWidth >=
            46 +
                math.min(scaler.scale(140), titleMeasure.width) +
                12 +
                badgeWidth;
        badgeMeasure.dispose();
        titleMeasure.dispose();
        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: EurotrexPalette.paleBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                reportDamageIcon(category),
                color: EurotrexPalette.navy,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: titleStyle)),
          ],
        );
        if (inline) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 12),
              badge,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 10), badge],
        );
      },
    );
  }
}
