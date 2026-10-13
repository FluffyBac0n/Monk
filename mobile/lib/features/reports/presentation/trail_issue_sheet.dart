import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../data/trail_issues.dart';
import 'report_screen.dart';
import 'report_card_header.dart';

class TrailIssueSheet extends ConsumerWidget {
  const TrailIssueSheet({
    super.key,
    required this.trailId,
    required this.issueId,
  });
  final String trailId, issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = trailIssuesProvider(trailId);
    ref.listen(provider, (_, next) {
      if (next.hasValue &&
          !next.requireValue.any((issue) => issue.id == issueId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.pop(context);
          }
        });
      }
    });
    final issue = ref
        .watch(provider)
        .value
        ?.where((issue) => issue.id == issueId)
        .firstOrNull;
    if (issue == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('official-issue-header'),
            decoration: const BoxDecoration(
              color: Color(0xFFF4C84A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: EurotrexPalette.navy.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      reportDamageIcon(issue.category),
                      color: EurotrexPalette.navy,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.t(
                          reportCategoryLabels[issue.category] ?? 'Other',
                        ),
                        style: const TextStyle(
                          color: EurotrexPalette.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.t('Close'),
                      color: EurotrexPalette.navy,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.t('Description:'), style: _labelStyle),
                  const SizedBox(height: 6),
                  Text(
                    issue.description,
                    key: const ValueKey('official-issue-description'),
                    style: const TextStyle(
                      color: EurotrexPalette.navy,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(context.l10n.t('Can hikers pass?'), style: _labelStyle),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.t(
                      reportAccessLabels[issue.passability] ?? 'Unsure',
                    ),
                    style: const TextStyle(
                      color: EurotrexPalette.navy,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color: EurotrexPalette.navy,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
}
