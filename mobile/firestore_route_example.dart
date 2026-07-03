/*
Firebase dependencies for a Flutter app:

dependencies:
  firebase_core: ^4.11.0
  cloud_firestore: ^6.6.0

Before using this in a real Flutter app, configure Firebase for the target
platforms and call Firebase.initializeApp() in main().
*/

import 'package:cloud_firestore/cloud_firestore.dart';

typedef LatLng = ({double lat, double lng});
typedef ElevationPoint = ({double distanceKm, double altitudeM});

class RoutePoint {
  const RoutePoint({
    required this.lat,
    required this.lng,
    required this.altitudeM,
    required this.distanceKm,
    required this.reverseDistanceKm,
  });

  final double lat;
  final double lng;
  final double altitudeM;
  final double distanceKm;
  final double reverseDistanceKm;
}

class RouteMarker {
  const RouteMarker({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.pointIndex,
    required this.distanceKm,
    required this.altitudeM,
    this.stageId,
  });

  final String id;
  final String name;
  final String? stageId;
  final double lat;
  final double lng;
  final int pointIndex;
  final double distanceKm;
  final double altitudeM;

  bool get isStageLinked => stageId != null && stageId!.isNotEmpty;
}

class RouteBounds {
  const RouteBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
}

class RouteRenderData {
  const RouteRenderData({
    required this.bounds,
    required this.polyline,
    required this.elevation,
    required this.markers,
  });

  final RouteBounds bounds;
  final List<LatLng> polyline;
  final List<ElevationPoint> elevation;
  final List<RouteMarker> markers;
}

Future<RouteRenderData> loadRouteForMap({
  required FirebaseFirestore firestore,
  String trailId = 'cyprus-e4',
}) async {
  final trailRef = firestore.collection('trails').doc(trailId);

  final results = await Future.wait<dynamic>([
    trailRef.collection('routeMetadata').doc('main').get(),
    trailRef.collection('routeChunks').orderBy('chunkIndex').get(),
    trailRef.collection('routeMarkers').orderBy('pointIndex').get(),
  ]);

  final metadataSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
  final chunksSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
  final markersSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;

  final metadata = metadataSnapshot.data();
  if (metadata == null) {
    throw StateError('Missing routeMetadata/main for trailId=$trailId');
  }

  final chunks = [
    for (final doc in chunksSnapshot.docs) {'id': doc.id, ...doc.data()},
  ];
  final markers = [
    for (final doc in markersSnapshot.docs) {'id': doc.id, ...doc.data()},
  ];

  return buildRouteRenderData(
    metadata: metadata,
    chunks: chunks,
    markers: markers,
  );
}

RouteRenderData buildRouteRenderData({
  required Map<String, dynamic> metadata,
  required List<Map<String, dynamic>> chunks,
  required List<Map<String, dynamic>> markers,
}) {
  final routePoints = expandRouteChunks(
    chunks,
    pointStride: metadata['pointStride'] as int? ?? 5,
  );

  return RouteRenderData(
    bounds: parseBounds(metadata['bounds'] as Map<String, dynamic>),
    polyline: [
      for (final point in routePoints) (lat: point.lat, lng: point.lng),
    ],
    elevation: [
      for (final point in routePoints)
        (distanceKm: point.distanceKm, altitudeM: point.altitudeM),
    ],
    markers: parseRouteMarkers(markers),
  );
}

List<RoutePoint> expandRouteChunks(
  List<Map<String, dynamic>> chunks, {
  int pointStride = 5,
}) {
  final sortedChunks = [
    ...chunks,
  ]..sort((a, b) => (a['chunkIndex'] as int).compareTo(b['chunkIndex'] as int));

  final routePoints = <RoutePoint>[];

  for (final chunk in sortedChunks) {
    final flatPoints = (chunk['points'] as List).cast<num>();

    if (flatPoints.length % pointStride != 0) {
      throw FormatException(
        'Chunk ${chunk['id'] ?? chunk['chunkIndex']} has '
        '${flatPoints.length} values, which is not divisible by '
        'pointStride=$pointStride.',
      );
    }

    for (var offset = 0; offset < flatPoints.length; offset += pointStride) {
      routePoints.add(
        RoutePoint(
          lat: flatPoints[offset].toDouble(),
          lng: flatPoints[offset + 1].toDouble(),
          altitudeM: flatPoints[offset + 2].toDouble(),
          distanceKm: flatPoints[offset + 3].toDouble(),
          reverseDistanceKm: flatPoints[offset + 4].toDouble(),
        ),
      );
    }
  }

  return routePoints;
}

List<RouteMarker> parseRouteMarkers(List<Map<String, dynamic>> markers) {
  final sortedMarkers = [
    ...markers,
  ]..sort((a, b) => (a['pointIndex'] as int).compareTo(b['pointIndex'] as int));

  return [
    for (final marker in sortedMarkers)
      RouteMarker(
        id: marker['id'] as String,
        name: (marker['stageName'] ?? marker['name'] ?? marker['id']) as String,
        stageId: marker['stageId'] as String?,
        lat: locationLatitude(marker['location']),
        lng: locationLongitude(marker['location']),
        pointIndex: marker['pointIndex'] as int,
        distanceKm: (marker['distanceKm'] as num).toDouble(),
        altitudeM: (marker['altitudeM'] as num).toDouble(),
      ),
  ];
}

RouteBounds parseBounds(Map<String, dynamic> bounds) {
  return RouteBounds(
    minLat: (bounds['minLat'] as num).toDouble(),
    maxLat: (bounds['maxLat'] as num).toDouble(),
    minLng: (bounds['minLng'] as num).toDouble(),
    maxLng: (bounds['maxLng'] as num).toDouble(),
  );
}

double locationLatitude(Object? location) {
  if (location is GeoPoint) {
    return location.latitude;
  }
  if (location is Map<String, dynamic>) {
    return (location['latitude'] as num).toDouble();
  }
  throw FormatException('Unsupported marker location value: $location');
}

double locationLongitude(Object? location) {
  if (location is GeoPoint) {
    return location.longitude;
  }
  if (location is Map<String, dynamic>) {
    return (location['longitude'] as num).toDouble();
  }
  throw FormatException('Unsupported marker location value: $location');
}

/*
Typical UI usage after loading:

final route = await loadRouteForMap(firestore: FirebaseFirestore.instance);

drawPolyline(route.polyline);
drawElevationChart(route.elevation);
drawTriangleMarkers(route.markers.map((m) => (lat: m.lat, lng: m.lng)));

The marker-to-route relationship is carried by pointIndex and distanceKm, but
for drawing markers on the map you can use marker.lat and marker.lng directly.
*/
