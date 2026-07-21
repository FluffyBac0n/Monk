import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../stages/presentation/stages_screen.dart';
import '../../trail/presentation/trail_direction_controller.dart';
import '../domain/trail_summary.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _sand = Color(0xFFF4F2EC);
const _yellow = Color(0xFFF2C94C);

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

    return Scaffold(
      backgroundColor: _sand,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 246,
            pinned: true,
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            title: const Text(
              'MONK',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.4),
            ),
            actions: [
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
                          l10n.t('TRAIL LIBRARY'),
                          style: const TextStyle(
                            color: _yellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                    isOffline:
                        stages.hasValue && stages.requireValue.isNotEmpty,
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
              ],
            ),
          ),
        ],
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
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _yellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.t('LONG DISTANCE'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    trail.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.routeDirection(start, end),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t(trail.description),
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(
                        isOffline
                            ? Icons.offline_pin_rounded
                            : Icons.cloud_download_outlined,
                        size: 19,
                        color: isOffline ? _green : Colors.black45,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          l10n.t(
                            isOffline
                                ? 'Trail guide available offline'
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
                        icon: const Icon(Icons.arrow_forward_rounded),
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
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
