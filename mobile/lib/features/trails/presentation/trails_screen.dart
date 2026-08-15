import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/legal/legal_consent_controller.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../../about/presentation/about_screen.dart';
import '../../accommodation/presentation/accommodation_controller.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../legal/presentation/legal_disclaimer_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../stages/presentation/stages_screen.dart';
import '../domain/trail_summary.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _sand = Color(0xFFF4F2EC);
const _yellow = Color(0xFFF2C94C);
const _comingSoonBlue = Color(0xFF1565C0);

class TrailsScreen extends ConsumerWidget {
  const TrailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final stages = ref.watch(stagesProvider);
    final route = ref.watch(elevationProvider);
    final trailDataReady =
        stages.hasValue &&
        stages.requireValue.isNotEmpty &&
        route.hasValue &&
        route.requireValue.isNotEmpty;
    final legalConsent = ref.watch(legalConsentProvider);
    final canExploreTrails = legalConsent.accepted;

    void openTerms() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: LegalDisclaimerScreen.routeName),
          builder: (_) => const LegalDisclaimerScreen(isInitialPrompt: false),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _sand,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: EurotrexPalette.navy,
            foregroundColor: Colors.white,
            title: Semantics(
              image: true,
              label: l10n.t('EUROTREX'),
              child: Image.asset(
                'assets/branding/eurotrex_wordmark.png',
                key: const ValueKey('landing-eurotrex-wordmark'),
                width: 138,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            actions: [
              IconButton(
                key: const ValueKey('about-us-button'),
                tooltip: l10n.t('About us'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: AboutScreen.routeName),
                    builder: (_) => const AboutScreen(),
                  ),
                ),
                icon: const Icon(Icons.info_outline_rounded),
              ),
              IconButton(
                key: const ValueKey('landing-terms'),
                tooltip: l10n.t('Terms & Conditions'),
                onPressed: openTerms,
                icon: const Icon(Icons.policy_outlined),
              ),
              IconButton(
                key: const ValueKey('landing-settings'),
                tooltip: l10n.t('Settings'),
                onPressed: () => Navigator.of(context).push<DebugHintReset>(
                  MaterialPageRoute<DebugHintReset>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [EurotrexPalette.navy, EurotrexPalette.blue],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            sliver: SliverList.list(
              children: [
                if (!canExploreTrails) ...[
                  _LegalAcceptanceRequiredBanner(onReview: openTerms),
                  const SizedBox(height: 14),
                ],
                for (final trail in availableTrails)
                  _TrailCard(
                    trail: trail,
                    formatter: formatter,
                    isOffline: trailDataReady,
                    isEnabled: canExploreTrails,
                    onExplore: () {
                      ref.read(lodgingsForTrailProvider);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: StagesScreen.routeName,
                          ),
                          builder: (_) => const StagesScreen(),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                const _ComingSoonTrailCard(
                  trailId: 'crete-e4',
                  trailName: 'Crete E4',
                ),
                const SizedBox(height: 10),
                const _ComingSoonTrailCard(
                  trailId: 'peloponnese-e4',
                  trailName: 'Peloponnese E4',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTrailCard extends StatelessWidget {
  const _ComingSoonTrailCard({required this.trailId, required this.trailName});

  final String trailId;
  final String trailName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: '${l10n.t(trailName)}. ${l10n.t('Coming soon')}',
      enabled: false,
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('coming-soon-$trailId'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _comingSoonBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _comingSoonBlue.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hiking_rounded, color: _comingSoonBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t(trailName),
                      style: const TextStyle(
                        color: _comingSoonBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('Coming soon'),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.schedule_rounded,
                color: Colors.black38,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailCard extends StatelessWidget {
  const _TrailCard({
    required this.trail,
    required this.formatter,
    required this.isOffline,
    required this.isEnabled,
    required this.onExplore,
  });

  final TrailSummary trail;
  final MeasurementFormatter formatter;
  final bool isOffline;
  final bool isEnabled;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      enabled: isEnabled,
      child: Material(
        key: ValueKey('trail-card-surface-${trail.id}'),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: trail.id == 'cyprus-e4'
              ? BorderSide(
                  color: EurotrexPalette.navy.withValues(alpha: 0.28),
                  width: 1.25,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('explore-${trail.id}'),
          onTap: isEnabled ? onExplore : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: ValueKey('trail-card-header-${trail.id}'),
                width: double.infinity,
                constraints: trail.id == 'cyprus-e4'
                    ? const BoxConstraints(minHeight: 150)
                    : null,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [EurotrexPalette.navy, EurotrexPalette.blue],
                  ),
                ),
                child: Stack(
                  children: [
                    if (trail.id == 'cyprus-e4')
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Image.asset(
                              'assets/branding/cyprus_e4_forest.jpg',
                              key: const ValueKey(
                                'trail-card-watermark-cyprus-e4',
                              ),
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    if (trail.id == 'cyprus-e4')
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            key: ValueKey(
                              'trail-card-watermark-fade-cyprus-e4',
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x80000000), Color(0x52000000)],
                                stops: [0.05, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      key: ValueKey('trail-card-header-content-${trail.id}'),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                key: ValueKey('trail-card-kind-${trail.id}'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _yellow,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  l10n.t('LONG DISTANCE'),
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: _TrailDataStatusBadge(
                                  trailId: trail.id,
                                  isOffline: isOffline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            trail.name,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                key: ValueKey('trail-card-details-${trail.id}'),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t(trail.description),
                      style: const TextStyle(height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _TrailStat(
                          value: formatter.distance(
                            trail.distanceKm,
                            decimals: 0,
                          ),
                          label: l10n.t('Distance'),
                        ),
                        _TrailStat(
                          value: '${trail.stageCount}',
                          label: l10n.t('Stages'),
                        ),
                        _TrailStat(
                          value: formatter.altitude(trail.highPointM),
                          label: l10n.t('High point'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        key: ValueKey('explore-trail-button-${trail.id}'),
                        onPressed: isEnabled ? onExplore : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: EurotrexPalette.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.hiking_rounded, size: 18),
                        label: Text(l10n.t('Explore trail')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalAcceptanceRequiredBanner extends StatelessWidget {
  const _LegalAcceptanceRequiredBanner({required this.onReview});

  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('legal-acceptance-required'),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: EurotrexPalette.paleBlue.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EurotrexPalette.paleBlue),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, color: EurotrexPalette.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('Trail exploration is disabled'),
                  style: const TextStyle(
                    color: EurotrexPalette.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.t(
                    'You must accept the Terms and Conditions before you can explore a trail.',
                  ),
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('review-legal-terms'),
            onPressed: onReview,
            child: Text(l10n.t('Review terms')),
          ),
        ],
      ),
    );
  }
}

class _TrailDataStatusBadge extends StatelessWidget {
  const _TrailDataStatusBadge({required this.trailId, required this.isOffline});

  final String trailId;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.t(
      isOffline ? 'OFFLINE TRAIL' : 'Trail data not downloaded',
    );
    final foreground = isOffline ? _green : Colors.white70;
    final background = isOffline
        ? const Color(0xFFE1F1E8)
        : Colors.white.withValues(alpha: 0.12);
    return Tooltip(
      message: label,
      child: Container(
        key: ValueKey('trail-data-status-badge-$trailId'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: foreground,
              size: 13,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailStat extends StatelessWidget {
  const _TrailStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.1),
          ),
        ],
      ),
    );
  }
}
