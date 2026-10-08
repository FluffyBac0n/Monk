import 'package:firebase_app_check/firebase_app_check.dart';

AppleAppCheckProvider appleAppCheckProviderForBuild({
  required bool isDebugBuild,
  String debugToken = '',
}) => isDebugBuild && debugToken.isNotEmpty
    ? AppleDebugProvider(debugToken: debugToken)
    : const AppleAppAttestProvider();
