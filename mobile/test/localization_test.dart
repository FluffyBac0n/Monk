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
    }
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
    expect(
      german.t('Search by stage name or number'),
      'Nach Etappenname oder -nummer suchen',
    );
    expect(german.t('Trail points'), 'Wegpunkte');
    expect(german.t('Filter accommodation'), 'Unterkünfte filtern');
    expect(german.t('Bookable online'), 'Online buchbar');
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
    expect(
      spanish.t('Search by stage name or number'),
      'Buscar por nombre o número de etapa',
    );
    expect(spanish.t('Trail points'), 'Puntos de la ruta');
    expect(spanish.t('Show accommodation'), 'Mostrar alojamientos');
    expect(spanish.t('Hide accommodation'), 'Ocultar alojamientos');
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
  });
}
