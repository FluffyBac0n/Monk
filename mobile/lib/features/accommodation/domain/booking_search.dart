Uri bookingComSearchUri({
  required String stageName,
  required DateTime currentDate,
}) {
  final checkIn = DateTime(
    currentDate.year,
    currentDate.month,
    currentDate.day,
  );
  final checkOut = checkIn.add(const Duration(days: 1));

  return Uri.https('www.booking.com', '/searchresults.html', {
    'ss': stageName.trim(),
    'checkin': _bookingDate(checkIn),
    'checkout': _bookingDate(checkOut),
  });
}

String _bookingDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
