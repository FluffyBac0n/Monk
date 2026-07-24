import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('de'), Locale('es')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  String t(String english) =>
      _translations[locale.languageCode]?[english] ?? english;

  String stage(int sequence) => '${t('Stage')} $sequence';

  String from(String place) => '${t('From')} $place';

  String routeDirection(String start, String end) => '$start  →  $end';

  String get pafosAirport => t('Pafos Airport');
  String get larnakaAirport => t('Larnaka Airport');
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

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
  'de': {
    'EUROTREX': 'EUROTREX',
    'Co-funded by the European Union':
        'Kofinanziert von der Europäischen Union',
    'Republic of Cyprus': 'Republik Zypern',
    'Crete E4': 'Crete E4',
    'Peloponnese E4': 'Peloponnes E4',
    'Settings': 'Einstellungen',
    'TRAIL LIBRARY': 'WEGBIBLIOTHEK',
    'Explore trails': 'Wanderwege entdecken',
    'Choose a trail to view its stages and maps.':
        'Wähle einen Weg, um Etappen und Karten anzusehen.',
    'Current trails': 'Aktuelle Wanderwege',
    'available': 'verfügbar',
    'LONG DISTANCE': 'FERNWANDERWEG',
    'A long-distance journey linking the coast, forests and Troodos mountains.':
        'Eine Fernwanderung, die Küste, Wälder und das Troodos-Gebirge verbindet.',
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
    'Cyprus E4': 'Cyprus E4',
    'Pafos Airport': 'Flughafen Pafos',
    'Larnaka Airport': 'Flughafen Larnaka',
    'Distance': 'Entfernung',
    'Stages': 'Etappen',
    'High point': 'Höchster Punkt',
    'Route': 'Route',
    'Filter': 'Filter',
    'Filter by services': 'Nach Angeboten filtern',
    'Stages must offer every selected service.':
        'Etappen müssen alle ausgewählten Angebote bieten.',
    'Clear': 'Zurücksetzen',
    'Apply filters': 'Filter anwenden',
    'No stages match these services.':
        'Keine Etappen entsprechen diesen Angeboten.',
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
    'Refresh elevation data': 'Höhendaten aktualisieren',
    'No elevation data is available.': 'Keine Höhendaten verfügbar.',
    'Could not download the elevation profile.':
        'Das Höhenprofil konnte nicht geladen werden.',
    'Zoom out': 'Verkleinern',
    'Zoom in': 'Vergrößern',
    'Reset elevation view': 'Höhenansicht zurücksetzen',
    'Hide stages': 'Etappen ausblenden',
    'Show stages': 'Etappen anzeigen',
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
    'h': 'Std.',
    'min': 'Min.',
    'Preparing the offline elevation profile…':
        'Offline-Höhenprofil wird vorbereitet…',
    'Download profile': 'Profil herunterladen',
    'Close stage summary': 'Etappenübersicht schließen',
    'Stage': 'Etappe',
    'Start point': 'Startpunkt',
    'Finish point': 'Zielpunkt',
    'From': 'Ab',
    'Stage length': 'Etappenlänge',
    'Altitude': 'Höhe',
    'Services': 'Angebote',
    'No services recorded for this stage.':
        'Für diese Etappe sind keine Angebote erfasst.',
    'Trail position': 'Position auf dem Weg',
    'Following the Cyprus E4': 'Auf dem Cyprus E4',
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
    'Download Cyprus E4 to browse its stages without a connection.':
        'Cyprus E4 herunterladen, um Etappen ohne Verbindung anzusehen.',
    'Download trail': 'Weg herunterladen',
    'Lodging': 'Unterkunft',
    'Book accommodation': 'Unterkunft buchen',
    'Accommodation booking': 'Unterkunftsbuchung',
    'Coming soon': 'Demnächst verfügbar',
    'Camping': 'Camping',
    'Food': 'Essen',
    'Groceries': 'Lebensmittel',
    'Drinking water': 'Trinkwasser',
    'Non-drinking water': 'Kein Trinkwasser',
    'Toilets': 'Toiletten',
    'Medical': 'Medizinische Hilfe',
    'Pharmacy': 'Apotheke',
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
    'Last updated': 'Zuletzt aktualisiert',
    'Not available': 'Nicht verfügbar',
    'Trail map available offline': 'Wanderkarte offline verfügbar',
    'Download interrupted': 'Download unterbrochen',
    'Take the map offline': 'Karte offline verfügbar machen',
    'Remove offline map': 'Offline-Karte entfernen',
    'Try again': 'Erneut versuchen',
    'Cancel': 'Abbrechen',
    'Remove': 'Entfernen',
    'Remove offline map?': 'Offline-Karte entfernen?',
    'Show the whole trail': 'Gesamten Weg anzeigen',
    'Start': 'Start',
    'Finish': 'Ziel',
    'Selected stage': 'Ausgewählte Etappe',
    'Other stages': 'Weitere Etappen',
    'My location': 'Mein Standort',
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
    'The detailed Cyprus E4 map is stored on this device.':
        'Die detaillierte Cyprus-E4-Karte ist auf diesem Gerät gespeichert.',
    'Please try the download again.': 'Bitte versuche den Download erneut.',
    'Downloads a detailed corridor around the complete Cyprus E4 for use without a connection.':
        'Lädt einen detaillierten Korridor entlang des gesamten Cyprus E4 für die Offline-Nutzung herunter.',
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
    'Trail information': 'Weginformationen',
    'Trail guide': 'Wanderführer',
    'App preferences': 'App-Einstellungen',
    'Know the signs. Prepare for the trail.':
        'Kenne die Markierungen. Bereite dich auf den Weg vor.',
    'Sign posting': 'Wegmarkierung',
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
    'EUROTREX': 'EUROTREX',
    'Co-funded by the European Union': 'Cofinanciado por la Unión Europea',
    'Republic of Cyprus': 'República de Chipre',
    'Crete E4': 'Crete E4',
    'Peloponnese E4': 'Peloponeso E4',
    'Settings': 'Ajustes',
    'TRAIL LIBRARY': 'BIBLIOTECA DE RUTAS',
    'Explore trails': 'Explorar rutas',
    'Choose a trail to view its stages and maps.':
        'Elige una ruta para ver sus etapas y mapas.',
    'Current trails': 'Rutas actuales',
    'available': 'disponible',
    'LONG DISTANCE': 'GRAN RECORRIDO',
    'A long-distance journey linking the coast, forests and Troodos mountains.':
        'Una travesía de larga distancia que une la costa, los bosques y las montañas de Troodos.',
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
    'Cyprus E4': 'Cyprus E4',
    'Pafos Airport': 'Aeropuerto de Pafos',
    'Larnaka Airport': 'Aeropuerto de Larnaka',
    'Distance': 'Distancia',
    'Stages': 'Etapas',
    'High point': 'Punto más alto',
    'Route': 'Ruta',
    'Filter': 'Filtrar',
    'Filter by services': 'Filtrar por servicios',
    'Stages must offer every selected service.':
        'Las etapas deben ofrecer todos los servicios seleccionados.',
    'Clear': 'Limpiar',
    'Apply filters': 'Aplicar filtros',
    'No stages match these services.':
        'Ninguna etapa coincide con estos servicios.',
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
    'Refresh elevation data': 'Actualizar datos de desnivel',
    'No elevation data is available.': 'No hay datos de desnivel.',
    'Could not download the elevation profile.':
        'No se pudo descargar el perfil de desnivel.',
    'Zoom out': 'Alejar',
    'Zoom in': 'Acercar',
    'Reset elevation view': 'Restablecer vista de desnivel',
    'Hide stages': 'Ocultar etapas',
    'Show stages': 'Mostrar etapas',
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
    'h': 'h',
    'min': 'min',
    'Preparing the offline elevation profile…':
        'Preparando el perfil sin conexión…',
    'Download profile': 'Descargar perfil',
    'Close stage summary': 'Cerrar resumen de etapa',
    'Stage': 'Etapa',
    'Start point': 'Punto de inicio',
    'Finish point': 'Punto final',
    'From': 'Desde',
    'Stage length': 'Longitud de etapa',
    'Altitude': 'Altitud',
    'Services': 'Servicios',
    'No services recorded for this stage.':
        'No hay servicios registrados para esta etapa.',
    'Trail position': 'Posición en la ruta',
    'Following the Cyprus E4': 'Siguiendo la Cyprus E4',
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
    'Download Cyprus E4 to browse its stages without a connection.':
        'Descarga Cyprus E4 para ver sus etapas sin conexión.',
    'Download trail': 'Descargar ruta',
    'Lodging': 'Alojamiento',
    'Book accommodation': 'Reservar alojamiento',
    'Accommodation booking': 'Reserva de alojamiento',
    'Coming soon': 'Próximamente',
    'Camping': 'Camping',
    'Food': 'Comida',
    'Groceries': 'Comestibles',
    'Drinking water': 'Agua potable',
    'Non-drinking water': 'Agua no potable',
    'Toilets': 'Aseos',
    'Medical': 'Asistencia médica',
    'Pharmacy': 'Farmacia',
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
    'Last updated': 'Última actualización',
    'Not available': 'No disponible',
    'Trail map available offline': 'Mapa de la ruta disponible sin conexión',
    'Download interrupted': 'Descarga interrumpida',
    'Take the map offline': 'Guardar el mapa sin conexión',
    'Remove offline map': 'Eliminar mapa sin conexión',
    'Try again': 'Intentar de nuevo',
    'Cancel': 'Cancelar',
    'Remove': 'Eliminar',
    'Remove offline map?': '¿Eliminar el mapa sin conexión?',
    'Show the whole trail': 'Mostrar toda la ruta',
    'Start': 'Inicio',
    'Finish': 'Final',
    'Selected stage': 'Etapa seleccionada',
    'Other stages': 'Otras etapas',
    'My location': 'Mi ubicación',
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
    'The detailed Cyprus E4 map is stored on this device.':
        'El mapa detallado de la Cyprus E4 está guardado en este dispositivo.',
    'Please try the download again.': 'Vuelve a intentar la descarga.',
    'Downloads a detailed corridor around the complete Cyprus E4 for use without a connection.':
        'Descarga un corredor detallado de toda la Cyprus E4 para usarlo sin conexión.',
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
    'Trail information': 'Información de la ruta',
    'Trail guide': 'Guía de la ruta',
    'App preferences': 'Preferencias de la aplicación',
    'Know the signs. Prepare for the trail.':
        'Conoce las señales. Prepárate para la ruta.',
    'Sign posting': 'Señalización',
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
