class RoutePoint {
  const RoutePoint({
    required this.pointIndex,
    required this.lat,
    required this.lng,
    required this.altitudeM,
    required this.distanceKm,
    required this.reverseDistanceKm,
  });

  final int pointIndex;
  final double lat;
  final double lng;
  final double altitudeM;
  final double distanceKm;
  final double reverseDistanceKm;
}
