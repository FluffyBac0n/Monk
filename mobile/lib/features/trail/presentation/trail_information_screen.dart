import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/eurotrex_palette.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _sand = Color(0xFFF4F2EC);
const _yellow = Color(0xFFF2C94C);

class TrailInformationScreen extends StatelessWidget {
  const TrailInformationScreen({super.key});

  static const routeName = '/trails/cyprus-e4/information';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _sand,
      appBar: AppBar(
        backgroundColor: EurotrexPalette.navy,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Trail information'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              '${l10n.t('Cyprus E4').toUpperCase()} · ${l10n.t('Trail guide').toUpperCase()}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              key: const ValueKey('trail-information-image-header'),
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [EurotrexPalette.navy, EurotrexPalette.blue],
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Image.asset(
                      'assets/branding/cyprus_e4_forest.jpg',
                      key: const ValueKey(
                        'trail-information-watermark-cyprus-e4',
                      ),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const DecoratedBox(
                    key: ValueKey('trail-information-watermark-fade-cyprus-e4'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x80000000), Color(0x52000000)],
                        stops: [0.05, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(
                          l10n.t('Cyprus E4'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.t('Know the signs. Prepare for the trail.'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                l10n.t('Photo: Persephoni Trail stage'),
                key: const ValueKey('trail-information-photo-note'),
                style: const TextStyle(
                  color: Color(0xFF68716B),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _InformationSection(
            icon: Icons.signpost_rounded,
            title: l10n.t('Sign posting'),
            children: [
              Text(
                l10n.t(
                  'Follow the yellow E4 signs and direction arrows. Markers may appear on posts, rocks or existing road signs.',
                ),
              ),
              const SizedBox(height: 14),
              _SignExample(label: l10n.t('Typical E4 waymark')),
              const SizedBox(height: 14),
              Text(
                l10n.t(
                  'Waymarks can be faded, damaged or missing, especially at junctions and on remote sections. Confirm your route on the offline map whenever the path is unclear.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InformationSection(
            icon: Icons.backpack_rounded,
            title: l10n.t('Useful tips'),
            children: [
              _Tip(
                icon: Icons.water_drop_outlined,
                title: l10n.t('Carry enough water'),
                body: l10n.t(
                  'Water sources are irregular and may be seasonal. Refill whenever a reliable opportunity is available.',
                ),
              ),
              _Tip(
                icon: Icons.wb_sunny_outlined,
                title: l10n.t('Plan for heat and daylight'),
                body: l10n.t(
                  'Start early, use sun protection and avoid exposed sections during the hottest hours.',
                ),
              ),
              _Tip(
                icon: Icons.download_for_offline_outlined,
                title: l10n.t('Keep the route offline'),
                body: l10n.t(
                  'Download the trail and map before leaving coverage, and carry a charged phone or backup power.',
                ),
              ),
              _Tip(
                icon: Icons.hiking_rounded,
                title: l10n.t('Wear suitable footwear'),
                body: l10n.t(
                  'The E4 includes asphalt, forest tracks and rough or loose mountain paths.',
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InformationSection(
            icon: Icons.health_and_safety_outlined,
            title: l10n.t('Before you set out'),
            children: [
              Text(
                l10n.t(
                  'Check the weather, tell someone your plan, and confirm that the stage suits your fitness and available daylight. In an emergency in Cyprus, call 112.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E3DD)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF465049), height: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _green),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SignExample extends StatelessWidget {
  const _SignExample({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8DF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: _yellow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _ink, width: 2),
            ),
            child: const Text(
              'E4  →',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({
    required this.icon,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
