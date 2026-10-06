import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/poi_directions.dart';

final poiDirectionsServiceProvider =
    Provider.family<PoiDirectionsService, String>(
      (ref, token) => PoiDirectionsService(accessToken: token),
    );

typedef DirectionsTransport = Future<Map<String, dynamic>> Function(Uri uri);

class PoiDirectionsService {
  PoiDirectionsService({
    required this.accessToken,
    Future<DirectionsCoordinate> Function()? locate,
    Future<bool> Function()? isOnline,
    DirectionsTransport? transport,
  }) : locate = locate ?? _locate,
       isOnline = isOnline ?? _isOnline,
       _transport = transport ?? _request;

  final String accessToken;
  final Future<DirectionsCoordinate> Function() locate;
  final Future<bool> Function() isOnline;
  final DirectionsTransport _transport;

  Future<PoiDirections> route({
    required DirectionsCoordinate origin,
    required DirectionsCoordinate destination,
    required DirectionsMode mode,
    required String language,
  }) async {
    if (!await isOnline()) {
      throw const DirectionsException(DirectionsFailure.offline);
    }
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/${mode.name}/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}',
      {
        'access_token': accessToken,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
        'language': {'en', 'de', 'es', 'it', 'fr'}.contains(language)
            ? language
            : 'en',
      },
    );
    try {
      return PoiDirections.fromJson(await _transport(uri));
    } on DirectionsException {
      rethrow;
    } on SocketException {
      throw const DirectionsException(DirectionsFailure.offline);
    } catch (_) {
      // Do not surface HTTP exceptions: they can contain the access token.
      throw const DirectionsException(DirectionsFailure.serviceUnavailable);
    }
  }
}

Future<bool> _isOnline() async => !(await Connectivity().checkConnectivity())
    .contains(ConnectivityResult.none);

Future<DirectionsCoordinate> _locate() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DirectionsException(DirectionsFailure.locationDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const DirectionsException(DirectionsFailure.permissionDenied);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return (latitude: position.latitude, longitude: position.longitude);
  } on DirectionsException {
    rethrow;
  } catch (_) {
    throw const DirectionsException(DirectionsFailure.locationUnavailable);
  }
}

Future<Map<String, dynamic>> _request(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    return await (() async {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw const DirectionsException(DirectionsFailure.serviceUnavailable);
      }
      return jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;
    })().timeout(const Duration(seconds: 30));
  } finally {
    client.close(force: true);
  }
}
