import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/features/elevation/domain/route_point.dart';
import 'package:eurotrex/features/stages/domain/stage.dart';

void main() {
  late Directory databaseDirectory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'eurotrex_database_test_',
    );
    await databaseFactory.setDatabasesPath(databaseDirectory.path);
  });

  tearDown(() async {
    if (databaseDirectory.existsSync()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test(
    'persists settings and replaces only the requested trail data',
    () async {
      final appDatabase = AppDatabase();
      final database = await appDatabase.database;
      addTearDown(database.close);

      await appDatabase.writeSetting('languageCode', 'en');
      await appDatabase.writeSetting('measurementSystem', 'imperial');
      await appDatabase.writeSetting('languageCode', 'fr');
      expect(await appDatabase.readSettings(), {
        'languageCode': 'fr',
        'measurementSystem': 'imperial',
      });

      await appDatabase.replaceStages('cyprus-e4', const [
        TrailStage(
          id: 'one',
          sequence: 1,
          name: 'Finish',
          distanceFromPathKm: 0.7,
          accumulatedDistanceKm: 100,
          segmentLengthKm: 4,
          elevationUpM: 20,
          elevationDownM: 35,
          altitudeM: 10,
          services: {'lodging': true},
        ),
        TrailStage(
          id: 'three',
          sequence: 3,
          name: 'Start',
          distanceFromPathKm: 0.1,
          accumulatedDistanceKm: 0,
          segmentLengthKm: 0,
          services: {},
        ),
      ]);
      await appDatabase.replaceStages('crete-e4', const [
        TrailStage(id: 'crete', sequence: 1, name: 'Crete', services: {}),
      ]);

      final stages = await appDatabase.readStages('cyprus-e4');
      expect(stages.map((stage) => stage.id), ['three', 'one']);
      expect(stages.last.distanceFromPathKm, 0.7);
      expect(stages.last.elevationDownM, 35);
      expect(stages.last.services, {'lodging': true});

      await appDatabase.replaceStages('cyprus-e4', const [
        TrailStage(
          id: 'replacement',
          sequence: 2,
          name: 'Replacement',
          services: {},
        ),
      ]);
      expect(
        (await appDatabase.readStages('cyprus-e4')).single.id,
        'replacement',
      );
      expect((await appDatabase.readStages('crete-e4')).single.id, 'crete');

      final points = List.generate(
        501,
        (index) => RoutePoint(
          pointIndex: index,
          lat: 34 + index / 10000,
          lng: 32 + index / 10000,
          altitudeM: index.toDouble(),
          distanceKm: index / 10,
          reverseDistanceKm: (500 - index) / 10,
        ),
      ).reversed.toList();
      await appDatabase.replaceRoutePoints('cyprus-e4', points);
      await appDatabase.replaceRoutePoints('crete-e4', const [
        RoutePoint(
          pointIndex: 0,
          lat: 35,
          lng: 25,
          altitudeM: 100,
          distanceKm: 0,
          reverseDistanceKm: 0,
        ),
      ]);

      final storedPoints = await appDatabase.readRoutePoints('cyprus-e4');
      expect(storedPoints, hasLength(501));
      expect(storedPoints.first.pointIndex, 0);
      expect(storedPoints.last.pointIndex, 500);
      expect(storedPoints[250].distanceKm, 25);

      await appDatabase.replaceRoutePoints('cyprus-e4', [points.first]);
      expect(await appDatabase.readRoutePoints('cyprus-e4'), hasLength(1));
      expect(await appDatabase.readRoutePoints('crete-e4'), hasLength(1));
      expect(await database.getVersion(), AppDatabase.schemaVersion);
    },
  );

  test('migrates a version 3 offline database without losing stages', () async {
    final path = p.join(databaseDirectory.path, 'eurotrex.db');
    final legacyDatabase = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE stages (
              id TEXT PRIMARY KEY,
              trail_id TEXT NOT NULL,
              sequence INTEGER NOT NULL,
              name TEXT NOT NULL,
              accumulated_distance_km REAL,
              segment_length_km REAL,
              altitude_m REAL,
              services_json TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE route_points (
              trail_id TEXT NOT NULL,
              point_index INTEGER NOT NULL,
              lat REAL NOT NULL,
              lng REAL NOT NULL,
              altitude_m REAL NOT NULL,
              distance_km REAL NOT NULL,
              reverse_distance_km REAL NOT NULL,
              PRIMARY KEY (trail_id, point_index)
            )
          ''');
          await database.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await database.insert('stages', {
            'id': 'legacy',
            'trail_id': 'cyprus-e4',
            'sequence': 7,
            'name': 'Legacy stage',
            'accumulated_distance_km': 10.5,
            'segment_length_km': 2.5,
            'altitude_m': 300,
            'services_json': '{"drinkableWater":true}',
          });
        },
      ),
    );
    await legacyDatabase.close();

    final appDatabase = AppDatabase();
    final upgradedDatabase = await appDatabase.database;
    addTearDown(upgradedDatabase.close);

    final stages = await appDatabase.readStages('cyprus-e4');
    expect(stages, hasLength(1));
    expect(stages.single.id, 'legacy');
    expect(stages.single.elevationUpM, isNull);
    expect(stages.single.elevationDownM, isNull);
    expect(stages.single.distanceFromPathKm, isNull);
    expect(stages.single.services['drinkableWater'], isTrue);
    expect(await upgradedDatabase.getVersion(), AppDatabase.schemaVersion);
  });
}
