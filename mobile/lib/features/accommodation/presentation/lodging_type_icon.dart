import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const mapboxOutdoorAccommodationGreen = Color(0xFF38890F);
const mapboxLodgingMauve = Color(0xFF8C727B);

final _markerImages = <String, Future<Uint8List>>{};

/// The map and cards use the same bundled Maki artwork on every map style.
Future<Uint8List> lodgingMarkerImage(String? type) => _markerImages.putIfAbsent(
  lodgingMakiIconName(type),
  () => _renderMarker(type),
);

Future<Uint8List> _renderMarker(String? type) async {
  final info = await vg.loadPicture(
    SvgAssetLoader('assets/maki/${lodgingMakiIconName(type)}.svg'),
    null,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(const Offset(21, 21), 20, Paint()..color = Colors.white);
  canvas.drawCircle(
    const Offset(21, 21),
    18,
    Paint()..color = lodgingMakiMarkerColor(type),
  );
  canvas.save();
  canvas.translate(8.5, 8.5);
  canvas.scale(25 / info.size.width, 25 / info.size.height);
  canvas.saveLayer(
    Offset.zero & info.size,
    Paint()
      ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn),
  );
  canvas.drawPicture(info.picture);
  canvas.restore();
  canvas.restore();
  info.picture.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(42, 42);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

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
