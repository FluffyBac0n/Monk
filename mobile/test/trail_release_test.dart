import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/core/database/trail_release_repository.dart';

void main() {
  test(
    'verification is tied to the release; legacy approvals do not establish it',
    () {
      final manifest = <String, dynamic>{
        'revisionId': 'revision',
        'payloadHash': 'hash',
        'sourceType': 'community',
        'verifyingOrganisationName': 'EuroTrex',
      };
      expect(releaseProvenance(manifest)['organisationVerified'], false);
      manifest['verification'] = {
        'status': 'verified',
        'organisationId': 'member',
        'organisationName': 'Responsible member',
        'revisionId': 'revision',
        'payloadHash': 'hash',
        'verifiedAt': Timestamp.fromMillisecondsSinceEpoch(1000),
        'country': 'Cyprus',
        'scope': 'National section',
      };
      final metadata = releaseProvenance(manifest);
      expect(metadata['organisationVerified'], true);
      expect(metadata['sourceType'], 'community');
      expect(metadata['verifiedBy'], 'Responsible member');
      expect(metadata['verifiedAtMs'], 1000);
      manifest['payloadHash'] = 'different';
      expect(releaseProvenance(manifest)['organisationVerified'], false);
    },
  );
  late Directory directory;
  late AppDatabase database;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('eurotrex_release_');
    await databaseFactory.setDatabasesPath(directory.path);
    database = AppDatabase();
  });
  tearDown(() async {
    await (await database.database).close();
    await directory.delete(recursive: true);
  });
  Future<void> seed(
    FakeFirebaseFirestore fs,
    String id, {
    int count = 2,
    String trail = 'test',
  }) async {
    final root = fs.collection('trails').doc(trail);
    await root.set({'publishedReleaseId': id});
    final r = root.collection('releases').doc(id);
    await r.set({
      'published': true,
      'pointStride': 5,
      'chunkCount': 1,
      'pointCount': count,
      'stageCount': 2,
    });
    await r.collection('routeChunks').doc('0').set({
      'chunkIndex': 0,
      'startPointIndex': 0,
      'endPointIndex': 1,
      'points': [35, 33, 100, 0, 1, 35, 33.01, 110, 1, 0],
    });
    for (final (stage, position) in [('start', 0), ('finish', 1)]) {
      await r.collection('stages').doc(stage).set({
        'sequence': position + 1,
        'name': stage,
        'accumulatedDistanceKm': position,
        'services': {'water': true},
      });
    }
  }

  test(
    'complete releases activate together, failed downloads preserve old data and rollback restores',
    () async {
      final fs = FakeFirebaseFirestore();
      final repository = TrailReleaseRepository(database, fs);
      await seed(fs, 'first');
      final first = await repository.sync('test');
      expect(first!.releaseId, 'first');
      expect((await database.readSettings())['trailRelease:test'], 'first');
      expect(await database.readStages('test'), hasLength(2));
      await seed(fs, 'broken', count: 3);
      await expectLater(repository.sync('test'), throwsFormatException);
      expect((await database.readSettings())['trailRelease:test'], 'first');
      expect((await database.readRoutePoints('test')).last.altitudeM, 110);
      await seed(fs, 'second');
      expect((await repository.sync('test'))!.releaseId, 'second');
      await fs.doc('trails/test').update({'publishedReleaseId': 'first'});
      expect((await repository.sync('test'))!.releaseId, 'first');
      await seed(fs, 'other', trail: 'other');
      await repository.sync('other');
      expect(await database.readStages('other'), hasLength(2));
      expect(await database.readStages('test'), hasLength(2));
    },
  );
  test(
    'release decoding rejects missing, reordered and invalid coordinates',
    () {
      final m = {'pointStride': 5, 'chunkCount': 1, 'pointCount': 2};
      final chunk = {
        'chunkIndex': 0,
        'startPointIndex': 0,
        'endPointIndex': 1,
        'points': [35, 33, 100, 0, 1, 35, 33.01, 110, 1, 0],
      };
      expect(decodeReleasePoints(m, [chunk]), hasLength(2));
      expect(() => decodeReleasePoints(m, []), throwsFormatException);
      expect(
        () => decodeReleasePoints(m, [
          {...chunk, 'chunkIndex': 1},
        ]),
        throwsFormatException,
      );
      expect(
        () => decodeReleasePoints(m, [
          {
            ...chunk,
            'points': [100, 33, 100, 0, 1, 35, 33.01, 110, 1, 0],
          },
        ]),
        throwsFormatException,
      );
    },
  );
}
