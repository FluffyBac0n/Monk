import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

final externalUrlLauncherProvider = Provider<ExternalUrlLauncher>((ref) {
  return (uri) {
    final scheme = uri.scheme.toLowerCase();
    final mode = switch (scheme) {
      'tel' || 'mailto' => LaunchMode.platformDefault,
      _ => LaunchMode.externalApplication,
    };
    return launchUrl(uri, mode: mode);
  };
});
