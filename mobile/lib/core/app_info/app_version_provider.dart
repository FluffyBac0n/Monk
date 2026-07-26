import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final buildNumber = packageInfo.buildNumber.trim();
  return buildNumber.isEmpty
      ? packageInfo.version
      : '${packageInfo.version} ($buildNumber)';
});
