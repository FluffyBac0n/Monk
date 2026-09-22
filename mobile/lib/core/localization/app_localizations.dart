import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'translations_fr.dart';
import 'translations_it.dart';
import 'translations_legal.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('it'),
    Locale('fr'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  String t(String english) =>
      _translations[locale.languageCode]?[english] ??
      (locale.languageCode == 'en' ? _englishTerminology[english] : null) ??
      english;

  String stage(int sequence) => '${t('Stage')} $sequence';

  String from(String place) => '${t('From')} $place';

  String routeDirection(String start, String end) => '$start  →  $end';

  String offTrailDistance(String distance) => t(
    'You are approximately {distance} from the trail.',
  ).replaceAll('{distance}', distance);

  String nearStageDistance(String stage, String distance) => t(
    'Near {stage} · {distance} from the trail',
  ).replaceAll('{stage}', stage).replaceAll('{distance}', distance);

  String bookingSearchAround(String stage) =>
      t('Search around {stage} for tonight.').replaceAll('{stage}', stage);

  String get pafosAirport => t('Pafos Airport');
  String get larnakaAirport => t('Larnaka Airport');

  @visibleForTesting
  static Set<String> translationKeys(Locale locale) => Set.unmodifiable(
    _translations[locale.languageCode]?.keys ?? const <String>{},
  );
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

const _englishTerminology = <String, String>{
  'Stage by stage': 'Point by point',
  'Stages': 'Stage points',
  'Stage': 'Stage point',
  'Stay': 'Stays',
  'Lodging': 'Stays',
  'Choose stage': 'Choose a stage point',
  'Search by stage or place': 'Search by stage point or place',
  'Choose two stages in trail order.':
      'Choose two stage points in trail order.',
  'Tap a stage on the map to choose your start, then your finish.':
      'Tap a stage point on the map to choose your start, then your finish.',
  'Choose two different stages.': 'Choose two different stage points.',
  'Show all stages': 'Show all stage points',
  'Choose a different stage for the finish.':
      'Choose a different stage point for the finish.',
  'Choose a start and finish stage.': 'Choose a start and finish stage point.',
  'Create a route to keep its itinerary and use it in Stage filters.':
      'Create a route to keep its itinerary and use it in stage-point filters.',
  'Saved to My routes and Stage filters.':
      'Saved to My routes and stage-point filters.',
  'Build a stage-to-stage itinerary': 'Build a route itinerary',
  'Choose your daily limits and overnight requirements. The planner uses the current E4 stage and accommodation data.':
      'Choose your daily limits and overnight requirements. The planner uses the current E4 stage-point and accommodation data.',
  'Filter stages': 'Filter stage points',
  'Choose stages, trail points and services.':
      'Choose stage points and services.',
  'Stage name': 'Stage-point name',
  'Search by stage name': 'Search by stage-point name',
  'Search by stage name or number': 'Search by stage point or number',
  'No stages found.': 'No stage points found.',
  'Stages must offer every selected service.':
      'Stage points must offer every selected service.',
  'No stages match these services.': 'No stage points match these services.',
  'No stages match these filters.': 'No stage points match these filters.',
  'The route stages are shown below.':
      'The route’s stage points are shown below.',
  'Hide stages': 'Hide stage points',
  'Show stages': 'Show stage points',
  'Close stage summary': 'Close stage-point summary',
  'Open Stage Info': 'Open stage-point information',
  'Tap a stage to see its details.': 'Tap a stage point to see its details.',
  'The numbers on the left show stage length, ascent, descent, and + distance from the trail.':
      'The numbers on the left show section distance, ascent, descent, and + distance from the trail.',
  'Stage length': 'Section distance',
  'No services recorded for this stage.':
      'No services recorded for this stage point.',
  'Stage information is stored on this device.':
      'Stage-point information is stored on this device.',
  'Back to stages': 'Back to stage points',
  'Download E4 - Cyprus to browse its stages without a connection.':
      'Download E4 - Cyprus to browse its stage points without a connection.',
  'Places to stay near this stage': 'Places to stay near this stage point',
  'No accommodation is listed for this stage.':
      'No stays are listed for this stage point.',
  'Try another nearby stage.': 'Try another nearby stage point.',
  'Route, stages and elevation': 'Route, stage points and elevation',
  'The route, stages and elevation will be removed. The offline map will remain on this device.':
      'The route, stage points and elevation will be removed. The offline map will remain on this device.',
  'Selected stage': 'Selected stage point',
  'Other stages': 'Other stage points',
  'The route, stages and elevation will remain offline. Only the offline map will be removed.':
      'The route, stage points and elevation will remain offline. Only the offline map will be removed.',
  'Find my stage': 'Find my stage point',
};

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _translations = <String, Map<String, String>>{
  'it': {...italianTranslations, ...italianLegalTranslations},
  'fr': {...frenchTranslations, ...frenchLegalTranslations},
  'de': {
    ...germanLegalTranslations,
    'EUROTREX': 'EUROTREX',
    'Co-funded by the European Union':
        'Kofinanziert von der Europäischen Union',
    'Republic of Cyprus': 'Republik Zypern',
    'Co-funded by the Republic of Cyprus':
        'Kofinanziert von der Republik Zypern',
    'About us': 'Über uns',
    'About EUROTREX': 'Über EUROTREX',
    'Our mission': 'Unsere Mission',
    'Explore Europe, one trail at a time.': 'Entdecke Europa – Weg für Weg.',
    'EUROTREX brings long-distance trails, stages, maps, elevation profiles and practical information together in one place.':
        'EUROTREX bündelt Fernwanderwege, Etappen, Karten, Höhenprofile und praktische Informationen an einem Ort.',
    'Visit our website': 'Unsere Website besuchen',
    'Project funding': 'Projektförderung',
    'The EUROTREX project is co-funded by the European Union and the Republic of Cyprus.':
        'Das EUROTREX-Projekt wird von der Europäischen Union und der Republik Zypern kofinanziert.',
    'Contact us': 'Kontakt',
    'Have an idea that could improve EUROTREX? Send us your suggestion.':
        'Hast du eine Idee, die EUROTREX verbessern könnte? Sende uns deinen Vorschlag.',
    'Send a suggestion': 'Vorschlag senden',
    'EUROTREX app suggestion': 'Vorschlag zur EUROTREX-App',
    'No email app is available. Opening the EUROTREX website contact form instead.':
        'Keine E-Mail-App verfügbar. Stattdessen wird das Kontaktformular auf der EUROTREX-Website geöffnet.',
    'Version': 'Version',
    'E4 - Crete': 'E4 - Crete',
    'E4 - Peloponnese': 'E4 - Peloponnese',
    'Settings': 'Einstellungen',
    'Reverse': 'Umkehren',
    'GPS': 'GPS',
    'Back': 'Zurück',
    'Reset': 'Zurücksetzen',
    'Developer tools': 'Entwicklertools',
    'Reset E4 hint': 'E4-Hinweis zurücksetzen',
    'Reset stage hint': 'Etappenhinweis zurücksetzen',
    'Reset metrics hint': 'Kennzahlenhinweis zurücksetzen',
    'Show the pulsing E4 trail information hint again.':
        'Den pulsierenden E4-Weginformationshinweis erneut anzeigen.',
    'Show the stage details helper again.':
        'Die Hilfe zu den Etappendetails erneut anzeigen.',
    'Show the left-side stage metrics helper again.':
        'Die Hilfe zu den Etappenkennzahlen auf der linken Seite erneut anzeigen.',
    'Tap the E4 sign to open trail information.':
        'Tippe auf das E4-Zeichen, um die Weginformationen zu öffnen.',
    'TRAIL LIBRARY': 'WEGBIBLIOTHEK',
    'Explore trails': 'Wanderwege entdecken',
    'Trails': 'Wanderwege',
    'Choose a trail to view its stages and maps.':
        'Wähle einen Weg, um Etappen und Karten anzusehen.',
    'Current trails': 'Aktuelle Wanderwege',
    'available': 'verfügbar',
    'LONG DISTANCE': 'FERNWANDERWEG',
    'OFFLINE TRAIL': 'OFFLINE-WANDERWEG',
    'E4': 'E4',
    'A long-distance journey linking the coast, forests and Troodos mountain.':
        'Eine Fernwanderung, die Küste, Wälder und den Troodos-Berg verbindet.',
    'Trail data not downloaded': 'Wegdaten nicht heruntergeladen',
    'Trail data available offline': 'Wegdaten offline verfügbar',
    'Trail data and map available offline':
        'Wegdaten und Karte offline verfügbar',
    'Trail data and background map are available offline.':
        'Wegdaten und Hintergrundkarte sind offline verfügbar.',
    'Trail data is available offline. Download the offline map to see map details without a connection.':
        'Wegdaten sind offline verfügbar. Lade die Offline-Karte herunter, um Kartendetails ohne Verbindung zu sehen.',
    'Explore trail': 'Weg erkunden',
    'Language': 'Sprache',
    'Measurements': 'Maßeinheiten',
    'Metric': 'Metrisch',
    'Imperial': 'Imperial',
    'Kilometres and metres': 'Kilometer und Meter',
    'Miles and feet': 'Meilen und Fuß',
    'Changes apply throughout the app.':
        'Änderungen gelten in der gesamten App.',
    'Stage by stage': 'Etappe für Etappe',
    'Refresh offline trail': 'Offline-Weg aktualisieren',
    'Walk from Pafos to Larnaka': 'Von Pafos nach Larnaka wandern',
    'Walk from Larnaka to Pafos': 'Von Larnaka nach Pafos wandern',
    'CYPRUS · LONG DISTANCE TRAIL': 'ZYPERN · FERNWANDERWEG',
    'E4 - Cyprus': 'E4 - Cyprus',
    'Pafos Airport': 'Flughafen Pafos',
    'Larnaka Airport': 'Flughafen Larnaka',
    'Distance': 'Entfernung',
    'Elevation Up': 'Höhenanstieg',
    'Elevation Down': 'Höhenabstieg',
    'Stages': 'Etappen',
    'High point': 'Höchster Punkt',
    'Route': 'Route',
    'Planner': 'Planer',
    'Route planner': 'Routenplaner',
    'Tailored E4 plan': 'Individueller E4-Plan',
    'Trip': 'Reise',
    'Pace': 'Tempo',
    'Stay': 'Übernachtung',
    'Your trip': 'Deine Reise',
    'How many walking days do you have?': 'Wie viele Wandertage hast du?',
    'days': 'Tage',
    'What would you like to walk?': 'Was möchtest du wandern?',
    'Best section': 'Bester Abschnitt',
    'Whole E4': 'Gesamter E4',
    'Where would you prefer to start?': 'Wo möchtest du beginnen?',
    'Best direction': 'Beste Richtung',
    'Auto': 'Auto',
    'Pafos': 'Pafos',
    'Larnaka': 'Larnaka',
    'We will compare both trail directions and choose the better fit.':
        'Wir vergleichen beide Wegrichtungen und wählen die passendere.',
    'Your daily pace': 'Dein tägliches Tempo',
    'How do you prefer to set your pace?':
        'Wie möchtest du dein Tempo festlegen?',
    'Hours': 'Stunden',
    'hours': 'Stunden',
    'per day': 'pro Tag',
    'Walking time includes an allowance for climbing. Each option adjusts the effort around this target.':
        'Die Gehzeit berücksichtigt Anstiege. Jede Option passt die Belastung an dieses Ziel an.',
    'Overnight stays': 'Übernachtungen',
    'Either': 'Beides',
    'Price per night': 'Preis pro Nacht',
    'The range applies per room, per night, using listed prices.':
        'Die Spanne gilt pro Zimmer und Nacht auf Basis der angegebenen Preise.',
    'Build my plans': 'Meine Pläne erstellen',
    'Relaxed': 'Entspannt',
    'Adventurous': 'Abenteuerlich',
    'My routes': 'Meine Routen',
    'New route': 'Neue Route',
    'Add route': 'Route hinzufügen',
    'Open and edit': 'Öffnen und bearbeiten',
    'Start date': 'Startdatum',
    'Choose section': 'Abschnitt wählen',
    'Custom': 'Benutzerdefiniert',
    'Suggested': 'Empfohlen',
    'Smart': 'Smart',
    'Walking days': 'Wandertage',
    'Swap start and finish': 'Start und Ziel tauschen',
    'Choose stage': 'Etappe wählen',
    'Search by stage or place': 'Nach Etappe oder Ort suchen',
    'Water': 'Wasser',
    'per night': 'pro Nacht',
    'Flexible': 'Flexibel',
    'Set as start': 'Als Start festlegen',
    'Set as finish': 'Als Ziel festlegen',
    'What should the planner hold fixed?':
        'Was soll der Planer fest einhalten?',
    'Fit my days': 'An meine Tage anpassen',
    'Limit effort': 'Belastung begrenzen',
    'Remove walking day': 'Wandertag entfernen',
    'Add walking day': 'Wandertag hinzufügen',
    'We will choose the number of days that stays within your daily limit.':
        'Wir wählen die Anzahl der Tage passend zu deinem Tageslimit.',
    'Walking time includes an allowance for climbing. Route styles rank alternatives without changing this limit.':
        'Die Gehzeit berücksichtigt Anstiege. Routenstile ordnen Alternativen, ohne dieses Limit zu ändern.',
    'Required average': 'Erforderlicher Durchschnitt',
    'Projected finish': 'Voraussichtliches Ziel',
    'Use suggested days': 'Empfohlene Tage verwenden',
    'Include stays without a listed price':
        'Unterkünfte ohne Preisangabe einbeziehen',
    'You can confirm their price before booking.':
        'Du kannst den Preis vor der Buchung bestätigen.',
    'Save route': 'Route speichern',
    'Review pace': 'Tempo prüfen',
    'Review stays': 'Übernachtungen prüfen',
    'Recommended': 'Empfohlen',
    'average': 'Durchschnitt',
    'Longest day': 'Längster Tag',
    'Camping nights': 'Campingnächte',
    'Choose two stages in trail order.': 'Wähle zwei Etappen in Wegrichtung.',
    'This section is too far for the selected number of days.':
        'Dieser Abschnitt ist für die gewählte Tageszahl zu lang.',
    'This short section has fewer useful stops than selected days.':
        'Dieser kurze Abschnitt hat weniger geeignete Stopps als gewählte Tage.',
    'One or more trail sections exceed your daily effort limit.':
        'Ein oder mehrere Abschnitte überschreiten dein Tageslimit.',
    'A suitable stay is available, but its price is not listed.':
        'Eine passende Unterkunft ist verfügbar, aber ohne Preisangabe.',
    'No listed stays fit the selected price range.':
        'Keine gelistete Unterkunft passt zur Preisspanne.',
    'The selected stay type is not available at the required stops.':
        'Die gewählte Übernachtungsart ist an den nötigen Stopps nicht verfügbar.',
    'The available overnight stops cannot make this exact day count.':
        'Mit den verfügbaren Übernachtungsstopps ist diese Tageszahl nicht möglich.',
    'There are not enough suitable overnight stops for this section.':
        'Für diesen Abschnitt gibt es nicht genug geeignete Übernachtungsstopps.',
    'Tap a stage on the map to choose your start, then your finish.':
        'Tippe auf eine Etappe auf der Karte, um zuerst Start und dann Ziel zu wählen.',
    'Choose two different stages.': 'Wähle zwei verschiedene Etappen.',
    'Show my location': 'Eigenen Standort anzeigen',
    'Center trail': 'Weg zentrieren',
    'Show all stages': 'Alle Etappen anzeigen',
    'Choose start': 'Start wählen',
    'Choose finish': 'Ziel wählen',
    'Choose a different stage for the finish.':
        'Wähle eine andere Etappe als Ziel.',
    'Choose a start and finish stage.': 'Wähle eine Start- und Zieletappe.',
    'The planner will choose the best-fitting section.':
        'Der Planer wählt den am besten passenden Abschnitt.',
    'Move overnight stop': 'Übernachtungsstopp verschieben',
    'Choose where to stay': 'Unterkunft wählen',
    'No accommodation is listed at this stop.':
        'Für diesen Stopp ist keine Unterkunft eingetragen.',
    'Move stop': 'Stopp verschieben',
    'Choose stay': 'Unterkunft wählen',
    'Start this day': 'Diesen Tag starten',
    'Your route at a glance': 'Deine Route im Überblick',
    'Route map is loading…': 'Routenkarte wird geladen…',
    'Day': 'Tag',
    'Offline readiness': 'Offline-Bereitschaft',
    'Offline map download in progress': 'Offline-Karte wird heruntergeladen',
    'Download the trail map before you leave coverage.':
        'Lade die Wegkarte herunter, bevor du den Empfangsbereich verlässt.',
    'Open map': 'Karte öffnen',
    'Manage': 'Verwalten',
    'from trail': 'vom Weg',
    'Open': 'Geöffnet',
    'Confirm availability for your planned date.':
        'Bestätige die Verfügbarkeit für dein geplantes Datum.',
    'Pafos to Larnaka': 'Pafos nach Larnaka',
    'Larnaka to Pafos': 'Larnaka nach Pafos',
    'No routes saved yet': 'Noch keine Routen gespeichert',
    'Create a route to keep its itinerary and use it in Stage filters.':
        'Erstelle eine Route, um ihren Reiseplan zu speichern und sie in den Etappenfiltern zu verwenden.',
    'Saved routes are unavailable.':
        'Gespeicherte Routen sind nicht verfügbar.',
    'Delete route': 'Route löschen',
    'Delete this saved route?': 'Diese gespeicherte Route löschen?',
    'Preferences': 'Präferenzen',
    'Itinerary': 'Reiseplan',
    'Choose your route': 'Wähle deine Route',
    'Finish must come after the start in the current direction.':
        'Das Ziel muss in der aktuellen Richtung nach dem Start liegen.',
    'Compare': 'Vergleichen',
    'Choose an itinerary': 'Wähle einen Reiseplan',
    'Budget': 'Budget',
    'Balanced': 'Ausgewogen',
    'Comfort': 'Komfort',
    'Unavailable for these preferences':
        'Für diese Präferenzen nicht verfügbar',
    'Done': 'Fertig',
    'Saved to My routes and Stage filters.':
        'Unter „Meine Routen“ und in den Etappenfiltern gespeichert.',
    'Build a stage-to-stage itinerary': 'Etappenplan erstellen',
    'Choose your daily limits and overnight requirements. The planner uses the current E4 stage and accommodation data.':
        'Wähle deine täglichen Grenzen und Anforderungen für Übernachtungen. Der Planer verwendet die aktuellen E4-Etappen- und Unterkunftsdaten.',
    'Daily walking limits': 'Tägliche Wandergrenzen',
    'Minimum': 'Minimum',
    'Maximum': 'Maximum',
    'Overnight stops': 'Übernachtungen',
    'Accommodation budget': 'Unterkunftsbudget',
    'Leave empty for no budget limit.': 'Leer lassen für kein Budgetlimit.',
    'Allow camping stages': 'Campingetappen zulassen',
    'Use camping when no accommodation stop fits the daily limits.':
        'Camping nutzen, wenn keine Unterkunft in die täglichen Grenzen passt.',
    'Find route': 'Route finden',
    'Enter a positive number.': 'Gib eine positive Zahl ein.',
    'Maximum must be at least the minimum.':
        'Das Maximum muss mindestens dem Minimum entsprechen.',
    'Trail data is unavailable.': 'Wegdaten sind nicht verfügbar.',
    'Balanced route found': 'Ausgewogene Route gefunden',
    'walking days': 'Wandertage',
    'total distance': 'Gesamtdistanz',
    'known prices': 'bekannte Preise',
    '{count} overnight prices are unknown. Confirm prices and availability before travelling.':
        '{count} Übernachtungspreise sind unbekannt. Bestätige Preise und Verfügbarkeit vor der Reise.',
    'Day-by-day itinerary': 'Tagesplan',
    'Walking times and prices are estimates. Check weather, trail conditions and accommodation availability before setting out.':
        'Gehzeiten und Preise sind Schätzungen. Prüfe Wetter, Wegbedingungen und Unterkunftsverfügbarkeit vor dem Start.',
    'Camping stage': 'Campingetappe',
    'Accommodation price unknown': 'Unterkunftspreis unbekannt',
    'No feasible route found': 'Keine passende Route gefunden',
    'Try widening the daily distance range or increasing the accommodation budget.':
        'Versuche, den täglichen Entfernungsbereich zu erweitern oder das Unterkunftsbudget zu erhöhen.',
    'Try widening the daily distance range, increasing the budget or allowing camping stages.':
        'Versuche, den täglichen Entfernungsbereich zu erweitern, das Budget zu erhöhen oder Campingetappen zuzulassen.',
    'Filter': 'Filter',
    'Filter stages': 'Etappen filtern',
    'Choose trail points and services.': 'Wegpunkte und Angebote auswählen.',
    'Choose stages, trail points and services.':
        'Etappen, Wegpunkte und Angebote auswählen.',
    'Stage name': 'Etappenname',
    'Search by stage name': 'Nach Etappenname suchen',
    'Search by stage name or number': 'Nach Etappenname oder -nummer suchen',
    'No stages found.': 'Keine Etappen gefunden.',
    'Trail points': 'Wegpunkte',
    'Points of Interest': 'Interessante Orte',
    'Beach': 'Strand',
    'Viewpoint': 'Aussichtspunkt',
    'Religious Sites': 'Religiöse Stätten',
    'Natural Landmarks': 'Naturdenkmäler',
    'Forests/Parks': 'Wälder/Parks',
    'Filter by services': 'Nach Angeboten filtern',
    'Stages must offer every selected service.':
        'Etappen müssen alle ausgewählten Angebote bieten.',
    'Clear': 'Zurücksetzen',
    'Apply': 'Anwenden',
    'Apply filters': 'Filter anwenden',
    'No stages match these services.':
        'Keine Etappen entsprechen diesen Angeboten.',
    'No stages match these filters.':
        'Keine Etappen entsprechen diesen Filtern.',
    'Clear filters': 'Filter löschen',
    'Go to top': 'Zum Anfang',
    'Go to end': 'Zum Ende',
    'Map': 'Karte',
    'Elevation': 'Höhenprofil',
    'The route stages are shown below.':
        'Die Etappen der Route werden unten angezeigt.',
    'Trail guide available offline': 'Wanderführer offline verfügbar',
    'Download this trail for offline use':
        'Diesen Weg für die Offline-Nutzung herunterladen',
    'Trail map': 'Wanderkarte',
    'Map layers': 'Kartenebenen',
    'Refresh elevation data': 'Höhendaten aktualisieren',
    'No elevation data is available.': 'Keine Höhendaten verfügbar.',
    'Could not download the elevation profile.':
        'Das Höhenprofil konnte nicht geladen werden.',
    'Zoom out': 'Verkleinern',
    'Zoom in': 'Vergrößern',
    'Reset elevation view': 'Höhenansicht zurücksetzen',
    'Hide stages': 'Etappen ausblenden',
    'Show stages': 'Etappen anzeigen',
    'Full trail': 'Gesamte Route',
    'Trail distance': 'Gesamtdistanz',
    'Highest point': 'Höchster Punkt',
    'High point position': 'Position des höchsten Punkts',
    'Offline samples': 'Offline-Messpunkte',
    'Total ascent': 'Gesamtanstieg',
    'Total descent': 'Gesamtabstieg',
    'Ascent': 'Anstieg',
    'Descent': 'Abstieg',
    'Estimated walking time': 'Geschätzte Gehzeit',
    'Naismith estimate based on distance and ascent. Breaks and terrain are not included.':
        'Schätzung nach Naismith basierend auf Distanz und Anstieg. Pausen und Gelände sind nicht berücksichtigt.',
    "Naismith's Rule estimates walking time by allowing:":
        'Die Naismith-Regel schätzt die Gehzeit anhand folgender Richtwerte:',
    '1 hour for every 5 km of distance': '1 Stunde je 5 km Strecke',
    '1 extra hour for every 600 m of ascent':
        '1 zusätzliche Stunde je 600 Höhenmeter',
    'Descent, terrain difficulty, breaks, weather, pack weight, and individual fitness are not included. Actual walking time may vary.':
        'Abstieg, Schwierigkeit des Geländes, Pausen, Wetter, Rucksackgewicht und individuelle Fitness werden nicht berücksichtigt. Die tatsächliche Gehzeit kann abweichen.',
    'h': 'Std.',
    'min': 'Min.',
    'Preparing the offline elevation profile…':
        'Offline-Höhenprofil wird vorbereitet…',
    'Download profile': 'Profil herunterladen',
    'Close stage summary': 'Etappenübersicht schließen',
    'Open Stage Info': 'Etappeninfo öffnen',
    'Stage': 'Etappe',
    'Tap a stage to see its details.':
        'Tippe auf eine Etappe, um ihre Details anzusehen.',
    'The numbers on the left show stage length, ascent, descent, and + distance from the trail.':
        'Links siehst du Etappenlänge, Aufstieg, Abstieg und mit + die Entfernung vom Weg.',
    'Start point': 'Startpunkt',
    'Finish point': 'Zielpunkt',
    'From': 'Ab',
    'From Start': 'Vom Start',
    'To Finish': 'Bis zum Ziel',
    'Stage length': 'Etappenlänge',
    'Altitude': 'Höhe',
    'Services': 'Angebote',
    'No services recorded for this stage.':
        'Für diese Etappe sind keine Angebote erfasst.',
    'Trail position': 'Position auf dem Weg',
    'Following E4 - Cyprus': 'Auf dem E4 - Zypern',
    'Route guidance will be available with the offline map.':
        'Die Routenführung wird mit der Offline-Karte verfügbar sein.',
    'Available offline': 'Offline verfügbar',
    'Stage information is stored on this device.':
        'Etappeninformationen sind auf diesem Gerät gespeichert.',
    'Previous': 'Zurück',
    'Next': 'Weiter',
    'Show on map': 'Auf Karte anzeigen',
    'Back to stages': 'Zurück zu den Etappen',
    'Take the trail offline': 'Weg offline verfügbar machen',
    'Could not download the trail':
        'Der Weg konnte nicht heruntergeladen werden',
    'Download E4 - Cyprus to browse its stages without a connection.':
        'E4 - Zypern herunterladen, um Etappen ohne Verbindung anzusehen.',
    'Download trail': 'Weg herunterladen',
    'Lodging': 'Unterkunft',
    'Accommodation': 'Unterkunft',
    'Show accommodation': 'Unterkünfte anzeigen',
    'Hide accommodation': 'Unterkünfte ausblenden',
    'Excursion': 'Abstecher',
    'Excursions': 'Abstecher',
    'Detour': 'Umleitung',
    'Detours': 'Umleitungen',
    'Alternative route': 'Alternativroute',
    'Leaves and rejoins the E4.':
        'Verlässt den E4 und führt später wieder darauf zurück.',
    'Detour route': 'Umleitungsroute',
    'E4 section': 'E4-Abschnitt',
    'Distance difference': 'Distanzunterschied',
    'Time difference': 'Zeitunterschied',
    'Show detours': 'Umleitungen anzeigen',
    'Hide detours': 'Umleitungen ausblenden',
    'No detour routes are available on the map.':
        'Auf der Karte sind keine Umleitungsrouten verfügbar.',
    'Detour routes are currently unavailable.':
        'Umleitungsrouten sind derzeit nicht verfügbar.',
    'One way': 'Einfach',
    'Out and back': 'Hin und zurück',
    'Loop': 'Rundweg',
    'Show excursions': 'Abstecher anzeigen',
    'Hide excursions': 'Abstecher ausblenden',
    'No excursion routes are available on the map.':
        'Auf der Karte sind keine Abstecher verfügbar.',
    'Excursion routes are currently unavailable.':
        'Abstecher sind derzeit nicht verfügbar.',
    'Close accommodation summary': 'Unterkunftsübersicht schließen',
    'Accommodation locations are currently unavailable.':
        'Unterkunftsstandorte sind derzeit nicht verfügbar.',
    'No accommodation locations are available on the map.':
        'Auf der Karte sind keine Unterkunftsstandorte verfügbar.',
    'Book accommodation': 'Unterkunft buchen',
    'Book': 'Buchen',
    'Filter accommodation': 'Unterkünfte filtern',
    'Bookable online': 'Online buchbar',
    'Price range': 'Preisspanne',
    'Any price': 'Beliebiger Preis',
    'Maximum distance from trail': 'Maximale Entfernung vom Weg',
    'Any distance': 'Beliebige Entfernung',
    'Accommodation type': 'Unterkunftsart',
    'No accommodation matches these filters.':
        'Keine Unterkunft entspricht diesen Filtern.',
    'Accommodation booking': 'Unterkunftsbuchung',
    'View places to stay': 'Unterkünfte ansehen',
    'Places to stay near this stage': 'Unterkünfte in der Nähe dieser Etappe',
    'Finding accommodation…': 'Unterkünfte werden gesucht…',
    'Accommodation information is currently unavailable.':
        'Unterkunftsinformationen sind derzeit nicht verfügbar.',
    'Check your connection and try again.':
        'Prüfe deine Verbindung und versuche es erneut.',
    'Please try again.': 'Bitte versuche es erneut.',
    'No accommodation is listed for this stage.':
        'Für diese Etappe sind keine Unterkünfte aufgeführt.',
    'Try another nearby stage.': 'Versuche es bei einer nahegelegenen Etappe.',
    'Find more stays on Booking.com':
        'Weitere Unterkünfte auf Booking.com finden',
    'Search around {stage} for tonight.':
        'Für heute Nacht rund um {stage} suchen.',
    'Booking link unavailable': 'Buchungslink nicht verfügbar',
    'Could not open this link.': 'Dieser Link konnte nicht geöffnet werden.',
    'Price': 'Preis',
    'Distance from trail': 'Entfernung vom Weg',
    'Season': 'Saison',
    'Opening hours': 'Öffnungszeiten',
    'Capacity': 'Kapazität',
    'person': 'Person',
    'people': 'Personen',
    'Check-in': 'Check-in',
    'Check-out': 'Check-out',
    'Phone': 'Telefon',
    'WhatsApp': 'WhatsApp',
    'Email': 'E-Mail',
    'View on map': 'Auf Karte anzeigen',
    'Free': 'Kostenlos',
    'Agrotourism': 'Agrotourismus',
    'Apartment': 'Ferienwohnung',
    'Bed & Breakfast': 'Bed & Breakfast',
    'Campsite': 'Campingplatz',
    'Guesthouse': 'Gästehaus',
    'Hostel': 'Hostel',
    'Hotel': 'Hotel',
    'Municipal': 'Städtisch',
    'Picnic site': 'Picknickplatz',
    'Religious': 'Religiöse Unterkunft',
    'April - October': 'April–Oktober',
    'Apr-Oct': 'Apr.–Okt.',
    'Apr–Oct': 'Apr.–Okt.',
    'Coming soon': 'Demnächst verfügbar',
    'Camping': 'Camping',
    'Food': 'Essen',
    'Groceries': 'Lebensmittel',
    'Drinking water': 'Trinkwasser',
    'Non-drinking water': 'Kein Trinkwasser',
    'Toilets': 'Toiletten',
    'Medical': 'Medizinische Hilfe',
    'Pharmacy': 'Apotheke',
    'ATM': 'Geldautomat',
    'Bus': 'Bus',
    'Offline map downloaded': 'Offline-Karte heruntergeladen',
    'Offline map not downloaded': 'Offline-Karte nicht heruntergeladen',
    'Downloading offline map': 'Offline-Karte wird heruntergeladen',
    'Offline map download failed': 'Offline-Karten-Download fehlgeschlagen',
    'Offline map removal failed': 'Offline-Karte konnte nicht entfernt werden',
    'Offline map available': 'Offline-Karte verfügbar',
    'Checking offline map…': 'Offline-Karte wird geprüft…',
    'Download offline map': 'Offline-Karte herunterladen',
    'Offline access': 'Offline-Zugriff',
    'Offline content for this trail': 'Offline-Inhalte für diesen Weg',
    'Checking trail data…': 'Wegdaten werden geprüft…',
    'Trail data status could not be read.':
        'Der Status der Wegdaten konnte nicht gelesen werden.',
    'Trail data': 'Wegdaten',
    'Route, stages and elevation': 'Route, Etappen und Höhenprofil',
    'Offline map': 'Offline-Karte',
    'Detailed map along the trail': 'Detaillierte Karte entlang des Wegs',
    'Check again': 'Erneut prüfen',
    'Size': 'Größe',
    'Route points': 'Routenpunkte',
    'Last updated': 'Zuletzt aktualisiert',
    'Not available': 'Nicht verfügbar',
    'Trail map available offline': 'Wanderkarte offline verfügbar',
    'Download interrupted': 'Download unterbrochen',
    'Take the map offline': 'Karte offline verfügbar machen',
    'Remove offline map': 'Offline-Karte entfernen',
    'Remove trail data': 'Wegdaten entfernen',
    'Try again': 'Erneut versuchen',
    'Cancel': 'Abbrechen',
    'Close': 'Schließen',
    'Remove': 'Entfernen',
    'Remove offline map?': 'Offline-Karte entfernen?',
    'Remove trail data?': 'Wegdaten entfernen?',
    'The route, stages and elevation will be removed. The offline map will remain on this device.':
        'Route, Etappen und Höhenprofil werden entfernt. Die Offline-Karte bleibt auf diesem Gerät.',
    'The trail data could not be removed.':
        'Die Wegdaten konnten nicht entfernt werden.',
    'Show the whole trail': 'Gesamten Weg anzeigen',
    'Start': 'Start',
    'Finish': 'Ziel',
    'Selected stage': 'Ausgewählte Etappe',
    'Other stages': 'Weitere Etappen',
    'My location': 'Mein Standort',
    'Near {stage} · {distance} from the trail':
        'Nahe {stage} · {distance} vom Weg',
    'Offline maps': 'Offline-Karten',
    'Downloaded': 'Heruntergeladen',
    'Checking offline maps…': 'Offline-Karten werden geprüft…',
    'No offline maps downloaded.': 'Keine Offline-Karten heruntergeladen.',
    'Delete offline maps': 'Offline-Karten löschen',
    'Delete offline maps?': 'Offline-Karten löschen?',
    'Delete': 'Löschen',
    'Firebase is not configured for this build.':
        'Firebase ist für diesen Build nicht konfiguriert.',
    'Could not update the trail. Your offline copy is unchanged.':
        'Der Weg konnte nicht aktualisiert werden. Die Offline-Kopie bleibt unverändert.',
    'The Troodos section contains the route’s largest climbs. Plan water and daylight before entering long mountain stages.':
        'Der Troodos-Abschnitt enthält die größten Anstiege der Route. Plane Wasser und Tageslicht vor langen Bergetappen ein.',
    'Offline map status could not be read.':
        'Der Status der Offline-Karte konnte nicht gelesen werden.',
    'The offline map could not be downloaded. Check your connection and try again.':
        'Die Offline-Karte konnte nicht heruntergeladen werden. Prüfe deine Verbindung und versuche es erneut.',
    'The offline map could not be removed.':
        'Die Offline-Karte konnte nicht entfernt werden.',
    'The detailed E4 - Cyprus map is stored on this device.':
        'Die detaillierte Karte des E4 - Zypern ist auf diesem Gerät gespeichert.',
    'Please try the download again.': 'Bitte versuche den Download erneut.',
    'Downloads a detailed corridor around the complete E4 - Cyprus for use without a connection.':
        'Lädt einen detaillierten Korridor entlang des gesamten E4 - Zypern für die Offline-Nutzung herunter.',
    'Download the route data first.': 'Lade zuerst die Routendaten herunter.',
    'The route, stages and elevation will remain offline. Only the offline map will be removed.':
        'Route, Etappen und Höhenprofil bleiben offline verfügbar. Nur die Offline-Karte wird entfernt.',
    'Turn on Location Services to show your position.':
        'Aktiviere die Ortungsdienste, um deine Position anzuzeigen.',
    'Location permission is needed to show your position.':
        'Zum Anzeigen deiner Position ist die Standortberechtigung erforderlich.',
    'Your location could not be read right now.':
        'Dein Standort konnte gerade nicht ermittelt werden.',
    'Map unavailable': 'Karte nicht verfügbar',
    'The map service is not configured for this build.':
        'Der Kartendienst ist für diesen Build nicht konfiguriert.',
    'Route data is not on this device yet.':
        'Die Routendaten sind noch nicht auf diesem Gerät.',
    'Find my stage': 'Meine Etappe finden',
    'You are not on the trail.': 'Du befindest dich nicht auf dem Weg.',
    'You are approximately {distance} from the trail.':
        'Du bist ungefähr {distance} vom Weg entfernt.',
    'Trail information': 'Weginformationen',
    'Trail guide': 'Wanderführer',
    'App preferences': 'App-Einstellungen',
    'Know the signs. Prepare for the trail.':
        'Kenne die Markierungen. Bereite dich auf den Weg vor.',
    'Sign posting': 'Wegmarkierung',
    'Photo: Persephoni Trail stage': 'Foto: Etappe Persephoni Trail',
    'Follow the yellow E4 signs and direction arrows. Markers may appear on posts, rocks or existing road signs.':
        'Folge den gelben E4-Schildern und Richtungspfeilen. Markierungen können an Pfosten, Felsen oder vorhandenen Verkehrsschildern angebracht sein.',
    'Typical E4 waymark': 'Typische E4-Wegmarkierung',
    'Waymarks can be faded, damaged or missing, especially at junctions and on remote sections. Confirm your route on the offline map whenever the path is unclear.':
        'Wegmarkierungen können verblasst, beschädigt oder nicht vorhanden sein, besonders an Kreuzungen und in abgelegenen Abschnitten. Prüfe die Route auf der Offline-Karte, wenn der Weg unklar ist.',
    'Useful tips': 'Nützliche Tipps',
    'Carry enough water': 'Nimm ausreichend Wasser mit',
    'Water sources are irregular and may be seasonal. Refill whenever a reliable opportunity is available.':
        'Wasserquellen sind unregelmäßig verteilt und können saisonabhängig sein. Fülle deine Vorräte bei jeder zuverlässigen Gelegenheit auf.',
    'Plan for heat and daylight': 'Plane Hitze und Tageslicht ein',
    'Start early, use sun protection and avoid exposed sections during the hottest hours.':
        'Starte früh, verwende Sonnenschutz und meide ungeschützte Abschnitte während der heißesten Stunden.',
    'Keep the route offline': 'Speichere die Route offline',
    'Download the trail and map before leaving coverage, and carry a charged phone or backup power.':
        'Lade Weg und Karte herunter, bevor du den Empfangsbereich verlässt, und nimm ein geladenes Telefon oder eine Powerbank mit.',
    'Wear suitable footwear': 'Trage geeignetes Schuhwerk',
    'The E4 includes asphalt, forest tracks and rough or loose mountain paths.':
        'Der E4 führt über Asphalt, Waldwege sowie raue oder lockere Bergpfade.',
    'Before you set out': 'Bevor du aufbrichst',
    'Check the weather, tell someone your plan, and confirm that the stage suits your fitness and available daylight. In an emergency in Cyprus, call 112.':
        'Prüfe das Wetter, informiere jemanden über deinen Plan und stelle sicher, dass die Etappe zu deiner Kondition und dem verfügbaren Tageslicht passt. Wähle in einem Notfall auf Zypern die 112.',
    'Download route': 'Route herunterladen',
  },
  'es': {
    ...spanishLegalTranslations,
    'EUROTREX': 'EUROTREX',
    'Co-funded by the European Union': 'Cofinanciado por la Unión Europea',
    'Republic of Cyprus': 'República de Chipre',
    'Co-funded by the Republic of Cyprus':
        'Cofinanciado por la República de Chipre',
    'About us': 'Sobre nosotros',
    'About EUROTREX': 'Sobre EUROTREX',
    'Our mission': 'Nuestra misión',
    'Explore Europe, one trail at a time.': 'Descubre Europa, ruta a ruta.',
    'EUROTREX brings long-distance trails, stages, maps, elevation profiles and practical information together in one place.':
        'EUROTREX reúne rutas de gran recorrido, etapas, mapas, perfiles de elevación e información práctica en un solo lugar.',
    'Visit our website': 'Visitar nuestro sitio web',
    'Project funding': 'Financiación del proyecto',
    'The EUROTREX project is co-funded by the European Union and the Republic of Cyprus.':
        'El proyecto EUROTREX está cofinanciado por la Unión Europea y la República de Chipre.',
    'Contact us': 'Contacto',
    'Have an idea that could improve EUROTREX? Send us your suggestion.':
        '¿Tienes una idea que podría mejorar EUROTREX? Envíanos tu sugerencia.',
    'Send a suggestion': 'Enviar una sugerencia',
    'EUROTREX app suggestion': 'Sugerencia para la aplicación EUROTREX',
    'No email app is available. Opening the EUROTREX website contact form instead.':
        'No hay ninguna aplicación de correo disponible. Se abrirá el formulario de contacto del sitio web de EUROTREX.',
    'Version': 'Versión',
    'E4 - Crete': 'E4 - Crete',
    'E4 - Peloponnese': 'E4 - Peloponnese',
    'Settings': 'Ajustes',
    'Reverse': 'Invertir',
    'GPS': 'GPS',
    'Back': 'Atrás',
    'Reset': 'Restablecer',
    'Developer tools': 'Herramientas de desarrollo',
    'Reset E4 hint': 'Restablecer aviso E4',
    'Reset stage hint': 'Restablecer aviso de etapa',
    'Reset metrics hint': 'Restablecer aviso de métricas',
    'Show the pulsing E4 trail information hint again.':
        'Volver a mostrar el aviso pulsante de información del sendero E4.',
    'Show the stage details helper again.':
        'Volver a mostrar la ayuda sobre los detalles de las etapas.',
    'Show the left-side stage metrics helper again.':
        'Volver a mostrar la ayuda de las métricas de etapa del lado izquierdo.',
    'Tap the E4 sign to open trail information.':
        'Toca la señal E4 para abrir la información de la ruta.',
    'TRAIL LIBRARY': 'BIBLIOTECA DE RUTAS',
    'Explore trails': 'Explorar rutas',
    'Trails': 'Rutas',
    'Choose a trail to view its stages and maps.':
        'Elige una ruta para ver sus etapas y mapas.',
    'Current trails': 'Rutas actuales',
    'available': 'disponible',
    'LONG DISTANCE': 'GRAN RECORRIDO',
    'OFFLINE TRAIL': 'RUTA SIN CONEXIÓN',
    'E4': 'E4',
    'A long-distance journey linking the coast, forests and Troodos mountain.':
        'Una travesía de larga distancia que une la costa, los bosques y la montaña de Troodos.',
    'Trail data not downloaded': 'Datos de la ruta no descargados',
    'Trail data available offline': 'Datos de la ruta disponibles sin conexión',
    'Trail data and map available offline':
        'Datos de la ruta y mapa disponibles sin conexión',
    'Trail data and background map are available offline.':
        'Los datos de la ruta y el mapa de fondo están disponibles sin conexión.',
    'Trail data is available offline. Download the offline map to see map details without a connection.':
        'Los datos de la ruta están disponibles sin conexión. Descarga el mapa sin conexión para ver los detalles sin conexión.',
    'Explore trail': 'Explorar ruta',
    'Language': 'Idioma',
    'Measurements': 'Unidades',
    'Metric': 'Métrico',
    'Imperial': 'Imperial',
    'Kilometres and metres': 'Kilómetros y metros',
    'Miles and feet': 'Millas y pies',
    'Changes apply throughout the app.':
        'Los cambios se aplican en toda la aplicación.',
    'Stage by stage': 'Etapa por etapa',
    'Refresh offline trail': 'Actualizar ruta sin conexión',
    'Walk from Pafos to Larnaka': 'Caminar de Pafos a Larnaka',
    'Walk from Larnaka to Pafos': 'Caminar de Larnaka a Pafos',
    'CYPRUS · LONG DISTANCE TRAIL': 'CHIPRE · SENDERO DE GRAN RECORRIDO',
    'E4 - Cyprus': 'E4 - Cyprus',
    'Pafos Airport': 'Aeropuerto de Pafos',
    'Larnaka Airport': 'Aeropuerto de Larnaka',
    'Distance': 'Distancia',
    'Elevation Up': 'Desnivel positivo',
    'Elevation Down': 'Desnivel negativo',
    'Stages': 'Etapas',
    'High point': 'Punto más alto',
    'Route': 'Ruta',
    'Planner': 'Planificador',
    'Route planner': 'Planificador de ruta',
    'Tailored E4 plan': 'Plan E4 personalizado',
    'Trip': 'Viaje',
    'Pace': 'Ritmo',
    'Stay': 'Estancia',
    'Your trip': 'Tu viaje',
    'How many walking days do you have?': '¿Cuántos días de caminata tienes?',
    'days': 'días',
    'What would you like to walk?': '¿Qué te gustaría recorrer?',
    'Best section': 'Mejor tramo',
    'Whole E4': 'E4 completa',
    'Where would you prefer to start?': '¿Dónde prefieres empezar?',
    'Best direction': 'Mejor dirección',
    'Auto': 'Auto',
    'Pafos': 'Pafos',
    'Larnaka': 'Lárnaca',
    'We will compare both trail directions and choose the better fit.':
        'Compararemos ambos sentidos del sendero y elegiremos el más adecuado.',
    'Your daily pace': 'Tu ritmo diario',
    'How do you prefer to set your pace?': '¿Cómo prefieres definir tu ritmo?',
    'Hours': 'Horas',
    'hours': 'horas',
    'per day': 'al día',
    'Walking time includes an allowance for climbing. Each option adjusts the effort around this target.':
        'El tiempo de caminata incluye un margen para las subidas. Cada opción ajusta el esfuerzo a este objetivo.',
    'Overnight stays': 'Pernoctaciones',
    'Either': 'Cualquiera',
    'Price per night': 'Precio por noche',
    'The range applies per room, per night, using listed prices.':
        'El rango se aplica por habitación y noche según los precios indicados.',
    'Build my plans': 'Crear mis planes',
    'Relaxed': 'Relajado',
    'Adventurous': 'Aventurero',
    'My routes': 'Mis rutas',
    'New route': 'Nueva ruta',
    'Add route': 'Añadir ruta',
    'Open and edit': 'Abrir y editar',
    'Start date': 'Fecha de inicio',
    'Choose section': 'Elegir tramo',
    'Custom': 'Personalizado',
    'Suggested': 'Sugerido',
    'Smart': 'Inteligente',
    'Walking days': 'Días de caminata',
    'Swap start and finish': 'Intercambiar inicio y final',
    'Choose stage': 'Elegir etapa',
    'Search by stage or place': 'Buscar por etapa o lugar',
    'Water': 'Agua',
    'per night': 'por noche',
    'Flexible': 'Flexible',
    'Set as start': 'Usar como inicio',
    'Set as finish': 'Usar como final',
    'What should the planner hold fixed?':
        '¿Qué debe mantener fijo el planificador?',
    'Fit my days': 'Ajustar a mis días',
    'Limit effort': 'Limitar esfuerzo',
    'Remove walking day': 'Quitar día de caminata',
    'Add walking day': 'Añadir día de caminata',
    'We will choose the number of days that stays within your daily limit.':
        'Elegiremos el número de días que respete tu límite diario.',
    'Walking time includes an allowance for climbing. Route styles rank alternatives without changing this limit.':
        'El tiempo incluye un margen para las subidas. Los estilos ordenan alternativas sin cambiar este límite.',
    'Required average': 'Promedio necesario',
    'Projected finish': 'Final previsto',
    'Use suggested days': 'Usar días sugeridos',
    'Include stays without a listed price':
        'Incluir estancias sin precio indicado',
    'You can confirm their price before booking.':
        'Puedes confirmar el precio antes de reservar.',
    'Save route': 'Guardar ruta',
    'Review pace': 'Revisar ritmo',
    'Review stays': 'Revisar estancias',
    'Recommended': 'Recomendado',
    'average': 'de media',
    'Longest day': 'Día más largo',
    'Camping nights': 'Noches de camping',
    'Choose two stages in trail order.':
        'Elige dos etapas en el orden del sendero.',
    'This section is too far for the selected number of days.':
        'Este tramo es demasiado largo para los días seleccionados.',
    'This short section has fewer useful stops than selected days.':
        'Este tramo corto tiene menos paradas útiles que días seleccionados.',
    'One or more trail sections exceed your daily effort limit.':
        'Uno o más tramos superan tu límite diario de esfuerzo.',
    'A suitable stay is available, but its price is not listed.':
        'Hay una estancia adecuada, pero su precio no está indicado.',
    'No listed stays fit the selected price range.':
        'Ninguna estancia indicada encaja en el rango de precio.',
    'The selected stay type is not available at the required stops.':
        'El tipo de estancia elegido no está disponible en las paradas necesarias.',
    'The available overnight stops cannot make this exact day count.':
        'Las paradas disponibles no permiten este número exacto de días.',
    'There are not enough suitable overnight stops for this section.':
        'No hay suficientes paradas nocturnas adecuadas para este tramo.',
    'Tap a stage on the map to choose your start, then your finish.':
        'Toca una etapa en el mapa para elegir el inicio y después el final.',
    'Choose two different stages.': 'Elige dos etapas diferentes.',
    'Show my location': 'Mostrar mi ubicación',
    'Center trail': 'Centrar ruta',
    'Show all stages': 'Mostrar todas las etapas',
    'Choose start': 'Elegir inicio',
    'Choose finish': 'Elegir final',
    'Choose a different stage for the finish.': 'Elige otra etapa como final.',
    'Choose a start and finish stage.':
        'Elige una etapa de inicio y otra de fin.',
    'The planner will choose the best-fitting section.':
        'El planificador elegirá el tramo más adecuado.',
    'Move overnight stop': 'Mover parada nocturna',
    'Choose where to stay': 'Elegir alojamiento',
    'No accommodation is listed at this stop.':
        'No hay alojamientos registrados en esta parada.',
    'Move stop': 'Mover parada',
    'Choose stay': 'Elegir alojamiento',
    'Start this day': 'Iniciar este día',
    'Your route at a glance': 'Tu ruta de un vistazo',
    'Route map is loading…': 'Cargando el mapa de la ruta…',
    'Day': 'Día',
    'Offline readiness': 'Preparación sin conexión',
    'Offline map download in progress':
        'Descarga del mapa sin conexión en curso',
    'Download the trail map before you leave coverage.':
        'Descarga el mapa de la ruta antes de quedarte sin cobertura.',
    'Open map': 'Abrir mapa',
    'Manage': 'Gestionar',
    'from trail': 'desde la ruta',
    'Open': 'Abierto',
    'Confirm availability for your planned date.':
        'Confirma la disponibilidad para la fecha prevista.',
    'Pafos to Larnaka': 'Pafos a Lárnaca',
    'Larnaka to Pafos': 'Lárnaca a Pafos',
    'No routes saved yet': 'Aún no hay rutas guardadas',
    'Create a route to keep its itinerary and use it in Stage filters.':
        'Crea una ruta para guardar su itinerario y usarla en los filtros de etapas.',
    'Saved routes are unavailable.':
        'Las rutas guardadas no están disponibles.',
    'Delete route': 'Eliminar ruta',
    'Delete this saved route?': '¿Eliminar esta ruta guardada?',
    'Preferences': 'Preferencias',
    'Itinerary': 'Itinerario',
    'Choose your route': 'Elige tu ruta',
    'Finish must come after the start in the current direction.':
        'El final debe estar después del inicio en la dirección actual.',
    'Compare': 'Comparar',
    'Choose an itinerary': 'Elige un itinerario',
    'Budget': 'Económico',
    'Balanced': 'Equilibrado',
    'Comfort': 'Comodidad',
    'Unavailable for these preferences':
        'No disponible para estas preferencias',
    'Done': 'Listo',
    'Saved to My routes and Stage filters.':
        'Guardado en Mis rutas y en los filtros de etapas.',
    'Build a stage-to-stage itinerary': 'Crea un itinerario etapa por etapa',
    'Choose your daily limits and overnight requirements. The planner uses the current E4 stage and accommodation data.':
        'Elige tus límites diarios y requisitos de alojamiento. El planificador utiliza los datos actuales de etapas y alojamientos del E4.',
    'Daily walking limits': 'Límites diarios de caminata',
    'Minimum': 'Mínimo',
    'Maximum': 'Máximo',
    'Overnight stops': 'Paradas nocturnas',
    'Accommodation budget': 'Presupuesto de alojamiento',
    'Leave empty for no budget limit.':
        'Déjalo vacío para no limitar el presupuesto.',
    'Allow camping stages': 'Permitir etapas con camping',
    'Use camping when no accommodation stop fits the daily limits.':
        'Usa campings cuando ningún alojamiento cumpla los límites diarios.',
    'Find route': 'Buscar ruta',
    'Enter a positive number.': 'Introduce un número positivo.',
    'Maximum must be at least the minimum.':
        'El máximo debe ser igual o superior al mínimo.',
    'Trail data is unavailable.': 'Los datos de la ruta no están disponibles.',
    'Balanced route found': 'Ruta equilibrada encontrada',
    'walking days': 'días de caminata',
    'total distance': 'distancia total',
    'known prices': 'precios conocidos',
    '{count} overnight prices are unknown. Confirm prices and availability before travelling.':
        'Se desconocen {count} precios nocturnos. Confirma los precios y la disponibilidad antes de viajar.',
    'Day-by-day itinerary': 'Itinerario día a día',
    'Walking times and prices are estimates. Check weather, trail conditions and accommodation availability before setting out.':
        'Los tiempos y precios son estimaciones. Comprueba el tiempo, las condiciones de la ruta y la disponibilidad antes de salir.',
    'Camping stage': 'Etapa con camping',
    'Accommodation price unknown': 'Precio de alojamiento desconocido',
    'No feasible route found': 'No se encontró una ruta viable',
    'Try widening the daily distance range or increasing the accommodation budget.':
        'Prueba a ampliar el intervalo de distancia diaria o aumentar el presupuesto.',
    'Try widening the daily distance range, increasing the budget or allowing camping stages.':
        'Prueba a ampliar el intervalo diario, aumentar el presupuesto o permitir campings.',
    'Filter': 'Filtrar',
    'Filter stages': 'Filtrar etapas',
    'Choose trail points and services.': 'Elige puntos de la ruta y servicios.',
    'Choose stages, trail points and services.':
        'Elige etapas, puntos de la ruta y servicios.',
    'Stage name': 'Nombre de la etapa',
    'Search by stage name': 'Buscar por nombre de etapa',
    'Search by stage name or number': 'Buscar por nombre o número de etapa',
    'No stages found.': 'No se encontraron etapas.',
    'Trail points': 'Puntos de la ruta',
    'Points of Interest': 'Puntos de interés',
    'Beach': 'Playa',
    'Viewpoint': 'Mirador',
    'Religious Sites': 'Lugares religiosos',
    'Natural Landmarks': 'Lugares naturales',
    'Forests/Parks': 'Bosques/parques',
    'Filter by services': 'Filtrar por servicios',
    'Stages must offer every selected service.':
        'Las etapas deben ofrecer todos los servicios seleccionados.',
    'Clear': 'Limpiar',
    'Apply': 'Aplicar',
    'Apply filters': 'Aplicar filtros',
    'No stages match these services.':
        'Ninguna etapa coincide con estos servicios.',
    'No stages match these filters.':
        'Ninguna etapa coincide con estos filtros.',
    'Clear filters': 'Quitar filtros',
    'Go to top': 'Ir al inicio',
    'Go to end': 'Ir al final',
    'Map': 'Mapa',
    'Elevation': 'Desnivel',
    'The route stages are shown below.':
        'Las etapas de la ruta se muestran abajo.',
    'Trail guide available offline': 'Guía disponible sin conexión',
    'Download this trail for offline use':
        'Descarga esta ruta para usarla sin conexión',
    'Trail map': 'Mapa de la ruta',
    'Map layers': 'Capas del mapa',
    'Refresh elevation data': 'Actualizar datos de desnivel',
    'No elevation data is available.': 'No hay datos de desnivel.',
    'Could not download the elevation profile.':
        'No se pudo descargar el perfil de desnivel.',
    'Zoom out': 'Alejar',
    'Zoom in': 'Acercar',
    'Reset elevation view': 'Restablecer vista de desnivel',
    'Hide stages': 'Ocultar etapas',
    'Show stages': 'Mostrar etapas',
    'Full trail': 'Ruta completa',
    'Trail distance': 'Distancia total',
    'Highest point': 'Punto más alto',
    'High point position': 'Posición del punto más alto',
    'Offline samples': 'Muestras sin conexión',
    'Total ascent': 'Ascenso total',
    'Total descent': 'Descenso total',
    'Ascent': 'Ascenso',
    'Descent': 'Descenso',
    'Estimated walking time': 'Tiempo estimado de caminata',
    'Naismith estimate based on distance and ascent. Breaks and terrain are not included.':
        'Estimación de Naismith basada en la distancia y el ascenso. No incluye descansos ni terreno.',
    "Naismith's Rule estimates walking time by allowing:":
        'La regla de Naismith estima el tiempo de caminata considerando:',
    '1 hour for every 5 km of distance': '1 hora por cada 5 km de distancia',
    '1 extra hour for every 600 m of ascent':
        '1 hora adicional por cada 600 m de ascenso',
    'Descent, terrain difficulty, breaks, weather, pack weight, and individual fitness are not included. Actual walking time may vary.':
        'No se incluyen el descenso, la dificultad del terreno, los descansos, el clima, el peso de la mochila ni la condición física individual. El tiempo real puede variar.',
    'h': 'h',
    'min': 'min',
    'Preparing the offline elevation profile…':
        'Preparando el perfil sin conexión…',
    'Download profile': 'Descargar perfil',
    'Close stage summary': 'Cerrar resumen de etapa',
    'Open Stage Info': 'Abrir información de la etapa',
    'Stage': 'Etapa',
    'Tap a stage to see its details.': 'Toca una etapa para ver sus detalles.',
    'The numbers on the left show stage length, ascent, descent, and + distance from the trail.':
        'Los números de la izquierda muestran longitud de la etapa, ascenso, descenso y la distancia a la ruta indicada con +.',
    'Start point': 'Punto de inicio',
    'Finish point': 'Punto final',
    'From': 'Desde',
    'From Start': 'Desde el inicio',
    'To Finish': 'Hasta la meta',
    'Stage length': 'Longitud de etapa',
    'Altitude': 'Altitud',
    'Services': 'Servicios',
    'No services recorded for this stage.':
        'No hay servicios registrados para esta etapa.',
    'Trail position': 'Posición en la ruta',
    'Following E4 - Cyprus': 'Siguiendo la E4 - Chipre',
    'Route guidance will be available with the offline map.':
        'La navegación estará disponible con el mapa sin conexión.',
    'Available offline': 'Disponible sin conexión',
    'Stage information is stored on this device.':
        'La información de la etapa está guardada en este dispositivo.',
    'Previous': 'Anterior',
    'Next': 'Siguiente',
    'Show on map': 'Mostrar en el mapa',
    'Back to stages': 'Volver a las etapas',
    'Take the trail offline': 'Guardar la ruta sin conexión',
    'Could not download the trail': 'No se pudo descargar la ruta',
    'Download E4 - Cyprus to browse its stages without a connection.':
        'Descarga E4 - Chipre para ver sus etapas sin conexión.',
    'Download trail': 'Descargar ruta',
    'Lodging': 'Alojamiento',
    'Accommodation': 'Alojamiento',
    'Show accommodation': 'Mostrar alojamientos',
    'Hide accommodation': 'Ocultar alojamientos',
    'Excursion': 'Excursión',
    'Excursions': 'Excursiones',
    'Detour': 'Desvío',
    'Detours': 'Desvíos',
    'Alternative route': 'Ruta alternativa',
    'Leaves and rejoins the E4.': 'Se desvía de la E4 y vuelve a conectarse.',
    'Detour route': 'Ruta del desvío',
    'E4 section': 'Tramo de la E4',
    'Distance difference': 'Diferencia de distancia',
    'Time difference': 'Diferencia de tiempo',
    'Show detours': 'Mostrar desvíos',
    'Hide detours': 'Ocultar desvíos',
    'No detour routes are available on the map.':
        'No hay rutas de desvío disponibles en el mapa.',
    'Detour routes are currently unavailable.':
        'Las rutas de desvío no están disponibles en este momento.',
    'One way': 'Solo ida',
    'Out and back': 'Ida y vuelta',
    'Loop': 'Circular',
    'Show excursions': 'Mostrar excursiones',
    'Hide excursions': 'Ocultar excursiones',
    'No excursion routes are available on the map.':
        'No hay rutas de excursión disponibles en el mapa.',
    'Excursion routes are currently unavailable.':
        'Las rutas de excursión no están disponibles en este momento.',
    'Close accommodation summary': 'Cerrar resumen del alojamiento',
    'Accommodation locations are currently unavailable.':
        'Las ubicaciones de alojamientos no están disponibles en este momento.',
    'No accommodation locations are available on the map.':
        'No hay ubicaciones de alojamientos disponibles en el mapa.',
    'Book accommodation': 'Reservar alojamiento',
    'Book': 'Reservar',
    'Filter accommodation': 'Filtrar alojamientos',
    'Bookable online': 'Reservable en línea',
    'Price range': 'Rango de precios',
    'Any price': 'Cualquier precio',
    'Maximum distance from trail': 'Distancia máxima desde la ruta',
    'Any distance': 'Cualquier distancia',
    'Accommodation type': 'Tipo de alojamiento',
    'No accommodation matches these filters.':
        'Ningún alojamiento coincide con estos filtros.',
    'Accommodation booking': 'Reserva de alojamiento',
    'View places to stay': 'Ver alojamientos',
    'Places to stay near this stage': 'Alojamientos cerca de esta etapa',
    'Finding accommodation…': 'Buscando alojamiento…',
    'Accommodation information is currently unavailable.':
        'La información del alojamiento no está disponible en este momento.',
    'Check your connection and try again.':
        'Comprueba tu conexión e inténtalo de nuevo.',
    'Please try again.': 'Vuelve a intentarlo.',
    'No accommodation is listed for this stage.':
        'No hay alojamientos registrados para esta etapa.',
    'Try another nearby stage.': 'Prueba con otra etapa cercana.',
    'Find more stays on Booking.com': 'Buscar más alojamientos en Booking.com',
    'Search around {stage} for tonight.':
        'Busca para esta noche cerca de {stage}.',
    'Booking link unavailable': 'Enlace de reserva no disponible',
    'Could not open this link.': 'No se pudo abrir este enlace.',
    'Price': 'Precio',
    'Distance from trail': 'Distancia desde la ruta',
    'Season': 'Temporada',
    'Opening hours': 'Horario de apertura',
    'Capacity': 'Capacidad',
    'person': 'persona',
    'people': 'personas',
    'Check-in': 'Entrada',
    'Check-out': 'Salida',
    'Phone': 'Teléfono',
    'WhatsApp': 'WhatsApp',
    'Email': 'Correo electrónico',
    'View on map': 'Ver en el mapa',
    'Free': 'Gratis',
    'Agrotourism': 'Agroturismo',
    'Apartment': 'Apartamento',
    'Bed & Breakfast': 'Alojamiento y desayuno',
    'Campsite': 'Camping',
    'Guesthouse': 'Casa de huéspedes',
    'Hostel': 'Hostal',
    'Hotel': 'Hotel',
    'Municipal': 'Municipal',
    'Picnic site': 'Área de pícnic',
    'Religious': 'Alojamiento religioso',
    'April - October': 'abril–octubre',
    'Apr-Oct': 'abr.–oct.',
    'Apr–Oct': 'abr.–oct.',
    'Coming soon': 'Próximamente',
    'Camping': 'Camping',
    'Food': 'Comida',
    'Groceries': 'Comestibles',
    'Drinking water': 'Agua potable',
    'Non-drinking water': 'Agua no potable',
    'Toilets': 'Aseos',
    'Medical': 'Asistencia médica',
    'Pharmacy': 'Farmacia',
    'ATM': 'Cajero automático',
    'Bus': 'Autobús',
    'Offline map downloaded': 'Mapa sin conexión descargado',
    'Offline map not downloaded': 'Mapa sin conexión no descargado',
    'Downloading offline map': 'Descargando mapa sin conexión',
    'Offline map download failed': 'Error al descargar el mapa',
    'Offline map removal failed': 'No se pudo eliminar el mapa sin conexión',
    'Offline map available': 'Mapa sin conexión disponible',
    'Checking offline map…': 'Comprobando el mapa sin conexión…',
    'Download offline map': 'Descargar mapa sin conexión',
    'Offline access': 'Acceso sin conexión',
    'Offline content for this trail': 'Contenido sin conexión de esta ruta',
    'Checking trail data…': 'Comprobando los datos de la ruta…',
    'Trail data status could not be read.':
        'No se pudo consultar el estado de los datos de la ruta.',
    'Trail data': 'Datos de la ruta',
    'Route, stages and elevation': 'Ruta, etapas y perfil de elevación',
    'Offline map': 'Mapa sin conexión',
    'Detailed map along the trail': 'Mapa detallado a lo largo de la ruta',
    'Check again': 'Comprobar de nuevo',
    'Size': 'Tamaño',
    'Route points': 'Puntos de la ruta',
    'Last updated': 'Última actualización',
    'Not available': 'No disponible',
    'Trail map available offline': 'Mapa de la ruta disponible sin conexión',
    'Download interrupted': 'Descarga interrumpida',
    'Take the map offline': 'Guardar el mapa sin conexión',
    'Remove offline map': 'Eliminar mapa sin conexión',
    'Remove trail data': 'Eliminar datos de la ruta',
    'Try again': 'Intentar de nuevo',
    'Cancel': 'Cancelar',
    'Close': 'Cerrar',
    'Remove': 'Eliminar',
    'Remove offline map?': '¿Eliminar el mapa sin conexión?',
    'Remove trail data?': '¿Eliminar los datos de la ruta?',
    'The route, stages and elevation will be removed. The offline map will remain on this device.':
        'Se eliminarán la ruta, las etapas y el perfil de elevación. El mapa sin conexión permanecerá en este dispositivo.',
    'The trail data could not be removed.':
        'No se pudieron eliminar los datos de la ruta.',
    'Show the whole trail': 'Mostrar toda la ruta',
    'Start': 'Inicio',
    'Finish': 'Final',
    'Selected stage': 'Etapa seleccionada',
    'Other stages': 'Otras etapas',
    'My location': 'Mi ubicación',
    'Near {stage} · {distance} from the trail':
        'Cerca de {stage} · a {distance} de la ruta',
    'Offline maps': 'Mapas sin conexión',
    'Downloaded': 'Descargado',
    'Checking offline maps…': 'Comprobando mapas sin conexión…',
    'No offline maps downloaded.': 'No hay mapas sin conexión descargados.',
    'Delete offline maps': 'Eliminar mapas sin conexión',
    'Delete offline maps?': '¿Eliminar mapas sin conexión?',
    'Delete': 'Eliminar',
    'Firebase is not configured for this build.':
        'Firebase no está configurado para esta compilación.',
    'Could not update the trail. Your offline copy is unchanged.':
        'No se pudo actualizar la ruta. La copia sin conexión no ha cambiado.',
    'The Troodos section contains the route’s largest climbs. Plan water and daylight before entering long mountain stages.':
        'La sección de Troodos contiene las mayores subidas de la ruta. Planifica el agua y las horas de luz antes de las largas etapas de montaña.',
    'Offline map status could not be read.':
        'No se pudo leer el estado del mapa sin conexión.',
    'The offline map could not be downloaded. Check your connection and try again.':
        'No se pudo descargar el mapa sin conexión. Comprueba tu conexión e inténtalo de nuevo.',
    'The offline map could not be removed.':
        'No se pudo eliminar el mapa sin conexión.',
    'The detailed E4 - Cyprus map is stored on this device.':
        'El mapa detallado de la E4 - Chipre está guardado en este dispositivo.',
    'Please try the download again.': 'Vuelve a intentar la descarga.',
    'Downloads a detailed corridor around the complete E4 - Cyprus for use without a connection.':
        'Descarga un corredor detallado de toda la E4 - Chipre para usarlo sin conexión.',
    'Download the route data first.': 'Descarga primero los datos de la ruta.',
    'The route, stages and elevation will remain offline. Only the offline map will be removed.':
        'La ruta, las etapas y el perfil de elevación seguirán disponibles sin conexión. Solo se eliminará el mapa sin conexión.',
    'Turn on Location Services to show your position.':
        'Activa los servicios de ubicación para mostrar tu posición.',
    'Location permission is needed to show your position.':
        'Se necesita permiso de ubicación para mostrar tu posición.',
    'Your location could not be read right now.':
        'No se pudo obtener tu ubicación en este momento.',
    'Map unavailable': 'Mapa no disponible',
    'The map service is not configured for this build.':
        'El servicio de mapas no está configurado para esta compilación.',
    'Route data is not on this device yet.':
        'Los datos de la ruta aún no están en este dispositivo.',
    'Find my stage': 'Encontrar mi etapa',
    'You are not on the trail.': 'No estás en la ruta.',
    'You are approximately {distance} from the trail.':
        'Estás aproximadamente a {distance} de la ruta.',
    'Trail information': 'Información de la ruta',
    'Trail guide': 'Guía de la ruta',
    'App preferences': 'Preferencias de la aplicación',
    'Know the signs. Prepare for the trail.':
        'Conoce las señales. Prepárate para la ruta.',
    'Sign posting': 'Señalización',
    'Photo: Persephoni Trail stage': 'Foto: etapa Persephoni Trail',
    'Follow the yellow E4 signs and direction arrows. Markers may appear on posts, rocks or existing road signs.':
        'Sigue las señales amarillas de la E4 y las flechas de dirección. Las marcas pueden aparecer en postes, rocas o señales de tráfico existentes.',
    'Typical E4 waymark': 'Marca típica de la E4',
    'Waymarks can be faded, damaged or missing, especially at junctions and on remote sections. Confirm your route on the offline map whenever the path is unclear.':
        'Las marcas pueden estar descoloridas, dañadas o faltar, especialmente en cruces y tramos remotos. Comprueba la ruta en el mapa sin conexión cuando el camino no esté claro.',
    'Useful tips': 'Consejos útiles',
    'Carry enough water': 'Lleva suficiente agua',
    'Water sources are irregular and may be seasonal. Refill whenever a reliable opportunity is available.':
        'Las fuentes de agua son irregulares y pueden ser estacionales. Repón agua siempre que encuentres una fuente fiable.',
    'Plan for heat and daylight': 'Planifica el calor y la luz del día',
    'Start early, use sun protection and avoid exposed sections during the hottest hours.':
        'Empieza temprano, usa protección solar y evita los tramos expuestos durante las horas de más calor.',
    'Keep the route offline': 'Guarda la ruta sin conexión',
    'Download the trail and map before leaving coverage, and carry a charged phone or backup power.':
        'Descarga la ruta y el mapa antes de perder la cobertura y lleva el teléfono cargado o una batería externa.',
    'Wear suitable footwear': 'Usa calzado adecuado',
    'The E4 includes asphalt, forest tracks and rough or loose mountain paths.':
        'La E4 incluye asfalto, pistas forestales y senderos de montaña irregulares o con terreno suelto.',
    'Before you set out': 'Antes de salir',
    'Check the weather, tell someone your plan, and confirm that the stage suits your fitness and available daylight. In an emergency in Cyprus, call 112.':
        'Consulta el tiempo, informa a alguien de tu plan y confirma que la etapa se adapta a tu condición física y a las horas de luz disponibles. En una emergencia en Chipre, llama al 112.',
    'Download route': 'Descargar ruta',
  },
};
