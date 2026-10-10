import 'package:eurotrex/core/localization/app_localizations.dart';
import 'package:eurotrex/features/map/data/offline_map_repository.dart';
import 'package:eurotrex/features/map/presentation/map_background_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Terrain keeps the existing downloaded map style', () {
    expect(MapBackground.terrain.styleUri, cyprusE4OfflineStyleUri);
    expect(
      MapBackground.values.map((value) => value.styleUri).toSet().length,
      4,
    );
  });

  testWidgets('background picker selects a map without changing POI filters', (
    tester,
  ) async {
    MapBackground? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapBackgroundSheet(
            selected: MapBackground.terrain,
            onSelect: (background) => chosen = background,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const ValueKey('map-background-terrain')),
          )
          .selected,
      isTrue,
    );
    await tester.tap(
      find.byKey(const ValueKey('map-background-satelliteLabels')),
    );
    expect(chosen, MapBackground.satelliteLabels);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Satellite with labels'), findsOneWidget);
  });

  testWidgets('layer labels translate and sheet scrolls on small screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = AppLocalizations(locale);
      if (locale.languageCode != 'en') {
        for (final key in [
          'Points of Interest',
          ...MapBackground.values.map((value) => value.label),
        ]) {
          expect(AppLocalizations.translationKeys(locale), contains(key));
        }
      }
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: MapBackgroundSheet(
                selected: MapBackground.satellite,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.t('Map layers')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('map-background-satelliteLabels')),
        150,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
