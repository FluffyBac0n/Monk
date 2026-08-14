import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/stages/domain/walking_time_estimator.dart';

void main() {
  test('uses Naismith distance and ascent allowances', () {
    final estimate = estimateNaismithWalkingTime(distanceKm: 10, ascentM: 600);

    expect(estimate, const Duration(hours: 3));
  });

  test('rounds the estimate to the nearest minute', () {
    final estimate = estimateNaismithWalkingTime(distanceKm: 6.27, ascentM: 52);

    expect(estimate, const Duration(hours: 1, minutes: 20));
  });

  test('rejects invalid inputs instead of producing a misleading estimate', () {
    expect(
      () => estimateNaismithWalkingTime(distanceKm: -1, ascentM: 0),
      throwsArgumentError,
    );
    expect(
      () => estimateNaismithWalkingTime(distanceKm: double.nan, ascentM: 0),
      throwsArgumentError,
    );
    expect(
      () => estimateNaismithWalkingTime(distanceKm: 1, ascentM: -1),
      throwsArgumentError,
    );
    expect(
      () =>
          estimateNaismithWalkingTime(distanceKm: 1, ascentM: double.infinity),
      throwsArgumentError,
    );
  });
}
