import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/external_url_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../stages/domain/stage.dart';
import '../domain/lodging.dart';
import 'accommodation_controller.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _sand = Color(0xFFF4F2EC);
const _bookingBlue = Color(0xFF1565C0);

class AccommodationScreen extends ConsumerWidget {
  const AccommodationScreen({required this.stage, super.key});

  final TrailStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lodgings = ref.watch(lodgingsForStageProvider(stage.id));
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );

    return Scaffold(
      key: ValueKey('accommodation-screen-${stage.id}'),
      backgroundColor: _sand,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('Accommodation'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              '${l10n.t('Cyprus E4').toUpperCase()} · ${l10n.t(stage.name).toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
      body: lodgings.when(
        loading: () => _AccommodationState(
          key: const ValueKey('accommodation-loading'),
          icon: Icons.hotel_rounded,
          title: l10n.t('Finding accommodation…'),
          progress: true,
        ),
        error: (_, _) => _AccommodationState(
          key: const ValueKey('accommodation-error'),
          icon: Icons.cloud_off_rounded,
          title: l10n.t('Accommodation information is currently unavailable.'),
          message: l10n.t('Please try again.'),
          action: FilledButton.icon(
            key: const ValueKey('accommodation-retry'),
            onPressed: () => ref.invalidate(lodgingsForStageProvider(stage.id)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.t('Try again')),
          ),
        ),
        data: (items) => items.isEmpty
            ? _AccommodationState(
                key: const ValueKey('accommodation-empty'),
                icon: Icons.hotel_outlined,
                title: l10n.t('No accommodation is listed for this stage.'),
                message: l10n.t('Try another nearby stage.'),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _PageIntroduction(stage: stage);
                  }
                  return _LodgingCard(
                    lodging: items[index - 1],
                    formatter: formatter,
                  );
                },
              ),
      ),
    );
  }
}

class _PageIntroduction extends StatelessWidget {
  const _PageIntroduction({required this.stage});

  final TrailStage stage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('Places to stay near this stage'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.t(stage.name),
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _LodgingCard extends ConsumerWidget {
  const _LodgingCard({required this.lodging, required this.formatter});

  final Lodging lodging;
  final MeasurementFormatter formatter;

  Future<void> _openExternal(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
  ) async {
    var launched = false;
    try {
      launched = await ref.read(externalUrlLauncherProvider)(uri);
    } on Exception {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('Could not open this link.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = lodging.name?.trim();
    final type = lodging.type?.trim();
    final village = lodging.village?.trim();
    final address = lodging.address?.trim();
    final phone = lodging.phone?.trim();
    final whatsapp = lodging.whatsapp?.trim();
    final email = lodging.email?.trim();
    final bookingUri = lodging.bookingUri;
    final mapsUri = lodging.mapsUri;
    final facts = <_LodgingFactData>[
      if (_formatPrice(lodging, l10n) case final price?)
        _LodgingFactData(
          icon: Icons.euro_rounded,
          label: l10n.t('Price'),
          value: price,
        ),
      if (lodging.distanceFromTrailKm case final distance?)
        _LodgingFactData(
          icon: Icons.route_rounded,
          label: l10n.t('Distance from trail'),
          value: formatter.distance(distance),
        ),
      if (_nonEmpty(lodging.monthsOpen) case final season?)
        _LodgingFactData(
          icon: Icons.calendar_month_rounded,
          label: l10n.t('Season'),
          value: l10n.t(season),
        ),
      if (_openingHours(lodging) case final hours?)
        _LodgingFactData(
          icon: Icons.schedule_rounded,
          label: l10n.t('Opening hours'),
          value: hours,
        ),
      if (lodging.capacityPeople case final capacity?)
        _LodgingFactData(
          icon: Icons.groups_rounded,
          label: l10n.t('Capacity'),
          value: '$capacity ${l10n.t(capacity == 1 ? 'person' : 'people')}',
        ),
      if (_meaningfulTime(lodging.checkInTime) case final checkIn?)
        _LodgingFactData(
          icon: Icons.login_rounded,
          label: l10n.t('Check-in'),
          value: checkIn,
        ),
      if (_meaningfulTime(lodging.checkOutTime) case final checkOut?)
        _LodgingFactData(
          icon: Icons.logout_rounded,
          label: l10n.t('Check-out'),
          value: checkOut,
        ),
    ];

    return Card(
      key: ValueKey('lodging-card-${lodging.id}'),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _bookingBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.hotel_rounded, color: _bookingBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null || name.isEmpty
                            ? l10n.t('Accommodation')
                            : l10n.t(name),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (type != null && type.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.t(type),
                          style: const TextStyle(
                            color: _bookingBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (village != null ||
                address != null ||
                phone != null ||
                whatsapp != null ||
                email != null) ...[
              const SizedBox(height: 14),
              SelectionArea(
                child: Column(
                  children: [
                    if (village != null || address != null)
                      _ContactRow(
                        icon: Icons.location_on_outlined,
                        value: [
                          if (address != null && address.isNotEmpty) address,
                          if (village != null &&
                              village.isNotEmpty &&
                              village != address)
                            village,
                        ].join(' · '),
                      ),
                    if (phone != null && phone.isNotEmpty)
                      _ContactRow(
                        icon: Icons.phone_outlined,
                        label: l10n.t('Phone'),
                        value: phone,
                      ),
                    if (whatsapp != null &&
                        whatsapp.isNotEmpty &&
                        whatsapp != phone)
                      _ContactRow(
                        icon: Icons.chat_outlined,
                        label: l10n.t('WhatsApp'),
                        value: whatsapp,
                      ),
                    if (email != null && email.isNotEmpty)
                      _ContactRow(
                        icon: Icons.email_outlined,
                        label: l10n.t('Email'),
                        value: email,
                      ),
                  ],
                ),
              ),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final fact in facts) _LodgingFact(data: fact)],
              ),
            ],
            const SizedBox(height: 16),
            if (mapsUri != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: ValueKey('map-lodging-${lodging.id}'),
                  onPressed: () => _openExternal(context, ref, mapsUri),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l10n.t('View on map')),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('book-lodging-${lodging.id}'),
                onPressed: bookingUri == null
                    ? null
                    : () => _openExternal(context, ref, bookingUri),
                style: FilledButton.styleFrom(
                  backgroundColor: _bookingBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black12,
                  disabledForegroundColor: Colors.black45,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: Icon(
                  bookingUri == null
                      ? Icons.link_off_rounded
                      : Icons.open_in_new_rounded,
                ),
                label: Text(
                  l10n.t(
                    bookingUri == null
                        ? 'Booking link unavailable'
                        : 'Book accommodation',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value, this.label});

  final IconData icon;
  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label == null ? value : '${label!}: $value',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _LodgingFactData {
  const _LodgingFactData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _LodgingFact extends StatelessWidget {
  const _LodgingFact({required this.data});

  final _LodgingFactData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _sand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 17, color: _green),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccommodationState extends StatelessWidget {
  const _AccommodationState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.progress = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (progress)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 58, color: _green),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _openingHours(Lodging lodging) {
  final opening = _meaningfulTime(lodging.openingTime);
  final closing = _meaningfulTime(lodging.closingTime);
  if (opening == null) return closing;
  if (closing == null) return opening;
  return '$opening–$closing';
}

String? _meaningfulTime(String? value) {
  final time = _nonEmpty(value);
  return time == '00:00' || time == '0:00' ? null : time;
}

String? _formatPrice(Lodging lodging, AppLocalizations l10n) {
  final minimum = lodging.priceMinEur;
  final maximum = lodging.priceMaxEur;
  if (minimum != null || maximum != null) {
    final low = minimum ?? maximum!;
    final high = maximum ?? minimum!;
    if (low == 0 && high == 0) return l10n.t('Free');
    return _formatEuro(low, high > low ? high : null, l10n);
  }
  return _nonEmpty(lodging.minPriceText);
}

String _formatEuro(double minimum, double? maximum, AppLocalizations l10n) {
  final low = _formatNumber(minimum, l10n);
  final high = maximum == null ? null : _formatNumber(maximum, l10n);
  if (l10n.locale.languageCode == 'de' || l10n.locale.languageCode == 'es') {
    return '${high == null ? low : '$low–$high'}\u00a0€';
  }
  return high == null ? '€$low' : '€$low–€$high';
}

String _formatNumber(double value, AppLocalizations l10n) {
  final amount = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return l10n.locale.languageCode == 'de' || l10n.locale.languageCode == 'es'
      ? amount.replaceFirst('.', ',')
      : amount;
}
