import 'app_settings.dart';

class MeasurementFormatter {
  const MeasurementFormatter(this.system);

  final MeasurementSystem system;

  double distanceValue(double kilometers) =>
      system == MeasurementSystem.metric ? kilometers : kilometers * 0.621371;

  double altitudeValue(double meters) =>
      system == MeasurementSystem.metric ? meters : meters * 3.28084;

  String distance(double kilometers, {int decimals = 1}) =>
      '${distanceValue(kilometers).toStringAsFixed(decimals)} ${system == MeasurementSystem.metric ? 'km' : 'mi'}';

  String altitude(double meters, {int decimals = 0}) =>
      '${altitudeValue(meters).toStringAsFixed(decimals)} ${system == MeasurementSystem.metric ? 'm' : 'ft'}';

  /// Formats a distance supplied in meters using a readable proximity unit.
  ///
  /// Short distances stay in metres/feet, while longer distances switch to
  /// kilometres/miles so an off-trail GPS reading never becomes an unwieldy
  /// multi-million-metre value.
  String proximityDistance(double meters) {
    final safeMeters = meters.isFinite ? meters.abs() : 0.0;
    if (system == MeasurementSystem.metric) {
      if (safeMeters < 1000) return altitude(safeMeters);
      final kilometers = safeMeters / 1000;
      return distance(kilometers, decimals: kilometers < 100 ? 1 : 0);
    }

    final feet = altitudeValue(safeMeters);
    if (feet < 5280) return altitude(safeMeters);
    final miles = distanceValue(safeMeters / 1000);
    return '${miles.toStringAsFixed(miles < 100 ? 1 : 0)} mi';
  }

  String get distanceUnit => system == MeasurementSystem.metric ? 'km' : 'mi';

  String get altitudeUnit => system == MeasurementSystem.metric ? 'm' : 'ft';
}
