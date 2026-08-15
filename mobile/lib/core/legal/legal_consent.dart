const currentLegalTermsVersion = '2026-08-15';
const legalTermsPromptSeenSetting = 'legalTermsPromptSeen';
const legalTermsAcceptedSetting = 'legalTermsAccepted';
const legalTermsAcceptedAtSetting = 'legalTermsAcceptedAtUtc';
const legalTermsAcceptedVersionSetting = 'legalTermsAcceptedVersion';

class LegalConsentState {
  const LegalConsentState({
    required this.isLoading,
    required this.promptSeen,
    required this.accepted,
    this.acceptedAtUtc,
    this.acceptedVersion,
  });

  const LegalConsentState.loading()
    : isLoading = true,
      promptSeen = false,
      accepted = false,
      acceptedAtUtc = null,
      acceptedVersion = null;

  const LegalConsentState.resolved({
    required this.promptSeen,
    required this.accepted,
    this.acceptedAtUtc,
    this.acceptedVersion,
  }) : isLoading = false;

  final bool isLoading;
  final bool promptSeen;
  final bool accepted;
  final String? acceptedAtUtc;
  final String? acceptedVersion;

  bool get requiresInitialPrompt => !isLoading && !promptSeen;
}
