import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/external_url_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/measurement_formatter.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../../elevation/presentation/elevation_screen.dart';
import '../../map/presentation/map_screen.dart';
import '../../stages/domain/stage.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../trail/presentation/trail_direction_controller.dart';
import '../domain/lodging.dart';
import 'accommodation_controller.dart';
import 'lodging_type_icon.dart';

const _ink = Color(0xFF17201B);
const _green = Color(0xFF277653);
const _sand = Color(0xFFF4F2EC);
const _yellow = Color(0xFFF2C94C);
const _bookingBlue = Color(0xFF1565C0);
const _stagesRouteName = '/trails/cyprus-e4/stages';
const _distanceFilterOptionsKm = <double>[0.5, 1, 2, 5];

class AccommodationScreen extends ConsumerStatefulWidget {
  const AccommodationScreen({required this.stage, super.key});

  final TrailStage stage;

  @override
  ConsumerState<AccommodationScreen> createState() =>
      _AccommodationScreenState();
}

class _AccommodationScreenState extends ConsumerState<AccommodationScreen> {
  _AccommodationFilters filters = const _AccommodationFilters();

  void _backToStages() {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == _stagesRouteName || route.isFirst,
    );
  }

  void _openMap(int? stageIndex, List<Lodging> lodgings) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          initialStageIndex: stageIndex,
          initialLodgings: lodgings
              .where((lodging) => lodging.location != null)
              .toList(growable: false),
        ),
      ),
    );
  }

  void _openElevation(int? stageIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ElevationScreen(initialStageIndex: stageIndex),
      ),
    );
  }

  Future<void> _openFilters(List<Lodging> lodgings) async {
    final updated = await showModalBottomSheet<_AccommodationFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _sand,
      builder: (_) => _AccommodationFilterSheet(
        initialFilters: filters,
        availableTypes: _availableLodgingTypes(lodgings),
        availablePriceRange: _availableLodgingPriceRange(lodgings),
      ),
    );
    if (updated != null && mounted) setState(() => filters = updated);
  }

  Future<void> _openDistanceFilter(MeasurementFormatter formatter) async {
    final updated = await showModalBottomSheet<_AccommodationFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _sand,
      builder: (_) => _AccommodationDistanceFilterSheet(
        initialFilters: filters,
        formatter: formatter,
      ),
    );
    if (updated != null && mounted) setState(() => filters = updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stage = widget.stage;
    final lodgings = ref.watch(lodgingsForStageProvider(stage.id));
    final formatter = MeasurementFormatter(
      ref.watch(appSettingsProvider).measurementSystem,
    );
    final sourceStages =
        ref.watch(stagesProvider).value ?? const <TrailStage>[];
    final direction = ref.watch(trailDirectionProvider);
    final orderedStages = direction.isReversed
        ? sourceStages.reversed.toList(growable: false)
        : sourceStages;
    final resolvedStageIndex = orderedStages.indexWhere(
      (candidate) => candidate.id == stage.id,
    );
    final stageIndex = resolvedStageIndex < 0 ? null : resolvedStageIndex;
    final allLodgings = lodgings.value ?? const <Lodging>[];

    return Scaffold(
      key: ValueKey('accommodation-screen-${stage.id}'),
      backgroundColor: _sand,
      bottomNavigationBar: _AccommodationBottomNavigationBar(
        activeFilterCount: filters.regularActiveCount,
        hasDistanceFilter: filters.maximumDistanceKm != null,
        onStages: _backToStages,
        onFilter: () => _openFilters(allLodgings),
        onDistanceFilter: () => _openDistanceFilter(formatter),
        onMap: () => _openMap(stageIndex, allLodgings),
        onElevation: () => _openElevation(stageIndex),
      ),
      appBar: AppBar(
        backgroundColor: EurotrexPalette.navy,
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
        data: (items) {
          if (items.isEmpty) {
            return _AccommodationState(
              key: const ValueKey('accommodation-empty'),
              icon: Icons.hotel_outlined,
              title: l10n.t('No accommodation is listed for this stage.'),
              message: l10n.t('Try another nearby stage.'),
            );
          }
          final filteredItems = items
              .where(filters.matches)
              .toList(growable: false);
          if (filteredItems.isEmpty) {
            return _AccommodationState(
              key: const ValueKey('accommodation-filter-empty'),
              icon: Icons.filter_alt_off_outlined,
              title: l10n.t('No accommodation matches these filters.'),
              action: OutlinedButton(
                key: const ValueKey('accommodation-clear-filters'),
                onPressed: () =>
                    setState(() => filters = const _AccommodationFilters()),
                child: Text(l10n.t('Clear filters')),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            itemCount: filteredItems.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) return _PageIntroduction(stage: stage);
              return _LodgingCard(
                lodging: filteredItems[index - 1],
                formatter: formatter,
              );
            },
          );
        },
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

class _AccommodationFilters {
  const _AccommodationFilters({
    this.bookableOnlineOnly = false,
    this.maximumDistanceKm,
    this.priceRangeEur,
    this.types = const <String>{},
  });

  final bool bookableOnlineOnly;
  final double? maximumDistanceKm;
  final RangeValues? priceRangeEur;
  final Set<String> types;

  int get regularActiveCount =>
      (bookableOnlineOnly ? 1 : 0) +
      (priceRangeEur == null ? 0 : 1) +
      types.length;

  bool matches(Lodging lodging) {
    if (bookableOnlineOnly && lodging.bookingUri == null) return false;
    if (maximumDistanceKm case final maximumDistance?) {
      final distance = lodging.distanceFromTrailKm;
      if (distance == null || distance > maximumDistance) return false;
    }
    if (priceRangeEur case final selectedPriceRange?) {
      final priceMinimum = lodging.priceMinEur ?? lodging.priceMaxEur;
      final priceMaximum = lodging.priceMaxEur ?? lodging.priceMinEur;
      if (priceMinimum == null || priceMaximum == null) return false;
      if (priceMaximum < selectedPriceRange.start ||
          priceMinimum > selectedPriceRange.end) {
        return false;
      }
    }
    if (types.isNotEmpty) {
      final type = lodging.type?.trim().toLowerCase();
      if (type == null || !types.contains(type)) return false;
    }
    return true;
  }
}

class _AccommodationFilterSheet extends StatefulWidget {
  const _AccommodationFilterSheet({
    required this.initialFilters,
    required this.availableTypes,
    required this.availablePriceRange,
  });

  final _AccommodationFilters initialFilters;
  final List<String> availableTypes;
  final RangeValues? availablePriceRange;

  @override
  State<_AccommodationFilterSheet> createState() =>
      _AccommodationFilterSheetState();
}

class _AccommodationFilterSheetState extends State<_AccommodationFilterSheet> {
  late bool bookableOnlineOnly = widget.initialFilters.bookableOnlineOnly;
  late double? maximumDistanceKm = widget.initialFilters.maximumDistanceKm;
  late RangeValues? priceRangeEur = widget.initialFilters.priceRangeEur;
  late Set<String> selectedTypes = {...widget.initialFilters.types};

  _AccommodationFilters get selection => _AccommodationFilters(
    bookableOnlineOnly: bookableOnlineOnly,
    maximumDistanceKm: maximumDistanceKm,
    priceRangeEur: priceRangeEur,
    types: Set.unmodifiable(selectedTypes),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final availablePriceRange = widget.availablePriceRange;
    final displayedPriceRange = _clampPriceRange(
      priceRangeEur ?? availablePriceRange,
      availablePriceRange,
    );
    return Theme(
      data: EurotrexPalette.controlsTheme(Theme.of(context)),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('accommodation-filter-sheet'),
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccommodationFilterPanel(
                key: const ValueKey('accommodation-bookable-panel'),
                icon: Icons.language_rounded,
                title: l10n.t('Bookable online'),
                trailing: Switch.adaptive(
                  key: const ValueKey('accommodation-bookable-filter'),
                  value: bookableOnlineOnly,
                  onChanged: (value) =>
                      setState(() => bookableOnlineOnly = value),
                ),
              ),
              if (availablePriceRange != null &&
                  displayedPriceRange != null) ...[
                const SizedBox(height: 12),
                _AccommodationFilterPanel(
                  key: const ValueKey('accommodation-price-panel'),
                  icon: Icons.euro_rounded,
                  title: l10n.t('Price range'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ChoiceChip(
                            key: const ValueKey('accommodation-price-any'),
                            label: Text(l10n.t('Any price')),
                            selected: priceRangeEur == null,
                            onSelected: (_) =>
                                setState(() => priceRangeEur = null),
                          ),
                          const Spacer(),
                          Text(
                            priceRangeEur == null
                                ? l10n.t('Any price')
                                : _formatEuro(
                                    displayedPriceRange.start,
                                    displayedPriceRange.end,
                                    l10n,
                                  ),
                            key: const ValueKey(
                              'accommodation-price-selection',
                            ),
                            style: const TextStyle(
                              color: EurotrexPalette.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      RangeSlider(
                        key: const ValueKey('accommodation-price-range'),
                        values: displayedPriceRange,
                        min: availablePriceRange.start,
                        max: availablePriceRange.end,
                        divisions: _priceRangeDivisions(availablePriceRange),
                        labels: RangeLabels(
                          _formatEuro(displayedPriceRange.start, null, l10n),
                          _formatEuro(displayedPriceRange.end, null, l10n),
                        ),
                        onChanged: (values) =>
                            setState(() => priceRangeEur = values),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.availableTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _AccommodationFilterPanel(
                  key: const ValueKey('accommodation-types-panel'),
                  icon: Icons.category_outlined,
                  title: l10n.t('Accommodation type'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in widget.availableTypes)
                        FilterChip(
                          key: ValueKey(
                            'accommodation-type-${_filterKey(type)}',
                          ),
                          avatar: LodgingTypeIcon(
                            type: type,
                            color: lodgingMakiMarkerColor(type),
                            size: 18,
                          ),
                          label: Text(l10n.t(type)),
                          selected: selectedTypes.contains(type.toLowerCase()),
                          onSelected: (selected) => setState(() {
                            final normalizedType = type.toLowerCase();
                            if (selected) {
                              selectedTypes.add(normalizedType);
                            } else {
                              selectedTypes.remove(normalizedType);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('accommodation-filter-clear'),
                      onPressed: () => Navigator.of(context).pop(
                        _AccommodationFilters(
                          maximumDistanceKm:
                              widget.initialFilters.maximumDistanceKm,
                        ),
                      ),
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                      label: Text(l10n.t('Clear')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('accommodation-filter-apply'),
                      onPressed: () => Navigator.of(context).pop(selection),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(l10n.t('Apply')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccommodationDistanceFilterSheet extends StatefulWidget {
  const _AccommodationDistanceFilterSheet({
    required this.initialFilters,
    required this.formatter,
  });

  final _AccommodationFilters initialFilters;
  final MeasurementFormatter formatter;

  @override
  State<_AccommodationDistanceFilterSheet> createState() =>
      _AccommodationDistanceFilterSheetState();
}

class _AccommodationDistanceFilterSheetState
    extends State<_AccommodationDistanceFilterSheet> {
  late double? maximumDistanceKm = widget.initialFilters.maximumDistanceKm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: EurotrexPalette.controlsTheme(Theme.of(context)),
      child: SafeArea(
        child: Padding(
          key: const ValueKey('accommodation-distance-filter-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccommodationFilterPanel(
                key: const ValueKey('accommodation-distance-panel'),
                icon: Icons.gps_fixed_rounded,
                title: l10n.t('Maximum distance from trail'),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('accommodation-distance-any'),
                      label: Text(l10n.t('Any distance')),
                      selected: maximumDistanceKm == null,
                      onSelected: (_) =>
                          setState(() => maximumDistanceKm = null),
                    ),
                    for (final distance in _distanceFilterOptionsKm)
                      ChoiceChip(
                        key: ValueKey('accommodation-distance-$distance'),
                        label: Text(widget.formatter.distance(distance)),
                        selected: maximumDistanceKm == distance,
                        onSelected: (_) =>
                            setState(() => maximumDistanceKm = distance),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('accommodation-distance-clear'),
                      onPressed: () => Navigator.of(context).pop(
                        _AccommodationFilters(
                          bookableOnlineOnly:
                              widget.initialFilters.bookableOnlineOnly,
                          priceRangeEur: widget.initialFilters.priceRangeEur,
                          types: widget.initialFilters.types,
                        ),
                      ),
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                      label: Text(l10n.t('Clear')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('accommodation-distance-apply'),
                      onPressed: () => Navigator.of(context).pop(
                        _AccommodationFilters(
                          bookableOnlineOnly:
                              widget.initialFilters.bookableOnlineOnly,
                          maximumDistanceKm: maximumDistanceKm,
                          priceRangeEur: widget.initialFilters.priceRangeEur,
                          types: widget.initialFilters.types,
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(l10n.t('Apply')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccommodationFilterPanel extends StatelessWidget {
  const _AccommodationFilterPanel({
    required this.icon,
    required this.title,
    this.child,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EurotrexPalette.paleBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: EurotrexPalette.paleBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: EurotrexPalette.navy, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: EurotrexPalette.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: 10),
                trailing,
              ],
            ],
          ),
          if (child case final child?) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

class _AccommodationBottomNavigationBar extends StatelessWidget {
  const _AccommodationBottomNavigationBar({
    required this.activeFilterCount,
    required this.hasDistanceFilter,
    required this.onStages,
    required this.onFilter,
    required this.onDistanceFilter,
    required this.onMap,
    required this.onElevation,
  });

  final int activeFilterCount;
  final bool hasDistanceFilter;
  final VoidCallback onStages;
  final VoidCallback onFilter;
  final VoidCallback onDistanceFilter;
  final VoidCallback onMap;
  final VoidCallback onElevation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      key: const ValueKey('accommodation-bottom-navigation'),
      color: EurotrexPalette.navy,
      child: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('accommodation-bottom-navigation-size'),
          height: 48,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AccommodationBottomAction(
                key: const ValueKey('accommodation-stages-shortcut'),
                icon: Icons.hiking_rounded,
                label: l10n.t('Back to stages'),
                onTap: onStages,
              ),
              _AccommodationBottomAction(
                key: const ValueKey('accommodation-filter'),
                icon: Icons.filter_list_rounded,
                label: l10n.t('Filter'),
                isActive: activeFilterCount > 0,
                badgeCount: activeFilterCount,
                onTap: onFilter,
              ),
              _AccommodationBottomAction(
                key: const ValueKey('accommodation-gps'),
                icon: hasDistanceFilter
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                label: l10n.t('Maximum distance from trail'),
                isActive: hasDistanceFilter,
                isPrimary: true,
                onTap: onDistanceFilter,
              ),
              _AccommodationBottomAction(
                key: const ValueKey('accommodation-map'),
                icon: Icons.map_outlined,
                label: l10n.t('Show on map'),
                onTap: onMap,
              ),
              _AccommodationBottomAction(
                key: const ValueKey('accommodation-elevation'),
                icon: Icons.landscape_outlined,
                label: l10n.t('Elevation'),
                onTap: onElevation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccommodationBottomAction extends StatelessWidget {
  const _AccommodationBottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isPrimary = false,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isPrimary;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final foreground = onTap == null
        ? Colors.white30
        : isActive
        ? Colors.white
        : Colors.white70;
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: isActive,
          enabled: onTap != null,
          label: label,
          child: InkWell(
            splashColor: Colors.white12,
            highlightColor: Colors.white10,
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Badge(
                    isLabelVisible: badgeCount > 0,
                    backgroundColor: _yellow,
                    textColor: _ink,
                    label: Text('$badgeCount'),
                    child: isPrimary
                        ? Container(
                            key: const ValueKey(
                              'accommodation-bottom-gps-surface',
                            ),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? EurotrexPalette.blue
                                  : Colors.white.withValues(alpha: 0.055),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(icon, color: foreground, size: 22),
                            ),
                          )
                        : SizedBox.square(
                            dimension: 24,
                            child: Center(
                              child: Icon(icon, color: foreground, size: 22),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final rawPhone = lodging.phone?.trim();
    final phone = lodging.dialingPhoneNumber;
    final whatsapp = lodging.whatsapp?.trim();
    final email = lodging.email?.trim();
    final phoneUri = lodging.phoneUri;
    final emailUri = lodging.emailUri;
    final bookingUri = lodging.bookingUri;
    final markerColor = lodgingMakiMarkerColor(type);
    final locationText = [
      if (address != null && address.isNotEmpty) address,
      if (village != null && village.isNotEmpty && village != address) village,
    ].join(' · ');
    final hasContactActions =
        lodging.location != null || phoneUri != null || emailUri != null;
    final hasStaticLocation =
        lodging.location == null && locationText.isNotEmpty;
    final hasWhatsapp =
        whatsapp != null && whatsapp.isNotEmpty && whatsapp != rawPhone;
    final facts = <_LodgingFactData>[
      if (_formatPrice(lodging, l10n) case final price?)
        _LodgingFactData(
          icon: Icons.euro_rounded,
          label: l10n.t('Price'),
          value: price,
        ),
      if (lodging.distanceFromTrailKm case final distance?)
        _LodgingFactData(
          icon: Icons.gps_fixed_rounded,
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
                  key: ValueKey('lodging-type-marker-${lodging.id}'),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: LodgingTypeIcon(
                      type: type,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
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
                          style: TextStyle(
                            color: markerColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (hasContactActions || hasStaticLocation || hasWhatsapp) ...[
              const SizedBox(height: 14),
              if (hasContactActions)
                Row(
                  key: ValueKey('lodging-contact-actions-${lodging.id}'),
                  children: [
                    if (lodging.location != null)
                      _ContactActionButton(
                        key: ValueKey('map-location-lodging-${lodging.id}'),
                        tooltip: l10n.t('Show on map'),
                        icon: const Icon(Icons.location_on_outlined),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MapScreen(initialLodging: lodging),
                          ),
                        ),
                      ),
                    if (lodging.location != null && phoneUri != null)
                      const SizedBox(width: 10),
                    if (phoneUri != null)
                      _ContactActionButton(
                        key: ValueKey('call-lodging-${lodging.id}'),
                        tooltip:
                            '${l10n.t('Phone')}: ${_formatPhoneForDisplay(phone!)}',
                        icon: const Icon(Icons.phone_outlined),
                        onTap: () => _openExternal(context, ref, phoneUri),
                      ),
                    if ((lodging.location != null || phoneUri != null) &&
                        emailUri != null)
                      const SizedBox(width: 10),
                    if (emailUri != null)
                      _ContactActionButton(
                        key: ValueKey('email-lodging-${lodging.id}'),
                        tooltip: '${l10n.t('Email')}: $email',
                        icon: const Icon(Icons.email_outlined),
                        onTap: () => _openExternal(context, ref, emailUri),
                      ),
                  ],
                ),
              if (hasContactActions && (hasStaticLocation || hasWhatsapp))
                const SizedBox(height: 8),
              if (hasStaticLocation || hasWhatsapp)
                SelectionArea(
                  child: Column(
                    children: [
                      if (hasStaticLocation)
                        _ContactRow(
                          icon: Icons.location_on_outlined,
                          value: locationText,
                        ),
                      if (hasWhatsapp)
                        _ContactRow(
                          icon: Icons.chat_outlined,
                          label: l10n.t('WhatsApp'),
                          value: whatsapp,
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
            if (bookingUri != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ValueKey('book-lodging-${lodging.id}'),
                  onPressed: () => _openExternal(context, ref, bookingUri),
                  style: FilledButton.styleFrom(
                    backgroundColor: _bookingBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l10n.t('Book')),
                ),
              ),
            ],
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

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: _bookingBlue.withValues(alpha: 0.07),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _bookingBlue.withValues(alpha: 0.18)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
              child: IconTheme(
                data: const IconThemeData(color: _bookingBlue, size: 22),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
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

List<String> _availableLodgingTypes(Iterable<Lodging> lodgings) {
  final typesByNormalizedName = <String, String>{};
  for (final lodging in lodgings) {
    final type = lodging.type?.trim();
    if (type == null || type.isEmpty) continue;
    typesByNormalizedName.putIfAbsent(type.toLowerCase(), () => type);
  }
  final types = typesByNormalizedName.values.toList(growable: false);
  types.sort(
    (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return types;
}

RangeValues? _availableLodgingPriceRange(Iterable<Lodging> lodgings) {
  double? minimum;
  double? maximum;
  for (final lodging in lodgings) {
    final low = lodging.priceMinEur ?? lodging.priceMaxEur;
    final high = lodging.priceMaxEur ?? lodging.priceMinEur;
    if (low == null || high == null || low < 0 || high < 0) continue;
    minimum = minimum == null || low < minimum ? low : minimum;
    maximum = maximum == null || high > maximum ? high : maximum;
  }
  if (minimum == null || maximum == null) return null;

  final roundedMinimum = (minimum / 10).floor() * 10.0;
  var roundedMaximum = (maximum / 10).ceil() * 10.0;
  if (roundedMaximum <= roundedMinimum) roundedMaximum = roundedMinimum + 10;
  return RangeValues(roundedMinimum, roundedMaximum);
}

RangeValues? _clampPriceRange(RangeValues? selected, RangeValues? available) {
  if (selected == null || available == null) return null;
  final start = selected.start.clamp(available.start, available.end).toDouble();
  final end = selected.end.clamp(available.start, available.end).toDouble();
  return start <= end ? RangeValues(start, end) : RangeValues(end, start);
}

int _priceRangeDivisions(RangeValues range) =>
    ((range.end - range.start) / 5).round().clamp(1, 100);

String _filterKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

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
  if (_usesPostfixedEuro(l10n.locale.languageCode)) {
    return '${high == null ? low : '$low–$high'}\u00a0€';
  }
  return high == null ? '€$low' : '€$low–€$high';
}

String _formatNumber(double value, AppLocalizations l10n) {
  final amount = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return _usesPostfixedEuro(l10n.locale.languageCode)
      ? amount.replaceFirst('.', ',')
      : amount;
}

bool _usesPostfixedEuro(String languageCode) =>
    const {'de', 'es', 'it', 'fr'}.contains(languageCode);

String _formatPhoneForDisplay(String number) {
  if (!number.startsWith('+357')) return number;
  final national = number.substring(4);
  if (national.length != 8) return '+357 $national';
  return '+357 ${national.substring(0, 2)} '
      '${national.substring(2, 5)} ${national.substring(5)}';
}
