import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'report_store.dart';

Uint8List _compress(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width * decoded.height > 24000000) {
    throw const FormatException('Unsupported photo.');
  }
  final oriented = img.bakeOrientation(decoded);
  final scaled = oriented.width >= oriented.height
      ? img.copyResize(
          oriented,
          width: oriented.width > 1800 ? 1800 : oriented.width,
        )
      : img.copyResize(
          oriented,
          height: oriented.height > 1800 ? 1800 : oriented.height,
        );
  // Reconstruct pixels so EXIF, camera identifiers and hidden GPS are discarded.
  final clean = img.Image.fromBytes(
    width: scaled.width,
    height: scaled.height,
    bytes: scaled.getBytes(order: img.ChannelOrder.rgb).buffer,
    numChannels: 3,
  );
  return Uint8List.fromList(img.encodeJpg(clean, quality: 80));
}

Future<String> importReportPhoto(XFile source, String reportId) async {
  if (await source.length() > 20 * 1024 * 1024) {
    throw const FormatException('Photo is too large.');
  }
  final bytes = await compute(_compress, await source.readAsBytes());
  if (bytes.length > 2 * 1024 * 1024) {
    throw const FormatException('Photo is too large.');
  }
  final root = await getApplicationDocumentsDirectory();
  final folder = await Directory(
    '${root.path}/trail-report-photos/$reportId',
  ).create(recursive: true);
  final file = File('${folder.path}/${const Uuid().v4()}.jpg');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<File> _pendingFile() async => File(
  '${(await getApplicationDocumentsDirectory()).path}/report-photo-pending',
);
Future<void> markReportPhotoPicker(String? id) async {
  final file = await _pendingFile();
  if (id != null) {
    await file.writeAsString(id, flush: true);
  } else if (await file.exists()) {
    await file.delete();
  }
}

Future<void> recoverReportPhoto(ReportStore store) async {
  if (!Platform.isAndroid) return;
  final file = await _pendingFile();
  if (!await file.exists()) return;
  final id = await file.readAsString();
  final response = await ImagePicker().retrieveLostData();
  final drafts = await store.all();
  final matching = drafts.where((d) => d.id == id && d.editable);
  if (matching.isNotEmpty) {
    final draft = matching.first;
    for (final photo in response.files ?? <XFile>[]) {
      if (draft.photos.length >= 3) break;
      draft.photos = [...draft.photos, await importReportPhoto(photo, id)];
    }
    await store.save(draft);
  }
  await markReportPhotoPicker(null);
}
