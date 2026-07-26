import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monk_mobile/features/accommodation/data/lodging_repository.dart';
import 'package:monk_mobile/features/accommodation/domain/lodging.dart';
import 'package:monk_mobile/features/accommodation/presentation/accommodation_controller.dart';

void main() {
  group('Lodging.fromFirestore', () {
    test('parses the authoritative lodging fields and nested contact', () {
      final lodging = Lodging.fromFirestore('forest-inn', {
        'stageId': '42-forest-stage',
        'stageSequence': 42,
        'stageName': 'Forest stage',
        'name': ' Forest Inn ',
        'type': 'Hotel',
        'village': 'Platres',
        'minPriceText': '€75–€95',
        'priceMinEur': 75,
        'priceMaxEur': 95.5,
        'distanceFromTrailKm': 0.4,
        'address': '1 Mountain Road',
        'contact': {
          'phone': '+357 99123456',
          'whatsapp': '+357 99123456',
          'email': 'stay@example.com',
          'website': 'https://booking.example.com/forest-inn',
          'googleMapsUrl': 'https://maps.example.com/forest-inn',
        },
        'openingTime': '08:00',
        'closingTime': '22:00',
        'monthsOpen': 'Apr-Oct',
        'capacityPeople': 28,
        'checkInTime': '14:00',
        'checkOutTime': '11:00',
      });

      expect(lodging.id, 'forest-inn');
      expect(lodging.stageId, '42-forest-stage');
      expect(lodging.stageSequence, 42);
      expect(lodging.stageName, 'Forest stage');
      expect(lodging.name, 'Forest Inn');
      expect(lodging.type, 'Hotel');
      expect(lodging.village, 'Platres');
      expect(lodging.minPriceText, '€75–€95');
      expect(lodging.priceMinEur, 75);
      expect(lodging.priceMaxEur, 95.5);
      expect(lodging.distanceFromTrailKm, 0.4);
      expect(lodging.address, '1 Mountain Road');
      expect(lodging.phone, '+357 99123456');
      expect(lodging.whatsapp, '+357 99123456');
      expect(lodging.email, 'stay@example.com');
      expect(lodging.website, 'https://booking.example.com/forest-inn');
      expect(lodging.googleMapsUrl, 'https://maps.example.com/forest-inn');
      expect(lodging.openingTime, '08:00');
      expect(lodging.closingTime, '22:00');
      expect(lodging.monthsOpen, 'Apr-Oct');
      expect(lodging.capacityPeople, 28);
      expect(lodging.checkInTime, '14:00');
      expect(lodging.checkOutTime, '11:00');
      expect(
        lodging.bookingUri,
        Uri.parse('https://booking.example.com/forest-inn'),
      );
      expect(lodging.mapsUri, Uri.parse('https://maps.example.com/forest-inn'));
    });

    test('keeps absent and malformed optional data nullable', () {
      final lodging = Lodging.fromFirestore('sparse', {
        'name': ' ',
        'priceMinEur': <String, Object?>{},
        'capacityPeople': true,
        'contact': 'not-a-map',
      });

      expect(lodging.name, isNull);
      expect(lodging.priceMinEur, isNull);
      expect(lodging.capacityPeople, isNull);
      expect(lodging.phone, isNull);
      expect(lodging.bookingUri, isNull);
      expect(lodging.mapsUri, isNull);
    });

    test('ignores non-finite numeric values', () {
      final lodging = Lodging.fromFirestore('non-finite', {
        'stageSequence': double.infinity,
        'priceMinEur': double.nan,
        'priceMaxEur': double.infinity,
        'distanceFromTrailKm': '-Infinity',
        'capacityPeople': double.nan,
      });

      expect(lodging.stageSequence, isNull);
      expect(lodging.priceMinEur, isNull);
      expect(lodging.priceMaxEur, isNull);
      expect(lodging.distanceFromTrailKm, isNull);
      expect(lodging.capacityPeople, isNull);
    });

    test('only exposes safe absolute HTTP booking and maps URLs', () {
      for (final url in [
        'booking.example.com/inn',
        '/relative-booking-page',
        'mailto:stay@example.com',
        'javascript:alert(1)',
      ]) {
        final lodging = Lodging.fromFirestore('unsafe', {
          'contact': {'website': url, 'googleMapsUrl': url},
        });

        expect(lodging.bookingUri, isNull, reason: url);
        expect(lodging.mapsUri, isNull, reason: url);
      }

      final lodging = Lodging.fromFirestore('safe', {
        'contact': {
          'website': 'http://booking.example.com/inn',
          'googleMapsUrl': 'https://maps.example.com/inn',
        },
      });
      expect(lodging.bookingUri, isNotNull);
      expect(lodging.mapsUri, isNotNull);
    });
  });

  test('sorts by trail distance, then name, with missing distances last', () {
    const lodgings = [
      Lodging(id: 'unknown', name: 'Nearby but unknown'),
      Lodging(id: 'zeta', name: 'Zeta Inn', distanceFromTrailKm: 0.8),
      Lodging(id: 'alpha', name: 'Alpha Inn', distanceFromTrailKm: 0.8),
      Lodging(id: 'closest', name: 'Closest', distanceFromTrailKm: 0.1),
    ];

    final sorted = sortLodgingsForDisplay(lodgings);

    expect(sorted.map((lodging) => lodging.id), [
      'closest',
      'alpha',
      'zeta',
      'unknown',
    ]);
    expect(lodgings.first.id, 'unknown');
  });

  test('stage provider delegates through the injectable repository', () async {
    final repository = _RecordingLodgingRepository();
    final container = ProviderContainer(
      overrides: [lodgingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final lodgings = await container.read(
      lodgingsForStageProvider('42-forest-stage').future,
    );

    expect(lodgings.single.id, 'result');
    expect(repository.trailId, 'cyprus-e4');
    expect(repository.stageId, '42-forest-stage');
  });
}

class _RecordingLodgingRepository implements LodgingRepository {
  String? trailId;
  String? stageId;

  @override
  Future<List<Lodging>> loadForStage({
    required String trailId,
    required String stageId,
  }) async {
    this.trailId = trailId;
    this.stageId = stageId;
    return const [Lodging(id: 'result')];
  }
}
