import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
}

class LocationServicesDisabledException implements Exception {
  const LocationServicesDisabledException();
}

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();
}

typedef DeviceLocationReader = Future<DeviceLocation> Function();

final deviceLocationReaderProvider = Provider<DeviceLocationReader>((ref) {
  return () async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw const LocationServicesDisabledException();
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException();
    }

    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
    );
  };
});
