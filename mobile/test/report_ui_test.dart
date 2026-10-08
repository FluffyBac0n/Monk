import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/core/localization/app_localizations.dart';
import 'package:eurotrex/core/localization/translations_reports.dart';
import 'package:eurotrex/features/reports/data/report_store.dart';
import 'package:eurotrex/features/reports/data/report_sync.dart';
import 'package:eurotrex/features/reports/presentation/report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MemoryReportStore extends ReportStore {
  MemoryReportStore() : super(AppDatabase());
  final drafts = <String, ReportDraft>{};
  @override
  Future<void> save(ReportDraft draft) async {
    drafts[draft.id] = ReportDraft.fromJson(draft.toJson());
  }

  @override
  Future<List<ReportDraft>> all() async => drafts.values.toList();
}

class OfflineReportSync extends ChangeNotifier implements ReportSync {
  @override
  void changed() => notifyListeners();
  @override
  Future<void> sync() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('report categories, states, and upload errors have translations', () {
    for (final locale in const ['de', 'es', 'it', 'fr']) {
      final keys = AppLocalizations.translationKeys(Locale(locale));
      expect(keys, containsAll(deReportTranslations.keys));
      expect(keys, containsAll(reportCategoryLabels.values));
      expect(keys, containsAll(reportAccessLabels.values));
      expect(keys, containsAll(reportStatusLabels.values));
      expect(keys, containsAll(reportErrorMessages));
      final l10n = AppLocalizations(Locale(locale));
      expect(l10n.t('Report trail problems'), isNot('Report trail problems'));
      expect(l10n.t('My reports'), isNot('My reports'));
    }
  });

  testWidgets('sending uses displayed GPS without a confirmation checkbox', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'EuroTrex',
      packageName: 'com.eurotrex.e4',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final store = MemoryReportStore();
    final sync = OfflineReportSync();
    final draft = ReportDraft(
      id: 'gps-draft',
      trailId: 'cyprus-e4',
      createdAt: DateTime.utc(2026, 10, 7),
      description: 'Broken signpost',
      latitude: 34.89,
      longitude: 32.87,
    );
    const l10n = AppLocalizations(Locale('de'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportStoreProvider.overrideWithValue(store),
          reportSyncProvider.overrideWithValue(sync),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ReportScreen(trailId: draft.trailId, draft: draft),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.t('Report trail problems')), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.textContaining('Reports are reviewed'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(l10n.t('Send report')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.t('Send report')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.t('My reports')), findsOneWidget);
    expect(find.text(l10n.t('Waiting for connection')), findsOneWidget);
    final saved = store.drafts[draft.id]!;
    expect(saved.state, 'queued');
    expect(saved.locationConfirmed, isTrue);
    expect(saved.latitude, 34.89);
    expect(saved.longitude, 32.87);
    expect(saved.valid, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    sync.dispose();
  });
}
