import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../about/presentation/about_screen.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../stages/presentation/stages_screen.dart';
import '../../trail/presentation/trail_direction_controller.dart';
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
    final direction = ref.watch(trailDirectionProvider);
    final stages = ref.watch(stagesProvider);
    final route = ref.watch(elevationProvider);
    final trailDataReady =
        stages.hasValue &&
        stages.requireValue.isNotEmpty &&
        route.hasValue &&
        route.requireValue.isNotEmpty;

    return Scaffold(
      backgroundColor: _sand,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 184,
            pinned: true,
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            title: Text(
              l10n.t('EUROTREX'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
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
                tooltip: l10n.t('Settings'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_ink, Color(0xFF315E47)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 70, 20, 22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('Explore trails'),
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.t('Choose a trail to view its stages and maps.'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            sliver: SliverList.list(
              children: [
                for (final trail in availableTrails)
                  _TrailCard(
                    trail: trail,
                    formatter: formatter,
                    isOffline: trailDataReady,
                    isReversed: direction.isReversed,
                    onExplore: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(
                          name: StagesScreen.routeName,
                        ),
                        builder: (_) => const StagesScreen(),
                      ),
                    ),
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
              const Icon(Icons.route_rounded, color: _comingSoonBlue),
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
    required this.isReversed,
    required this.onExplore,
  });

  final TrailSummary trail;
  final MeasurementFormatter formatter;
  final bool isOffline;
  final bool isReversed;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = l10n.t(isReversed ? trail.endName : trail.startName);
    final end = l10n.t(isReversed ? trail.startName : trail.endName);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('explore-${trail.id}'),
        onTap: onExplore,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: ValueKey('trail-card-header-${trail.id}'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF275F45), Color(0xFF183226)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 12),
                  Text(
                    trail.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.routeDirection(start, end),
                    style: const TextStyle(color: Colors.white70),
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
                  Row(
                    children: [
                      Icon(
                        isOffline
                            ? Icons.offline_pin_rounded
                            : Icons.cloud_download_outlined,
                        size: 19,
                        color: isOffline ? _green : Colors.black45,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.t(
                            isOffline
                                ? 'Trail data available offline'
                                : 'Trail data not downloaded',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: onExplore,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(l10n.t('Explore trail')),
                      ),
                    ],
                  ),
                ],
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
