import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_localizations.dart';
import 'core/settings/app_settings_controller.dart';
import 'features/trails/presentation/trails_screen.dart';

final firebaseReadyProvider = Provider<bool>((ref) => false);

class MonkApp extends ConsumerWidget {
  const MonkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      title: 'Monk',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.language.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF277653),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F2EC),
        useMaterial3: true,
        cardTheme: const CardThemeData(margin: EdgeInsets.zero),
        appBarTheme: const AppBarTheme(centerTitle: false),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8CC7A1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TrailsScreen(),
    );
  }
}
