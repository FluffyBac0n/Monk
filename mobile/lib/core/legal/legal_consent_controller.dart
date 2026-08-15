import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'legal_consent.dart';

final legalConsentProvider =
    NotifierProvider<LegalConsentController, LegalConsentState>(
      LegalConsentController.new,
    );

class LegalConsentController extends Notifier<LegalConsentState> {
  @override
  LegalConsentState build() {
    unawaited(_restore());
    return const LegalConsentState.loading();
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(appDatabaseProvider).readSettings();
      final accepted = stored[legalTermsAcceptedSetting] == 'true';
      state = LegalConsentState.resolved(
        promptSeen: accepted || stored[legalTermsPromptSeenSetting] == 'true',
        accepted: accepted,
        acceptedAtUtc: accepted ? stored[legalTermsAcceptedAtSetting] : null,
        acceptedVersion: accepted
            ? stored[legalTermsAcceptedVersionSetting]
            : null,
      );
    } catch (_) {
      state = const LegalConsentState.resolved(
        promptSeen: false,
        accepted: false,
      );
    }
  }

  Future<void> acceptTerms() async {
    if (state.accepted) return;

    final acceptedAtUtc = DateTime.now().toUtc().toIso8601String();
    state = LegalConsentState.resolved(
      promptSeen: true,
      accepted: true,
      acceptedAtUtc: acceptedAtUtc,
      acceptedVersion: currentLegalTermsVersion,
    );

    await _writeSetting(legalTermsAcceptedSetting, 'true');
    // Acceptance is the authoritative decision. Persist it before the
    // supporting metadata so a partial write can never restore as declined.
    await _writeSetting(legalTermsPromptSeenSetting, 'true');
    await _writeSetting(legalTermsAcceptedAtSetting, acceptedAtUtc);
    await _writeSetting(
      legalTermsAcceptedVersionSetting,
      currentLegalTermsVersion,
    );
  }

  Future<void> continueWithoutAccepting() async {
    if (state.accepted) return;
    state = const LegalConsentState.resolved(promptSeen: true, accepted: false);
    await _writeSetting(legalTermsPromptSeenSetting, 'true');
  }

  Future<void> _writeSetting(String key, String value) async {
    try {
      await ref.read(appDatabaseProvider).writeSetting(key, value);
    } catch (_) {
      // Keep the in-memory decision if persistence is temporarily unavailable.
    }
  }
}
