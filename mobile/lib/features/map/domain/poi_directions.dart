typedef DirectionsCoordinate = ({double latitude, double longitude});

enum DirectionsMode { walking, driving }

enum DirectionsFailure {
  offline,
  noRoute,
  locationDisabled,
  permissionDenied,
  locationUnavailable,
  serviceUnavailable,
}

class DirectionsException implements Exception {
  const DirectionsException(this.failure);
  final DirectionsFailure failure;
}

class DirectionsStep {
  const DirectionsStep({required this.instruction, required this.distanceM});
  final String instruction;
  final double distanceM;
}

class PoiDirections {
  const PoiDirections({
    required this.coordinates,
    required this.distanceM,
    required this.durationSeconds,
    required this.steps,
  });
  final List<DirectionsCoordinate> coordinates;
  final double distanceM;
  final double durationSeconds;
  final List<DirectionsStep> steps;

  factory PoiDirections.fromJson(Map<String, dynamic> json) {
    if (json['code'] == 'NoRoute' || json['code'] == 'NoSegment') {
      throw const DirectionsException(DirectionsFailure.noRoute);
    }
    try {
      if (json['code'] != 'Ok') throw const FormatException();
      final routes = json['routes'] as List;
      if (routes.isEmpty) {
        throw const DirectionsException(DirectionsFailure.noRoute);
      }
      final route = routes.first as Map;
      final geometry = route['geometry'] as Map;
      if (geometry['type'] != 'LineString') throw const FormatException();
      final coordinates = (geometry['coordinates'] as List)
          .map((value) {
            final pair = value as List;
            final longitude = (pair[0] as num).toDouble();
            final latitude = (pair[1] as num).toDouble();
            if (!latitude.isFinite ||
                !longitude.isFinite ||
                latitude.abs() > 90 ||
                longitude.abs() > 180) {
              throw const FormatException();
            }
            return (latitude: latitude, longitude: longitude);
          })
          .toList(growable: false);
      if (coordinates.length < 2) throw const FormatException();
      return PoiDirections(
        coordinates: List.unmodifiable(coordinates),
        distanceM: _nonNegative(route['distance']),
        durationSeconds: _nonNegative(route['duration']),
        steps: List.unmodifiable([
          for (final leg in route['legs'] as List)
            for (final step in leg['steps'] as List)
              DirectionsStep(
                instruction: step['maneuver']['instruction'] as String,
                distanceM: _nonNegative(step['distance']),
              ),
        ]),
      );
    } on DirectionsException {
      rethrow;
    } catch (_) {
      throw const DirectionsException(DirectionsFailure.serviceUnavailable);
    }
  }
}

double _nonNegative(Object? value) {
  final number = (value as num).toDouble();
  if (!number.isFinite || number < 0) throw const FormatException();
  return number;
}
