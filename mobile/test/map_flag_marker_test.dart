import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/map/presentation/map_flag_marker.dart';

void main() {
  testWidgets('renders and caches a valid PNG flag marker', (tester) async {
    final firstFuture = mapFlagMarkerImage(Colors.green);
    final secondFuture = mapFlagMarkerImage(Colors.green);

    expect(identical(firstFuture, secondFuture), isTrue);
    final bytes = (await tester.runAsync(() => firstFuture))!;
    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(bytes.length, greaterThan(100));
    expect(mapFlagMarkerWidth, 42);
    expect(mapFlagMarkerHeight, 42);
  });
}
