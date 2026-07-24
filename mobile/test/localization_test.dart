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
    expect(german.t('Estimated walking time'), 'Geschätzte Gehzeit');
    expect(german.t('Selected stage'), 'Ausgewählte Etappe');

    expect(spanish.t('EUROTREX'), 'EUROTREX');
    expect(
      spanish.t('Co-funded by the European Union'),
      'Cofinanciado por la Unión Europea',
    );
    expect(spanish.t('Republic of Cyprus'), 'República de Chipre');
    expect(spanish.t('Crete E4'), 'Crete E4');
    expect(spanish.t('Peloponnese E4'), 'Peloponeso E4');
    expect(spanish.t('Offline access'), 'Acceso sin conexión');
    expect(spanish.t('Estimated walking time'), 'Tiempo estimado de caminata');
    expect(spanish.t('Selected stage'), 'Etapa seleccionada');
  });
}
