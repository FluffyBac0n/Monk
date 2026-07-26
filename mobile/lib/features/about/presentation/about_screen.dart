import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info/app_version_provider.dart';
import '../../../core/links/external_url_launcher.dart';
import '../../../core/localization/app_localizations.dart';

const eurotrexWebsiteUrl = 'https://eurotrex.eu';
const eurotrexSuggestionsEmail = 'info@eurotrex.eu';

String _encodeQueryParameters(Map<String, String> parameters) {
  return parameters.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('&');
}

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _sand = Color(0xFFF4F2EC);
const _blue = Color(0xFF1565C0);

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const routeName = '/about';

  Future<bool> _tryOpen(WidgetRef ref, Uri uri) async {
    try {
      return await ref.read(externalUrlLauncherProvider)(uri);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openExternal(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
  ) async {
    final launched = await _tryOpen(ref, uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('Could not open this link.'))),
      );
    }
  }

  Future<void> _sendSuggestion(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final emailUri = Uri(
      scheme: 'mailto',
      path: eurotrexSuggestionsEmail,
      query: _encodeQueryParameters({
        'subject': l10n.t('EUROTREX app suggestion'),
      }),
    );
    if (await _tryOpen(ref, emailUri)) {
      return;
    }

    final openedWebsite = await _tryOpen(ref, Uri.parse(eurotrexWebsiteUrl));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.t(
            openedWebsite
                ? 'No email app is available. Opening the EUROTREX website contact form instead.'
                : 'Could not open this link.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final version = ref.watch(appVersionProvider);

    return Scaffold(
      key: const ValueKey('about-screen'),
      backgroundColor: _sand,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('About us'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              l10n.t('About EUROTREX').toUpperCase(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const _AboutHero(),
          const SizedBox(height: 14),
          _AboutCard(
            icon: Icons.explore_rounded,
            title: l10n.t('About EUROTREX'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.t(
                    'EUROTREX brings long-distance trails, stages, maps, elevation profiles and practical information together in one place.',
                  ),
                  style: const TextStyle(color: Colors.black87, height: 1.45),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const ValueKey('about-website'),
                  onPressed: () => _openExternal(
                    context,
                    ref,
                    Uri.parse(eurotrexWebsiteUrl),
                  ),
                  icon: const Icon(Icons.language_rounded),
                  label: Text(l10n.t('Visit our website')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AboutCard(
            icon: Icons.handshake_outlined,
            title: l10n.t('Project funding'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.t(
                    'The EUROTREX project is co-funded by the European Union and supported by the Republic of Cyprus.',
                  ),
                  style: const TextStyle(color: Colors.black87, height: 1.45),
                ),
                const SizedBox(height: 16),
                _PartnerRow(
                  semanticLabel: l10n.t('Co-funded by the European Union'),
                  imageKey: const ValueKey('about-eu-logo'),
                  asset: 'assets/branding/eu_flag_color.png',
                  label: l10n.t('Co-funded by the European Union'),
                  imageHeight: 42,
                ),
                const SizedBox(height: 10),
                _PartnerRow(
                  semanticLabel: l10n.t('Supported by the Republic of Cyprus'),
                  imageKey: const ValueKey('about-cyprus-logo'),
                  asset: 'assets/branding/republic_of_cyprus_emblem.png',
                  label: l10n.t('Supported by the Republic of Cyprus'),
                  imageHeight: 50,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AboutCard(
            icon: Icons.lightbulb_outline_rounded,
            title: l10n.t('Contact us'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.t(
                    'Have an idea that could improve EUROTREX? Send us your suggestion.',
                  ),
                  style: const TextStyle(color: Colors.black87, height: 1.45),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const ValueKey('about-suggestions-email'),
                  onPressed: () => _sendSuggestion(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: Text(l10n.t('Send a suggestion')),
                ),
                const SizedBox(height: 8),
                Text(
                  eurotrexSuggestionsEmail,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          version.when(
            loading: () => const SizedBox(
              height: 18,
              child: Center(
                child: SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (value) => Text(
              '${l10n.t('Version')} $value',
              key: const ValueKey('about-version'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, Color(0xFF315E47)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('EUROTREX'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.t('Explore Europe, one trail at a time.'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ink.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: _green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({
    required this.semanticLabel,
    required this.imageKey,
    required this.asset,
    required this.label,
    required this.imageHeight,
  });

  final String semanticLabel;
  final Key imageKey;
  final String asset;
  final String label;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _sand,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 54,
                child: Center(
                  child: Image.asset(
                    asset,
                    key: imageKey,
                    height: imageHeight,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
