import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/eurotrex_palette.dart';

/// Shared problem symbols for the report form, saved reports and map cards.
class ReportDamageIcon extends StatelessWidget {
  const ReportDamageIcon({
    super.key,
    required this.category,
    this.size = 22,
    this.color = EurotrexPalette.navy,
  });

  final String category;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final asset = switch (category) {
      'signpost' => 'broken-signpost',
      'obstruction' => 'falling-rocks',
      'path_damage' => 'damaged-path',
      _ => null,
    };
    if (asset == null) {
      return Icon(
        category == 'vegetation'
            ? Icons.grass_rounded
            : Icons.warning_amber_rounded,
        size: size,
        color: color,
      );
    }
    return SvgPicture.asset(
      'assets/report-icons/$asset.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
