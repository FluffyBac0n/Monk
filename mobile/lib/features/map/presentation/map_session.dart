import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'map_background_sheet.dart';

/// Survives map routes being popped, without keeping native maps or GPS streams
/// alive. Each trail has its own browsing session for the lifetime of the app.
final mapSessionProvider = Provider.family<MapSession, String>(
  (ref, trailId) => MapSession(),
);

class MapSession {
  CameraState? camera;
  MapBackground background = MapBackground.terrain;
  bool gpsEnabled = false;
  bool stagesVisible = false;
  bool stagesExplicitlyHidden = false;
  bool lodgingsVisible = false;
  bool excursionsVisible = false;
  bool detoursVisible = false;
}

/// A location fix may recenter after an explicit GPS tap, but must never set
/// zoom, pitch, bearing or padding. Subsequent fixes only update the puck.
CameraOptions? mapGpsCameraUpdate({
  required bool explicitFocus,
  required double latitude,
  required double longitude,
}) => explicitFocus
    ? CameraOptions(center: Point(coordinates: Position(longitude, latitude)))
    : null;
