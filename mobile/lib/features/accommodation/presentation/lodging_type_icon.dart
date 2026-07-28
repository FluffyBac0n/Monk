import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const mapboxOutdoorAccommodationGreen = Color(0xFF38890F);
const mapboxLodgingMauve = Color(0xFF8C727B);

String lodgingMakiIconName(String? type) {
  final normalized = type?.trim().toLowerCase() ?? '';
  if (normalized.contains('picnic')) return 'picnic-site';
  if (normalized.contains('camp') || normalized.contains('tent')) {
    return 'campsite';
  }
  if (normalized.contains('shelter') ||
      normalized.contains('refuge') ||
      normalized.contains('hut')) {
    return 'shelter';
  }
  if (normalized.contains('agrotour') ||
      normalized.contains('farm') ||
      normalized.contains('rural')) {
    return 'farm';
  }
  if (normalized.contains('religious') ||
      normalized.contains('monastery') ||
      normalized.contains('convent')) {
    return 'place-of-worship';
  }
  if (normalized.contains('municipal') || normalized.contains('community')) {
    return 'town-hall';
  }
  if (normalized.contains('apartment') ||
      normalized.contains('flat') ||
      normalized.contains('villa') ||
      normalized.contains('holiday home')) {
    return 'residential-community';
  }
  if (normalized.contains('hostel')) return 'suitcase';
  if (normalized.contains('guest') ||
      normalized.contains('bed & breakfast') ||
      normalized.contains('bed and breakfast') ||
      normalized.contains('b&b')) {
    return 'home';
  }
  return 'lodging';
}

Color lodgingMakiMarkerColor(String? type) {
  return switch (lodgingMakiIconName(type)) {
    'picnic-site' ||
    'campsite' ||
    'shelter' ||
    'farm' => mapboxOutdoorAccommodationGreen,
    _ => mapboxLodgingMauve,
  };
}

class LodgingTypeIcon extends StatelessWidget {
  const LodgingTypeIcon({
    required this.type,
    required this.color,
    this.size = 26,
    super.key,
  });

  final String? type;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconName = lodgingMakiIconName(type);
    return SvgPicture.asset(
      'assets/maki/$iconName.svg',
      key: ValueKey('lodging-type-icon-$iconName'),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
