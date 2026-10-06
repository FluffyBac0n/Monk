import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/poi_directions_service.dart';
import '../domain/poi_directions.dart';

class PoiDirectionsController extends ChangeNotifier {
  PoiDirectionsController(this.service);
  final PoiDirectionsService service;
  int _generation = 0;
  bool busy = false;
  DirectionsMode mode = DirectionsMode.walking;
  PoiDirections? route;
  double? straightLineDistanceM;
  DirectionsFailure? failure;

  Future<void> load({
    required DirectionsCoordinate destination,
    required DirectionsMode mode,
    required String language,
  }) async {
    final generation = ++_generation;
    this.mode = mode;
    busy = true;
    route = null;
    failure = null;
    straightLineDistanceM = null;
    notifyListeners();
    try {
      final origin = await service.locate();
      if (generation != _generation) return;
      straightLineDistanceM = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
      final result = await service.route(
        origin: origin,
        destination: destination,
        mode: mode,
        language: language,
      );
      if (generation != _generation) return;
      route = result;
    } on DirectionsException catch (error) {
      if (generation != _generation) return;
      failure = error.failure;
    } catch (_) {
      if (generation != _generation) return;
      failure = DirectionsFailure.serviceUnavailable;
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _generation++;
    route = null;
    straightLineDistanceM = null;
    failure = null;
    busy = false;
    mode = DirectionsMode.walking;
    notifyListeners();
  }

  void mapUnavailable() {
    route = null;
    failure = DirectionsFailure.serviceUnavailable;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
