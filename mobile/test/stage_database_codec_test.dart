import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/core/database/stage_database_codec.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';

void main() {
  test(
    'round-trips stage path distance and elevation through the database row codec',
    () {
      const stage = TrailStage(
        id: '122-acheleia',
        sequence: 122,
        name: 'Acheleia',
        distanceFromPathKm: 0.46,
        accumulatedDistanceKm: 6.27,
        segmentLengthKm: 6.27,
        elevationUpM: 52,
        elevationDownM: 15,
        altitudeM: 39,
        services: {'drinkableWater': true},
      );

      final row = encodeTrailStageRow('cyprus-e4', stage);
      final restored = decodeTrailStageRow(row);

      expect(row['distance_from_path_km'], 0.46);
      expect(row['elevation_up_m'], 52);
      expect(row['elevation_down_m'], 15);
      expect(restored.distanceFromPathKm, stage.distanceFromPathKm);
      expect(restored.elevationUpM, stage.elevationUpM);
      expect(restored.elevationDownM, stage.elevationDownM);
      expect(restored.services, stage.services);
    },
  );

  test('decodes nullable elevation columns from a migrated legacy row', () {
    final restored = decodeTrailStageRow({
      'id': 'legacy-stage',
      'trail_id': 'cyprus-e4',
      'sequence': 1,
      'name': 'Legacy stage',
      'accumulated_distance_km': null,
      'segment_length_km': null,
      'altitude_m': null,
      'services_json': '{}',
    });

    expect(restored.distanceFromPathKm, isNull);
    expect(restored.elevationUpM, isNull);
    expect(restored.elevationDownM, isNull);
  });
}
