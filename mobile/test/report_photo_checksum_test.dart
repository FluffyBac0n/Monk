import 'dart:io';
import 'package:eurotrex/features/reports/data/report_photo_checksum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('report-checksum-'),
  );
  tearDown(() async => directory.delete(recursive: true));

  test(
    'hashes the actual saved bytes using the standard MD5 encoding',
    () async {
      final file = await File(
        '${directory.path}/photo.jpg',
      ).writeAsBytes([97, 98, 99]);
      final checksum = await ReportPhotoChecksum.fromFile('photo_0', file);
      expect(checksum.toJson(), {
        'id': 'photo_0',
        'md5Hash': 'kAFQmDzST7DWlj99KOF/cg==',
        'byteLength': 3,
      });
      expect(await file.readAsBytes(), [97, 98, 99]);
    },
  );

  test(
    'a changed or truncated original produces a different manifest on retry',
    () async {
      final file = await File(
        '${directory.path}/photo.jpg',
      ).writeAsBytes(List.filled(200000, 42));
      final original = await ReportPhotoChecksum.fromFile('photo_0', file);
      expect(original.byteLength, 200000);
      await file.writeAsBytes(List.filled(199999, 42));
      final truncated = await ReportPhotoChecksum.fromFile('photo_0', file);
      expect(truncated.byteLength, 199999);
      expect(truncated.md5Hash, isNot(original.md5Hash));
      await file.writeAsBytes(List.filled(200000, 43));
      final changed = await ReportPhotoChecksum.fromFile('photo_0', file);
      expect(changed.byteLength, original.byteLength);
      expect(changed.md5Hash, isNot(original.md5Hash));
    },
  );

  test('a missing original cannot silently produce a checksum', () async {
    await expectLater(
      ReportPhotoChecksum.fromFile(
        'photo_0',
        File('${directory.path}/missing.jpg'),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
