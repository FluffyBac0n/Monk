import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<Uint8List>? _stagePin;
Future<Uint8List> mapStagePinImage() => _stagePin ??= _renderPin();

/// Paints the shared map marker with its tip anchored at [position].
void paintStageMapPin(Canvas canvas, Offset position, {double height = 32}) {
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.scale(height / 80);
  canvas.translate(-32, -76);
  _drawPin(canvas, outline: true);
  canvas.restore();
}

class StagePinIcon extends StatelessWidget {
  const StagePinIcon({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 24,
    height: 24,
    child: Center(
      child: CustomPaint(size: Size(19.2, 24), painter: _StagePinPainter()),
    ),
  );
}

class _StagePinPainter extends CustomPainter {
  const _StagePinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 80);
    _drawPin(canvas, outline: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StagePinPainter oldDelegate) => false;
}

void _drawPin(Canvas canvas, {required bool outline}) {
  final pin = Path()
    ..moveTo(32, 76)
    ..cubicTo(26, 66, 6, 46, 6, 30)
    ..cubicTo(6, -3, 58, -3, 58, 30)
    ..cubicTo(58, 46, 38, 66, 32, 76)
    ..close();
  if (outline) {
    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
  }
  canvas.drawPath(pin, Paint()..color = const Color(0xFFC63732));
  canvas.drawCircle(const Offset(32, 29), 10, Paint()..color = Colors.white);
}

Future<Uint8List> _renderPin() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _drawPin(canvas, outline: true);
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 80);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}
