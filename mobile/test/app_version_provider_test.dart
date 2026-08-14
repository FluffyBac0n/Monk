import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:eurotrex/core/app_info/app_version_provider.dart';

void main() {
  test('formats the public app version with its build number', () async {
    PackageInfo.setMockInitialValues(
      appName: 'EuroTrex',
      packageName: 'com.eurotrex.e4',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
      installerStore: null,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(appVersionProvider.future), '1.2.3 (42)');
  });

  test('omits an empty build number', () async {
    PackageInfo.setMockInitialValues(
      appName: 'EuroTrex',
      packageName: 'com.eurotrex.e4',
      version: '1.2.3',
      buildNumber: ' ',
      buildSignature: '',
      installerStore: null,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(appVersionProvider.future), '1.2.3');
  });
}
