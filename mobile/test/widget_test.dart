import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/app.dart';
import 'package:monk_mobile/core/app_info/app_version_provider.dart';
import 'package:monk_mobile/core/database/app_database.dart';
import 'package:monk_mobile/core/database/database_provider.dart';
import 'package:monk_mobile/core/links/external_url_launcher.dart';
import 'package:monk_mobile/core/settings/app_settings.dart';
import 'package:monk_mobile/core/settings/app_settings_controller.dart';
import 'package:monk_mobile/features/about/presentation/about_screen.dart';
import 'package:monk_mobile/features/accommodation/data/lodging_repository.dart';
import 'package:monk_mobile/features/accommodation/domain/lodging.dart';
import 'package:monk_mobile/features/accommodation/presentation/accommodation_controller.dart';
import 'package:monk_mobile/features/accommodation/presentation/accommodation_screen.dart';
import 'package:monk_mobile/features/elevation/domain/route_point.dart';
import 'package:monk_mobile/features/elevation/presentation/elevation_controller.dart';
import 'package:monk_mobile/features/elevation/presentation/elevation_screen.dart';
import 'package:monk_mobile/features/map/presentation/map_screen.dart';
import 'package:monk_mobile/features/map/domain/offline_map_state.dart';
import 'package:monk_mobile/features/map/presentation/offline_map_controller.dart';
import 'package:monk_mobile/features/stages/domain/stage.dart';
import 'package:monk_mobile/features/stages/presentation/stages_controller.dart';
import 'package:monk_mobile/features/stages/presentation/stages_screen.dart';
import 'package:monk_mobile/features/trail/domain/trail_direction.dart';
import 'package:monk_mobile/features/trail/domain/trail_preferences.dart';
import 'package:monk_mobile/features/trail/presentation/trail_information_screen.dart';

void main() {
  testWidgets('E4 waymark opens trail information and stops pulsing', (
    tester,
  ) async {
    final database = _FakeAppDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          stagesProvider.overrideWith(_FakeStagesController.new),
          offlineMapProvider.overrideWith(_FakeOfflineMapController.new),
        ],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final longDistance = find.byKey(
      const ValueKey('stage-long-distance-badge'),
    );
    final offlineStatus = find.byKey(
      const ValueKey('offline-map-status-badge'),
    );
    expect(longDistance, findsOneWidget);
    expect(offlineStatus, findsOneWidget);
    final stageHeaderWatermark = find.byKey(
      const ValueKey('stages-header-watermark-cyprus-e4'),
    );
    expect(stageHeaderWatermark, findsOneWidget);
    expect(
      tester.widget<Image>(stageHeaderWatermark).image,
      const AssetImage('assets/branding/cyprus_e4_forest.jpg'),
    );
    expect(
      find.byKey(const ValueKey('stages-header-watermark-fade-cyprus-e4')),
      findsOneWidget,
    );
    expect(
      tester.getCenter(longDistance).dx,
      lessThan(tester.getCenter(offlineStatus).dx),
    );
    expect(
      find.byKey(const ValueKey('offline-map-status-banner')),
      findsNothing,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('OFFLINE TRAIL'), findsOneWidget);

    final providerScope = ProviderScope.containerOf(
      tester.element(find.byType(StagesScreen)),
    );
    await providerScope.read(offlineMapProvider.notifier).delete();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.info_outline_rounded), findsWidgets);
    expect(find.text('OFFLINE MAP NOT DOWNLOADED'), findsOneWidget);

    final information = find.byKey(const ValueKey('stage-e4-waymark'));
    final reverse = find.byKey(const ValueKey('reverse-trail-direction'));
    final refresh = find.byKey(const ValueKey('refresh-offline-trail'));
    final settings = find.byKey(const ValueKey('trail-settings'));
    final toolbar = find.byKey(const ValueKey('trail-toolbar-actions'));
    final bottomNavigation = find.byKey(
      const ValueKey('stage-bottom-navigation'),
    );
    expect(information, findsOneWidget);
    expect(find.byKey(const ValueKey('trail-information')), findsNothing);
    expect(
      find.byKey(const ValueKey('stage-e4-waymark-pulsing')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stage-e4-waymark-halo')), findsOneWidget);
    expect(reverse, findsOneWidget);
    expect(refresh, findsNothing);
    expect(settings, findsOneWidget);
    expect(
      tester.widget<Row>(toolbar).mainAxisAlignment,
      MainAxisAlignment.end,
    );
    expect(find.descendant(of: toolbar, matching: settings), findsOneWidget);
    expect(find.descendant(of: toolbar, matching: reverse), findsNothing);
    expect(
      find.descendant(of: bottomNavigation, matching: reverse),
      findsOneWidget,
    );
    expect(find.text('Stage by stage'), findsNothing);

    await tester.tap(information);
    await tester.pumpAndSettle();
    expect(find.byType(TrailInformationScreen), findsOneWidget);
    final informationWatermark = find.byKey(
      const ValueKey('trail-information-watermark-cyprus-e4'),
    );
    expect(informationWatermark, findsOneWidget);
    expect(
      (tester.widget<Image>(informationWatermark).image as AssetImage)
          .assetName,
      'assets/branding/cyprus_e4_forest.jpg',
    );
    expect(
      find.byKey(const ValueKey('trail-information-watermark-fade-cyprus-e4')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trail-information-image-header')),
        matching: find.byIcon(Icons.route_rounded),
      ),
      findsNothing,
    );
    expect(find.text('Photo: Persephoni Trail stage'), findsOneWidget);
    expect(find.text('Sign posting'), findsOneWidget);
    expect(database.settings[cyprusE4TrailInformationSeenSetting], 'true');
    await tester.scrollUntilVisible(
      find.text('Useful tips'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Useful tips'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-e4-waymark-pulsing')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('stage-e4-waymark-halo')), findsNothing);
    expect(find.byKey(const ValueKey('stage-e4-waymark-seen')), findsOneWidget);
  });

  testWidgets('trail header reveals a compact title after scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stagesProvider.overrideWith(_ManyStagesController.new),
          offlineMapProvider.overrideWith(_FakeOfflineMapController.new),
        ],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final compactTitle = find.byKey(
      const ValueKey('trail-compact-title-opacity'),
    );
    expect(tester.widget<AnimatedOpacity>(compactTitle).opacity, 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedOpacity>(compactTitle).opacity, 1);
    expect(find.byKey(const ValueKey('trail-compact-title')), findsOneWidget);
  });

  testWidgets('stage details helper is dismissed after opening a stage', (
    tester,
  ) async {
    final database = _FakeAppDatabase()
      ..settings[cyprusE4TrailInformationSeenSetting] = 'true';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          stagesProvider.overrideWith(_FakeStagesController.new),
          elevationProvider.overrideWith(_FakeElevationController.new),
        ],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final helper = find.byKey(const ValueKey('stage-details-helper'));
    final stageCard = find.byKey(
      const ValueKey('stage-card-124-pafos-airport'),
    );
    expect(helper, findsOneWidget);
    expect(
      find.descendant(
        of: helper,
        matching: find.text('Tap a stage to see its details.'),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: stageCard, matching: helper), findsOneWidget);

    await tester.tap(stageCard);
    await tester.pumpAndSettle();

    expect(find.byType(StageDetailScreen), findsOneWidget);
    expect(database.settings[cyprusE4StageDetailsHintSeenSetting], 'true');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(helper, findsNothing);
  });

  testWidgets('pulling down at the top refreshes the stages', (tester) async {
    final database = _FakeAppDatabase()
      ..settings[cyprusE4TrailInformationSeenSetting] = 'true';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          stagesProvider.overrideWith(_RefreshTrackingStagesController.new),
        ],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StagesScreen)),
    );
    final controller =
        container.read(stagesProvider.notifier)
            as _RefreshTrackingStagesController;
    expect(controller.syncCalls, 0);
    expect(find.byKey(const ValueKey('stage-pull-to-refresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('refresh-offline-trail')), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(controller.syncCalls, 1);
  });

  testWidgets('debug settings can restart both guidance hints', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = _FakeAppDatabase()
      ..settings[cyprusE4TrailInformationSeenSetting] = 'true'
      ..settings[cyprusE4StageDetailsHintSeenSetting] = 'true';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          stagesProvider.overrideWith(_FakeStagesController.new),
          offlineMapProvider.overrideWith(_FakeOfflineMapController.new),
        ],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stage-e4-waymark-seen')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-e4-waymark-halo')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trail-settings')));
    await tester.pumpAndSettle();
    final resetHint = find.byKey(const ValueKey('reset-e4-information-hint'));
    await tester.scrollUntilVisible(
      resetHint,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(resetHint);
    await tester.pumpAndSettle();

    expect(find.byType(StagesScreen), findsOneWidget);
    expect(database.settings[cyprusE4TrailInformationSeenSetting], 'false');
    expect(
      find.byKey(const ValueKey('stage-e4-waymark-pulsing')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stage-e4-waymark-halo')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-details-helper')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trail-settings')));
    await tester.pumpAndSettle();
    final resetStageHint = find.byKey(
      const ValueKey('reset-stage-details-hint'),
    );
    await tester.scrollUntilVisible(
      resetStageHint,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(resetStageHint);
    await tester.pumpAndSettle();

    expect(find.byType(StagesScreen), findsOneWidget);
    expect(database.settings[cyprusE4StageDetailsHintSeenSetting], 'false');
    expect(find.byKey(const ValueKey('stage-details-helper')), findsOneWidget);
  });

  testWidgets('shows Trails and opens Cyprus E4', (tester) async {
    final lodgingRepository = _TrailPreloadLodgingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lodgingRepositoryProvider.overrideWithValue(lodgingRepository),
        ],
        child: const MonkApp(),
      ),
    );
    await tester.pumpAndSettle();

    final landingWordmark = find.byKey(
      const ValueKey('landing-eurotrex-wordmark'),
    );
    expect(landingWordmark, findsOneWidget);
    expect(find.text('EUROTREX'), findsNothing);
    expect(find.text('MONK'), findsNothing);
    expect(find.text('TRAIL LIBRARY'), findsNothing);
    final headerGap =
        tester.getTopLeft(find.text('Trails')).dy -
        tester.getBottomLeft(landingWordmark).dy;
    expect(headerGap, greaterThanOrEqualTo(16));
    expect(headerGap, lessThan(80));
    expect(find.text('Trails'), findsOneWidget);
    expect(find.text('Explore trails'), findsNothing);
    expect(
      find.text('Choose a trail to view its stages and maps.'),
      findsNothing,
    );
    expect(find.text('Cyprus E4'), findsOneWidget);
    final cyprusCard = find.byKey(const ValueKey('explore-cyprus-e4'));
    final exploreButton = find.byKey(
      const ValueKey('explore-trail-button-cyprus-e4'),
    );
    expect(
      find.descendant(
        of: exploreButton,
        matching: find.byIcon(Icons.hiking_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: exploreButton,
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsNothing,
    );
    final trailHeader = find.byKey(
      const ValueKey('trail-card-header-cyprus-e4'),
    );
    final trailKind = find.byKey(const ValueKey('trail-card-kind-cyprus-e4'));
    final trailDataStatus = find.byKey(
      const ValueKey('trail-data-status-badge-cyprus-e4'),
    );
    final trailHeaderContent = find.byKey(
      const ValueKey('trail-card-header-content-cyprus-e4'),
    );
    expect(
      tester.widget<Padding>(trailHeaderContent).padding,
      const EdgeInsets.all(16),
    );
    final trailWatermark = find.byKey(
      const ValueKey('trail-card-watermark-cyprus-e4'),
    );
    expect(
      find.descendant(of: trailHeader, matching: trailWatermark),
      findsOneWidget,
    );
    expect(
      (tester.widget<Image>(trailWatermark).image as AssetImage).assetName,
      'assets/branding/cyprus_e4_forest.jpg',
    );
    expect(tester.getSize(trailHeader).height, greaterThanOrEqualTo(165));
    expect(
      find.byKey(const ValueKey('trail-card-watermark-fade-cyprus-e4')),
      findsOneWidget,
    );
    expect(
      tester.widget<Container>(trailKind).padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    );
    expect(
      find.descendant(of: trailHeader, matching: trailDataStatus),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trail-card-route-cyprus-e4')),
      findsNothing,
    );
    expect(find.text('Pafos Airport  →  Larnaka Airport'), findsNothing);
    expect(
      find.text(
        'A long-distance journey linking the coast, forests and Troodos mountain.',
      ),
      findsOneWidget,
    );
    expect(
      (tester.getCenter(trailKind).dy - tester.getCenter(trailDataStatus).dy)
          .abs(),
      lessThan(1),
    );
    expect(find.text('TRAIL DATA NOT DOWNLOADED'), findsOneWidget);
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('trail-card-details-cyprus-e4')),
          )
          .padding,
      const EdgeInsets.all(16),
    );
    await tester.tap(cyprusCard);
    await tester.pumpAndSettle();
    expect(lodgingRepository.trailLoadCalls, 1);
    expect(find.text('EUROTREX'), findsNothing);
    expect(landingWordmark, findsNothing);
    expect(
      find.byKey(const ValueKey('stages-eurotrex-wordmark')),
      findsNothing,
    );
    final toolbarActions = find.byKey(const ValueKey('trail-toolbar-actions'));
    expect(toolbarActions, findsOneWidget);
    expect(
      tester.widget<Row>(toolbarActions).mainAxisAlignment,
      MainAxisAlignment.end,
    );
    expect(find.byKey(const ValueKey('about-eu-logo')), findsNothing);
    expect(find.byKey(const ValueKey('about-cyprus-logo')), findsNothing);
    expect(find.text('Take the trail offline'), findsOneWidget);
    expect(find.text('Download trail'), findsWidgets);
  });

  testWidgets('funding partners and contact links live on About', (
    tester,
  ) async {
    final launchedUris = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
          externalUrlLauncherProvider.overrideWithValue((uri) async {
            launchedUris.add(uri);
            return true;
          }),
        ],
        child: const MonkApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('explore-trails-partners-footer')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('about-eu-logo')), findsNothing);
    expect(find.byKey(const ValueKey('about-cyprus-logo')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('about-us-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('about-screen')), findsOneWidget);
    expect(find.text('Project funding'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('about-eurotrex-wordmark')),
      findsOneWidget,
    );
    expect(find.text('EUROTREX'), findsNothing);
    expect(find.text('About EUROTREX'), findsNothing);
    expect(find.text('Our mission'), findsOneWidget);
    expect(find.text('Co-funded by the Republic of Cyprus'), findsOneWidget);
    expect(find.textContaining('supported by the Republic'), findsNothing);

    final euLogo = find.byKey(const ValueKey('about-eu-logo'));
    final cyprusLogo = find.byKey(const ValueKey('about-cyprus-logo'));
    expect(euLogo, findsOneWidget);
    expect(cyprusLogo, findsOneWidget);
    expect(
      (tester.widget<Image>(euLogo).image as AssetImage).assetName,
      'assets/branding/eu_flag_color.png',
    );
    expect(
      (tester.widget<Image>(cyprusLogo).image as AssetImage).assetName,
      'assets/branding/republic_of_cyprus_emblem.png',
    );

    final website = find.byKey(const ValueKey('about-website'));
    await tester.scrollUntilVisible(
      website,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(website);
    await tester.pump();

    final suggestions = find.byKey(const ValueKey('about-suggestions-email'));
    await tester.scrollUntilVisible(
      suggestions,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(suggestions);
    await tester.pump();

    expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    expect(launchedUris.first, Uri.parse(eurotrexWebsiteUrl));
    expect(launchedUris.last.scheme, 'mailto');
    expect(launchedUris.last.path, eurotrexSuggestionsEmail);
    expect(
      launchedUris.last.queryParameters['subject'],
      'EUROTREX app suggestion',
    );
  });

  testWidgets(
    'suggestion opens the website contact form when email is unavailable',
    (tester) async {
      final launchedUris = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
            externalUrlLauncherProvider.overrideWithValue((uri) async {
              launchedUris.add(uri);
              return uri.scheme == 'https';
            }),
          ],
          child: const MaterialApp(home: AboutScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final suggestions = find.byKey(const ValueKey('about-suggestions-email'));
      await tester.scrollUntilVisible(
        suggestions,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(suggestions);
      await tester.pump();

      expect(launchedUris, hasLength(2));
      expect(launchedUris.first.scheme, 'mailto');
      expect(launchedUris.first.path, eurotrexSuggestionsEmail);
      expect(launchedUris.last, Uri.parse(eurotrexWebsiteUrl));
      expect(
        find.text(
          'No email app is available. Opening the EUROTREX website contact form instead.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('upcoming E4 trails are noninteractive coming-soon rows', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MonkApp()));
    await tester.pumpAndSettle();

    const upcomingTrails = {
      'crete-e4': 'Crete E4',
      'peloponnese-e4': 'Peloponnese E4',
    };
    for (final trail in upcomingTrails.entries) {
      final card = find.byKey(ValueKey('coming-soon-${trail.key}'));
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(trail.value)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Coming soon')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.schedule_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byWidgetPredicate((widget) {
            if (widget is! Container || widget.decoration is! BoxDecoration) {
              return false;
            }
            return (widget.decoration! as BoxDecoration).color ==
                const Color(0xFFF2C94C);
          }),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('stage detail presents route metrics and services', (
    tester,
  ) async {
    const start = TrailStage(
      id: '124-pafos-airport',
      sequence: 124,
      name: 'Pafos Airport',
      accumulatedDistanceKm: 0,
      segmentLengthKm: 0,
      altitudeM: 2,
      services: {},
    );
    const stage = TrailStage(
      id: '123-acheleia',
      sequence: 123,
      name: 'Acheleia',
      accumulatedDistanceKm: 6.3,
      segmentLengthKm: 6.3,
      elevationUpM: 52,
      elevationDownM: 15,
      altitudeM: 39,
      services: {'lodging': true, 'drinkableWater': true, 'busStop': true},
    );
    const finish = TrailStage(
      id: '122-finish',
      sequence: 122,
      name: 'Finish',
      accumulatedDistanceKm: 10,
      segmentLengthKm: 3.7,
      altitudeM: 50,
      services: {},
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StageDetailScreen(
            stages: [start, stage, finish],
            initialIndex: 1,
          ),
        ),
      ),
    );

    expect(find.text('Acheleia'), findsOneWidget);
    expect(find.textContaining('STAGE 123'), findsOneWidget);
    expect(find.text('From Start'), findsOneWidget);
    expect(find.text('From Pafos'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-detail-position')),
        matching: find.text('6.3 km'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-detail-position')),
        matching: find.byKey(const ValueKey('stage-length-route-icon')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('stage-length-route-icon'))),
      const Size(40, 24),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-detail-position')),
        matching: find.byIcon(Icons.flag_rounded),
      ),
      findsNWidgets(2),
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('stage-length-start-flag')))
          .color,
      const Color(0xFF277653),
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('stage-length-finish-flag')))
          .color,
      const Color(0xFFD14B45),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-detail-position')),
        matching: find.byIcon(Icons.straighten_rounded),
      ),
      findsNothing,
    );
    expect(find.text('52 m'), findsOneWidget);
    expect(find.text('15 m'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('stage-detail-altitude')),
              matching: find.byIcon(Icons.landscape_outlined),
            ),
          )
          .color,
      Colors.black54,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('stage-detail-descent')),
              matching: find.byIcon(Icons.trending_down_rounded),
            ),
          )
          .color,
      const Color(0xFFD14B45),
    );
    expect(find.text('1 h 21 min'), findsOneWidget);
    final walkingTimeLabel = find.byKey(
      const ValueKey('walking-time-footnote-label'),
    );
    expect(walkingTimeLabel, findsOneWidget);
    expect(
      tester.widget<Text>(walkingTimeLabel).textSpan?.toPlainText(),
      'Estimated walking time *',
    );
    expect(
      find.byKey(const ValueKey('walking-time-footnote-note')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('walking-time-footnote-note')))
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('stage-detail-secondary-metrics')),
            )
            .dy,
      ),
    );
    expect(
      tester.getCenter(find.byKey(const Key('stage-detail-position'))).dy,
      closeTo(
        tester.getCenter(find.byKey(const Key('stage-detail-walking-time'))).dy,
        1,
      ),
    );
    expect(
      tester
          .getCenter(find.byKey(const Key('stage-detail-distance-from-start')))
          .dy,
      greaterThan(
        tester.getCenter(find.byKey(const Key('stage-detail-position'))).dy,
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-detail-distance-from-start')),
        matching: find.byIcon(Icons.hiking_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('stage-detail-walking-time')),
              matching: find.byIcon(Icons.schedule_rounded),
            ),
          )
          .color,
      const Color(0xFF1565C0),
    );
    expect(find.text('Drinking water'), findsOneWidget);
    expect(find.text('Available offline'), findsNothing);
    final bottomNavigation = find.byKey(
      const ValueKey('stage-detail-bottom-navigation'),
    );
    expect(bottomNavigation, findsOneWidget);
    expect(
      find.byKey(const Key('stage-detail-stages-shortcut')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-detail-accommodation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stage-detail-gps')), findsOneWidget);
    final mapAction = find.byKey(const ValueKey('stage-detail-map'));
    final elevationAction = find.byKey(
      const ValueKey('stage-detail-elevation'),
    );
    final appBar = find.byType(AppBar);
    expect(find.descendant(of: appBar, matching: mapAction), findsNothing);
    expect(
      find.descendant(of: appBar, matching: elevationAction),
      findsNothing,
    );
    expect(
      tester.getCenter(mapAction).dx,
      lessThan(tester.getCenter(elevationAction).dx),
    );
  });

  testWidgets('stage detail swipes between adjacent stages', (tester) async {
    const stages = [
      TrailStage(
        id: 'start',
        sequence: 3,
        name: 'Pafos Airport',
        accumulatedDistanceKm: 0,
        services: {},
      ),
      TrailStage(
        id: 'middle',
        sequence: 2,
        name: 'Troodos',
        accumulatedDistanceKm: 10,
        segmentLengthKm: 10,
        elevationUpM: 100,
        elevationDownM: 50,
        services: {},
      ),
      TrailStage(
        id: 'finish',
        sequence: 1,
        name: 'Larnaka Airport',
        accumulatedDistanceKm: 20,
        services: {},
      ),
    ];
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StageDetailScreen(stages: stages, initialIndex: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final swipeArea = find.byKey(const ValueKey('stage-detail-swipe-area'));
    expect(find.text('Troodos'), findsOneWidget);
    expect(find.textContaining('2/3'), findsOneWidget);

    await tester.fling(swipeArea, const Offset(-320, 0), 900);
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(const ValueKey('stage-detail-slide-transition')),
          )
          .position
          .value
          .dx,
      greaterThan(0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Larnaka Airport'), findsOneWidget);
    expect(find.textContaining('3/3'), findsOneWidget);

    await tester.fling(swipeArea, const Offset(320, 0), 900);
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(const ValueKey('stage-detail-slide-transition')),
          )
          .position
          .value
          .dx,
      lessThan(0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Troodos'), findsOneWidget);
    expect(find.textContaining('2/3'), findsOneWidget);
  });

  testWidgets('map preview appears on every stage including the start', (
    tester,
  ) async {
    final stages = List.generate(
      8,
      (index) => TrailStage(
        id: 'stage-$index',
        sequence: 8 - index,
        name: index == 0 ? 'Start' : 'Stage $index',
        accumulatedDistanceKm: index * 5,
        services: const {},
      ),
    );
    for (var stageIndex = 0; stageIndex < stages.length; stageIndex++) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StageDetailScreen(
              key: ValueKey('preview-stage-$stageIndex'),
              stages: stages,
              initialIndex: stageIndex,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(stageIndex == 0 ? 'Start' : 'Stage $stageIndex'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('stage-map-preview')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('stage-map-preview'))).height,
        250,
      );
      expect(find.byKey(const Key('stage-trail-position-copy')), findsNothing);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Next'), findsNothing);
    }
  });

  testWidgets('stage map preview carries its accommodation into the map', (
    tester,
  ) async {
    const stages = [
      TrailStage(
        id: 'preview-start',
        sequence: 2,
        name: 'Preview start',
        accumulatedDistanceKm: 0,
        services: {},
      ),
      TrailStage(
        id: 'preview-stage',
        sequence: 1,
        name: 'Preview stage',
        accumulatedDistanceKm: 10,
        services: {},
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          elevationProvider.overrideWith(_FakeElevationController.new),
          lodgingRepositoryProvider.overrideWithValue(
            const _FakeLodgingRepository({
              'preview-stage': [
                Lodging(
                  id: 'preview-hotel',
                  stageId: 'preview-stage',
                  name: 'Preview Hotel',
                  type: 'Hotel',
                  location: LodgingLocation(latitude: 34.76, longitude: 32.46),
                ),
              ],
            }),
          ),
        ],
        child: const MaterialApp(
          home: StageDetailScreen(stages: stages, initialIndex: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final preview = find.byKey(const Key('stage-map-open'));
    await tester.scrollUntilVisible(
      preview,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(preview);
    await tester.pumpAndSettle();

    final map = tester.widget<MapScreen>(find.byType(MapScreen));
    expect(map.initialStageIndex, 1);
    expect(map.initialLodgings.map((lodging) => lodging.id), ['preview-hotel']);
  });

  testWidgets('stage detail shortcut returns past the map to stages', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'stage-one',
      sequence: 1,
      name: 'Stage one',
      accumulatedDistanceKm: 10,
      services: {},
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (rootContext) => Scaffold(
              body: TextButton(
                key: const Key('open-map-route'),
                onPressed: () => Navigator.of(rootContext).push(
                  MaterialPageRoute<void>(
                    builder: (mapContext) => Scaffold(
                      body: TextButton(
                        key: const Key('open-stage-from-map'),
                        onPressed: () => Navigator.of(mapContext).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const StageDetailScreen(
                              stages: [stage],
                              initialIndex: 0,
                            ),
                          ),
                        ),
                        child: const Text('Map screen'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Stages screen'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-map-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-stage-from-map')));
    await tester.pumpAndSettle();
    expect(find.text('Stage one'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stage-detail-stages-shortcut')));
    await tester.pumpAndSettle();
    expect(find.text('Stages screen'), findsOneWidget);
    expect(find.text('Map screen'), findsNothing);
  });

  testWidgets('stage effort swaps ascent and descent for reverse travel', (
    tester,
  ) async {
    const reverseStart = TrailStage(
      id: 'reverse-start',
      sequence: 3,
      name: 'Larnaka Airport',
      accumulatedDistanceKm: 10,
      segmentLengthKm: 6.3,
      elevationUpM: 52,
      elevationDownM: 15,
      services: {},
    );
    const stage = TrailStage(
      id: 'reverse-stage',
      sequence: 2,
      name: 'Reverse stage',
      accumulatedDistanceKm: 3.7,
      segmentLengthKm: 3.7,
      elevationUpM: 400,
      elevationDownM: 300,
      services: {},
    );
    const reverseFinish = TrailStage(
      id: 'reverse-finish',
      sequence: 1,
      name: 'Pafos Airport',
      accumulatedDistanceKm: 0,
      segmentLengthKm: 0,
      services: {},
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StageDetailScreen(
            stages: [reverseStart, stage, reverseFinish],
            initialIndex: 1,
            direction: TrailDirection.larnakaToPafos,
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('stage-detail-ascent')),
        matching: find.text('15 m'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-detail-descent')),
        matching: find.text('52 m'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 h 17 min'), findsOneWidget);
  });

  testWidgets('zero-length trail endpoint is presented as the finish', (
    tester,
  ) async {
    const stages = [
      TrailStage(
        id: 'start',
        sequence: 2,
        name: 'Pafos Airport',
        accumulatedDistanceKm: 0,
        segmentLengthKm: 0,
        services: {},
      ),
      TrailStage(
        id: 'finish',
        sequence: 1,
        name: 'Larnaka Airport',
        accumulatedDistanceKm: 558,
        segmentLengthKm: 0,
        services: {},
      ),
    ];
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StageDetailScreen(stages: stages, initialIndex: 1),
        ),
      ),
    );

    expect(find.textContaining('FINISH'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('0.0 km'), findsNothing);
  });

  testWidgets('reversed start takes priority over its stored stage length', (
    tester,
  ) async {
    const stages = [
      TrailStage(
        id: 'larnaka',
        sequence: 1,
        name: 'Larnaka Airport',
        accumulatedDistanceKm: 558,
        segmentLengthKm: 2.4,
        elevationUpM: 90,
        elevationDownM: 30,
        services: {},
      ),
      TrailStage(
        id: 'previous-stage',
        sequence: 2,
        name: 'Previous stage',
        accumulatedDistanceKm: 555.6,
        segmentLengthKm: 3,
        services: {},
      ),
    ];
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StageDetailScreen(
            stages: stages,
            initialIndex: 0,
            direction: TrailDirection.larnakaToPafos,
          ),
        ),
      ),
    );

    final positionCard = find.byKey(const Key('stage-detail-position'));
    expect(
      find.descendant(of: positionCard, matching: find.text('Start')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: positionCard, matching: find.text('Trail position')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: positionCard, matching: find.text('2.4 km')),
      findsNothing,
    );
    expect(
      find.descendant(of: positionCard, matching: find.text('Stage length')),
      findsNothing,
    );
    expect(find.byKey(const Key('stage-detail-ascent')), findsNothing);
    expect(find.byKey(const Key('stage-detail-descent')), findsNothing);
    expect(find.byKey(const Key('stage-detail-walking-time')), findsNothing);
  });

  testWidgets('stage detail elevation shortcut opens the selected stage', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'stage-one',
      sequence: 1,
      name: 'Stage one',
      accumulatedDistanceKm: 5,
      altitudeM: 50,
      services: {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          elevationProvider.overrideWith(_FakeElevationController.new),
          stagesProvider.overrideWith(_SingleStageController.new),
        ],
        child: const MaterialApp(
          home: StageDetailScreen(stages: [stage], initialIndex: 0),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('stage-detail-elevation')));
    await tester.pumpAndSettle();
    expect(find.byType(ElevationScreen), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(
      chart.transformationConfig.transformationController!.value
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
    final stageToggle = find.byKey(const Key('elevation-stage-toggle'));
    expect(find.text('Stage one'), findsOneWidget);

    await tester.tap(stageToggle);
    await tester.pumpAndSettle();
    expect(find.text('Stage one'), findsOneWidget);

    await tester.tap(stageToggle);
    await tester.pumpAndSettle();
    expect(find.text('Stage one'), findsNothing);

    await tester.tap(stageToggle);
    await tester.pumpAndSettle();
    expect(find.text('Stage one'), findsOneWidget);
  });

  testWidgets('stages can reverse the shared trail direction', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stagesProvider.overrideWith(_EndpointStagesController.new)],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final pafosCard = find.byKey(const ValueKey('stage-card-pafos'));
    final larnakaCard = find.byKey(const ValueKey('stage-card-larnaka'));
    final pafosDistance = find.byKey(
      const ValueKey('stage-card-distance-pafos'),
    );
    final larnakaDistance = find.byKey(
      const ValueKey('stage-card-distance-larnaka'),
    );
    final pafosAltitude = find.byKey(
      const ValueKey('stage-card-altitude-pafos'),
    );
    final larnakaAltitude = find.byKey(
      const ValueKey('stage-card-altitude-larnaka'),
    );
    final pafosServices = find.byKey(
      const ValueKey('stage-card-services-pafos'),
    );
    final larnakaSideMetrics = find.byKey(
      const ValueKey('stage-side-metrics-larnaka'),
    );
    final pafosEndpoint = find.byKey(const ValueKey('stage-endpoint-pafos'));
    final larnakaEndpoint = find.byKey(
      const ValueKey('stage-endpoint-larnaka'),
    );
    final pafosMarker = find.byKey(const ValueKey('stage-marker-pafos'));
    final larnakaMarker = find.byKey(const ValueKey('stage-marker-larnaka'));
    final larnakaAscent = find.byKey(const ValueKey('stage-ascent-larnaka'));
    final larnakaDescent = find.byKey(const ValueKey('stage-descent-larnaka'));
    final larnakaLength = find.byKey(const ValueKey('stage-length-larnaka'));
    final pafosAscent = find.byKey(const ValueKey('stage-ascent-pafos'));
    final pafosDescent = find.byKey(const ValueKey('stage-descent-pafos'));
    final pafosLength = find.byKey(const ValueKey('stage-length-pafos'));

    expect(find.text('Pafos Airport  →  Larnaka Airport'), findsOneWidget);
    expect(pafosDistance, findsNothing);
    expect(pafosAltitude, findsOneWidget);
    expect(larnakaDistance, findsOneWidget);
    expect(larnakaAltitude, findsOneWidget);
    expect(
      tester.getCenter(larnakaDistance).dx,
      lessThan(tester.getCenter(larnakaAltitude).dx),
    );
    expect(
      find.descendant(of: pafosServices, matching: pafosAltitude),
      findsNothing,
    );
    expect(
      tester.getCenter(larnakaSideMetrics).dx,
      lessThan(tester.getCenter(larnakaMarker).dx),
    );
    expect(
      find.descendant(of: larnakaAscent, matching: find.text('120m')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: larnakaDescent, matching: find.text('45m')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: larnakaLength, matching: find.text('10.0km')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: larnakaLength,
        matching: find.byIcon(Icons.straighten_rounded),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(
      find.descendant(of: pafosEndpoint, matching: find.text('Start')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: larnakaEndpoint, matching: find.text('Finish')),
      findsOneWidget,
    );
    expect(
      tester.getCenter(pafosEndpoint).dx,
      lessThan(tester.getCenter(pafosMarker).dx),
    );
    expect(
      tester.getCenter(larnakaEndpoint).dx,
      lessThan(tester.getCenter(larnakaMarker).dx),
    );
    expect(
      find.descendant(of: pafosCard, matching: find.text('Start')),
      findsNothing,
    );
    expect(
      find.descendant(of: larnakaCard, matching: find.text('Finish')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('reverse-trail-direction')));
    await tester.pumpAndSettle();

    expect(find.text('Larnaka Airport  →  Pafos Airport'), findsOneWidget);
    expect(larnakaDistance, findsNothing);
    expect(pafosDistance, findsOneWidget);
    expect(larnakaAscent, findsNothing);
    expect(larnakaDescent, findsNothing);
    expect(larnakaLength, findsNothing);
    expect(
      find.descendant(of: pafosAscent, matching: find.text('45m')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pafosDescent, matching: find.text('120m')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pafosLength, matching: find.text('10.0km')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: larnakaEndpoint, matching: find.text('Start')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pafosEndpoint, matching: find.text('Finish')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: larnakaCard, matching: find.text('Start')),
      findsNothing,
    );
    expect(
      find.descendant(of: pafosCard, matching: find.text('Finish')),
      findsNothing,
    );

    await tester.ensureVisible(larnakaCard);
    await tester.tap(larnakaCard);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stage-detail-ascent')), findsNothing);
    expect(find.byKey(const Key('stage-detail-descent')), findsNothing);
    expect(find.byKey(const Key('stage-detail-walking-time')), findsNothing);
  });

  testWidgets('bottom navigation filters stages by trail points and services', (
    tester,
  ) async {
    Future<void> tapFilterAction(Key key) async {
      final action = find.byKey(key);
      await tester.scrollUntilVisible(
        action,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [stagesProvider.overrideWith(_FilterStagesController.new)],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stage-bottom-navigation')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-gps-locate')), findsNothing);
    final troodosNumber = find.byKey(const ValueKey('stage-number-troodos'));
    expect(troodosNumber, findsOneWidget);
    expect(tester.widget<Text>(troodosNumber).data, '2');
    expect(tester.widget<Text>(troodosNumber).style?.fontSize, 12);
    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Filter stages'), findsNothing);
    expect(
      find.text('Choose stages, trail points and services.'),
      findsNothing,
    );
    expect(find.text('Stage name'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-name-filter')), findsOneWidget);
    expect(find.text('Trail points'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-filter-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-filter-finish')), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Apply filters'), findsNothing);
    expect(
      find.byKey(const Key('clear-service-filter-selection')),
      findsOneWidget,
    );
    expect(
      tester.widget(find.byKey(const Key('clear-service-filter-selection'))),
      isA<OutlinedButton>(),
    );

    final stageNameFilter = find.byKey(const ValueKey('stage-name-filter'));
    await tester.enterText(stageNameFilter, '#2');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-name-suggestion-troodos')),
      findsOneWidget,
    );
    await tester.enterText(stageNameFilter, 'troo');
    await tester.pumpAndSettle();
    final troodosSuggestion = find.byKey(
      const ValueKey('stage-name-suggestion-troodos'),
    );
    expect(troodosSuggestion, findsOneWidget);
    await tester.tap(troodosSuggestion);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('selected-stage-filter-troodos')),
      findsOneWidget,
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final applyFilters = find.byKey(const Key('apply-service-filters'));
    await tester.scrollUntilVisible(
      applyFilters,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(applyFilters);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stage-card-troodos')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-pafos')), findsNothing);
    expect(find.byKey(const ValueKey('stage-card-larnaka')), findsNothing);
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('stage-waymark-line')))
          .color,
      const Color(0xFFB9BDB8),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('stage-line-before-troodos')),
          )
          .color,
      const Color(0xFFB9BDB8),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('stage-line-after-troodos')),
          )
          .color,
      Colors.transparent,
    );

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    await tapFilterAction(const Key('clear-service-filter-selection'));
    expect(find.byKey(const ValueKey('stage-card-troodos')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-pafos')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-larnaka')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stage-name-filter')),
      'pafos',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-name-suggestion-pafos')));
    await tester.enterText(
      find.byKey(const ValueKey('stage-name-filter')),
      'larnaka',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('stage-name-suggestion-larnaka')),
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tapFilterAction(const Key('apply-service-filters'));
    expect(find.byKey(const ValueKey('stage-card-pafos')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-troodos')), findsNothing);
    expect(find.byKey(const ValueKey('stage-card-larnaka')), findsOneWidget);
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('stage-line-after-pafos')),
          )
          .color,
      Colors.transparent,
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('stage-line-before-larnaka')),
          )
          .color,
      Colors.transparent,
    );
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('stage-waymark-line')))
          .color,
      const Color(0xFFB9BDB8),
    );

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    await tapFilterAction(const Key('clear-service-filter-selection'));

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-filter-start')));
    await tapFilterAction(const Key('apply-service-filters'));
    expect(find.byKey(const ValueKey('stage-card-pafos')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-larnaka')), findsNothing);
    expect(find.byKey(const ValueKey('stage-card-troodos')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reverse-trail-direction')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stage-card-larnaka')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-pafos')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    await tapFilterAction(const Key('clear-service-filter-selection'));
    expect(find.text('Filter stages'), findsNothing);
    expect(find.byKey(const ValueKey('stage-card-larnaka')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-card-pafos')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('service-filter-lodging')));
    await tapFilterAction(const Key('apply-service-filters'));
    expect(find.text('No stages match these filters.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    await tapFilterAction(const Key('clear-service-filter-selection'));
    expect(find.text('Filter stages'), findsNothing);
    expect(find.text('No stages match these filters.'), findsNothing);
  });

  testWidgets('stage number search matches an exact single-digit stage', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stagesProvider.overrideWith(_ManyStagesController.new)],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stage-bottom-filter')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stage-name-filter')),
      '1',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stage-name-suggestion-stage-29')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stage-name-suggestion-stage-9')),
      findsNothing,
    );
  });

  testWidgets('stage bottom navigation stays visible and opens trail views', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stagesProvider.overrideWith(_ManyStagesController.new),
          elevationProvider.overrideWith(_FakeElevationController.new),
        ],
        child: const MaterialApp(home: StagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final bottomNavigation = find.byKey(
      const ValueKey('stage-bottom-navigation'),
    );
    expect(bottomNavigation, findsOneWidget);
    expect(find.byKey(const ValueKey('stage-bottom-filter')), findsOneWidget);
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reverse-trail-direction')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-bottom-gps')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stage-bottom-gps-surface')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stage-bottom-map')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stage-bottom-elevation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stage-e4-waymark')), findsOneWidget);
    expect(
      find.descendant(of: bottomNavigation, matching: find.text('Filter')),
      findsNothing,
    );
    expect(
      find.descendant(of: bottomNavigation, matching: find.text('Map')),
      findsNothing,
    );
    expect(
      find.descendant(of: bottomNavigation, matching: find.text('Elevation')),
      findsNothing,
    );
    expect(
      tester.widget<Material>(bottomNavigation).color,
      const Color(0xFFF4F2EC),
    );

    final navigationSize = find.byKey(
      const ValueKey('stage-bottom-navigation-size'),
    );
    final filter = find.byKey(const ValueKey('stage-bottom-filter'));
    final reverse = find.byKey(const ValueKey('reverse-trail-direction'));
    final gps = find.byKey(const ValueKey('stage-bottom-gps'));
    final initialBottom = tester.getBottomLeft(bottomNavigation).dy;
    expect(tester.getSize(navigationSize), const Size(800, 48));
    expect(tester.getCenter(reverse).dx, lessThan(tester.getCenter(filter).dx));
    expect(tester.getCenter(filter).dx, lessThan(tester.getCenter(gps).dx));
    expect(
      tester.getCenter(gps).dx,
      moreOrLessEquals(tester.getCenter(bottomNavigation).dx, epsilon: 0.1),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getSize(navigationSize), const Size(800, 48));
    expect(tester.getBottomLeft(bottomNavigation).dy, initialBottom);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.getSize(navigationSize), const Size(800, 48));
    expect(tester.getBottomLeft(bottomNavigation).dy, initialBottom);

    await tester.tap(find.byKey(const ValueKey('stage-bottom-map')));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    expect(bottomNavigation, findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-bottom-elevation')));
    await tester.pumpAndSettle();
    expect(find.byType(ElevationScreen), findsOneWidget);
    expect(bottomNavigation, findsNothing);
  });

  testWidgets('stage accommodation opens and launches its booking website', (
    tester,
  ) async {
    const lodgingStage = TrailStage(
      id: 'lodging-stage',
      sequence: 1,
      name: 'Lodging stage',
      accumulatedDistanceKm: 1,
      altitudeM: 100,
      services: {},
    );
    final launchedUris = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stagesProvider.overrideWith(_LodgingStagesController.new),
          elevationProvider.overrideWith(_FakeElevationController.new),
          lodgingRepositoryProvider.overrideWithValue(
            const _FakeLodgingRepository({
              'lodging-stage': [
                Lodging(
                  id: 'forest-inn',
                  stageId: 'lodging-stage',
                  name: 'Forest Inn',
                  type: 'Hotel',
                  village: 'Platres',
                  address: '1 Mountain Road',
                  phone: '+357 99123456',
                  email: 'stay@example.com',
                  priceMinEur: 75,
                  priceMaxEur: 95,
                  distanceFromTrailKm: 0.4,
                  monthsOpen: 'Apr–Oct',
                  capacityPeople: 28,
                  checkInTime: '14:00',
                  checkOutTime: '11:00',
                  website: 'https://booking.example.com/forest-inn',
                  location: LodgingLocation(
                    latitude: 34.915,
                    longitude: 32.845,
                  ),
                ),
              ],
            }),
          ),
          externalUrlLauncherProvider.overrideWithValue((uri) async {
            launchedUris.add(uri);
            return true;
          }),
        ],
        child: const MaterialApp(
          home: StageDetailScreen(stages: [lodgingStage], initialIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final booking = find.byKey(const ValueKey('stage-detail-accommodation'));
    expect(booking, findsOneWidget);
    expect(
      find.descendant(of: booking, matching: find.text('1')),
      findsOneWidget,
    );
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('0.0 km'), findsNothing);
    expect(find.text('View places to stay'), findsNothing);
    expect(find.text('View accommodation'), findsNothing);
    expect(find.text('Coming soon'), findsNothing);
    expect(
      find.byKey(const ValueKey('stage-accommodation-lodging-stage')),
      findsNothing,
    );

    await tester.tap(booking);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accommodation-screen-lodging-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('lodging-type-icon-lodging')),
      findsOneWidget,
    );
    final marker = tester.widget<Container>(
      find.byKey(const ValueKey('lodging-type-marker-forest-inn')),
    );
    expect(
      marker.decoration,
      isA<BoxDecoration>()
          .having(
            (decoration) => decoration.color,
            'color',
            const Color(0xFF8C727B),
          )
          .having((decoration) => decoration.shape, 'shape', BoxShape.circle),
    );
    expect(find.text('Forest Inn'), findsOneWidget);
    expect(find.textContaining('Platres'), findsNothing);
    expect(find.text('0.4 km'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cyprus-country-flag-forest-inn')),
      findsNothing,
    );
    expect(find.text('+357 99 123 456'), findsNothing);
    expect(find.text('Book accommodation'), findsNothing);
    expect(find.text('Book'), findsOneWidget);

    final bottomNavigation = find.byKey(
      const ValueKey('accommodation-bottom-navigation'),
    );
    final stagesShortcut = find.byKey(
      const ValueKey('accommodation-stages-shortcut'),
    );
    final filterAction = find.byKey(const ValueKey('accommodation-filter'));
    final gpsAction = find.byKey(const ValueKey('accommodation-gps'));
    final navigationMap = find.byKey(const ValueKey('accommodation-map'));
    final navigationElevation = find.byKey(
      const ValueKey('accommodation-elevation'),
    );
    expect(bottomNavigation, findsOneWidget);
    expect(
      tester.getCenter(stagesShortcut).dx,
      lessThan(tester.getCenter(filterAction).dx),
    );
    expect(
      tester.getCenter(filterAction).dx,
      lessThan(tester.getCenter(gpsAction).dx),
    );
    expect(
      tester.getCenter(gpsAction).dx,
      lessThan(tester.getCenter(navigationMap).dx),
    );
    expect(
      tester.getCenter(navigationMap).dx,
      lessThan(tester.getCenter(navigationElevation).dx),
    );
    final gpsInkWell = find.descendant(
      of: gpsAction,
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(gpsInkWell).onTap, isNotNull);
    expect(
      find.descendant(
        of: filterAction,
        matching: find.byIcon(Icons.filter_list_rounded),
      ),
      findsOneWidget,
    );

    final contactActions = find.byKey(
      const ValueKey('lodging-contact-actions-forest-inn'),
    );
    final map = find.byKey(const ValueKey('map-location-lodging-forest-inn'));
    final call = find.byKey(const ValueKey('call-lodging-forest-inn'));
    final email = find.byKey(const ValueKey('email-lodging-forest-inn'));
    expect(contactActions, findsOneWidget);
    expect(find.descendant(of: contactActions, matching: map), findsOneWidget);
    expect(find.descendant(of: contactActions, matching: call), findsOneWidget);
    expect(
      find.descendant(of: contactActions, matching: email),
      findsOneWidget,
    );
    expect(
      (tester.getCenter(map).dy - tester.getCenter(call).dy).abs(),
      lessThan(1),
    );
    expect(
      (tester.getCenter(call).dy - tester.getCenter(email).dy).abs(),
      lessThan(1),
    );

    await tester.scrollUntilVisible(
      call,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(call);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      email,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(email);
    await tester.pumpAndSettle();
    expect(launchedUris, [
      Uri.parse('tel:+35799123456'),
      Uri.parse('mailto:stay@example.com'),
    ]);
    launchedUris.clear();

    expect(find.text('View on map'), findsNothing);
    await tester.scrollUntilVisible(
      map,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(map);
    await tester.pumpAndSettle();

    final mapScreen = tester.widget<MapScreen>(find.byType(MapScreen));
    expect(mapScreen.initialLodging?.id, 'forest-inn');
    expect(mapScreen.initialLodging?.location?.latitude, 34.915);
    expect(mapScreen.initialLodging?.location?.longitude, 32.845);
    expect(launchedUris, isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final book = find.byKey(const ValueKey('book-lodging-forest-inn'));
    await tester.scrollUntilVisible(
      book,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(book);
    await tester.pumpAndSettle();
    expect(launchedUris, [Uri.parse('https://booking.example.com/forest-inn')]);

    await tester.tap(navigationMap);
    await tester.pumpAndSettle();
    final stageMap = tester.widget<MapScreen>(find.byType(MapScreen));
    expect(stageMap.initialStageIndex, 0);
    expect(stageMap.initialLodgings.map((lodging) => lodging.id), [
      'forest-inn',
    ]);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(navigationElevation);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElevationScreen>(find.byType(ElevationScreen))
          .initialStageIndex,
      0,
    );
  });

  testWidgets('stage accommodation action is disabled when none is available', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'no-lodging-stage',
      sequence: 1,
      name: 'No lodging stage',
      accumulatedDistanceKm: 0,
      services: {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lodgingRepositoryProvider.overrideWithValue(
            const _FakeLodgingRepository({}),
          ),
        ],
        child: const MaterialApp(
          home: StageDetailScreen(stages: [stage], initialIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View places to stay'), findsNothing);
    final accommodation = find.byKey(
      const ValueKey('stage-detail-accommodation'),
    );
    final action = tester.widget<InkWell>(
      find.descendant(of: accommodation, matching: find.byType(InkWell)),
    );
    final tooltip = tester.widget<Tooltip>(
      find.descendant(of: accommodation, matching: find.byType(Tooltip)),
    );
    expect(action.onTap, isNull);
    expect(tooltip.message, 'No accommodation is listed for this stage.');
  });

  testWidgets('accommodation filters by booking distance and type', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'lodging-stage',
      sequence: 1,
      name: 'Lodging stage',
      accumulatedDistanceKm: 1,
      services: {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stagesProvider.overrideWith(_LodgingStagesController.new),
          lodgingRepositoryProvider.overrideWithValue(
            const _FakeLodgingRepository({
              'lodging-stage': [
                Lodging(
                  id: 'online-hotel',
                  stageId: 'lodging-stage',
                  name: 'Online Hotel',
                  type: 'Hotel',
                  distanceFromTrailKm: 0.3,
                  website: 'https://booking.example.com/hotel',
                ),
                Lodging(
                  id: 'nearby-guesthouse',
                  stageId: 'lodging-stage',
                  name: 'Nearby Guesthouse',
                  type: 'Guesthouse',
                  distanceFromTrailKm: 0.4,
                ),
                Lodging(
                  id: 'distant-picnic-site',
                  stageId: 'lodging-stage',
                  name: 'Distant Picnic Site',
                  type: 'Picnic site',
                  distanceFromTrailKm: 3,
                  website: 'https://booking.example.com/picnic',
                ),
              ],
            }),
          ),
        ],
        child: const MaterialApp(home: AccommodationScreen(stage: stage)),
      ),
    );
    await tester.pumpAndSettle();

    final filterAction = find.byKey(const ValueKey('accommodation-filter'));
    final initialFilterBadge = tester.widget<Badge>(
      find.descendant(of: filterAction, matching: find.byType(Badge)),
    );
    expect(initialFilterBadge.isLabelVisible, isFalse);
    await tester.tap(filterAction);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accommodation-filter-sheet')),
      findsOneWidget,
    );
    expect(find.text('Filter accommodation'), findsNothing);
    expect(find.text('Bookable online'), findsOneWidget);
    expect(find.text('Maximum distance from trail'), findsNothing);
    expect(find.text('Accommodation type'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Apply filters'), findsNothing);
    final hotelType = find.byKey(const ValueKey('accommodation-type-hotel'));
    expect(
      find.descendant(
        of: hotelType,
        matching: find.byKey(const ValueKey('lodging-type-icon-lodging')),
      ),
      findsOneWidget,
    );
    final guesthouseType = find.byKey(
      const ValueKey('accommodation-type-guesthouse'),
    );
    expect(
      find.descendant(
        of: guesthouseType,
        matching: find.byKey(const ValueKey('lodging-type-icon-home')),
      ),
      findsOneWidget,
    );
    final picnicType = find.byKey(
      const ValueKey('accommodation-type-picnic-site'),
    );
    expect(
      find.descendant(
        of: picnicType,
        matching: find.byKey(const ValueKey('lodging-type-icon-picnic-site')),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('accommodation-bookable-filter')),
    );
    await tester.scrollUntilVisible(
      hotelType,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(hotelType);
    final apply = find.byKey(const ValueKey('accommodation-filter-apply'));
    await tester.scrollUntilVisible(
      apply,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(apply);
    await tester.pumpAndSettle();

    final gpsAction = find.byKey(const ValueKey('accommodation-gps'));
    await tester.tap(gpsAction);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accommodation-distance-filter-sheet')),
      findsOneWidget,
    );
    expect(find.text('Maximum distance from trail'), findsOneWidget);
    expect(find.byIcon(Icons.gps_fixed_rounded), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('accommodation-distance-0.5')));
    await tester.tap(
      find.byKey(const ValueKey('accommodation-distance-apply')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lodging-card-online-hotel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('lodging-card-nearby-guesthouse')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('lodging-card-distant-picnic-site')),
      findsNothing,
    );
    expect(
      find.descendant(of: filterAction, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: gpsAction,
        matching: find.byIcon(Icons.gps_fixed_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(filterAction);
    await tester.pumpAndSettle();
    final clear = find.byKey(const ValueKey('accommodation-filter-clear'));
    await tester.scrollUntilVisible(
      clear,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: filterAction, matching: find.text('2')),
      findsNothing,
    );
  });

  testWidgets('accommodation stage shortcut returns to the stage flow', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'lodging-stage',
      sequence: 1,
      name: 'Lodging stage',
      services: {},
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lodgingRepositoryProvider.overrideWithValue(
            const _FakeLodgingRepository({}),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(
            key: ValueKey('stages-flow-root'),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const AccommodationScreen(stage: stage),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('accommodation-stages-shortcut')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stages-flow-root')), findsOneWidget);
    expect(find.byType(AccommodationScreen), findsNothing);
  });

  testWidgets('accommodation handles empty data and invalid booking links', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'stage-without-link',
      sequence: 1,
      name: 'Mountain stage',
      services: {},
    );
    final repository = _MutableLodgingRepository(const [
      Lodging(
        id: 'mountain-shelter',
        stageId: 'stage-without-link',
        name: 'Mountain Shelter',
        website: 'not-a-valid-url',
        googleMapsUrl: 'https://maps.example.com/mountain-shelter',
        checkInTime: '00:00',
        checkOutTime: '00:00',
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [lodgingRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AccommodationScreen(stage: stage)),
      ),
    );
    await tester.pumpAndSettle();

    final unavailable = find.byKey(
      const ValueKey('book-lodging-mountain-shelter'),
    );
    expect(unavailable, findsNothing);
    expect(find.text('Booking link unavailable'), findsNothing);
    expect(find.text('00:00'), findsNothing);
    expect(
      find.byKey(const ValueKey('map-location-lodging-mountain-shelter')),
      findsNothing,
    );
    expect(find.text('View on map'), findsNothing);

    repository.lodgings = const [];
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccommodationScreen)),
    );
    container.invalidate(lodgingsForStageProvider(stage.id));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accommodation-empty')), findsOneWidget);
    expect(
      find.text('No accommodation is listed for this stage.'),
      findsOneWidget,
    );
  });

  testWidgets('accommodation error state retries the stage query', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'retry-stage',
      sequence: 1,
      name: 'Retry stage',
      services: {},
    );
    final repository = _RetryLodgingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [lodgingRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AccommodationScreen(stage: stage)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('accommodation-error')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accommodation-retry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('lodging-card-recovered-lodging')),
      findsOneWidget,
    );
    expect(repository.calls, 2);
  });

  testWidgets('accommodation reports an external booking launch failure', (
    tester,
  ) async {
    const stage = TrailStage(
      id: 'failed-launch-stage',
      sequence: 1,
      name: 'Failed launch stage',
      services: {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lodgingRepositoryProvider.overrideWithValue(
            const _FakeLodgingRepository({
              'failed-launch-stage': [
                Lodging(
                  id: 'failed-launch-lodging',
                  name: 'Forest Hotel',
                  website: 'https://booking.example.com/forest-hotel',
                ),
              ],
            }),
          ),
          externalUrlLauncherProvider.overrideWithValue((_) async => false),
        ],
        child: const MaterialApp(home: AccommodationScreen(stage: stage)),
      ),
    );
    await tester.pumpAndSettle();

    final book = find.byKey(
      const ValueKey('book-lodging-failed-launch-lodging'),
    );
    await tester.scrollUntilVisible(
      book,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(book);
    await tester.pump();

    expect(find.text('Could not open this link.'), findsOneWidget);
  });

  testWidgets('settings change language and measurement system app-wide', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stagesProvider.overrideWith(_FakeStagesController.new),
          appSettingsProvider.overrideWith(_FakeAppSettingsController.new),
          offlineMapProvider.overrideWith(_FakeOfflineMapController.new),
        ],
        child: const MonkApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('App preferences'), findsNothing);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Metric'), findsOneWidget);
    expect(
      find.byKey(const Key('settings-delete-offline-maps')),
      findsOneWidget,
    );

    final deleteOfflineMap = find.byKey(
      const Key('settings-delete-offline-maps'),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(deleteOfflineMap);
    await tester.pumpAndSettle();
    expect(find.text('Remove offline map?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-offline-maps')));
    await tester.pumpAndSettle();
    expect(find.text('Offline map not downloaded'), findsOneWidget);

    final imperial = find.text('Imperial');
    await tester.drag(find.byType(ListView).last, const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(imperial);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('347 mi'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Maßeinheiten'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-setting')));
    await tester.pumpAndSettle();
    expect(find.text('Italiano'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    await tester.tap(find.text('Italiano'));
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni'), findsOneWidget);
    expect(find.text('Lingua'), findsOneWidget);
    expect(find.text('Unità di misura'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Unités de mesure'), findsOneWidget);
  });

  testWidgets('elevation stage markers can be shown and hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          elevationProvider.overrideWith(_FakeElevationController.new),
          stagesProvider.overrideWith(_FakeStagesController.new),
        ],
        child: const MaterialApp(home: ElevationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('elevation-total-ascent')),
        matching: find.text('98 m'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('elevation-total-descent')),
        matching: find.text('0 m'),
      ),
      findsOneWidget,
    );
    expect(find.text('Total ascent'), findsOneWidget);
    expect(find.text('Total descent'), findsOneWidget);
    expect(find.text('Offline samples'), findsNothing);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.transformationConfig.scaleAxis, FlScaleAxis.horizontal);
    expect(chart.transformationConfig.maxScale, 15);
    final transformationController =
        chart.transformationConfig.transformationController!;
    final chartCenter = tester.getCenter(find.byType(LineChart));
    final leftFinger = await tester.startGesture(
      chartCenter - const Offset(20, 0),
      pointer: 1,
    );
    final rightFinger = await tester.startGesture(
      chartCenter + const Offset(20, 0),
      pointer: 2,
    );
    await leftFinger.moveTo(chartCenter - const Offset(70, 0));
    await rightFinger.moveTo(chartCenter + const Offset(70, 0));
    await tester.pump();
    await leftFinger.up();
    await rightFinger.up();
    expect(transformationController.value.storage[0], greaterThan(1));

    await tester.tap(find.byKey(const Key('elevation-reset-view')));
    await tester.pump();
    expect(transformationController.value.storage[0], 1);

    await tester.tap(find.byKey(const Key('elevation-zoom-in')));
    await tester.pump();
    final translationBeforePan = transformationController.value.storage[12];
    await tester.drag(find.byType(LineChart), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(
      transformationController.value.storage[12],
      isNot(translationBeforePan),
    );
    await tester.tap(find.byKey(const Key('elevation-reset-view')));
    await tester.pump();

    final stageToggle = find.byKey(const Key('elevation-stage-toggle'));
    expect(
      find.descendant(
        of: stageToggle,
        matching: find.byIcon(Icons.location_on_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(stageToggle);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: stageToggle,
        matching: find.byIcon(Icons.location_on_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(stageToggle);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: stageToggle,
        matching: find.byIcon(Icons.location_on_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('map hides provider details when configuration is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MapScreen(accessToken: '')),
      ),
    );

    expect(find.text('Map unavailable'), findsOneWidget);
    expect(
      find.text('The map service is not configured for this build.'),
      findsOneWidget,
    );
    expect(find.textContaining('Mapbox'), findsNothing);
  });
}

class _FakeElevationController extends ElevationController {
  @override
  Future<List<RoutePoint>> build() async => const [
    RoutePoint(
      pointIndex: 0,
      lat: 34.7,
      lng: 32.4,
      altitudeM: 2,
      distanceKm: 0,
      reverseDistanceKm: 10,
    ),
    RoutePoint(
      pointIndex: 1,
      lat: 34.8,
      lng: 32.5,
      altitudeM: 100,
      distanceKm: 10,
      reverseDistanceKm: 0,
    ),
  ];
}

class _FakeStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: '124-pafos-airport',
      sequence: 124,
      name: 'Pafos Airport',
      accumulatedDistanceKm: 0,
      altitudeM: 2,
      services: {},
    ),
  ];
}

class _LodgingStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: 'lodging-stage',
      sequence: 1,
      name: 'Lodging stage',
      accumulatedDistanceKm: 1,
      altitudeM: 100,
      services: {},
    ),
  ];
}

class _RefreshTrackingStagesController extends StagesController {
  int syncCalls = 0;

  static const stages = [
    TrailStage(
      id: 'refresh-stage',
      sequence: 1,
      name: 'Refresh stage',
      accumulatedDistanceKm: 0,
      altitudeM: 2,
      services: {},
    ),
  ];

  @override
  Future<List<TrailStage>> build() async => stages;

  @override
  Future<void> sync() async {
    syncCalls++;
    state = const AsyncData(stages);
  }
}

class _EndpointStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: 'pafos',
      sequence: 2,
      name: 'Pafos Airport',
      accumulatedDistanceKm: 0,
      segmentLengthKm: 0,
      altitudeM: 2,
      services: {},
    ),
    TrailStage(
      id: 'larnaka',
      sequence: 1,
      name: 'Larnaka Airport',
      accumulatedDistanceKm: 10,
      segmentLengthKm: 10,
      elevationUpM: 120,
      elevationDownM: 45,
      altitudeM: 4,
      services: {},
    ),
  ];
}

class _FilterStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: 'pafos',
      sequence: 3,
      name: 'Pafos Airport',
      accumulatedDistanceKm: 0,
      services: {},
    ),
    TrailStage(
      id: 'troodos',
      sequence: 2,
      name: 'Troodos',
      accumulatedDistanceKm: 5,
      services: {},
    ),
    TrailStage(
      id: 'larnaka',
      sequence: 1,
      name: 'Larnaka Airport',
      accumulatedDistanceKm: 10,
      services: {},
    ),
  ];
}

class _ManyStagesController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => List.generate(
    30,
    (index) => TrailStage(
      id: 'stage-$index',
      sequence: 30 - index,
      name: 'Stage place $index',
      accumulatedDistanceKm: index * 10,
      altitudeM: index * 20,
      services: const {},
    ),
  );
}

class _SingleStageController extends StagesController {
  @override
  Future<List<TrailStage>> build() async => const [
    TrailStage(
      id: 'stage-one',
      sequence: 1,
      name: 'Stage one',
      accumulatedDistanceKm: 5,
      altitudeM: 50,
      services: {},
    ),
  ];
}

class _FakeAppSettingsController extends AppSettingsController {
  @override
  AppSettings build() => const AppSettings();

  @override
  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
  }

  @override
  void setMeasurementSystem(MeasurementSystem measurementSystem) {
    state = state.copyWith(measurementSystem: measurementSystem);
  }
}

class _FakeAppDatabase extends AppDatabase {
  final Map<String, String> settings = {};

  @override
  Future<Map<String, String>> readSettings() async => Map.of(settings);

  @override
  Future<void> writeSetting(String key, String value) async {
    settings[key] = value;
  }
}

class _FakeOfflineMapController extends OfflineMapController {
  @override
  Future<OfflineMapState> build() async =>
      const OfflineMapState.ready(completedBytes: 1024 * 1024);

  @override
  Future<void> delete() async {
    state = const AsyncData(OfflineMapState.notDownloaded());
  }
}

class _FakeLodgingRepository implements LodgingRepository {
  const _FakeLodgingRepository(this.lodgingsByStage);

  final Map<String, List<Lodging>> lodgingsByStage;

  @override
  Future<List<Lodging>> loadForTrail({required String trailId}) async {
    return lodgingsByStage.values
        .expand((lodgings) => lodgings)
        .toList(growable: false);
  }

  @override
  Future<List<Lodging>> loadForStage({
    required String trailId,
    required String stageId,
  }) async {
    return lodgingsByStage[stageId] ?? const [];
  }
}

class _TrailPreloadLodgingRepository implements LodgingRepository {
  int trailLoadCalls = 0;

  @override
  Future<List<Lodging>> loadForTrail({required String trailId}) async {
    trailLoadCalls++;
    return const [];
  }

  @override
  Future<List<Lodging>> loadForStage({
    required String trailId,
    required String stageId,
  }) async {
    return const [];
  }
}

class _MutableLodgingRepository implements LodgingRepository {
  _MutableLodgingRepository(this.lodgings);

  List<Lodging> lodgings;

  @override
  Future<List<Lodging>> loadForTrail({required String trailId}) async {
    return lodgings;
  }

  @override
  Future<List<Lodging>> loadForStage({
    required String trailId,
    required String stageId,
  }) async {
    return lodgings;
  }
}

class _RetryLodgingRepository implements LodgingRepository {
  int calls = 0;

  @override
  Future<List<Lodging>> loadForTrail({required String trailId}) async {
    return const [];
  }

  @override
  Future<List<Lodging>> loadForStage({
    required String trailId,
    required String stageId,
  }) async {
    calls++;
    if (calls == 1) throw StateError('Temporary failure');
    return const [
      Lodging(
        id: 'recovered-lodging',
        name: 'Recovered lodging',
        website: 'https://booking.example.com/recovered',
      ),
    ];
  }
}
