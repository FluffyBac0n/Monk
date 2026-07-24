/// Estimates moving time using Naismith's rule:
/// one hour per 5 km of distance plus one hour per 600 m of ascent.
///
/// The estimate deliberately excludes breaks, terrain, weather, load, fitness,
/// and descent penalties. The caller should label the result as an estimate.
Duration estimateNaismithWalkingTime({
  required double distanceKm,
  required double ascentM,
}) {
  if (!distanceKm.isFinite || distanceKm < 0) {
    throw ArgumentError.value(
      distanceKm,
      'distanceKm',
      'must be finite and ≥ 0',
    );
  }
  if (!ascentM.isFinite || ascentM < 0) {
    throw ArgumentError.value(ascentM, 'ascentM', 'must be finite and ≥ 0');
  }

  final estimatedMinutes = (distanceKm * 12 + ascentM / 10).round();
  final hasMovement = distanceKm > 0 || ascentM > 0;
  return Duration(
    minutes: hasMovement && estimatedMinutes == 0 ? 1 : estimatedMinutes,
  );
}
