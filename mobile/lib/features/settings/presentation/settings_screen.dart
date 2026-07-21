import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../map/domain/offline_map_state.dart';
import '../../map/presentation/offline_map_controller.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _red = Color(0xFFD14B45);
const _sand = Color(0xFFF4F2EC);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _sand,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: Text(
          l10n.t('Settings'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _SettingsCard(
            icon: Icons.translate_rounded,
            title: l10n.t('Language'),
            child: DropdownButtonFormField<AppLanguage>(
              key: const Key('language-setting'),
              initialValue: settings.language,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final language in AppLanguage.values)
                  DropdownMenuItem(
                    value: language,
                    child: Text(language.displayName),
                  ),
              ],
              onChanged: (language) {
                if (language != null) {
                  ref.read(appSettingsProvider.notifier).setLanguage(language);
                }
              },
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
          const _OfflineMapsSetting(),
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
    );
  }
}

class _OfflineMapsSetting extends ConsumerWidget {
  const _OfflineMapsSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final offlineMap = ref.watch(offlineMapProvider);
    final state = offlineMap.value;
    final isReady = state?.isReady == true;
    final status = isReady
        ? '${l10n.t('Downloaded')} · ${formatOfflineBytes(state!.completedBytes)}'
        : offlineMap.isLoading
        ? l10n.t('Checking offline maps…')
        : l10n.t('No offline maps downloaded.');

    return _SettingsCard(
      icon: Icons.offline_pin_rounded,
      title: l10n.t('Offline maps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(status, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('settings-delete-offline-maps'),
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _red.withValues(alpha: 0.35),
              disabledForegroundColor: Colors.white70,
            ),
            onPressed: isReady
                ? () => _confirmDeleteOfflineMaps(context, ref)
                : null,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l10n.t('Delete offline maps')),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteOfflineMaps(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.t('Delete offline maps?')),
      content: Text(
        l10n.t(
          'The route, stages and elevation will remain offline. Only the Mapbox background tiles will be removed.',
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
          child: Text(l10n.t('Delete')),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _green),
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
