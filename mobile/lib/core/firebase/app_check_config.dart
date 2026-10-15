import 'package:firebase_app_check/firebase_app_check.dart';

AndroidAppCheckProvider androidAppCheckProviderForBuild({
  required bool isDebugBuild,
  String debugToken = '',
}) => isDebugBuild && debugToken.isNotEmpty
    ? AndroidDebugProvider(debugToken: debugToken)
    : const AndroidPlayIntegrityProvider();

AppleAppCheckProvider appleAppCheckProviderForBuild({
  required bool isDebugBuild,
  String debugToken = '',
}) => isDebugBuild && debugToken.isNotEmpty
    ? AppleDebugProvider(debugToken: debugToken)
    : const AppleAppAttestProvider();
