import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/core/localization/app_localizations.dart';
import 'package:monk_mobile/core/settings/app_settings.dart';

void main() {
  test('Italian and French are supported app languages', () {
    expect(AppLanguage.fromCode('it'), AppLanguage.italian);
    expect(AppLanguage.fromCode('fr'), AppLanguage.french);
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      containsAll(<String>['en', 'de', 'es', 'it', 'fr']),
    );
    expect(AppLanguage.values.map((language) => language.flagEmoji), <String>[
      '🇬🇧',
      '🇩🇪',
      '🇪🇸',
      '🇮🇹',
      '🇫🇷',
    ]);
  });

  test('every translated locale covers the complete UI catalog', () {
    final referenceKeys = AppLocalizations.translationKeys(const Locale('de'));

    for (final locale in const [Locale('es'), Locale('it'), Locale('fr')]) {
      final translatedKeys = AppLocalizations.translationKeys(locale);
      expect(
        translatedKeys,
        referenceKeys,
        reason: '${locale.languageCode} should not fall back to English',
      );
      final localizations = AppLocalizations(locale);
      for (final key in translatedKeys) {
        expect(
          localizations.t(key).trim(),
          isNotEmpty,
          reason: '${locale.languageCode} must provide a value for "$key"',
        );
      }
    }
  });

  test('every directly localized UI string exists in the catalog', () {
    final catalog = AppLocalizations.translationKeys(const Locale('de'));
    final localizedString = RegExp(
      r"\.t\(\s*'((?:\\.|[^'])*)'",
      multiLine: true,
      dotAll: true,
    );
    final missing = <String, String>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in localizedString.allMatches(source)) {
        final key = match.group(1)!.replaceAll(r"\'", "'");
        if (!catalog.contains(key)) missing[key] = entity.path;
      }
    }

    expect(missing, isEmpty, reason: 'Missing translation keys: $missing');
  });

  test('Italian and French localize representative app flows', () {
    const italian = AppLocalizations(Locale('it'));
    const french = AppLocalizations(Locale('fr'));

    expect(italian.t('Settings'), 'Impostazioni');
    expect(italian.t('Explore trails'), 'Esplora i sentieri');
    expect(italian.t('Trails'), 'Sentieri');
    expect(italian.t('Stage'), 'Tappa');
    expect(italian.t('Accommodation'), 'Alloggi');
    expect(italian.t('Offline map'), 'Mappa offline');
    expect(italian.t('Find my stage'), 'Trova la mia tappa');
    expect(italian.t('From Start'), 'Dalla partenza');
    expect(italian.t('To Finish'), 'All’arrivo');
    expect(italian.t('Points of Interest'), 'Punti di interesse');
    expect(italian.t('Beach'), 'Spiaggia');
    expect(italian.t('Viewpoint'), 'Punto panoramico');
    expect(italian.t('Religious Sites'), 'Luoghi religiosi');
    expect(italian.t('Natural Landmarks'), 'Luoghi naturali');
    expect(italian.t('Forests/Parks'), 'Boschi/parchi');
    expect(italian.t('ATM'), 'Bancomat');
    expect(
      italian.t('Tap the E4 sign to open trail information.'),
      'Tocca il segnale E4 per aprire le informazioni sul sentiero.',
    );
    expect(
      italian.t(
        'The numbers on the left show ascent, descent, stage length, and + distance from the trail.',
      ),
      'I numeri a sinistra mostrano salita, discesa, lunghezza della tappa e, con +, la distanza dal sentiero.',
    );
    expect(
      italian.offTrailDistance('240 m'),
      'Ti trovi a circa 240 m dal sentiero.',
    );
    expect(
      italian.t('Tap a stage to see its details.'),
      'Tocca una tappa per visualizzarne i dettagli.',
    );

    expect(french.t('Settings'), 'Paramètres');
    expect(french.t('Explore trails'), 'Explorer les sentiers');
    expect(french.t('Trails'), 'Sentiers');
    expect(french.t('Stage'), 'Étape');
    expect(french.t('Accommodation'), 'Hébergements');
    expect(french.t('Offline map'), 'Carte hors ligne');
    expect(french.t('Find my stage'), 'Trouver mon étape');
    expect(french.t('From Start'), 'Depuis le départ');
    expect(french.t('To Finish'), 'Jusqu’à l’arrivée');
    expect(french.t('Points of Interest'), 'Points d’intérêt');
    expect(french.t('Beach'), 'Plage');
    expect(french.t('Viewpoint'), 'Point de vue');
    expect(french.t('Religious Sites'), 'Sites religieux');
    expect(french.t('Natural Landmarks'), 'Sites naturels');
    expect(french.t('Forests/Parks'), 'Forêts/parcs');
    expect(french.t('ATM'), 'Distributeur automatique');
    expect(
      french.t('Tap the E4 sign to open trail information.'),
      'Touchez le balisage E4 pour ouvrir les informations du sentier.',
    );
    expect(
      french.t(
        'The numbers on the left show ascent, descent, stage length, and + distance from the trail.',
      ),
      'Les nombres à gauche indiquent la montée, la descente, la longueur de l’étape et, avec +, la distance par rapport au sentier.',
    );
    expect(
      french.offTrailDistance('240 m'),
      'Vous êtes à environ 240 m du sentier.',
    );
    expect(
      french.t('Tap a stage to see its details.'),
      'Touchez une étape pour voir ses détails.',
    );
  });

  test('new offline, stage, and map copy is localized', () {
    const german = AppLocalizations(Locale('de'));
    const spanish = AppLocalizations(Locale('es'));

    expect(german.t('EUROTREX'), 'EUROTREX');
    expect(
      german.t('Co-funded by the European Union'),
      'Kofinanziert von der Europäischen Union',
    );
    expect(german.t('Republic of Cyprus'), 'Republik Zypern');
    expect(german.t('Crete E4'), 'Crete E4');
    expect(german.t('Peloponnese E4'), 'Peloponnes E4');
    expect(german.t('OFFLINE TRAIL'), 'OFFLINE-WANDERWEG');
    expect(german.t('Offline access'), 'Offline-Zugriff');
    expect(german.t('Offline map'), 'Offline-Karte');
    expect(german.t('Map unavailable'), 'Karte nicht verfügbar');
    expect(german.t('Accommodation'), 'Unterkunft');
    expect(german.t('Show accommodation'), 'Unterkünfte anzeigen');
    expect(german.t('Hide accommodation'), 'Unterkünfte ausblenden');
    expect(german.t('Excursions'), 'Abstecher');
    expect(german.t('Detours'), 'Umleitungen');
    expect(german.t('Alternative route'), 'Alternativroute');
    expect(german.t('Show detours'), 'Umleitungen anzeigen');
    expect(german.t('Show excursions'), 'Abstecher anzeigen');
    expect(german.t('Hide excursions'), 'Abstecher ausblenden');
    expect(
      german.t('Close accommodation summary'),
      'Unterkunftsübersicht schließen',
    );
    expect(
      german.t('Accommodation locations are currently unavailable.'),
      'Unterkunftsstandorte sind derzeit nicht verfügbar.',
    );
    expect(
      german.t('No accommodation locations are available on the map.'),
      'Auf der Karte sind keine Unterkunftsstandorte verfügbar.',
    );
    expect(german.t('Book accommodation'), 'Unterkunft buchen');
    expect(german.t('Book'), 'Buchen');
    expect(german.t('Apply'), 'Anwenden');
    expect(german.t('Filter stages'), 'Etappen filtern');
    expect(german.t('Stage name'), 'Etappenname');
    expect(german.t('From Start'), 'Vom Start');
    expect(german.t('To Finish'), 'Bis zum Ziel');
    expect(
      german.t('Search by stage name or number'),
      'Nach Etappenname oder -nummer suchen',
    );
    expect(german.t('Trail points'), 'Wegpunkte');
    expect(german.t('Points of Interest'), 'Interessante Orte');
    expect(german.t('Beach'), 'Strand');
    expect(german.t('Viewpoint'), 'Aussichtspunkt');
    expect(german.t('Religious Sites'), 'Religiöse Stätten');
    expect(german.t('Natural Landmarks'), 'Naturdenkmäler');
    expect(german.t('Forests/Parks'), 'Wälder/Parks');
    expect(german.t('ATM'), 'Geldautomat');
    expect(
      german.t('Tap the E4 sign to open trail information.'),
      'Tippe auf das E4-Zeichen, um die Weginformationen zu öffnen.',
    );
    expect(
      german.t(
        'The numbers on the left show ascent, descent, stage length, and + distance from the trail.',
      ),
      'Links siehst du Aufstieg, Abstieg, Etappenlänge und mit + die Entfernung vom Weg.',
    );
    expect(german.t('Filter accommodation'), 'Unterkünfte filtern');
    expect(german.t('Bookable online'), 'Online buchbar');
    expect(german.t('Price range'), 'Preisspanne');
    expect(german.t('Any price'), 'Beliebiger Preis');
    expect(german.t('View places to stay'), 'Unterkünfte ansehen');
    expect(german.t('View on map'), 'Auf Karte anzeigen');
    expect(german.t('April - October'), 'April–Oktober');
    expect(
      german.t('Booking link unavailable'),
      'Buchungslink nicht verfügbar',
    );
    expect(german.t('Estimated walking time'), 'Geschätzte Gehzeit');
    expect(german.t('Selected stage'), 'Ausgewählte Etappe');
    expect(german.t('About us'), 'Über uns');
    expect(german.t('About EUROTREX'), 'Über EUROTREX');
    expect(german.t('Our mission'), 'Unsere Mission');
    expect(
      german.t('Explore Europe, one trail at a time.'),
      'Entdecke Europa – Weg für Weg.',
    );
    expect(
      german.t(
        'EUROTREX brings long-distance trails, stages, maps, elevation profiles and practical information together in one place.',
      ),
      'EUROTREX bündelt Fernwanderwege, Etappen, Karten, Höhenprofile und praktische Informationen an einem Ort.',
    );
    expect(german.t('Visit our website'), 'Unsere Website besuchen');
    expect(german.t('Project funding'), 'Projektförderung');
    expect(
      german.t(
        'The EUROTREX project is co-funded by the European Union and the Republic of Cyprus.',
      ),
      'Das EUROTREX-Projekt wird von der Europäischen Union und der Republik Zypern kofinanziert.',
    );
    expect(
      german.t('Co-funded by the Republic of Cyprus'),
      'Kofinanziert von der Republik Zypern',
    );
    expect(german.t('Contact us'), 'Kontakt');
    expect(
      german.t(
        'Have an idea that could improve EUROTREX? Send us your suggestion.',
      ),
      'Hast du eine Idee, die EUROTREX verbessern könnte? Sende uns deinen Vorschlag.',
    );
    expect(german.t('Send a suggestion'), 'Vorschlag senden');
    expect(german.t('EUROTREX app suggestion'), 'Vorschlag zur EUROTREX-App');
    expect(
      german.t(
        'No email app is available. Opening the EUROTREX website contact form instead.',
      ),
      'Keine E-Mail-App verfügbar. Stattdessen wird das Kontaktformular auf der EUROTREX-Website geöffnet.',
    );
    expect(german.t('Version'), 'Version');
    expect(german.t('Find my stage'), 'Meine Etappe finden');
    expect(
      german.t('You are not on the trail.'),
      'Du befindest dich nicht auf dem Weg.',
    );
    expect(
      german.offTrailDistance('240 m'),
      'Du bist ungefähr 240 m vom Weg entfernt.',
    );

    expect(spanish.t('EUROTREX'), 'EUROTREX');
    expect(
      spanish.t('Co-funded by the European Union'),
      'Cofinanciado por la Unión Europea',
    );
    expect(spanish.t('Republic of Cyprus'), 'República de Chipre');
    expect(spanish.t('Crete E4'), 'Crete E4');
    expect(spanish.t('Peloponnese E4'), 'Peloponeso E4');
    expect(spanish.t('Offline access'), 'Acceso sin conexión');
    expect(spanish.t('Offline map'), 'Mapa sin conexión');
    expect(spanish.t('Map unavailable'), 'Mapa no disponible');
    expect(spanish.t('Accommodation'), 'Alojamiento');
    expect(spanish.t('Apply'), 'Aplicar');
    expect(spanish.t('Filter stages'), 'Filtrar etapas');
    expect(spanish.t('Stage name'), 'Nombre de la etapa');
    expect(spanish.t('From Start'), 'Desde el inicio');
    expect(spanish.t('To Finish'), 'Hasta la meta');
    expect(
      spanish.t('Search by stage name or number'),
      'Buscar por nombre o número de etapa',
    );
    expect(spanish.t('Trail points'), 'Puntos de la ruta');
    expect(spanish.t('Points of Interest'), 'Puntos de interés');
    expect(spanish.t('Beach'), 'Playa');
    expect(spanish.t('Viewpoint'), 'Mirador');
    expect(spanish.t('Religious Sites'), 'Lugares religiosos');
    expect(spanish.t('Natural Landmarks'), 'Lugares naturales');
    expect(spanish.t('Forests/Parks'), 'Bosques/parques');
    expect(
      spanish.t('Tap the E4 sign to open trail information.'),
      'Toca la señal E4 para abrir la información de la ruta.',
    );
    expect(
      spanish.t(
        'The numbers on the left show ascent, descent, stage length, and + distance from the trail.',
      ),
      'Los números de la izquierda muestran ascenso, descenso, longitud de la etapa y la distancia a la ruta indicada con +.',
    );
    expect(spanish.t('Show accommodation'), 'Mostrar alojamientos');
    expect(spanish.t('Hide accommodation'), 'Ocultar alojamientos');
    expect(spanish.t('Excursions'), 'Excursiones');
    expect(spanish.t('Detours'), 'Desvíos');
    expect(spanish.t('Alternative route'), 'Ruta alternativa');
    expect(spanish.t('Show detours'), 'Mostrar desvíos');
    expect(spanish.t('Show excursions'), 'Mostrar excursiones');
    expect(spanish.t('Hide excursions'), 'Ocultar excursiones');
    expect(
      spanish.t('Close accommodation summary'),
      'Cerrar resumen del alojamiento',
    );
    expect(
      spanish.t('Accommodation locations are currently unavailable.'),
      'Las ubicaciones de alojamientos no están disponibles en este momento.',
    );
    expect(
      spanish.t('No accommodation locations are available on the map.'),
      'No hay ubicaciones de alojamientos disponibles en el mapa.',
    );
    expect(spanish.t('Book accommodation'), 'Reservar alojamiento');
    expect(spanish.t('Book'), 'Reservar');
    expect(spanish.t('Filter accommodation'), 'Filtrar alojamientos');
    expect(spanish.t('Bookable online'), 'Reservable en línea');
    expect(spanish.t('Price range'), 'Rango de precios');
    expect(spanish.t('Any price'), 'Cualquier precio');
    expect(spanish.t('View places to stay'), 'Ver alojamientos');
    expect(spanish.t('View on map'), 'Ver en el mapa');
    expect(spanish.t('April - October'), 'abril–octubre');
    expect(
      spanish.t('Booking link unavailable'),
      'Enlace de reserva no disponible',
    );
    expect(spanish.t('Estimated walking time'), 'Tiempo estimado de caminata');
    expect(spanish.t('Selected stage'), 'Etapa seleccionada');
    expect(spanish.t('About us'), 'Sobre nosotros');
    expect(spanish.t('About EUROTREX'), 'Sobre EUROTREX');
    expect(spanish.t('Our mission'), 'Nuestra misión');
    expect(
      spanish.t('Explore Europe, one trail at a time.'),
      'Descubre Europa, ruta a ruta.',
    );
    expect(
      spanish.t(
        'EUROTREX brings long-distance trails, stages, maps, elevation profiles and practical information together in one place.',
      ),
      'EUROTREX reúne rutas de gran recorrido, etapas, mapas, perfiles de elevación e información práctica en un solo lugar.',
    );
    expect(spanish.t('Visit our website'), 'Visitar nuestro sitio web');
    expect(spanish.t('Project funding'), 'Financiación del proyecto');
    expect(
      spanish.t(
        'The EUROTREX project is co-funded by the European Union and the Republic of Cyprus.',
      ),
      'El proyecto EUROTREX está cofinanciado por la Unión Europea y la República de Chipre.',
    );
    expect(
      spanish.t('Co-funded by the Republic of Cyprus'),
      'Cofinanciado por la República de Chipre',
    );
    expect(spanish.t('Contact us'), 'Contacto');
    expect(
      spanish.t(
        'Have an idea that could improve EUROTREX? Send us your suggestion.',
      ),
      '¿Tienes una idea que podría mejorar EUROTREX? Envíanos tu sugerencia.',
    );
    expect(spanish.t('Send a suggestion'), 'Enviar una sugerencia');
    expect(
      spanish.t('EUROTREX app suggestion'),
      'Sugerencia para la aplicación EUROTREX',
    );
    expect(
      spanish.t(
        'No email app is available. Opening the EUROTREX website contact form instead.',
      ),
      'No hay ninguna aplicación de correo disponible. Se abrirá el formulario de contacto del sitio web de EUROTREX.',
    );
    expect(spanish.t('Version'), 'Versión');
    expect(spanish.t('Find my stage'), 'Encontrar mi etapa');
    expect(spanish.t('You are not on the trail.'), 'No estás en la ruta.');
    expect(
      spanish.offTrailDistance('240 m'),
      'Estás aproximadamente a 240 m de la ruta.',
    );
  });
}
