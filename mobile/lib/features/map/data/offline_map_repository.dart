import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../elevation/domain/route_point.dart';
import '../domain/offline_map_state.dart';

const cyprusE4OfflineRegionId = 'cyprus-e4-outdoors-v1';
const cyprusE4OfflineStyleUri = MapboxStyles.OUTDOORS;

typedef OfflineProgressCallback =
    void Function(double progress, int completedBytes);

class OfflineMapRepository {
  TileStore? _tileStore;
  OfflineManager? _offlineManager;

  Future<void> _initialize() async {
    _tileStore ??= await TileStore.createDefault();
    _offlineManager ??= await OfflineManager.create();
    _tileStore!.setDiskQuota(null);
  }

  Future<OfflineMapState> readStatus() async {
    await _initialize();
    final regions = await _tileStore!.allTileRegions();
    final styles = await _offlineManager!.allStylePacks();

    TileRegion? region;
    for (final candidate in regions) {
      if (candidate.id == cyprusE4OfflineRegionId) {
        region = candidate;
        break;
      }
    }
    StylePack? style;
    for (final candidate in styles) {
      if (candidate.styleURI == cyprusE4OfflineStyleUri) {
        style = candidate;
        break;
      }
    }

    final regionBytes = region?.completedResourceSize ?? 0;
    final styleBytes = style?.completedResourceSize ?? 0;
    final completedBytes = regionBytes + styleBytes;
    final regionComplete =
        region != null &&
        region.requiredResourceCount > 0 &&
        region.completedResourceCount >= region.requiredResourceCount;
    final styleComplete =
        style != null &&
        style.requiredResourceCount > 0 &&
        style.completedResourceCount >= style.requiredResourceCount;
    if (regionComplete && styleComplete) {
      return OfflineMapState.ready(completedBytes: completedBytes);
    }

    final required =
        (region?.requiredResourceCount ?? 0) +
        (style?.requiredResourceCount ?? 0);
    final completed =
        (region?.completedResourceCount ?? 0) +
        (style?.completedResourceCount ?? 0);
    return OfflineMapState.notDownloaded(
      progress: required == 0 ? 0 : (completed / required).clamp(0, 1),
      completedBytes: completedBytes,
    );
  }

  Future<OfflineMapState> download(
    List<RoutePoint> points, {
    required OfflineProgressCallback onProgress,
  }) async {
    if (points.isEmpty) {
      throw StateError('Route geometry is required for an offline download.');
    }
    await _initialize();

    var styleBytes = 0;
    await _offlineManager!.loadStylePack(
      cyprusE4OfflineStyleUri,
      StylePackLoadOptions(
        glyphsRasterizationMode:
            GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
        metadata: const {'trailId': 'cyprus-e4', 'version': 1},
        acceptExpired: true,
      ),
      (progress) {
        styleBytes = progress.completedResourceSize;
        final fraction = progress.requiredResourceCount == 0
            ? 0.0
            : progress.completedResourceCount / progress.requiredResourceCount;
        onProgress((fraction * 0.12).clamp(0, 0.12), styleBytes);
      },
    );
    onProgress(0.12, styleBytes);

    await _tileStore!.loadTileRegion(
      cyprusE4OfflineRegionId,
      TileRegionLoadOptions(
        geometry: buildOfflineCorridorGeometry(points),
        descriptorsOptions: [
          TilesetDescriptorOptions(
            styleURI: cyprusE4OfflineStyleUri,
            minZoom: 6,
            maxZoom: 15,
          ),
        ],
        metadata: const {
          'trailId': 'cyprus-e4',
          'version': 1,
          'coverage': 'route-corridor',
        },
        acceptExpired: true,
        networkRestriction: NetworkRestriction.NONE,
      ),
      (progress) {
        final fraction = progress.requiredResourceCount == 0
            ? 0.0
            : progress.completedResourceCount / progress.requiredResourceCount;
        onProgress(
          (0.12 + fraction * 0.88).clamp(0, 1),
          styleBytes + progress.completedResourceSize,
        );
      },
    );

    return readStatus();
  }

  Future<void> delete() async {
    await _initialize();
    final regions = await _tileStore!.allTileRegions();
    if (regions.any((region) => region.id == cyprusE4OfflineRegionId)) {
      await _tileStore!.removeRegion(cyprusE4OfflineRegionId);
    }
    final styles = await _offlineManager!.allStylePacks();
    if (styles.any((style) => style.styleURI == cyprusE4OfflineStyleUri)) {
      await _offlineManager!.removeStylePack(cyprusE4OfflineStyleUri);
    }
  }
}

Map<String?, Object?> buildOfflineCorridorGeometry(List<RoutePoint> points) {
  const sampleSpacingKm = 1.25;
  const latitudePadding = 0.018;
  const longitudePadding = 0.022;
  final sampled = <RoutePoint>[];
  var nextDistance = points.first.distanceKm;
  for (final point in points) {
    if (point.distanceKm >= nextDistance) {
      sampled.add(point);
      nextDistance = point.distanceKm + sampleSpacingKm;
    }
  }
  if (sampled.isEmpty || sampled.last.pointIndex != points.last.pointIndex) {
    sampled.add(points.last);
  }

  return <String?, Object?>{
    'type': 'MultiPolygon',
    'coordinates': [
      for (final point in sampled)
        [
          [
            [point.lng - longitudePadding, point.lat - latitudePadding],
            [point.lng + longitudePadding, point.lat - latitudePadding],
            [point.lng + longitudePadding, point.lat + latitudePadding],
            [point.lng - longitudePadding, point.lat + latitudePadding],
            [point.lng - longitudePadding, point.lat - latitudePadding],
          ],
        ],
    ],
  };
}
