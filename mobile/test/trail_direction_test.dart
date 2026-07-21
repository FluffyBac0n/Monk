import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/features/trail/domain/trail_direction.dart';

void main() {
  test('reverse direction recalculates distance from the new start', () {
    const totalDistanceKm = 558.1;

    expect(
      TrailDirection.pafosToLarnaka.distanceFromStart(100, totalDistanceKm),
      100,
    );
    expect(
      TrailDirection.larnakaToPafos.distanceFromStart(100, totalDistanceKm),
      closeTo(458.1, 0.001),
    );
  });

  test('reverse direction swaps route endpoints', () {
    expect(
      TrailDirection.larnakaToPafos.routeLabel,
      'Larnaka Airport  →  Pafos Airport',
    );
  });
}
