import 'package:eurotrex/core/localization/app_localizations.dart';
import 'package:eurotrex/features/reports/presentation/report_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget preview(
  String state,
  String? status, {
  Locale locale = const Locale('en'),
  double scale = 1,
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
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReportStatusBadge(uploadState: state, remoteStatus: status),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('upload receipt is distinct from forwarding to an authority', (
    tester,
  ) async {
    for (final status in [null, 'new']) {
      await tester.pumpWidget(preview('sent', status));
      await tester.pumpAndSettle();
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Sent'), findsNothing);
    }
    for (final entry in {
      'reviewed': 'Reviewed',
      'forwarded': 'Sent',
      'resolved': 'Resolved',
      'duplicate': 'Duplicate',
      'dismissed': 'Dismissed',
    }.entries) {
      await tester.pumpWidget(preview('sent', entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }
    await tester.pumpWidget(preview('failed', 'resolved'));
    await tester.pumpAndSettle();
    expect(find.text('Upload failed — saved on device'), findsOneWidget);
    expect(find.text('Resolved'), findsNothing);
  });

  testWidgets('badges translate and wrap at large text sizes', (tester) async {
    final expected = {
      'en': 'Received',
      'de': 'Empfangen',
      'es': 'Recibido',
      'it': 'Ricevuta',
      'fr': 'Reçu',
    };
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(preview('sent', 'new', locale: locale, scale: 2));
      await tester.pumpAndSettle();
      expect(find.text(expected[locale.languageCode]!), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        preview('failed', null, locale: locale, scale: 2),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          AppLocalizations(locale).t('Upload failed — saved on device'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
