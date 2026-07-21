import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/stages/domain/stage.dart';
import '../../features/elevation/domain/route_point.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get database async {
    return _database ??= await openDatabase(
      p.join(await getDatabasesPath(), 'monk.db'),
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
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
        await db.execute(
          'CREATE INDEX stages_trail_sequence '
          'ON stages (trail_id, sequence DESC)',
        );
        await _createRoutePointsTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createRoutePointsTable(db);
        if (oldVersion < 3) await _createSettingsTable(db);
      },
    );
  }

  Future<List<RoutePoint>> readRoutePoints(String trailId) async {
    final db = await database;
    final rows = await db.query(
      'route_points',
      where: 'trail_id = ?',
      whereArgs: [trailId],
      orderBy: 'point_index ASC',
    );
    return rows
        .map(
          (row) => RoutePoint(
            pointIndex: row['point_index']! as int,
            lat: (row['lat']! as num).toDouble(),
            lng: (row['lng']! as num).toDouble(),
            altitudeM: (row['altitude_m']! as num).toDouble(),
            distanceKm: (row['distance_km']! as num).toDouble(),
            reverseDistanceKm: (row['reverse_distance_km']! as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> replaceRoutePoints(
    String trailId,
    List<RoutePoint> points,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'route_points',
        where: 'trail_id = ?',
        whereArgs: [trailId],
      );
      const batchSize = 500;
      for (var start = 0; start < points.length; start += batchSize) {
        final batch = txn.batch();
        final end = (start + batchSize).clamp(0, points.length);
        for (final point in points.sublist(start, end)) {
          batch.insert('route_points', {
            'trail_id': trailId,
            'point_index': point.pointIndex,
            'lat': point.lat,
            'lng': point.lng,
            'altitude_m': point.altitudeM,
            'distance_km': point.distanceKm,
            'reverse_distance_km': point.reverseDistanceKm,
          });
        }
        await batch.commit(noResult: true);
      }
    });
  }

  static Future<void> _createRoutePointsTable(Database db) async {
    await db.execute('''
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
    await db.execute(
      'CREATE INDEX route_points_trail_distance '
      'ON route_points (trail_id, distance_km)',
    );
  }

  static Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<Map<String, String>> readSettings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }

  Future<void> writeSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TrailStage>> readStages(String trailId) async {
    final db = await database;
    final rows = await db.query(
      'stages',
      where: 'trail_id = ?',
      whereArgs: [trailId],
      orderBy: 'sequence DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> replaceStages(String trailId, List<TrailStage> stages) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('stages', where: 'trail_id = ?', whereArgs: [trailId]);
      final batch = txn.batch();
      for (final stage in stages) {
        batch.insert('stages', {
          'id': stage.id,
          'trail_id': trailId,
          'sequence': stage.sequence,
          'name': stage.name,
          'accumulated_distance_km': stage.accumulatedDistanceKm,
          'segment_length_km': stage.segmentLengthKm,
          'altitude_m': stage.altitudeM,
          'services_json': jsonEncode(stage.services),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  TrailStage _fromRow(Map<String, Object?> row) {
    return TrailStage(
      id: row['id']! as String,
      sequence: row['sequence']! as int,
      name: row['name']! as String,
      accumulatedDistanceKm: (row['accumulated_distance_km'] as num?)
          ?.toDouble(),
      segmentLengthKm: (row['segment_length_km'] as num?)?.toDouble(),
      altitudeM: (row['altitude_m'] as num?)?.toDouble(),
      services:
          (jsonDecode(row['services_json']! as String) as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, value == true)),
    );
  }
}
