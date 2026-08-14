import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/excursions/domain/trail_excursion.dart';

void main() {
  test('parses an imported stage excursion summary', () {
    final excursion = TrailExcursion.fromFirestore('moutti-tis-sotiras', {
      'routeType': 'outAndBack',
      'anchorType': 'stage',
      'anchorStageId': '101-moutti-tis-sotiras-excursion',
      'anchorStageSequence': 101,
      'anchorStageName': 'Moutti tis Sotiras Excursion',
      'routeDistanceKm': 0.7,
      'totalDistanceKm': 1.4,
      'elevationUpM': 120,
      'elevationDownM': 120,
      'estimatedWalkingTimeMinutes': 29,
      'pointStride': 5,
      'distanceFromTrailKm': 0.001,
      'mainTrailDistanceKm': 98.07,
      'startLocation': {'latitude': 34.91, 'longitude': 32.89},
      'endLocation': {'latitude': 34.92, 'longitude': 32.9},
    });

    expect(excursion.routeType, ExcursionRouteType.outAndBack);
    expect(excursion.anchorType, ExcursionAnchorType.stage);
    expect(excursion.anchorStageId, '101-moutti-tis-sotiras-excursion');
    expect(excursion.anchorStageSequence, 101);
    expect(excursion.displayName, 'Moutti tis Sotiras Excursion');
    expect(excursion.totalDistanceKm, 1.4);
    expect(excursion.startLocation?.latitude, 34.91);
    expect(excursion.endLocation?.longitude, 32.9);
  });

  test('supports trail and standalone excursions without a stage', () {
    final trail = TrailExcursion.fromFirestore('forest-loop', {
      'routeType': 'loop',
      'anchorType': 'trail',
      'routeDistanceKm': '4.25',
      'totalDistanceKm': '4.25',
      'elevationUpM': '180',
      'elevationDownM': 180,
      'estimatedWalkingTimeMinutes': '69',
    });
    final standalone = TrailExcursion.fromFirestore('coastal-walk', {
      'routeType': 'oneWay',
      'anchorType': 'standalone',
    });

    expect(trail.routeType, ExcursionRouteType.loop);
    expect(trail.anchorType, ExcursionAnchorType.trail);
    expect(trail.displayName, 'Forest loop');
    expect(trail.totalDistanceKm, 4.25);
    expect(standalone.anchorType, ExcursionAnchorType.standalone);
    expect(standalone.anchorStageId, isNull);
  });

  test('rejects invalid coordinates and keeps a safe route stride', () {
    final excursion = TrailExcursion.fromFirestore('invalid-route', {
      'routeType': 'oneWay',
      'anchorType': 'stage',
      'pointStride': 2,
      'startLocation': {'latitude': 95, 'longitude': 32.9},
    });

    expect(excursion.pointStride, 5);
    expect(excursion.startLocation, isNull);
  });
}
