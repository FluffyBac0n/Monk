import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

/// The upload receipt and the trail team's workflow are separate states.
/// A successful upload is Received; Sent means forwarded to an authority.
class ReportStatusBadge extends StatelessWidget {
  const ReportStatusBadge({
    super.key,
    required this.uploadState,
    this.remoteStatus,
  });

  final String uploadState;
  final String? remoteStatus;

  static const textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.4,
  );

  (String, int, int) get _appearance {
    final status = uploadState == 'sent' ? remoteStatus ?? 'new' : uploadState;
    return switch (status) {
      'new' => ('Received', 0xFFFFF0C6, 0xFF725300),
      'reviewed' => ('Reviewed', 0xFFE2EBFA, 0xFF254B9A),
      'forwarded' => ('Sent', 0xFFEDE6F4, 0xFF67458A),
      'resolved' => ('Resolved', 0xFFDCEFE4, 0xFF17583A),
      'duplicate' => ('Duplicate', 0xFFE9EBEC, 0xFF4E5A60),
      'dismissed' => ('Dismissed', 0xFFE9EBEC, 0xFF4E5A60),
      'draft' => ('Draft', 0xFFE9EBEC, 0xFF4E5A60),
      'queued' => ('Waiting for connection', 0xFFFFF0C6, 0xFF725300),
      'uploading' => ('Uploading…', 0xFFE2EBFA, 0xFF254B9A),
      'failed' => ('Upload failed — saved on device', 0xFFFBE5E2, 0xFF8C3025),
      _ => ('Status unavailable', 0xFFE9EBEC, 0xFF4E5A60),
    };
  }

  String localizedLabel(BuildContext context) => context.l10n.t(_appearance.$1);

  @override
  Widget build(BuildContext context) {
    final (_, background, foreground) = _appearance;
    final translated = localizedLabel(context);
    return Semantics(
      label: '${context.l10n.t('Status')}: $translated',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Color(background),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          translated,
          style: textStyle.copyWith(color: Color(foreground)),
        ),
      ),
    );
  }
}
