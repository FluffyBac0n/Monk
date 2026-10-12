import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../reports/domain/trail_issue.dart';

Future<Uint8List>? _warningImage;
Future<Uint8List> trailIssueMarkerImage() => _warningImage ??= _drawWarning();
Future<Uint8List> _drawWarning() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final triangle = Path()
    ..moveTo(32, 5)
    ..lineTo(60, 55)
    ..quadraticBezierTo(62, 60, 56, 60)
    ..lineTo(8, 60)
    ..quadraticBezierTo(2, 60, 4, 55)
    ..close();
  canvas.drawPath(
    triangle,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(triangle, Paint()..color = const Color(0xFFF2C94C));
  canvas.drawPath(
    triangle,
    Paint()
      ..color = const Color(0xFF9D302C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawLine(
    const Offset(32, 24),
    const Offset(32, 40),
    Paint()
      ..color = const Color(0xFF303E4E)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawCircle(
    const Offset(32, 49),
    3,
    Paint()..color = const Color(0xFF303E4E),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

/// A separate layer so issue updates never move the camera or reset POIs/GPS.
class TrailIssueLayer {
  TrailIssueLayer(this.map, this.onTap);
  final MapboxMap map;
  final void Function(TrailIssue) onTap;
  PointAnnotationManager? _manager;
  Cancelable? _listener;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  int _generation = 0;
  final Map<String, TrailIssue> _byAnnotation = {};

  Future<void> update(List<TrailIssue> issues) {
    final generation = ++_generation;
    final next = _pending.then((_) async {
      if (_disposed || generation != _generation) return;
      _listener?.cancel();
      _listener = null;
      _byAnnotation.clear();
      final old = _manager;
      _manager = null;
      if (old != null) await map.annotations.removeAnnotationManager(old);
      if (_disposed || generation != _generation || issues.isEmpty) return;
      final image = await trailIssueMarkerImage();
      if (_disposed || generation != _generation) return;
      final manager = await map.annotations.createPointAnnotationManager(
        id: 'eurotrex-official-issues',
      );
      _manager = manager;
      await manager.setIconAllowOverlap(true);
      await manager.setIconIgnorePlacement(true);
      final annotations = await manager.createMulti([
        for (final issue in issues)
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(issue.longitude, issue.latitude),
            ),
            image: image,
            iconSize: 1.3,
            iconAnchor: IconAnchor.CENTER,
            customData: {'issueId': issue.id},
          ),
      ]);
      if (_disposed || generation != _generation) return;
      for (var i = 0; i < annotations.length; i++) {
        final annotation = annotations[i];
        if (annotation != null) _byAnnotation[annotation.id] = issues[i];
      }
      _listener = manager.tapEvents(
        onTap: (annotation) {
          final issue = _byAnnotation[annotation.id];
          if (!_disposed && issue != null) onTap(issue);
        },
      );
    });
    // A disposed native map can finish a pending platform call after navigation.
    _pending = next.catchError((Object error) {
      if (!_disposed) {
        debugPrint('Could not update official trail issue markers.');
      }
    });
    return _pending;
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _listener?.cancel();
    _byAnnotation.clear();
  }
}
