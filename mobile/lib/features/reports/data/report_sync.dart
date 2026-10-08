import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app.dart';
import '../../../core/database/database_provider.dart';
import 'report_store.dart';
import 'report_photos.dart';
import 'report_photo_checksum.dart';

const reportUploadFailure =
    'Could not send. Your report and photos are saved; retry when connected.';
const reportPhotoIntegrityFailure =
    'A photo failed its integrity check. Your report and photos are saved; retry the upload.';
const reportVerificationFailure =
    'This app could not be verified. Your report is saved. Please update the app or contact EuroTrex.';
const reportAuthenticationFailure =
    'The reporting service rejected this submission. Your report is saved. Please try again or contact EuroTrex.';
const reportErrorMessages = {
  reportUploadFailure,
  reportPhotoIntegrityFailure,
  reportVerificationFailure,
  reportAuthenticationFailure,
  'Could not send. Your report is saved; retry when connected.',
  'The original submission account is unavailable. Keep this report and contact EuroTrex.',
  'The daily report limit has been reached. Please try tomorrow.',
  'This trail is unavailable.',
  'This submission identifier is already in use.',
  'This draft expired. Create a new report.',
  'This draft expired.',
  'Some photos have not finished uploading.',
  'Photo is too large.',
  'A photo cannot be read. Please replace it.',
  'You cannot submit this report.',
};

String reportUploadErrorMessage(Object error) {
  if (error is StateError && reportErrorMessages.contains(error.message)) {
    return error.message;
  }
  if (error is FirebaseException) {
    if (error.plugin == 'firebase_app_check') return reportVerificationFailure;
    if (error is FirebaseFunctionsException &&
        reportErrorMessages.contains(error.message)) {
      return error.message!;
    }
    if (error.code == 'unauthenticated' ||
        error.code == 'permission-denied' ||
        error is FirebaseAuthException) {
      return reportAuthenticationFailure;
    }
  }
  return reportUploadFailure;
}

final reportStoreProvider = Provider(
  (ref) => ReportStore(ref.watch(appDatabaseProvider)),
);
final reportSyncProvider = Provider((ref) {
  final sync = ReportSync(
    ref.watch(reportStoreProvider),
    enabled: ref.watch(firebaseReadyProvider),
  );
  ref.onDispose(sync.dispose);
  return sync;
});

class ReportSync extends ChangeNotifier with WidgetsBindingObserver {
  ReportSync(this.store, {required this.enabled, this.firebaseApp}) {
    WidgetsBinding.instance.addObserver(this);
    _connection = Connectivity().onConnectivityChanged.listen(
      (_) => unawaited(sync()),
      onError: (_) {},
    );
    _retry = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(sync()),
    );
    unawaited(_recover());
  }
  Future<void> _recover() async {
    try {
      await recoverReportPhoto(store);
      changed();
    } catch (_) {}
    await sync();
  }

  final ReportStore store;
  final bool enabled;
  final FirebaseApp? firebaseApp;
  bool _running = false, _disposed = false, _active = true;
  StreamSubscription<List<ConnectivityResult>>? _connection;
  Timer? _retry;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) unawaited(sync());
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _connection?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> sync() async {
    if (_running || !enabled || !_active || _disposed) return;
    _running = true;
    try {
      if ((await Connectivity().checkConnectivity()).contains(
        ConnectivityResult.none,
      )) {
        return;
      }
      final functions = FirebaseFunctions.instanceFor(
        app: firebaseApp,
        region: 'europe-west1',
      );
      final drafts = await store.all();
      for (final draft in drafts.where(
        (d) => ['queued', 'uploading', 'failed'].contains(d.state),
      )) {
        if (!_active || _disposed) break;
        try {
          final auth = FirebaseAuth.instanceFor(
            app: firebaseApp ?? Firebase.app(),
          );
          final user =
              auth.currentUser ?? (await auth.signInAnonymously()).user!;
          if (draft.ownerUid != null && draft.ownerUid != user.uid) {
            throw StateError(
              'The original submission account is unavailable. Keep this report and contact EuroTrex.',
            );
          }
          draft.ownerUid = user.uid;
          draft.state = 'uploading';
          draft.error = '';
          await store.save(draft);
          changed();
          // Named apps are used only by isolated emulator integration tests.
          // Live uploads must have an App Check token before contacting the
          // callable, so failed device verification gets an actionable error.
          if (firebaseApp == null) {
            final token = await FirebaseAppCheck.instance.getToken();
            if (token == null || token.isEmpty) {
              throw StateError(reportVerificationFailure);
            }
          }
          final begin = await functions
              .httpsCallable('beginTrailReport')
              .call(draft.submission());
          if ((begin.data as Map)['received'] != true) {
            final checksums = <ReportPhotoChecksum>[];
            for (var i = 0; i < draft.photos.length; i++) {
              // Hash the saved original on every attempt, including when an
              // interrupted upload is reused. The backend checks these bytes
              // before publishing any photo or accepting the report.
              checksums.add(
                await ReportPhotoChecksum.fromFile(
                  'photo_$i',
                  File(draft.photos[i]),
                ),
              );
              final reference = FirebaseStorage.instanceFor(app: firebaseApp).ref(
                'trail-report-uploads/${user.uid}/${draft.id}/photo_$i/photo.jpg',
              );
              var uploaded = false;
              try {
                await reference.getMetadata();
                uploaded = true;
              } on FirebaseException catch (e) {
                if (e.code != 'object-not-found') rethrow;
              }
              if (!uploaded) {
                await reference.putFile(
                  File(draft.photos[i]),
                  SettableMetadata(contentType: 'image/jpeg'),
                );
              }
            }
            await functions.httpsCallable('finalizeTrailReport').call({
              'reportId': draft.id,
              'photoChecksums': checksums
                  .map((checksum) => checksum.toJson())
                  .toList(),
            });
          }
          draft.state = 'sent';
          draft.remoteStatus = 'new';
          draft.error = '';
          await store.save(draft);
          changed();
        } catch (e) {
          if (const bool.fromEnvironment('dart.vm.product') == false) {
            // Codes only: never log report content, location or credentials.
            debugPrint(
              'Report upload failed: ${e is FirebaseException ? '${e.plugin}/${e.code}' : e.runtimeType}',
            );
          }
          draft.state = 'failed';
          draft.error = reportUploadErrorMessage(e);
          await store.save(draft);
          changed();
        }
      }
    } catch (_) {
      // Connectivity/auth failures must never interrupt browsing or discard drafts.
    } finally {
      _running = false;
      changed();
    }
  }

  Future<void> refreshReceipt(ReportDraft draft) async {
    if (!enabled || draft.state != 'sent') return;
    try {
      final response = await FirebaseFunctions.instanceFor(
        app: firebaseApp,
        region: 'europe-west1',
      ).httpsCallable('trailReportReceipt').call({'reportId': draft.id});
      draft.remoteStatus = (response.data as Map)['status'] as String?;
      await store.save(draft);
      changed();
    } catch (_) {
      /* Keep the last confirmed receipt offline. */
    }
  }
}
