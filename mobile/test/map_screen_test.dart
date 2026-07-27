import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/core/localization/app_localizations.dart';
import 'package:monk_mobile/core/settings/app_settings.dart';
import 'package:monk_mobile/core/settings/measurement_formatter.dart';
import 'package:monk_mobile/features/accommodation/domain/lodging.dart';
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

  testWidgets('lodging map summary localizes details and handles card tap', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _lodgingSummaryApp(
        locale: const Locale('de'),
        lodging: const Lodging(
          id: 'forest-inn',
          name: 'Pafos Airport',
          type: 'Guesthouse',
          village: 'Larnaka Airport',
          distanceFromTrailKm: 0.4,
          website: 'https://booking.example.com/forest-inn',
        ),
        onTap: () => tapCount++,
      ),
    );

    expect(find.text('Flughafen Pafos'), findsOneWidget);
    expect(find.text('Gästehaus · Flughafen Larnaka · 0.4 km'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('lodging-map-summary-forest-inn')),
    );
    expect(tapCount, 1);
  });

  testWidgets('lodging map summary localizes an unavailable booking link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _lodgingSummaryApp(
        locale: const Locale('es'),
        lodging: const Lodging(
          id: 'mountain-shelter',
          name: 'Accommodation',
          type: 'Guesthouse',
          village: 'Pafos Airport',
        ),
      ),
    );

    expect(find.text('Alojamiento'), findsOneWidget);
    expect(
      find.text(
        'Casa de huéspedes · Aeropuerto de Pafos · '
        'Enlace de reserva no disponible',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
  });

  testWidgets('lodging map summary close does not invoke the card tap', (
    tester,
  ) async {
    var tapCount = 0;
    var closeCount = 0;

    await tester.pumpWidget(
      _lodgingSummaryApp(
        lodging: const Lodging(
          id: 'village-hotel',
          name: 'Village Hotel',
          website: 'https://booking.example.com/village-hotel',
        ),
        onTap: () => tapCount++,
        onClose: () => closeCount++,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('lodging-map-summary-close-village-hotel')),
    );

    expect(closeCount, 1);
    expect(tapCount, 0);
  });
}

Widget _lodgingSummaryApp({
  required Lodging lodging,
  Locale locale = const Locale('en'),
  VoidCallback? onTap,
  VoidCallback? onClose,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 76,
          child: LodgingMapSummaryCard(
            lodging: lodging,
            formatter: const MeasurementFormatter(MeasurementSystem.metric),
            onTap: onTap ?? _doNothing,
            onClose: onClose ?? _doNothing,
          ),
        ),
      ),
    ),
  );
}

void _doNothing() {}
