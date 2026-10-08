import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';

class ReportDraft {
  ReportDraft({
    required this.id,
    required this.trailId,
    required this.createdAt,
    this.stageId,
    this.description = '',
    this.category = 'signpost',
    this.passability = 'unsure',
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.locationSource = 'gps',
    this.contactEmail = '',
    this.photos = const [],
    this.state = 'draft',
    this.error = '',
    this.ownerUid,
    this.appVersion = '',
    this.remoteStatus,
    this.locationConfirmed = false,
  });
  final String id, trailId;
  final DateTime createdAt;
  String? stageId, ownerUid, remoteStatus;
  String description, category, passability, locationSource, contactEmail;
  String state, error, appVersion;
  double? latitude, longitude, accuracyM;
  bool locationConfirmed;
  List<String> photos;
  bool get editable => state == 'draft';
  bool get valid =>
      description.trim().isNotEmpty &&
      description.trim().length <= 500 &&
      latitude != null &&
      longitude != null &&
      locationConfirmed &&
      photos.length <= 3 &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180 &&
      (contactEmail.trim().isEmpty ||
          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contactEmail.trim()));
  Map<String, dynamic> toJson() => {
    'id': id,
    'trailId': trailId,
    'stageId': stageId,
    'createdAt': createdAt.toIso8601String(),
    'description': description,
    'category': category,
    'passability': passability,
    'latitude': latitude,
    'longitude': longitude,
    'accuracyM': accuracyM,
    'locationSource': locationSource,
    'contactEmail': contactEmail,
    'photos': photos,
    'state': state,
    'error': error,
    'ownerUid': ownerUid,
    'appVersion': appVersion,
    'remoteStatus': remoteStatus,
    'locationConfirmed': locationConfirmed,
  };
  factory ReportDraft.fromJson(Map<String, dynamic> j) => ReportDraft(
    id: j['id'],
    trailId: j['trailId'],
    stageId: j['stageId'],
    createdAt: DateTime.parse(j['createdAt']),
    description: j['description'],
    category: j['category'],
    passability: j['passability'],
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    accuracyM: (j['accuracyM'] as num?)?.toDouble(),
    locationSource: j['locationSource'],
    contactEmail: j['contactEmail'],
    photos: List<String>.from(j['photos']),
    state: j['state'],
    error: j['error'],
    ownerUid: j['ownerUid'],
    appVersion: j['appVersion'],
    remoteStatus: j['remoteStatus'],
    locationConfirmed: j['locationConfirmed'] == true,
  );
  Map<String, dynamic> submission() => {
    'reportId': id,
    'trailId': trailId,
    'stageId': stageId,
    'description': description.trim(),
    'category': category,
    'passability': passability,
    'latitude': latitude,
    'longitude': longitude,
    'accuracyM': accuracyM,
    'locationSource': locationSource,
    'contactEmail': contactEmail.trim(),
    'observedAtMs': createdAt.millisecondsSinceEpoch,
    'appVersion': appVersion,
    'photoIds': [for (var i = 0; i < photos.length; i++) 'photo_$i'],
  };
}

class ReportStore {
  ReportStore(this.database);
  final AppDatabase database;
  Future<Database> get _db async {
    final db = await database.database;
    await db.execute(
      'CREATE TABLE IF NOT EXISTS trail_report_drafts (id TEXT PRIMARY KEY, created_at TEXT NOT NULL, payload TEXT NOT NULL)',
    );
    return db;
  }

  Future<List<ReportDraft>> all() async => [
    for (final row in await (await _db).query(
      'trail_report_drafts',
      orderBy: 'created_at DESC',
    ))
      ReportDraft.fromJson(jsonDecode(row['payload'] as String)),
  ];
  Future<void> save(ReportDraft draft) async {
    await (await _db).insert('trail_report_drafts', {
      'id': draft.id,
      'created_at': draft.createdAt.toIso8601String(),
      'payload': jsonEncode(draft.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(ReportDraft draft) async {
    await (await _db).delete(
      'trail_report_drafts',
      where: 'id = ?',
      whereArgs: [draft.id],
    );
    for (final path in draft.photos) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
