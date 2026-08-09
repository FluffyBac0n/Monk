import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/features/detours/domain/trail_detour.dart';

void main() {
  test('parses the imported detour summary and affected stages', () {
    final detour = TrailDetour.fromFirestore('teishia-tis-madaris', {
      'name': 'Teishia tis Madaris',
      'routeDistanceKm': 6.6702,
      'elevationUpM': 399.52,
      'elevationDownM': 480.74,
      'estimatedWalkingTimeMinutes': 120,
      'replacedMainTrailDistanceKm': 5.5032,
      'replacedElevationUpM': 324.85,
      'replacedElevationDownM': 403.21,
      'replacedEstimatedWalkingTimeMinutes': 99,
      'distanceDifferenceKm': 1.167,
      'estimatedWalkingTimeDifferenceMinutes': 21,
      'averageDistanceFromTrailKm': 0.664,
      'maximumDistanceFromTrailKm': 1.128,
      'affectedStageIds': ['66-spilia', '65-saranti'],
      'affectedStageSequences': [66, 65],
      'affectedStageNames': ['Spilia', 'Saranti'],
      'pointStride': 5,
      'startConnection': {'mainTrailDistanceKm': 268.394},
      'endConnection': {'mainTrailDistanceKm': 273.897},
    });

    expect(detour.name, 'Teishia tis Madaris');
    expect(detour.routeDistanceKm, closeTo(6.6702, 0.0001));
    expect(detour.replacedMainTrailDistanceKm, closeTo(5.5032, 0.0001));
    expect(detour.distanceDifferenceKm, closeTo(1.167, 0.0001));
    expect(detour.affectedStageIds, ['66-spilia', '65-saranti']);
    expect(detour.affectedStageSequences, [66, 65]);
    expect(detour.startMainTrailDistanceKm, closeTo(268.394, 0.001));
    expect(detour.endMainTrailDistanceKm, closeTo(273.897, 0.001));
  });

  test('uses safe defaults for incomplete detour summaries', () {
    final detour = TrailDetour.fromFirestore('forest-option', const {});

    expect(detour.name, 'Forest option');
    expect(detour.routeDistanceKm, 0);
    expect(detour.affectedStageIds, isEmpty);
    expect(detour.pointStride, 5);
  });
}
