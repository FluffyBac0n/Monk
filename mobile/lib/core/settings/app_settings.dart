enum AppLanguage {
  english('en', 'English'),
  german('de', 'Deutsch'),
  spanish('es', 'Español');

  const AppLanguage(this.code, this.displayName);

  final String code;
  final String displayName;

  static AppLanguage fromCode(String? code) => values.firstWhere(
    (language) => language.code == code,
    orElse: () => AppLanguage.english,
  );
}

enum MeasurementSystem { metric, imperial }

class AppSettings {
  const AppSettings({
    this.language = AppLanguage.english,
    this.measurementSystem = MeasurementSystem.metric,
  });

  final AppLanguage language;
  final MeasurementSystem measurementSystem;

  AppSettings copyWith({
    AppLanguage? language,
    MeasurementSystem? measurementSystem,
  }) => AppSettings(
    language: language ?? this.language,
    measurementSystem: measurementSystem ?? this.measurementSystem,
  );
}
