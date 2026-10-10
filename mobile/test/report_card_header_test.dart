import 'package:eurotrex/core/localization/app_localizations.dart';
import 'package:eurotrex/features/reports/presentation/report_card_header.dart';
import 'package:eurotrex/features/reports/presentation/report_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget header(
  double width, {
  double scale = 1,
  Locale locale = const Locale('en'),
  String state = 'sent',
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ReportCardHeader(
              category: 'signpost',
              title: context.l10n.t('Damaged or missing signpost'),
              uploadState: state,
              remoteStatus: 'resolved',
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('status aligns at the top right on a normal phone card', (
    tester,
  ) async {
    for (final state in ['draft', 'sent']) {
      await tester.pumpWidget(header(329, state: state));
      await tester.pumpAndSettle();
      final badge = tester.getRect(find.byType(ReportStatusBadge));
      final icon = tester.getRect(find.byIcon(Icons.signpost_outlined));
      expect(badge.right, closeTo(329, .1));
      expect(badge.top, 0);
      expect(badge.left, greaterThan(icon.right));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('status wraps below the heading on narrow cards and large text', (
    tester,
  ) async {
    for (final scenario in [(240.0, 1.0), (329.0, 2.0)]) {
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(
          header(scenario.$1, scale: scenario.$2, locale: locale),
        );
        await tester.pumpAndSettle();
        final title = tester.getRect(
          find.text(AppLocalizations(locale).t('Damaged or missing signpost')),
        );
        final badge = tester.getRect(find.byType(ReportStatusBadge));
        expect(badge.top, greaterThan(title.bottom));
        expect(badge.right, lessThanOrEqualTo(scenario.$1));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
