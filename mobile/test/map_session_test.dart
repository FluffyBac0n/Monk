import 'package:eurotrex/features/map/presentation/map_session.dart';
import 'package:eurotrex/features/map/presentation/map_background_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GPS updates never set zoom, tilt, bearing or layers', () {
    final first = mapGpsCameraUpdate(
      explicitFocus: true,
      latitude: 35,
      longitude: 33,
    )!;
    expect(first.center!.coordinates.lat, 35);
    expect(first.zoom, isNull);
    expect(first.pitch, isNull);
    expect(first.bearing, isNull);
    expect(first.padding, isNull);
    for (var i = 0; i < 5; i++) {
      expect(
        mapGpsCameraUpdate(
          explicitFocus: false,
          latitude: 35 + i / 1000,
          longitude: 33,
        ),
        isNull,
      );
    }
  });
  test(
    'map choices survive removal of the screen listener and are trail-specific',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = mapSessionProvider('cyprus-e4');
      final subscription = container.listen(provider, (_, _) {});
      final session = subscription.read();
      session.background = MapBackground.satelliteLabels;
      session.gpsEnabled = true;
      session.stagesVisible = true;
      session.lodgingsVisible = true;
      session.excursionsVisible = true;
      session.detoursVisible = true;
      subscription.close();
      await container.pump();
      final returned = container.read(provider);
      expect(identical(session, returned), isTrue);
      expect(returned.background, MapBackground.satelliteLabels);
      expect(
        returned.gpsEnabled &&
            returned.stagesVisible &&
            returned.lodgingsVisible &&
            returned.excursionsVisible &&
            returned.detoursVisible,
        isTrue,
      );
      expect(
        container.read(mapSessionProvider('crete-e4')).gpsEnabled,
        isFalse,
      );
    },
  );
}
