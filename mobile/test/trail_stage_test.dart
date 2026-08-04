import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/features/stages/domain/stage.dart';

void main() {
  test('parses authoritative stage path distance and elevation fields', () {
    final stage = TrailStage.fromFirestore('122-acheleia', {
      'sequence': 122,
      'name': 'Acheleia',
      'distanceFromPathKm': 0.46,
      'accumulatedDistanceKm': 6.27,
      'segmentLengthKm': 6.27,
      'elevationUpM': 52,
      'elevationDownM': 15.0,
      'altitudeM': 39,
      'services': {'drinkableWater': true},
    });

    expect(stage.distanceFromPathKm, 0.46);
    expect(stage.elevationUpM, 52);
    expect(stage.elevationDownM, 15);
    expect(stage.services['drinkableWater'], isTrue);
  });

  test('keeps missing stage elevation fields nullable', () {
    final stage = TrailStage.fromFirestore('legacy-stage', {
      'sequence': 1,
      'name': 'Legacy stage',
      'services': <String, bool>{},
    });

    expect(stage.distanceFromPathKm, isNull);
    expect(stage.elevationUpM, isNull);
    expect(stage.elevationDownM, isNull);
  });
}
