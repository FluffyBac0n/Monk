import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Firebase exposes object MD5 hashes as base64. This is an integrity check,
/// not an authentication mechanism; access remains enforced by Firebase.
class ReportPhotoChecksum {
  const ReportPhotoChecksum({
    required this.id,
    required this.md5Hash,
    required this.byteLength,
  });

  final String id, md5Hash;
  final int byteLength;

  static Future<ReportPhotoChecksum> fromFile(String id, File file) async {
    var byteLength = 0;
    final digest = await md5
        .bind(
          file.openRead().map((bytes) {
            byteLength += bytes.length;
            return bytes;
          }),
        )
        .first;
    return ReportPhotoChecksum(
      id: id,
      md5Hash: base64Encode(digest.bytes),
      byteLength: byteLength,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'md5Hash': md5Hash,
    'byteLength': byteLength,
  };
}
