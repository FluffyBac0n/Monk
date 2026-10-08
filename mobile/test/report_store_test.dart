import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/features/reports/data/report_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MemoryDatabase extends AppDatabase {
  final Future<Database> connection = databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
  );
  @override
  Future<Database> get database => connection;
}

void main() {
  sqfliteFfiInit();
  test(
    'offline draft persists coordinates, trail identity and pending photo paths',
    () async {
      final db = MemoryDatabase();
      final store = ReportStore(db);
      final draft = ReportDraft(
        id: 'report1',
        trailId: 'cyprus-e4',
        createdAt: DateTime.utc(2026, 10, 6),
        description: 'Broken sign',
        latitude: 34.89,
        longitude: 32.87,
        locationConfirmed: true,
        photos: ['/saved/photo.jpg'],
        state: 'queued',
      );
      await store.save(draft);
      final restored = (await ReportStore(db).all()).single;
      expect(restored.valid, isTrue);
      expect(restored.trailId, 'cyprus-e4');
      expect(restored.photos, ['/saved/photo.jpg']);
      expect(restored.state, 'queued');
      expect(restored.submission()['reportId'], 'report1');
      expect(restored.submission()['photoIds'], ['photo_0']);
      restored.state = 'sent';
      restored.remoteStatus = 'reviewed';
      await store.save(restored);
      expect((await store.all()).single.remoteStatus, 'reviewed');
      await (await db.database).close();
    },
  );
  test('a location must be confirmed and description/email validated', () {
    final d = ReportDraft(
      id: 'id',
      trailId: 'cyprus-e4',
      createdAt: DateTime.now(),
      description: 'Fallen rock',
      latitude: 34,
      longitude: 32,
    );
    expect(d.valid, isFalse);
    d.locationConfirmed = true;
    expect(d.valid, isTrue);
    d.contactEmail = 'bad';
    expect(d.valid, isFalse);
    d.contactEmail = '';
    d.description = 'x' * 501;
    expect(d.valid, isFalse);
  });
}
