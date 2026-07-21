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

  String get distanceUnit => system == MeasurementSystem.metric ? 'km' : 'mi';

  String get altitudeUnit => system == MeasurementSystem.metric ? 'm' : 'ft';
}
