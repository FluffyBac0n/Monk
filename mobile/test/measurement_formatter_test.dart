import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/core/settings/app_settings.dart';
import 'package:eurotrex/core/settings/measurement_formatter.dart';

void main() {
  test('formats metric distances and altitudes', () {
    const formatter = MeasurementFormatter(MeasurementSystem.metric);

    expect(formatter.distance(10), '10.0 km');
    expect(formatter.altitude(100), '100 m');
    expect(formatter.proximityDistance(950), '950 m');
    expect(formatter.proximityDistance(1068), '1.1 km');
    expect(formatter.proximityDistance(11529720), '11530 km');
  });

  test('converts distances and altitudes to imperial units', () {
    const formatter = MeasurementFormatter(MeasurementSystem.imperial);

    expect(formatter.distance(10), '6.2 mi');
    expect(formatter.altitude(100), '328 ft');
    expect(formatter.proximityDistance(1000), '3281 ft');
    expect(formatter.proximityDistance(1609.344), '1.0 mi');
  });
}
