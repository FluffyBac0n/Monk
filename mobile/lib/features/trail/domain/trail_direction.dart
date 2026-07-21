enum TrailDirection {
  pafosToLarnaka,
  larnakaToPafos;

  bool get isReversed => this == TrailDirection.larnakaToPafos;

  String get startName => isReversed ? 'Larnaka Airport' : 'Pafos Airport';

  String get endName => isReversed ? 'Pafos Airport' : 'Larnaka Airport';

  String get routeLabel => '$startName  →  $endName';

  String get compactLabel =>
      isReversed ? 'LARNAKA TO PAFOS' : 'PAFOS TO LARNAKA';

  double distanceFromStart(double pafosDistanceKm, double totalDistanceKm) {
    return isReversed
        ? (totalDistanceKm - pafosDistanceKm)
              .clamp(0.0, totalDistanceKm)
              .toDouble()
        : pafosDistanceKm;
  }
}
