import 'package:eurotrex/core/settings/app_settings.dart';
import 'package:eurotrex/core/settings/measurement_formatter.dart';
import 'package:eurotrex/features/accommodation/domain/lodging.dart';
import 'package:eurotrex/features/map/data/poi_directions_service.dart';
import 'package:eurotrex/features/map/domain/poi_directions.dart';
import 'package:eurotrex/features/map/presentation/map_screen.dart';
import 'package:eurotrex/features/map/presentation/poi_directions_card.dart';
import 'package:eurotrex/features/map/presentation/poi_directions_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'poi_directions_test.dart' as fixtures;

void main() {
  for (final width in [320.0, 400.0]) {
    testWidgets(
      'Directions is reachable in the compact POI card at width $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = PoiDirectionsController(
          PoiDirectionsService(
            accessToken: 'test',
            locate: () async => fixtures.origin,
            isOnline: () async => true,
            transport: (_) async => fixtures.routeJson(),
          ),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Stack(
                  children: [
                    MapLodgingInfoSheet(
                      lodging: const Lodging(
                        id: 'hotel',
                        name: 'A very long accommodation name',
                        distanceFromTrailKm: 2.4,
                        village: 'Troodos',
                        address: 'Forest Road 1',
                      ),
                      formatter: const MeasurementFormatter(
                        MeasurementSystem.metric,
                      ),
                      onBook: () {},
                      onClose: () {},
                      route: controller.route,
                      directions: PoiDirectionsCard(
                        controller: controller,
                        formatter: const MeasurementFormatter(
                          MeasurementSystem.metric,
                        ),
                        onDirections: (mode) => controller.load(
                          destination: fixtures.destination,
                          mode: mode,
                          language: 'en',
                        ),
                        onClear: controller.clear,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Troodos'), findsNothing);
        expect(find.text('Forest Road 1'), findsNothing);
        expect(
          find.byKey(const ValueKey('map-lodging-contact-actions-hotel')),
          findsNothing,
        );
        expect(
          tester.getSize(find.byType(DraggableScrollableSheet)).height,
          lessThan(200),
        );
        // Hold the finger after crossing the expansion threshold: rebuilding
        // the details must not start a snap animation underneath the gesture.
        final sheet = find.byType(DraggableScrollableSheet);
        final compactHeight = tester.getSize(sheet).height;
        final drag = await tester.startGesture(
          tester.getCenter(find.text('A very long accommodation name')),
        );
        await drag.moveBy(const Offset(0, -20));
        await tester.pump();
        await drag.moveBy(const Offset(0, -65));
        await tester.pump();
        await tester.pump();
        await drag.moveBy(const Offset(0, -60));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.getSize(sheet).height, greaterThan(compactHeight + 80));
        final draggedHeight = tester.getSize(sheet).height;
        await drag.up();
        await tester.pumpAndSettle();
        expect(tester.getSize(sheet).height, closeTo(draggedHeight, 1));
        expect(find.text('Forest Road 1'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('poi-directions-button')));
        await tester.pumpAndSettle();
        expect(tester.getSize(sheet).height, closeTo(draggedHeight, 1));
        expect(find.text('Forest Road 1'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('poi-directions-clear')));
        await tester.pumpAndSettle();
        expect(tester.getSize(sheet).height, closeTo(draggedHeight, 1));
        await tester.tap(find.text('A very long accommodation name'));
        await tester.pumpAndSettle();
        expect(find.text('Forest Road 1'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('poi-directions-button')));
        await tester.pumpAndSettle();
        expect(find.text('1.2 km · 15 min · Walking'), findsOneWidget);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('poi-directions-summary')))
              .bottom,
          lessThan(720),
        );
        expect(find.text('Forest Road 1'), findsNothing);
        await tester.tap(find.text('A very long accommodation name'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Troodos'), findsOneWidget);
        expect(find.text('Forest Road 1'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('map-lodging-contact-actions-hotel')),
          findsOneWidget,
        );
        await tester.tap(find.text('A very long accommodation name'));
        await tester.pumpAndSettle();
        expect(find.text('Forest Road 1'), findsNothing);
        expect(
          find.byKey(const ValueKey('poi-directions-instructions')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('poi-directions-mode')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Driving').last);
        await tester.pumpAndSettle();
        expect(find.text('1.2 km · 15 min · Driving'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('poi-directions-clear')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('poi-directions-summary')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('offline card labels straight-line distance and can retry', (
    tester,
  ) async {
    final controller = PoiDirectionsController(
      PoiDirectionsService(
        accessToken: 'test',
        locate: () async => fixtures.origin,
        isOnline: () async => false,
      ),
    );
    addTearDown(controller.dispose);
    await controller.load(
      destination: fixtures.destination,
      mode: DirectionsMode.walking,
      language: 'en',
    );
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoiDirectionsCard(
            controller: controller,
            formatter: const MeasurementFormatter(MeasurementSystem.imperial),
            onDirections: (_) => retries++,
            onClear: controller.clear,
          ),
        ),
      ),
    );
    expect(
      find.text('Connect to the internet to get directions.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Straight-line distance from you'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('poi-directions-summary')), findsNothing);
    await tester.tap(find.text('Directions'));
    expect(retries, 1);
  });
}
