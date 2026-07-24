import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/core/localization/app_localizations.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/map/presentation/map_screen.dart';

void main() {
  const west = RoutePoint(
    pointIndex: 0,
    lat: 34.8,
    lng: 32.4,
    altitudeM: 10,
    distanceKm: 0,
    reverseDistanceKm: 100,
  );
  const east = RoutePoint(
    pointIndex: 1,
    lat: 34.8,
    lng: 33.6,
    altitudeM: 10,
    distanceKm: 100,
    reverseDistanceKm: 0,
  );

  test('whole-route fit stays north-up on a portrait map', () {
    expect(routeFitBearing(const [west, east], const Size(390, 760)), 0);
  });

  test('whole-route fit stays north-up on a landscape map', () {
    expect(routeFitBearing(const [west, east], const Size(760, 390)), 0);
  });

  testWidgets('map route direction remains readable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MapScreen(accessToken: ''),
        ),
      ),
    );

    final subtitle = tester.widget<Text>(
      find.byKey(const ValueKey('map-route-direction')),
    );
    expect(subtitle.data, contains('FLUGHAFEN PAFOS'));
    expect(subtitle.data, contains('FLUGHAFEN LARNAKA'));
    expect(subtitle.maxLines, 2);
    expect(subtitle.softWrap, isTrue);
    expect(subtitle.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);
  });
}
