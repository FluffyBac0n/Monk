import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monk_mobile/core/localization/app_localizations.dart';

void main() {
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
    expect(german.t('Offline access'), 'Offline-Zugriff');
    expect(german.t('Offline map'), 'Offline-Karte');
    expect(german.t('Map unavailable'), 'Karte nicht verfügbar');
    expect(german.t('Accommodation'), 'Unterkunft');
    expect(german.t('Book accommodation'), 'Unterkunft buchen');
    expect(german.t('April - October'), 'April–Oktober');
    expect(
      german.t('Booking link unavailable'),
      'Buchungslink nicht verfügbar',
    );
    expect(german.t('Estimated walking time'), 'Geschätzte Gehzeit');
    expect(german.t('Selected stage'), 'Ausgewählte Etappe');
    expect(german.t('About us'), 'Über uns');
    expect(german.t('About EUROTREX'), 'Über EUROTREX');
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
        'The EUROTREX project is co-funded by the European Union and supported by the Republic of Cyprus.',
      ),
      'Das EUROTREX-Projekt wird von der Europäischen Union kofinanziert und von der Republik Zypern unterstützt.',
    );
    expect(
      german.t('Supported by the Republic of Cyprus'),
      'Unterstützt von der Republik Zypern',
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
    expect(german.nearbyStage('Platres'), 'Etappe in der Nähe: Platres');

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
    expect(spanish.t('Book accommodation'), 'Reservar alojamiento');
    expect(spanish.t('April - October'), 'abril–octubre');
    expect(
      spanish.t('Booking link unavailable'),
      'Enlace de reserva no disponible',
    );
    expect(spanish.t('Estimated walking time'), 'Tiempo estimado de caminata');
    expect(spanish.t('Selected stage'), 'Etapa seleccionada');
    expect(spanish.t('About us'), 'Sobre nosotros');
    expect(spanish.t('About EUROTREX'), 'Sobre EUROTREX');
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
        'The EUROTREX project is co-funded by the European Union and supported by the Republic of Cyprus.',
      ),
      'El proyecto EUROTREX está cofinanciado por la Unión Europea y cuenta con el apoyo de la República de Chipre.',
    );
    expect(
      spanish.t('Supported by the Republic of Cyprus'),
      'Con el apoyo de la República de Chipre',
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
    expect(spanish.nearbyStage('Platres'), 'Etapa cercana: Platres');
  });
}
