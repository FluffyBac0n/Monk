import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/map/domain/stage_preview.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final points = List.generate(
    11,
    (i) => RoutePoint(
      pointIndex: i,
      lat: 35 + i * .01,
      lng: 33 + i * .01,
      altitudeM: 1000 + i * 10,
      distanceKm: i.toDouble(),
      reverseDistanceKm: 10 - i.toDouble(),
    ),
  );
  TrailStage stage(double? km) => TrailStage(
    id: '$km',
    sequence: 1,
    name: '$km',
    services: const {},
    accumulatedDistanceKm: km,
  );
  test('previews arriving section with interpolated endpoints', () {
    final section = stagePreviewPoints(
      points: points,
      stages: [stage(0), stage(2.5), stage(7.5)],
      stageIndex: 2,
    );
    expect(section.map((p) => p.distanceKm), [2.5, 3, 4, 5, 6, 7, 7.5]);
    expect(section.first.lat, closeTo(35.025, .00001));
    expect(section.last.lng, closeTo(33.075, .00001));
  });
  test('trail start previews the first section', () {
    final section = stagePreviewPoints(
      points: points,
      stages: [stage(0), stage(2.5), stage(7.5)],
      stageIndex: 0,
    );
    expect(section.map((p) => p.distanceKm), [0, 1, 2, 2.5]);
  });
  test('reversed stages preserve travel direction', () {
    final section = stagePreviewPoints(
      points: points,
      stages: [stage(7.5), stage(2.5), stage(0)],
      stageIndex: 1,
    );
    expect(section.map((p) => p.distanceKm), [7.5, 7, 6, 5, 4, 3, 2.5]);
  });
  test('missing or invalid sections are unavailable', () {
    for (final stages in [
      <TrailStage>[],
      [stage(0)],
      [stage(0), stage(null)],
      [stage(0), stage(double.nan)],
      [stage(0), stage(0)],
    ]) {
      expect(
        stagePreviewPoints(points: points, stages: stages, stageIndex: 0),
        isEmpty,
      );
    }
    expect(
      stagePreviewPoints(
        points: [],
        stages: [stage(0), stage(1)],
        stageIndex: 0,
      ),
      isEmpty,
    );
    expect(
      stagePreviewPoints(
        points: points,
        stages: [stage(0), stage(1)],
        stageIndex: 2,
      ),
      isEmpty,
    );
  });
}
