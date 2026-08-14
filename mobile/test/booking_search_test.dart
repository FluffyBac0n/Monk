import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/accommodation/domain/booking_search.dart';

void main() {
  test('builds a Booking.com stage search for tonight', () {
    final uri = bookingComSearchUri(
      stageName: '  Troodos Square  ',
      currentDate: DateTime(2026, 8, 14, 23, 45),
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.booking.com');
    expect(uri.path, '/searchresults.html');
    expect(uri.queryParameters['ss'], 'Troodos Square');
    expect(uri.queryParameters['checkin'], '2026-08-14');
    expect(uri.queryParameters['checkout'], '2026-08-15');
  });

  test('advances checkout correctly across a year boundary', () {
    final uri = bookingComSearchUri(
      stageName: 'Pafos Airport',
      currentDate: DateTime(2026, 12, 31),
    );

    expect(uri.queryParameters['checkin'], '2026-12-31');
    expect(uri.queryParameters['checkout'], '2027-01-01');
  });
}
