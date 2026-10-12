import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../data/trail_issues.dart';
import 'report_screen.dart';

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
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFF9D302C),
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.t(
                        reportCategoryLabels[issue.category] ?? 'Other',
                      ),
                      style: const TextStyle(
                        color: EurotrexPalette.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.t('Close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                issue.description,
                key: const ValueKey('official-issue-description'),
                style: const TextStyle(fontSize: 16, height: 1.45),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.t(
                  reportAccessLabels[issue.passability] ?? 'Unsure',
                ),
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
