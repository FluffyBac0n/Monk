import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/features/accommodation/data/lodging_repository.dart';
import 'package:eurotrex/features/detours/data/detour_repository.dart';
import 'package:eurotrex/features/detours/domain/trail_detour.dart';
import 'package:eurotrex/features/elevation/data/elevation_repository.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/excursions/data/excursion_repository.dart';
import 'package:eurotrex/features/excursions/domain/trail_excursion.dart';
import 'package:eurotrex/features/stages/data/stage_repository.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';

void main() {
  group('StageRepository', () {
    test('syncs stages in route order and replaces the offline copy', () async {
      final firestore = FakeFirebaseFirestore();
      final database = _RecordingAppDatabase();
      final stages = firestore
          .collection('trails')
          .doc('cyprus-e4')
          .collection('stages');
      await stages.doc('finish').set({
        'sequence': 1,
        'name': 'Finish',
        'accumulatedDistanceKm': 10,
        'services': <String, bool>{},
      });
      await stages.doc('start').set({
        'sequence': 2,
        'name': 'Start',
        'accumulatedDistanceKm': 0,
        'services': {'lodging': true},
      });

      final result = await StageRepository(
        database: database,
        firestore: firestore,
      ).sync('cyprus-e4');

      expect(result.map((stage) => stage.id), ['start', 'finish']);
      expect(database.replacedStageTrailId, 'cyprus-e4');
      expect(database.replacedStages, same(result));
      expect(result.first.services['lodging'], isTrue);
    });

    test('loads the offline copy and rejects sync without Firebase', () async {
      final database = _RecordingAppDatabase()
        ..localStages = const [
          TrailStage(id: 'offline', sequence: 1, name: 'Offline', services: {}),
        ];
      final repository = StageRepository(database: database);

      expect((await repository.loadLocal('cyprus-e4')).single.id, 'offline');
      expect(database.readStageTrailId, 'cyprus-e4');
      await expectLater(
        repository.sync('cyprus-e4'),
        throwsA(isA<FirebaseNotConfiguredException>()),
      );
    });
  });

  group('ElevationRepository', () {
    test('syncs ordered route chunks using metadata stride', () async {
      final firestore = FakeFirebaseFirestore();
      final database = _RecordingAppDatabase();
      final trail = firestore.collection('trails').doc('cyprus-e4');
      await trail.collection('routeMetadata').doc('main').set({
        'pointStride': 6,
      });
      await trail.collection('routeChunks').doc('later').set({
        'chunkIndex': 1,
        'points': [34.8, 32.5, 120, 1.5, 8.5, 999],
      });
      await trail.collection('routeChunks').doc('first').set({
        'chunkIndex': 0,
        'points': [34.7, 32.4, 10, 0, 10, 999],
      });

      final result = await ElevationRepository(
        database: database,
        firestore: firestore,
      ).sync('cyprus-e4');

      expect(result.map((point) => point.pointIndex), [0, 1]);
      expect(result.map((point) => point.distanceKm), [0, 1.5]);
      expect(database.replacedRouteTrailId, 'cyprus-e4');
      expect(database.replacedRoutePoints, same(result));
    });

    test('loads cached points and validates remote metadata', () async {
      const cached = RoutePoint(
        pointIndex: 0,
        lat: 34.7,
        lng: 32.4,
        altitudeM: 10,
        distanceKm: 0,
        reverseDistanceKm: 10,
      );
      final database = _RecordingAppDatabase()
        ..localRoutePoints = const [cached];
      final repository = ElevationRepository(database: database);

      expect(await repository.loadLocal('cyprus-e4'), [cached]);
      expect(database.readRouteTrailId, 'cyprus-e4');
      await expectLater(
        repository.sync('cyprus-e4'),
        throwsA(isA<StateError>()),
      );

      final missingMetadata = ElevationRepository(
        database: database,
        firestore: FakeFirebaseFirestore(),
      );
      await expectLater(
        missingMetadata.sync('cyprus-e4'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Missing route metadata.',
          ),
        ),
      );
    });
  });

  group('FirestoreLodgingRepository', () {
    test('filters by stage and sorts by distance, name, then id', () async {
      final firestore = FakeFirebaseFirestore();
      final lodgings = firestore
          .collection('trails')
          .doc('cyprus-e4')
          .collection('lodgings');
      await lodgings.doc('z-near').set({
        'stageId': 'stage-a',
        'name': 'Zeta',
        'distanceFromTrailKm': 0.2,
      });
      await lodgings.doc('a-near').set({
        'stageId': 'stage-a',
        'name': 'Alpha',
        'distanceFromTrailKm': 0.2,
      });
      await lodgings.doc('far').set({
        'stageId': 'stage-a',
        'name': 'Far',
        'distanceFromTrailKm': 2,
      });
      await lodgings.doc('other').set({
        'stageId': 'stage-b',
        'name': 'Other stage',
        'distanceFromTrailKm': 0.1,
      });

      final repository = FirestoreLodgingRepository(firestore: firestore);

      expect(
        (await repository.loadForStage(
          trailId: 'cyprus-e4',
          stageId: 'stage-a',
        )).map((lodging) => lodging.id),
        ['a-near', 'z-near', 'far'],
      );
      expect(
        (await repository.loadForTrail(
          trailId: 'cyprus-e4',
        )).map((lodging) => lodging.id),
        ['other', 'a-near', 'z-near', 'far'],
      );
    });

    test('rejects reads without Firebase configuration', () async {
      const repository = FirestoreLodgingRepository();

      await expectLater(
        repository.loadForTrail(trailId: 'cyprus-e4'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.loadForStage(trailId: 'cyprus-e4', stageId: 'stage-a'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('FirestoreExcursionRepository', () {
    test('sorts summaries and assembles each ordered route', () async {
      final firestore = FakeFirebaseFirestore();
      final excursions = firestore
          .collection('trails')
          .doc('cyprus-e4')
          .collection('excursions');
      await excursions.doc('standalone').set({
        'anchorType': 'standalone',
        'anchorStageName': 'Zeta',
      });
      await excursions.doc('later').set({
        'mainTrailDistanceKm': 20,
        'anchorStageName': 'Later',
      });
      await excursions.doc('first').set({
        'mainTrailDistanceKm': 10,
        'anchorStageName': 'First',
        'pointStride': 5,
      });
      await excursions.doc('first').collection('routeChunks').doc('b').set({
        'chunkIndex': 1,
        'points': [34.8, 32.5, 20, 2, 0],
      });
      await excursions.doc('first').collection('routeChunks').doc('a').set({
        'chunkIndex': 0,
        'points': [34.7, 32.4, 10, 0, 2],
      });

      final repository = FirestoreExcursionRepository(firestore: firestore);
      final summaries = await repository.loadForTrail(trailId: 'cyprus-e4');
      final routes = await repository.loadRoutesForTrail(
        trailId: 'cyprus-e4',
        excursions: [summaries.first],
      );

      expect(summaries.map((item) => item.id), [
        'first',
        'later',
        'standalone',
      ]);
      expect(routes.single.excursion.id, 'first');
      expect(routes.single.points.map((point) => point.distanceKm), [0, 2]);
    });

    test('rejects reads without Firebase configuration', () async {
      const repository = FirestoreExcursionRepository();

      await expectLater(
        repository.loadForTrail(trailId: 'cyprus-e4'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.loadRoutesForTrail(
          trailId: 'cyprus-e4',
          excursions: const [],
        ),
        completes,
      );
      await expectLater(
        repository.loadRoutesForTrail(
          trailId: 'cyprus-e4',
          excursions: const [
            TrailExcursion(
              id: 'excursion',
              routeType: ExcursionRouteType.oneWay,
              anchorType: ExcursionAnchorType.stage,
              routeDistanceKm: 1,
              totalDistanceKm: 1,
              elevationUpM: 0,
              elevationDownM: 0,
              estimatedWalkingTimeMinutes: 10,
              pointStride: 5,
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('FirestoreDetourRepository', () {
    test('sorts summaries and assembles each ordered route', () async {
      final firestore = FakeFirebaseFirestore();
      final detours = firestore
          .collection('trails')
          .doc('cyprus-e4')
          .collection('detours');
      await detours.doc('unknown').set({'name': 'Zeta'});
      await detours.doc('later').set({
        'name': 'Later',
        'startConnection': {'mainTrailDistanceKm': 20},
      });
      await detours.doc('first').set({
        'name': 'First',
        'pointStride': 5,
        'startConnection': {'mainTrailDistanceKm': 10},
      });
      await detours.doc('first').collection('routeChunks').doc('b').set({
        'chunkIndex': 1,
        'points': [34.8, 32.5, 20, 2, 0],
      });
      await detours.doc('first').collection('routeChunks').doc('a').set({
        'chunkIndex': 0,
        'points': [34.7, 32.4, 10, 0, 2],
      });

      final repository = FirestoreDetourRepository(firestore: firestore);
      final summaries = await repository.loadForTrail(trailId: 'cyprus-e4');
      final routes = await repository.loadRoutesForTrail(
        trailId: 'cyprus-e4',
        detours: [summaries.first],
      );

      expect(summaries.map((item) => item.id), ['first', 'later', 'unknown']);
      expect(routes.single.detour.id, 'first');
      expect(routes.single.points.map((point) => point.distanceKm), [0, 2]);
    });

    test('rejects configured operations without Firebase', () async {
      const repository = FirestoreDetourRepository();

      await expectLater(
        repository.loadForTrail(trailId: 'cyprus-e4'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.loadRoutesForTrail(
          trailId: 'cyprus-e4',
          detours: const [
            TrailDetour(
              id: 'detour',
              name: 'Detour',
              routeDistanceKm: 1,
              elevationUpM: 0,
              elevationDownM: 0,
              estimatedWalkingTimeMinutes: 10,
              replacedMainTrailDistanceKm: 1,
              replacedElevationUpM: 0,
              replacedElevationDownM: 0,
              replacedEstimatedWalkingTimeMinutes: 10,
              distanceDifferenceKm: 0,
              estimatedWalkingTimeDifferenceMinutes: 0,
              averageDistanceFromTrailKm: 0,
              maximumDistanceFromTrailKm: 0,
              affectedStageIds: [],
              affectedStageSequences: [],
              affectedStageNames: [],
              pointStride: 5,
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _RecordingAppDatabase extends AppDatabase {
  List<TrailStage> localStages = const [];
  List<RoutePoint> localRoutePoints = const [];
  String? readStageTrailId;
  String? replacedStageTrailId;
  List<TrailStage>? replacedStages;
  String? readRouteTrailId;
  String? replacedRouteTrailId;
  List<RoutePoint>? replacedRoutePoints;

  @override
  Future<List<TrailStage>> readStages(String trailId) async {
    readStageTrailId = trailId;
    return localStages;
  }

  @override
  Future<void> replaceStages(String trailId, List<TrailStage> stages) async {
    replacedStageTrailId = trailId;
    replacedStages = stages;
  }

  @override
  Future<List<RoutePoint>> readRoutePoints(String trailId) async {
    readRouteTrailId = trailId;
    return localRoutePoints;
  }

  @override
  Future<void> replaceRoutePoints(
    String trailId,
    List<RoutePoint> points,
  ) async {
    replacedRouteTrailId = trailId;
    replacedRoutePoints = points;
  }
}
