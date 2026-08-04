import 'dart:convert';

import '../../features/stages/domain/stage.dart';

Map<String, Object?> encodeTrailStageRow(String trailId, TrailStage stage) {
  return {
    'id': stage.id,
    'trail_id': trailId,
    'sequence': stage.sequence,
    'name': stage.name,
    'distance_from_path_km': stage.distanceFromPathKm,
    'accumulated_distance_km': stage.accumulatedDistanceKm,
    'segment_length_km': stage.segmentLengthKm,
    'elevation_up_m': stage.elevationUpM,
    'elevation_down_m': stage.elevationDownM,
    'altitude_m': stage.altitudeM,
    'services_json': jsonEncode(stage.services),
  };
}

TrailStage decodeTrailStageRow(Map<String, Object?> row) {
  return TrailStage(
    id: row['id']! as String,
    sequence: row['sequence']! as int,
    name: row['name']! as String,
    distanceFromPathKm: (row['distance_from_path_km'] as num?)?.toDouble(),
    accumulatedDistanceKm: (row['accumulated_distance_km'] as num?)?.toDouble(),
    segmentLengthKm: (row['segment_length_km'] as num?)?.toDouble(),
    elevationUpM: (row['elevation_up_m'] as num?)?.toDouble(),
    elevationDownM: (row['elevation_down_m'] as num?)?.toDouble(),
    altitudeM: (row['altitude_m'] as num?)?.toDouble(),
    services:
        (jsonDecode(row['services_json']! as String) as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value == true)),
  );
}
