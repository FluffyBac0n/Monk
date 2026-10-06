import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/map/data/poi_directions_service.dart';
import 'package:eurotrex/features/map/domain/poi_directions.dart';
import 'package:eurotrex/features/map/presentation/poi_directions_controller.dart';

const origin = (latitude: 34.888, longitude: 32.862);
const destination = (latitude: 34.892, longitude: 32.869);

Map<String, dynamic> routeJson() => {
  'code': 'Ok',
  'routes': [
    {
      'distance': 1200,
      'duration': 900,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [32.862, 34.888],
          [32.869, 34.892],
        ],
      },
      'legs': [
        {
          'steps': [
            {
              'distance': 1200,
              'maneuver': {'instruction': 'Continue to the hotel'},
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  test(
    'Directions request uses longitude first and returns route geometry, ETA and steps',
    () async {
      Uri? requested;
      final service = PoiDirectionsService(
        accessToken: 'test-token',
        isOnline: () async => true,
        transport: (uri) async {
          requested = uri;
          return routeJson();
        },
      );
      final route = await service.route(
        origin: origin,
        destination: destination,
        mode: DirectionsMode.walking,
        language: 'de',
      );
      expect(
        requested!.path,
        '/directions/v5/mapbox/walking/32.862,34.888;32.869,34.892',
      );
      expect(requested!.queryParameters['geometries'], 'geojson');
      expect(requested!.queryParameters['steps'], 'true');
      expect(requested!.queryParameters['language'], 'de');
      expect(route.coordinates, [origin, destination]);
      expect(route.distanceM, 1200);
      expect(route.durationSeconds, 900);
      expect(route.steps.single.instruction, 'Continue to the hotel');
    },
  );

  test('offline routing keeps GPS distance but makes no API request', () async {
    var requests = 0;
    final controller = PoiDirectionsController(
      PoiDirectionsService(
        accessToken: 'test',
        locate: () async => origin,
        isOnline: () async => false,
        transport: (_) async {
          requests++;
          return routeJson();
        },
      ),
    );
    addTearDown(controller.dispose);
    await controller.load(
      destination: destination,
      mode: DirectionsMode.walking,
      language: 'en',
    );
    expect(controller.failure, DirectionsFailure.offline);
    expect(controller.route, isNull);
    expect(controller.straightLineDistanceM, greaterThan(0));
    expect(requests, 0);
    expect(controller.busy, false);
  });

  test('clearing an in-flight request prevents the route returning', () async {
    final response = Completer<Map<String, dynamic>>();
    final requested = Completer<void>();
    final controller = PoiDirectionsController(
      PoiDirectionsService(
        accessToken: 'test',
        locate: () async => origin,
        isOnline: () async => true,
        transport: (_) {
          requested.complete();
          return response.future;
        },
      ),
    );
    addTearDown(controller.dispose);
    final pending = controller.load(
      destination: destination,
      mode: DirectionsMode.walking,
      language: 'en',
    );
    await requested.future;
    controller.clear();
    response.complete(routeJson());
    await pending;
    expect(controller.route, isNull);
    expect(controller.straightLineDistanceM, isNull);
    expect(controller.busy, false);
  });

  test('new travel mode wins over an older delayed result', () async {
    final walking = Completer<Map<String, dynamic>>();
    final requested = Completer<void>();
    final controller = PoiDirectionsController(
      PoiDirectionsService(
        accessToken: 'test',
        locate: () async => origin,
        isOnline: () async => true,
        transport: (uri) {
          if (uri.path.contains('/walking/')) {
            requested.complete();
            return walking.future;
          }
          return Future.value(routeJson()..['routes'][0]['distance'] = 2000);
        },
      ),
    );
    addTearDown(controller.dispose);
    final pending = controller.load(
      destination: destination,
      mode: DirectionsMode.walking,
      language: 'en',
    );
    await requested.future;
    await controller.load(
      destination: destination,
      mode: DirectionsMode.driving,
      language: 'en',
    );
    walking.complete(routeJson());
    await pending;
    expect(controller.mode, DirectionsMode.driving);
    expect(controller.route!.distanceM, 2000);
  });

  for (final code in ['NoRoute', 'NoSegment']) {
    test('$code yields a useful no-route error', () {
      expect(
        () => PoiDirections.fromJson({'code': code}),
        throwsA(
          isA<DirectionsException>().having(
            (e) => e.failure,
            'failure',
            DirectionsFailure.noRoute,
          ),
        ),
      );
    });
  }

  test('bad geometry and invalid distance are rejected', () {
    final json = routeJson();
    json['routes'][0]['geometry']['coordinates'][0] = [200.0, 100.0];
    expect(
      () => PoiDirections.fromJson(json),
      throwsA(isA<DirectionsException>()),
    );
    final invalidDistance = routeJson();
    invalidDistance['routes'][0]['distance'] = -5;
    expect(
      () => PoiDirections.fromJson(invalidDistance),
      throwsA(isA<DirectionsException>()),
    );
  });

  test('denied permission does not contact the directions service', () async {
    final controller = PoiDirectionsController(
      PoiDirectionsService(
        accessToken: 'test',
        locate: () async =>
            throw const DirectionsException(DirectionsFailure.permissionDenied),
        transport: (_) async => fail('Unexpected API request'),
      ),
    );
    addTearDown(controller.dispose);
    await controller.load(
      destination: destination,
      mode: DirectionsMode.walking,
      language: 'en',
    );
    expect(controller.failure, DirectionsFailure.permissionDenied);
    expect(controller.straightLineDistanceM, isNull);
  });

  test(
    'network exceptions cannot expose token-bearing URLs to the UI',
    () async {
      final service = PoiDirectionsService(
        accessToken: 'test',
        isOnline: () async => true,
        transport: (_) async => throw const SocketException('private URL'),
      );
      expect(
        service.route(
          origin: origin,
          destination: destination,
          mode: DirectionsMode.walking,
          language: 'en',
        ),
        throwsA(
          isA<DirectionsException>().having(
            (e) => e.failure,
            'failure',
            DirectionsFailure.offline,
          ),
        ),
      );
    },
  );
}
