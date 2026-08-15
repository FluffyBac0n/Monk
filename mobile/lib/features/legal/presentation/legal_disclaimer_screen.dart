import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/legal/legal_consent_controller.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/eurotrex_chrome_theme.dart';
import '../../../core/theme/eurotrex_palette.dart';

const _sand = Color(0xFFF4F2EC);

class LegalDisclaimerScreen extends ConsumerWidget {
  const LegalDisclaimerScreen({required this.isInitialPrompt, super.key});

  static const routeName = '/terms';

  final bool isInitialPrompt;

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    await ref.read(legalConsentProvider.notifier).acceptTerms();
    if (!isInitialPrompt && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final consent = ref.watch(legalConsentProvider);
    final sections = <_LegalSection>[
      _LegalSection(
        icon: Icons.handshake_outlined,
        title: l10n.t('Agreement and eligibility'),
        body: l10n.t(
          'These Terms govern your use of the EuroTrex mobile app. By accepting, you confirm that you have read, understood and agreed to them. If you are under the legal age in your country, use the app only with permission and supervision from a parent or legal guardian.',
        ),
      ),
      _LegalSection(
        icon: Icons.health_and_safety_outlined,
        title: l10n.t('Outdoor safety and personal responsibility'),
        body: l10n.t(
          'Hiking and other outdoor activities involve inherent risks, including injury, death, sudden weather, wildfire, difficult terrain, wildlife and limited communications. You are responsible for checking current conditions, choosing a route suitable for your health and ability, carrying suitable equipment, water and supplies, and deciding when to turn back.',
        ),
      ),
      _LegalSection(
        icon: Icons.route_outlined,
        title: l10n.t('Navigation, trail data and access'),
        body: l10n.t(
          'Routes, maps, GPS positions, elevations, distances, walking times, services, excursions and detours may be inaccurate, incomplete or outdated. EuroTrex is a planning aid and does not replace official signs, current authority notices, a suitable backup map or your own judgement. Check closures, permits, private property, protected areas and local rules, and never enter a restricted or unsafe area merely because a route is displayed.',
        ),
      ),
      _LegalSection(
        icon: Icons.offline_bolt_outlined,
        title: l10n.t('Device, offline and location limitations'),
        body: l10n.t(
          'GPS and offline features may fail because of battery level, device settings, signal, storage, downloads, software or map-provider availability. Carry an alternative navigation method. If you grant location access, it is used to show your position and estimate nearby stages and trail distance; permissions can be managed in device settings.',
        ),
      ),
      _LegalSection(
        icon: Icons.hotel_outlined,
        title: l10n.t('Accommodation and third-party services'),
        body: l10n.t(
          'Accommodation information and external links, including Booking.com, are provided for convenience. Verify availability, location, prices, suitability and booking terms directly with the provider. EuroTrex is not the host, booking agent or seller and is not a party to transactions with third parties; their terms and privacy policies apply.',
        ),
      ),
      _LegalSection(
        icon: Icons.emergency_outlined,
        title: l10n.t('Emergency use'),
        body: l10n.t(
          'EuroTrex does not monitor your trip and cannot contact rescue services for you. In an emergency, call 112 in Cyprus and the European Union, or the applicable local emergency number elsewhere.',
        ),
      ),
      _LegalSection(
        icon: Icons.copyright_outlined,
        title: l10n.t('Intellectual property and acceptable use'),
        body: l10n.t(
          'The app and its text, branding, images, maps and trail data may be protected by intellectual-property rights belonging to EuroTrex or its licensors. You may use them for personal, non-commercial trail planning only and must not copy, resell, scrape or redistribute them except where law or an applicable licence permits.',
        ),
      ),
      _LegalSection(
        icon: Icons.balance_outlined,
        title: l10n.t('Availability, warranties and liability'),
        body: l10n.t(
          'The app and its content are provided on an as-is and as-available basis. Features and data may change, be interrupted or be removed. To the maximum extent permitted by law, EuroTrex excludes warranties and liability for losses arising from reliance on trail data, outdoor activity, device or connectivity failure, or third-party services. Nothing in these Terms limits liability or mandatory consumer rights that cannot legally be limited. Material changes will be communicated when required by law.',
        ),
      ),
      _LegalSection(
        icon: Icons.gavel_outlined,
        title: l10n.t('Governing law and contact'),
        body: l10n.t(
          'These Terms are governed by the laws of the Republic of Cyprus, without depriving you of mandatory protections that apply in your country of residence. Questions about these Terms may be sent to info@eurotrex.eu.',
        ),
      ),
    ];

    return PopScope(
      canPop: !isInitialPrompt,
      child: Scaffold(
        key: const ValueKey('legal-disclaimer-screen'),
        backgroundColor: _sand,
        appBar: EurotrexChromeTheme.appBar(
          automaticallyImplyLeading: !isInitialPrompt,
          title: Text(
            l10n.t('Terms & Conditions'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            _LegalHero(isAccepted: consent.accepted),
            const SizedBox(height: 14),
            for (final section in sections) ...[
              _LegalSectionCard(section: section),
              const SizedBox(height: 10),
            ],
            _AcceptanceCard(isAccepted: consent.accepted),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: _sand,
              border: Border(top: BorderSide(color: Color(0xFFD8DDDA))),
            ),
            child: consent.accepted
                ? FilledButton.icon(
                    key: const ValueKey('legal-accepted-status'),
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(l10n.t('Terms accepted')),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('accept-legal-terms'),
                          onPressed: () => _accept(context, ref),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(l10n.t('I accept')),
                        ),
                      ),
                      if (isInitialPrompt) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            key: const ValueKey('continue-without-accepting'),
                            onPressed: () => ref
                                .read(legalConsentProvider.notifier)
                                .continueWithoutAccepting(),
                            child: Text(l10n.t('Continue without accepting')),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class LegalLoadingScreen extends StatelessWidget {
  const LegalLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey('legal-consent-loading'),
      backgroundColor: EurotrexPalette.navy,
      body: Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}

class _LegalHero extends StatelessWidget {
  const _LegalHero({required this.isAccepted});

  final bool isAccepted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EurotrexPalette.navy, EurotrexPalette.blue],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAccepted ? Icons.verified_user_rounded : Icons.policy_outlined,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('Terms and Safety Disclaimer'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.t('Last updated: 15 August 2026'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isAccepted) ...[
            const SizedBox(height: 12),
            Text(
              l10n.t(
                'Please read these Terms before exploring a trail. You may continue without accepting, but trail exploration will remain disabled.',
              ),
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8DDDA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, color: EurotrexPalette.blue, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    color: EurotrexPalette.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            section.body,
            style: const TextStyle(color: Color(0xFF38433D), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _AcceptanceCard extends StatelessWidget {
  const _AcceptanceCard({required this.isAccepted});

  final bool isAccepted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('legal-acceptance-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAccepted
            ? const Color(0xFFE1F1E8)
            : EurotrexPalette.paleBlue.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAccepted
              ? const Color(0xFF8CC7A1)
              : EurotrexPalette.paleBlue,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('Acceptance on this device'),
            style: const TextStyle(
              color: EurotrexPalette.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            l10n.t(
              'Once accepted, the decision is stored on this device and cannot be withdrawn inside the app. To remove the local acceptance record, you must uninstall the app.',
            ),
            style: const TextStyle(height: 1.4),
          ),
          if (!isAccepted) ...[
            const SizedBox(height: 7),
            Text(
              l10n.t(
                'If you do not accept, the app will open but trail exploration will remain disabled. You can review and accept these Terms later from the landing page.',
              ),
              style: const TextStyle(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
