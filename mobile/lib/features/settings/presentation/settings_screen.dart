import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../map/domain/offline_map_state.dart';
import '../../map/presentation/offline_map_controller.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../trail/domain/trail_preferences.dart';

const _green = Color(0xFF277653);
const _red = Color(0xFFD14B45);
const _sand = Color(0xFFF4F2EC);

enum DebugHintReset { e4Information, stageDetails, stageMetrics }

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _sand,
      appBar: AppBar(
        backgroundColor: EurotrexPalette.navy,
        foregroundColor: Colors.white,
        title: Text(
          l10n.t('Settings'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: Theme(
        data: EurotrexPalette.controlsTheme(Theme.of(context)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            _SettingsCard(
              icon: Icons.translate_rounded,
              title: l10n.t('Language'),
              child: _LanguageSelector(
                value: settings.language,
                onChanged: ref.read(appSettingsProvider.notifier).setLanguage,
              ),
            ),
            const SizedBox(height: 14),
            _SettingsCard(
              icon: Icons.straighten_rounded,
              title: l10n.t('Measurements'),
              child: SegmentedButton<MeasurementSystem>(
                key: const Key('measurement-setting'),
                segments: [
                  ButtonSegment(
                    value: MeasurementSystem.metric,
                    label: Text(l10n.t('Metric')),
                    tooltip: l10n.t('Kilometres and metres'),
                  ),
                  ButtonSegment(
                    value: MeasurementSystem.imperial,
                    label: Text(l10n.t('Imperial')),
                    tooltip: l10n.t('Miles and feet'),
                  ),
                ],
                selected: {settings.measurementSystem},
                onSelectionChanged: (selection) => ref
                    .read(appSettingsProvider.notifier)
                    .setMeasurementSystem(selection.single),
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 14),
            const _OfflineAccessSetting(),
            if (kDebugMode) ...[
              const SizedBox(height: 14),
              _SettingsCard(
                icon: Icons.science_outlined,
                title: l10n.t('Developer tools'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t(
                        'Show the pulsing E4 trail information hint again.',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('reset-e4-information-hint'),
                      onPressed: () async {
                        try {
                          await ref
                              .read(appDatabaseProvider)
                              .writeSetting(
                                cyprusE4TrailInformationSeenSetting,
                                'false',
                              );
                        } catch (_) {
                          // The current Stages session can still reset the hint.
                        }
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pop(DebugHintReset.e4Information);
                        }
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(l10n.t('Reset E4 hint')),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('Show the stage details helper again.'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('reset-stage-details-hint'),
                      onPressed: () async {
                        try {
                          await ref
                              .read(appDatabaseProvider)
                              .writeSetting(
                                cyprusE4StageDetailsHintSeenSetting,
                                'false',
                              );
                        } catch (_) {
                          // The current Stages session can still reset the hint.
                        }
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pop(DebugHintReset.stageDetails);
                        }
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(l10n.t('Reset stage hint')),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('Show the left-side stage metrics helper again.'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('reset-stage-metrics-hint'),
                      onPressed: () async {
                        try {
                          await ref
                              .read(appDatabaseProvider)
                              .writeSetting(
                                cyprusE4StageMetricsHintSeenSetting,
                                'false',
                              );
                        } catch (_) {
                          // The current Stages session can still reset the hint.
                        }
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pop(DebugHintReset.stageMetrics);
                        }
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(l10n.t('Reset metrics hint')),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              l10n.t('Changes apply throughout the app.'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.value, required this.onChanged});

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EurotrexPalette.paleBlue.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EurotrexPalette.blue, width: 1.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          key: const Key('language-setting'),
          value: value,
          isExpanded: true,
          elevation: 2,
          padding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
          dropdownColor: const Color(0xFFFBFAF6),
          borderRadius: BorderRadius.circular(16),
          menuMaxHeight: 320,
          focusColor: Colors.transparent,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: EurotrexPalette.blue,
          ),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: EurotrexPalette.navy,
            fontWeight: FontWeight.w500,
          ),
          selectedItemBuilder: (context) => [
            for (final language in AppLanguage.values)
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    _LanguageFlag(language: language),
                    const SizedBox(width: 10),
                    Text(language.displayName),
                  ],
                ),
              ),
          ],
          items: [
            for (final language in AppLanguage.values)
              DropdownMenuItem(
                value: language,
                child: Row(
                  children: [
                    _LanguageFlag(language: language),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        language.displayName,
                        style: TextStyle(
                          color: EurotrexPalette.navy,
                          fontWeight: language == value
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (language == value) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 19,
                        color: EurotrexPalette.blue,
                      ),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (language) {
            if (language != null) onChanged(language);
          },
        ),
      ),
    );
  }
}

class _LanguageFlag extends StatelessWidget {
  const _LanguageFlag({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('language-flag-${language.code}'),
      width: 32,
      height: 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EurotrexPalette.paleBlue),
      ),
      child: Text(
        language.flagEmoji,
        style: const TextStyle(fontSize: 18, height: 1),
      ),
    );
  }
}

class _OfflineAccessSetting extends ConsumerWidget {
  const _OfflineAccessSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final offlineMap = ref.watch(offlineMapProvider);
    final stages = ref.watch(stagesProvider);
    final route = ref.watch(elevationProvider);
    final routePoints = route.value ?? const [];
    final trailDataChecking = stages.isLoading || route.isLoading;
    final trailDataFailed = stages.hasError || route.hasError;
    final trailDataReady =
        !trailDataChecking &&
        !trailDataFailed &&
        (stages.value?.isNotEmpty ?? false) &&
        routePoints.isNotEmpty;

    return _SettingsCard(
      icon: Icons.offline_pin_rounded,
      title: l10n.t('Offline access'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.t('Cyprus E4'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.t('Offline content for this trail'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          _TrailDataStatus(
            checking: trailDataChecking,
            failed: trailDataFailed,
            ready: trailDataReady,
          ),
          const SizedBox(height: 10),
          _OfflineMapStatus(
            asyncState: offlineMap,
            canDownload: routePoints.isNotEmpty,
            onDownload: () =>
                ref.read(offlineMapProvider.notifier).download(routePoints),
            onRefresh: () => ref.read(offlineMapProvider.notifier).refresh(),
            onDelete: () => _confirmDeleteOfflineMap(context, ref),
          ),
        ],
      ),
    );
  }
}

class _TrailDataStatus extends StatelessWidget {
  const _TrailDataStatus({
    required this.checking,
    required this.failed,
    required this.ready,
  });

  final bool checking;
  final bool failed;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = failed
        ? _red
        : ready
        ? _green
        : Colors.black54;
    final status = checking
        ? l10n.t('Checking trail data…')
        : failed
        ? l10n.t('Trail data status could not be read.')
        : ready
        ? l10n.t('Trail data available offline')
        : l10n.t('Trail data not downloaded');

    return _OfflineStatusPanel(
      icon: ready ? Icons.check_circle_rounded : Icons.route_rounded,
      color: color,
      title: l10n.t('Trail data'),
      status: status,
      description: l10n.t('Route, stages and elevation'),
      trailing: checking
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : null,
    );
  }
}

class _OfflineMapStatus extends StatelessWidget {
  const _OfflineMapStatus({
    required this.asyncState,
    required this.canDownload,
    required this.onDownload,
    required this.onRefresh,
    required this.onDelete,
  });

  final AsyncValue<OfflineMapState> asyncState;
  final bool canDownload;
  final VoidCallback onDownload;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (asyncState.isLoading) {
      return _OfflineStatusPanel(
        icon: Icons.map_outlined,
        color: Colors.black54,
        title: l10n.t('Offline map'),
        status: l10n.t('Checking offline maps…'),
        description: l10n.t('Detailed map along the trail'),
        trailing: const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (asyncState.hasError || asyncState.value == null) {
      return _OfflineStatusPanel(
        icon: Icons.cloud_off_rounded,
        color: _red,
        title: l10n.t('Offline map'),
        status: l10n.t('Offline map status could not be read.'),
        description: l10n.t('Detailed map along the trail'),
        footer: OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.t('Check again')),
        ),
      );
    }

    final state = asyncState.requireValue;
    final ready = state.phase == OfflineMapPhase.ready;
    final downloading = state.phase == OfflineMapPhase.downloading;
    final failed = state.phase == OfflineMapPhase.failed;
    final removalFailed = failed && state.failure == OfflineMapFailure.removal;
    final color = failed
        ? _red
        : ready
        ? _green
        : Colors.black54;
    final icon = failed
        ? Icons.cloud_off_rounded
        : ready
        ? Icons.check_circle_rounded
        : downloading
        ? Icons.downloading_rounded
        : Icons.map_outlined;
    final status = failed
        ? l10n.t(state.message ?? 'Offline map download failed')
        : ready
        ? l10n.t('Offline map downloaded')
        : downloading
        ? l10n.t('Downloading offline map')
        : l10n.t('Offline map not downloaded');

    return _OfflineStatusPanel(
      icon: icon,
      color: color,
      title: l10n.t('Offline map'),
      status: status,
      description: l10n.t('Detailed map along the trail'),
      body: Column(
        children: [
          if (downloading) ...[
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(state.progress * 100).round()}%'),
                Text(formatOfflineBytes(state.completedBytes)),
              ],
            ),
          ],
          if (ready || state.completedBytes > 0) ...[
            _OfflineFact(
              label: l10n.t('Size'),
              value: formatOfflineBytes(state.completedBytes),
            ),
          ],
          if (ready) ...[
            _OfflineFact(
              label: l10n.t('Last updated'),
              value: state.downloadedAt == null
                  ? l10n.t('Not available')
                  : _formatOfflineMapDate(context, state.downloadedAt!),
            ),
          ],
        ],
      ),
      footer: ready
          ? FilledButton.icon(
              key: const Key('settings-delete-offline-maps'),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
              ),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l10n.t('Remove offline map')),
            )
          : downloading
          ? null
          : FilledButton.icon(
              key: const Key('settings-download-offline-map'),
              onPressed: removalFailed
                  ? onRefresh
                  : canDownload
                  ? onDownload
                  : null,
              icon: Icon(
                removalFailed ? Icons.refresh_rounded : Icons.download_rounded,
              ),
              label: Text(
                l10n.t(
                  removalFailed
                      ? 'Check again'
                      : failed
                      ? 'Try again'
                      : 'Download offline map',
                ),
              ),
            ),
    );
  }
}

class _OfflineStatusPanel extends StatelessWidget {
  const _OfflineStatusPanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.status,
    required this.description,
    this.trailing,
    this.body,
    this.footer,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String status;
  final String description;
  final Widget? trailing;
  final Widget? body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (body != null) ...[const SizedBox(height: 13), body!],
          if (footer != null) ...[
            const SizedBox(height: 13),
            SizedBox(width: double.infinity, child: footer!),
          ],
        ],
      ),
    );
  }
}

class _OfflineFact extends StatelessWidget {
  const _OfflineFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

String _formatOfflineMapDate(BuildContext context, DateTime downloadedAt) {
  final localTime = downloadedAt.toLocal();
  final material = MaterialLocalizations.of(context);
  final date = material.formatCompactDate(localTime);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(localTime),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$date · $time';
}

Future<void> _confirmDeleteOfflineMap(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.t('Remove offline map?')),
      content: Text(
        l10n.t(
          'The route, stages and elevation will remain offline. Only the offline map will be removed.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.t('Cancel')),
        ),
        FilledButton(
          key: const Key('confirm-delete-offline-maps'),
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.t('Remove')),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(offlineMapProvider.notifier).delete();
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
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
        border: Border.all(color: EurotrexPalette.paleBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: EurotrexPalette.paleBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: EurotrexPalette.navy, size: 19),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}
