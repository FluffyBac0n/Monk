import 'route_point.dart';

class ElevationTotals {
  const ElevationTotals({required this.ascentM, required this.descentM});

  final double ascentM;
  final double descentM;
}

ElevationTotals calculateElevationTotals(List<RoutePoint> points) {
  var ascentM = 0.0;
  var descentM = 0.0;

  for (var index = 1; index < points.length; index++) {
    final changeM = points[index].altitudeM - points[index - 1].altitudeM;
    if (!changeM.isFinite) continue;
    if (changeM > 0) {
      ascentM += changeM;
    } else {
      descentM -= changeM;
    }
  }

  return ElevationTotals(ascentM: ascentM, descentM: descentM);
}
