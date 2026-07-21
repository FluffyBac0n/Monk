import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/core/settings/app_settings.dart';
import 'package:monk_mobile/core/settings/measurement_formatter.dart';

void main() {
  test('formats metric distances and altitudes', () {
    const formatter = MeasurementFormatter(MeasurementSystem.metric);

    expect(formatter.distance(10), '10.0 km');
    expect(formatter.altitude(100), '100 m');
  });

  test('converts distances and altitudes to imperial units', () {
    const formatter = MeasurementFormatter(MeasurementSystem.imperial);

    expect(formatter.distance(10), '6.2 mi');
    expect(formatter.altitude(100), '328 ft');
  });
}
