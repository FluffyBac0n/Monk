import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/map/data/offline_map_repository.dart';
import 'package:eurotrex/features/map/domain/offline_map_state.dart';

void main() {
  test('builds a closed offline corridor covering the full route', () {
    const points = [
      RoutePoint(
        pointIndex: 0,
        lat: 34.70,
        lng: 32.40,
        altitudeM: 10,
        distanceKm: 0,
        reverseDistanceKm: 3,
      ),
      RoutePoint(
        pointIndex: 1,
        lat: 34.71,
        lng: 32.41,
        altitudeM: 20,
        distanceKm: 1.5,
        reverseDistanceKm: 1.5,
      ),
      RoutePoint(
        pointIndex: 2,
        lat: 34.72,
        lng: 32.42,
        altitudeM: 30,
        distanceKm: 3,
        reverseDistanceKm: 0,
      ),
    ];

    final geometry = buildOfflineCorridorGeometry(points);
    expect(geometry['type'], 'MultiPolygon');
    final polygons = geometry['coordinates']! as List<Object?>;
    expect(polygons, hasLength(3));

    final firstRing =
        ((polygons.first! as List<Object?>).first! as List<Object?>);
    expect(firstRing.first, firstRing.last);
    final lastRing =
        ((polygons.last! as List<Object?>).first! as List<Object?>);
    final lastCoordinate = lastRing[2]! as List<double>;
    expect(lastCoordinate.first, greaterThan(points.last.lng));
    expect(lastCoordinate.last, greaterThan(points.last.lat));
  });

  test('keeps the route endpoint when corridor sampling skips it', () {
    const points = [
      RoutePoint(
        pointIndex: 0,
        lat: 34.7,
        lng: 32.4,
        altitudeM: 10,
        distanceKm: 0,
        reverseDistanceKm: 0.5,
      ),
      RoutePoint(
        pointIndex: 1,
        lat: 34.71,
        lng: 32.41,
        altitudeM: 20,
        distanceKm: 0.5,
        reverseDistanceKm: 0,
      ),
    ];

    final polygons =
        buildOfflineCorridorGeometry(points)['coordinates']! as List<Object?>;
    expect(polygons, hasLength(2));
  });

  test('rejects an offline download without route geometry', () async {
    await expectLater(
      OfflineMapRepository().download(const [], onProgress: (_, _) {}),
      throwsA(isA<StateError>()),
    );
  });

  test('formats downloaded offline map sizes', () {
    expect(formatOfflineBytes(0), '0 B');
    expect(formatOfflineBytes(1536), '1.5 KB');
    expect(formatOfflineBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatOfflineBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
  });

  test('reads the offline map download timestamp from metadata', () {
    expect(
      parseOfflineMapDownloadedAt('2026-07-24T09:30:00.000Z'),
      DateTime.utc(2026, 7, 24, 9, 30),
    );
    expect(
      parseOfflineMapDownloadedAt(
        DateTime.utc(2026, 7, 24, 9, 30).millisecondsSinceEpoch,
      ),
      DateTime.utc(2026, 7, 24, 9, 30),
    );
    expect(parseOfflineMapDownloadedAt('not-a-date'), isNull);
    expect(parseOfflineMapDownloadedAt(Object()), isNull);
  });

  test('failed state retains interrupted download details', () {
    final downloadedAt = DateTime.utc(2026, 7, 24, 9, 30);
    final state = OfflineMapState.failed(
      'download failed',
      failure: OfflineMapFailure.download,
      progress: 0.42,
      completedBytes: 2048,
      downloadedAt: downloadedAt,
    );

    expect(state.isFailed, isTrue);
    expect(state.progress, 0.42);
    expect(state.completedBytes, 2048);
    expect(state.downloadedAt, downloadedAt);
    expect(state.failure, OfflineMapFailure.download);
  });
}
