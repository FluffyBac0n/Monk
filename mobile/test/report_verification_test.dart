import 'package:cloud_functions/cloud_functions.dart';
import 'package:eurotrex/core/firebase/app_check_config.dart';
import 'package:eurotrex/features/reports/data/report_sync.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release and profile builds always use App Attest', () {
    expect(
      appleAppCheckProviderForBuild(
        isDebugBuild: false,
        debugToken: 'private-test-token',
      ),
      isA<AppleAppAttestProvider>(),
    );
  });

  test('debug provider requires an explicit private development token', () {
    expect(
      appleAppCheckProviderForBuild(isDebugBuild: true),
      isA<AppleAppAttestProvider>(),
    );
    final provider = appleAppCheckProviderForBuild(
      isDebugBuild: true,
      debugToken: 'private-test-token',
    );
    expect(provider, isA<AppleDebugProvider>());
    expect((provider as AppleDebugProvider).debugToken, 'private-test-token');
  });

  test(
    'verification and service rejection do not look like connection errors',
    () {
      expect(
        reportUploadErrorMessage(
          FirebaseException(plugin: 'firebase_app_check', code: 'unknown'),
        ),
        reportVerificationFailure,
      );
      expect(
        reportUploadErrorMessage(StateError(reportVerificationFailure)),
        reportVerificationFailure,
      );
      expect(
        reportUploadErrorMessage(
          FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'UNAUTHENTICATED',
          ),
        ),
        reportAuthenticationFailure,
      );
      expect(
        reportUploadErrorMessage(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: reportPhotoIntegrityFailure,
          ),
        ),
        reportPhotoIntegrityFailure,
      );
      const limit =
          'The daily report limit has been reached. Please try tomorrow.';
      expect(
        reportUploadErrorMessage(
          FirebaseFunctionsException(
            code: 'resource-exhausted',
            message: limit,
          ),
        ),
        limit,
      );
      expect(
        reportUploadErrorMessage(Exception('Internal details')),
        reportUploadFailure,
      );
    },
  );
}
