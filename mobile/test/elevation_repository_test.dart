import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/elevation/data/elevation_repository.dart';

void main() {
  test('expands flat Firestore route chunks in order', () {
    final points = expandRoutePointValues([
      [34.7, 32.4, 2, 0, 558],
      [34.8, 32.5, 125, 1.25, 556.75],
    ]);

    expect(points, hasLength(2));
    expect(points.first.pointIndex, 0);
    expect(points.last.altitudeM, 125);
    expect(points.last.distanceKm, 1.25);
  });

  test('rejects malformed route chunks', () {
    expect(
      () => expandRoutePointValues([
        [34.7, 32.4, 2],
      ]),
      throwsFormatException,
    );
  });
}
