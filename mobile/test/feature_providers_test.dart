import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/features/detours/data/detour_repository.dart';
import 'package:eurotrex/features/detours/domain/trail_detour.dart';
import 'package:eurotrex/features/detours/presentation/detour_controller.dart';
import 'package:eurotrex/features/excursions/data/excursion_repository.dart';
import 'package:eurotrex/features/excursions/domain/trail_excursion.dart';
import 'package:eurotrex/features/excursions/presentation/excursion_controller.dart';
import 'package:eurotrex/features/trail/domain/trail_direction.dart';
import 'package:eurotrex/features/trail/presentation/trail_direction_controller.dart';

void main() {
  test(
    'excursion providers load summaries before their route geometry',
    () async {
      final repository = _RecordingExcursionRepository();
      final container = ProviderContainer(
        overrides: [excursionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final routes = await container.read(
        excursionRoutesForTrailProvider.future,
      );

      expect(routes.single.excursion.id, 'excursion');
      expect(repository.calls, ['summaries:cyprus-e4', 'routes:cyprus-e4']);
      expect(repository.receivedExcursions, const [_excursion]);
    },
  );

  test('detour providers load summaries before their route geometry', () async {
    final repository = _RecordingDetourRepository();
    final container = ProviderContainer(
      overrides: [detourRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final routes = await container.read(detourRoutesForTrailProvider.future);

    expect(routes.single.detour.id, 'detour');
    expect(repository.calls, ['summaries:cyprus-e4', 'routes:cyprus-e4']);
    expect(repository.receivedDetours, const [_detour]);
  });

  test('trail direction controller toggles and restores both directions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(trailDirectionProvider),
      TrailDirection.pafosToLarnaka,
    );
    container.read(trailDirectionProvider.notifier).toggle();
    expect(
      container.read(trailDirectionProvider),
      TrailDirection.larnakaToPafos,
    );
    container.read(trailDirectionProvider.notifier).toggle();
    expect(
      container.read(trailDirectionProvider),
      TrailDirection.pafosToLarnaka,
    );
  });
}

const _excursion = TrailExcursion(
  id: 'excursion',
  routeType: ExcursionRouteType.outAndBack,
  anchorType: ExcursionAnchorType.stage,
  routeDistanceKm: 1,
  totalDistanceKm: 2,
  elevationUpM: 20,
  elevationDownM: 20,
  estimatedWalkingTimeMinutes: 30,
  pointStride: 5,
);

const _detour = TrailDetour(
  id: 'detour',
  name: 'Detour',
  routeDistanceKm: 5,
  elevationUpM: 100,
  elevationDownM: 100,
  estimatedWalkingTimeMinutes: 90,
  replacedMainTrailDistanceKm: 4,
  replacedElevationUpM: 80,
  replacedElevationDownM: 80,
  replacedEstimatedWalkingTimeMinutes: 75,
  distanceDifferenceKm: 1,
  estimatedWalkingTimeDifferenceMinutes: 15,
  averageDistanceFromTrailKm: 0.4,
  maximumDistanceFromTrailKm: 0.8,
  affectedStageIds: ['stage'],
  affectedStageSequences: [1],
  affectedStageNames: ['Stage'],
  pointStride: 5,
);

class _RecordingExcursionRepository implements ExcursionRepository {
  final calls = <String>[];
  List<TrailExcursion>? receivedExcursions;

  @override
  Future<List<TrailExcursion>> loadForTrail({required String trailId}) async {
    calls.add('summaries:$trailId');
    return const [_excursion];
  }

  @override
  Future<List<TrailExcursionRoute>> loadRoutesForTrail({
    required String trailId,
    required List<TrailExcursion> excursions,
  }) async {
    calls.add('routes:$trailId');
    receivedExcursions = excursions;
    return [
      TrailExcursionRoute(excursion: excursions.single, points: const []),
    ];
  }
}

class _RecordingDetourRepository implements DetourRepository {
  final calls = <String>[];
  List<TrailDetour>? receivedDetours;

  @override
  Future<List<TrailDetour>> loadForTrail({required String trailId}) async {
    calls.add('summaries:$trailId');
    return const [_detour];
  }

  @override
  Future<List<TrailDetourRoute>> loadRoutesForTrail({
    required String trailId,
    required List<TrailDetour> detours,
  }) async {
    calls.add('routes:$trailId');
    receivedDetours = detours;
    return [TrailDetourRoute(detour: detours.single, points: const [])];
  }
}
