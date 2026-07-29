import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const mapFlagMarkerWidth = 42;
const mapFlagMarkerHeight = 42;

final Map<int, Future<Uint8List>> _flagMarkerImages = {};

Future<Uint8List> mapFlagMarkerImage(Color color) {
  return _flagMarkerImages.putIfAbsent(
    color.toARGB32(),
    () => _renderFlagMarker(color),
  );
}

Future<Uint8List> _renderFlagMarker(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(mapFlagMarkerWidth / 2, mapFlagMarkerHeight / 2);
  const radius = 17.5;
  const poleX = 17.0;
  const poleTop = 12.5;
  const poleBottom = 30.5;

  canvas.drawCircle(
    center.translate(0, 1.5),
    radius + 1,
    Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    center,
    radius - 3,
    Paint()
      ..color = color
      ..style = PaintingStyle.fill,
  );

  final flag = Path()
    ..moveTo(poleX, poleTop + 1)
    ..cubicTo(22, 10.5, 26.5, 14.5, 31.5, 12)
    ..lineTo(31.5, 21.5)
    ..cubicTo(26.5, 24, 22, 20, poleX, 22.5)
    ..close();

  final flagPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawLine(
    const Offset(poleX, poleTop),
    const Offset(poleX, poleBottom),
    Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(flag, flagPaint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(mapFlagMarkerWidth, mapFlagMarkerHeight);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) {
    throw StateError('Could not render the map flag marker.');
  }
  return bytes.buffer.asUint8List();
}
