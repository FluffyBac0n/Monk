import 'route_point.dart';

class ElevationTotals {
  const ElevationTotals({required this.ascentM, required this.descentM});

  final double ascentM;
  final double descentM;
}

ElevationTotals calculateElevationTotals(
  List<RoutePoint> points, {
  double minimumChangeM = 0,
}) {
  if (points.length < 2) {
    return const ElevationTotals(ascentM: 0, descentM: 0);
  }
  var ascentM = 0.0;
  var descentM = 0.0;
  var referenceAltitudeM = points.first.altitudeM;

  for (var index = 1; index < points.length; index++) {
    final altitudeM = points[index].altitudeM;
    final changeM = altitudeM - referenceAltitudeM;
    if (!changeM.isFinite) continue;
    if (changeM.abs() < minimumChangeM) continue;
    if (changeM > 0) {
      ascentM += changeM;
    } else {
      descentM -= changeM;
    }
    referenceAltitudeM = altitudeM;
  }

  return ElevationTotals(ascentM: ascentM, descentM: descentM);
}
