import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide Size, ImageSource;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/location/device_location.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/eurotrex_chrome_theme.dart';
import '../../../core/theme/eurotrex_palette.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../stages/domain/trail_location_matcher.dart';
import '../../stages/presentation/stages_controller.dart';
import '../../trail/domain/trail_direction.dart';
import '../data/report_photos.dart';
import '../data/report_store.dart';
import '../data/report_sync.dart';
import 'report_card_header.dart';

const _reportSand = Color(0xFFF4F2EC);
const _reportSurface = Color(0xFFFBFAF6);

ThemeData _reportTheme(ThemeData base) =>
    EurotrexPalette.controlsTheme(base).copyWith(
      scaffoldBackgroundColor: _reportSand,
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: EurotrexPalette.paleBlue),
        ),
      ),
    );

Widget _reportTitle(String title) => Text(
  title,
  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
);

Widget _reportMenuItem(IconData icon, String title) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, color: EurotrexPalette.blue, size: 22),
    const SizedBox(width: 12),
    Flexible(child: Text(title)),
  ],
);

class _ReportPane extends StatelessWidget {
  const _ReportPane({
    required this.title,
    required this.icon,
    required this.children,
    this.detail,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: EurotrexPalette.paleBlue),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EurotrexPalette.paleBlue.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: EurotrexPalette.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (detail != null)
              Text(
                detail!,
                style: const TextStyle(
                  color: EurotrexPalette.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        ...children,
      ],
    ),
  );
}

const reportCategoryLabels = {
  'signpost': 'Damaged or missing signpost',
  'vegetation': 'Overgrown vegetation',
  'obstruction': 'Obstruction or rockfall',
  'path_damage': 'Damaged path',
  'other': 'Other',
};
const reportStatusLabels = {
  'new': 'Received',
  'reviewed': 'Reviewed',
  'forwarded': 'Sent',
  'resolved': 'Resolved',
  'duplicate': 'Duplicate',
  'dismissed': 'Dismissed',
  'uploading': 'Uploading…',
};
const reportAccessLabels = {
  'passable': 'Passable',
  'difficult': 'Difficult',
  'blocked': 'Blocked',
  'unsure': 'Unsure',
};

class ReportMenu extends StatelessWidget {
  const ReportMenu({super.key, required this.trailId, this.stageId});
  final String trailId;
  final String? stageId;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: context.l10n.t('Report trail problems'),
    icon: const Icon(Icons.warning_amber_rounded),
    position: PopupMenuPosition.under,
    color: _reportSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: EurotrexPalette.paleBlue),
    ),
    onSelected: (action) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => action == 'new'
            ? ReportScreen(trailId: trailId, stageId: stageId)
            : const MyReportsScreen(),
      ),
    ),
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'new',
        textStyle: const TextStyle(
          color: EurotrexPalette.navy,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        child: _reportMenuItem(
          Icons.warning_amber_rounded,
          context.l10n.t('Report trail problems'),
        ),
      ),
      PopupMenuItem(
        value: 'mine',
        textStyle: const TextStyle(
          color: EurotrexPalette.navy,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        child: _reportMenuItem(
          Icons.assignment_outlined,
          context.l10n.t('My reports'),
        ),
      ),
    ],
  );
}

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    super.key,
    required this.trailId,
    this.stageId,
    this.draft,
  });
  final String trailId;
  final String? stageId;
  final ReportDraft? draft;
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late ReportDraft draft;
  late TextEditingController description, contact;
  bool busy = false;
  String? error;
  Future<void> _saves = Future.value();
  @override
  void initState() {
    super.initState();
    draft =
        widget.draft ??
        ReportDraft(
          id: const Uuid().v4(),
          trailId: widget.trailId,
          stageId: widget.stageId,
          createdAt: DateTime.now().toUtc(),
        );
    description = TextEditingController(text: draft.description);
    contact = TextEditingController(text: draft.contactEmail);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.draft == null) {
        await save();
        if (mounted) await locate();
      }
    });
  }

  Future<void> save() {
    draft.description = description.text;
    draft.contactEmail = contact.text;
    final snapshot = ReportDraft.fromJson(draft.toJson());
    final store = ref.read(reportStoreProvider);
    _saves = _saves.catchError((_) {}).then((_) => store.save(snapshot));
    return _saves;
  }

  void autosave() {
    unawaited(
      save().catchError((_) {
        if (mounted) {
          setState(
            () => error =
                'Your draft could not be saved. Please free some device storage.',
          );
        }
      }),
    );
  }

  @override
  void dispose() {
    description.dispose();
    contact.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final location = await ref.read(deviceLocationReaderProvider)();
      if (!mounted) return;
      draft.latitude = location.latitude;
      draft.longitude = location.longitude;
      draft.accuracyM = location.accuracyM;
      draft.locationSource = 'gps';
      draft.locationConfirmed = false;
      matchStage();
      await save();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Location is unavailable. Choose the problem location on the map or enter coordinates.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void matchStage() {
    if (draft.trailId != cyprusE4TrailId || draft.latitude == null) return;
    final points = ref.read(elevationProvider).value;
    final stages = ref.read(stagesProvider).value;
    if (points == null || stages == null) return;
    final match = findNearbyTrailStage(
      latitude: draft.latitude!,
      longitude: draft.longitude!,
      locationAccuracyM: draft.accuracyM ?? 0,
      routePoints: points,
      stages: stages,
      direction: TrailDirection.pafosToLarnaka,
      proximityThresholdM: 500,
    );
    draft.stageId = match?.stageId ?? draft.stageId;
  }

  Future<void> chooseLocation() async {
    final result = await Navigator.of(context).push<(double, double)>(
      MaterialPageRoute(
        builder: (_) => ReportLocationScreen(
          latitude: draft.latitude ?? 34.89,
          longitude: draft.longitude ?? 32.87,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      draft.latitude = result.$1;
      draft.longitude = result.$2;
      draft.accuracyM = null;
      draft.locationSource = 'pin';
      draft.locationConfirmed = true;
    });
    matchStage();
    await save();
  }

  Future<void> photo(ImageSource source) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await save();
      await markReportPhotoPicker(draft.id);
      final selected = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (selected != null) {
        final path = await importReportPhoto(selected, draft.id);
        draft.photos = [...draft.photos, path];
        await save();
      }
      await markReportPhotoPicker(null);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not add this photo. Check camera/photo access or choose another image.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    draft.description = description.text;
    draft.contactEmail = contact.text;
    // Sending confirms the displayed GPS/pin; no separate checkbox is needed.
    draft.locationConfirmed = draft.latitude != null && draft.longitude != null;
    if (!draft.valid) {
      setState(
        () => error =
            'Add a description, choose a location, and check the optional email.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      draft.appVersion = '${info.version}+${info.buildNumber}';
      draft.state = 'queued';
      await save();
      final sync = ref.read(reportSyncProvider);
      sync.changed();
      unawaited(sync.sync());
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MyReportsScreen()),
        );
      }
    } catch (_) {
      draft.state = 'draft';
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not save the report. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String s) => context.l10n.t(s);
    return Theme(
      data: _reportTheme(Theme.of(context)),
      child: Scaffold(
        appBar: EurotrexChromeTheme.appBar(
          title: _reportTitle(t('Report trail problems')),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
            children: [
              _ReportPane(
                title: t('Problem'),
                icon: Icons.warning_amber_rounded,
                children: [
                  DropdownButtonFormField<String>(
                    dropdownColor: _reportSurface,
                    borderRadius: BorderRadius.circular(16),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: EurotrexPalette.blue,
                    ),
                    style: const TextStyle(
                      color: EurotrexPalette.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    initialValue: draft.category,
                    decoration: InputDecoration(labelText: t('Problem type')),
                    items: [
                      for (final entry in reportCategoryLabels.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(
                                reportDamageIcon(entry.key),
                                size: 22,
                                color: EurotrexPalette.navy,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t(entry.value),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    isExpanded: true,
                    onChanged: busy
                        ? null
                        : (v) {
                            draft.category = v!;
                            autosave();
                          },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: description,
                    maxLength: 500,
                    minLines: 3,
                    maxLines: 5,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: t('What is the problem?'),
                      hintText: t(
                        'Describe what happened and what needs attention.',
                      ),
                    ),
                    onChanged: (_) => autosave(),
                  ),

                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    dropdownColor: _reportSurface,
                    borderRadius: BorderRadius.circular(16),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: EurotrexPalette.blue,
                    ),
                    style: const TextStyle(
                      color: EurotrexPalette.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    initialValue: draft.passability,
                    decoration: InputDecoration(
                      labelText: t('Can hikers pass?'),
                    ),
                    items: [
                      for (final entry in reportAccessLabels.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(t(entry.value)),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            draft.passability = v!;
                            autosave();
                          },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ReportPane(
                title: t('Location'),
                icon: Icons.location_on_outlined,
                children: [
                  if (draft.latitude != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _reportSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${draft.latitude!.toStringAsFixed(6)}, ${draft.longitude!.toStringAsFixed(6)}${draft.accuracyM == null ? '' : ' · ±${draft.accuracyM!.round()} m'}',
                        style: const TextStyle(
                          color: EurotrexPalette.navy,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : locate,
                        icon: const Icon(Icons.my_location),
                        label: Text(t('Use GPS')),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : chooseLocation,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: Text(t('Choose on map')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ReportPane(
                title: t('Photos'),
                icon: Icons.photo_library_outlined,
                detail: '${draft.photos.length}/3',
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final path in draft.photos)
                        SizedBox(
                          width: 94,
                          height: 112,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton.filled(
                                  tooltip: t('Remove photo'),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          setState(
                                            () => draft.photos = draft.photos
                                                .where((p) => p != path)
                                                .toList(),
                                          );
                                          await save();
                                          await File(path).delete();
                                        },
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (draft.photos.isNotEmpty) const SizedBox(height: 16),
                  if (draft.photos.length < 3)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => photo(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(t('Camera')),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => photo(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(t('Photo library')),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: contact,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                maxLength: 254,
                decoration: InputDecoration(
                  labelText: t('Email for follow-up (optional)'),
                ),
                onChanged: (_) => autosave(),
              ),
              Text(
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontSize: 12,
                  height: 1.5,
                ),
                t(
                  'Your location, description and photos will be shared with the assigned trail team and may be forwarded to the responsible authority. Your email is excluded from exports by default.',
                ),
              ),
              const SizedBox(height: 20),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    t(error!),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              FilledButton.icon(
                onPressed: busy ? null : submit,
                icon: const Icon(Icons.send_outlined),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                label: Text(t('Send report')),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        await save();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: Text(t('Save draft')),
              ),
              Text(
                style: const TextStyle(
                  color: EurotrexPalette.navy,
                  fontSize: 12,
                  height: 1.5,
                ),
                t(
                  'Offline? Your report and photos stay on this device and upload when you reopen the app with a connection.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(reportSyncProvider);
    return Theme(
      data: _reportTheme(Theme.of(context)),
      child: Scaffold(
        appBar: EurotrexChromeTheme.appBar(
          title: _reportTitle(context.l10n.t('My reports')),
          actions: [
            IconButton(
              tooltip: context.l10n.t('Retry uploads'),
              onPressed: sync.sync,
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: sync,
          builder: (context, _) => FutureBuilder<List<ReportDraft>>(
            future: ref.read(reportStoreProvider).all(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    context.l10n.t('Saved reports could not be read.'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return Center(child: Text(context.l10n.t('No reports yet.')));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final draft in snapshot.data!)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReportCardHeader(
                              category: draft.category,
                              title: context.l10n.t(
                                reportCategoryLabels[draft.category] ?? 'Other',
                              ),
                              uploadState: draft.state,
                              remoteStatus: draft.remoteStatus,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              draft.description.isEmpty
                                  ? context.l10n.t('Draft')
                                  : draft.description,
                            ),
                            if (draft.state == 'sent') ...[
                              const SizedBox(height: 12),
                              SelectableText(
                                '${context.l10n.t('Reference')}: ${draft.id}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (draft.error.isNotEmpty)
                              Text(
                                context.l10n.t(
                                  reportErrorMessages.contains(draft.error)
                                      ? draft.error
                                      : reportUploadFailure,
                                ),
                              ),
                            Wrap(
                              children: [
                                if (draft.editable)
                                  TextButton(
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ReportScreen(
                                            trailId: draft.trailId,
                                            draft: draft,
                                          ),
                                        ),
                                      );
                                      sync.changed();
                                    },
                                    child: Text(
                                      context.l10n.t('Continue draft'),
                                    ),
                                  ),
                                if (draft.state == 'failed' ||
                                    draft.state == 'queued')
                                  TextButton(
                                    onPressed: sync.sync,
                                    child: Text(
                                      context.l10n.t('Retry uploads'),
                                    ),
                                  ),
                                if (draft.state == 'sent')
                                  TextButton(
                                    onPressed: () => sync.refreshReceipt(draft),
                                    child: Text(
                                      context.l10n.t('Refresh status'),
                                    ),
                                  ),
                                if (draft.editable || draft.state == 'sent')
                                  TextButton(
                                    onPressed: () async {
                                      final remove = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: Text(
                                            context.l10n.t(
                                              'Remove from this device?',
                                            ),
                                          ),
                                          content: Text(
                                            context.l10n.t(
                                              'A submitted report remains with the trail team.',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: Text(
                                                context.l10n.t('Cancel'),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: Text(
                                                context.l10n.t('Remove'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (remove == true) {
                                        await ref
                                            .read(reportStoreProvider)
                                            .remove(draft);
                                        sync.changed();
                                      }
                                    },
                                    child: Text(context.l10n.t('Remove')),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class ReportLocationScreen extends StatefulWidget {
  const ReportLocationScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });
  final double latitude, longitude;
  @override
  State<ReportLocationScreen> createState() => _ReportLocationScreenState();
}

class _ReportLocationScreenState extends State<ReportLocationScreen> {
  MapboxMap? map;
  late double latitude = widget.latitude, longitude = widget.longitude;
  bool moved = false;
  final lat = TextEditingController(), lng = TextEditingController();
  @override
  void initState() {
    super.initState();
    lat.text = latitude.toStringAsFixed(6);
    lng.text = longitude.toStringAsFixed(6);
  }

  @override
  void dispose() {
    lat.dispose();
    lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _reportTheme(Theme.of(context)),
    child: Scaffold(
      appBar: EurotrexChromeTheme.appBar(
        title: _reportTitle(context.l10n.t('Choose problem location')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.t(
                'Move the map until the pin is on the problem. You can also enter coordinates.',
              ),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (const String.fromEnvironment('MAPBOX_ACCESS_TOKEN') != '')
                  MapWidget(
                    styleUri: MapboxStyles.OUTDOORS,
                    viewport: CameraViewportState(
                      center: Point(coordinates: Position(longitude, latitude)),
                      zoom: 15,
                    ),
                    onMapCreated: (value) => map = value,
                    onScrollListener: (_) => moved = true,
                    onMapIdleListener: (_) async {
                      if (map == null || !moved) return;
                      final camera = await map!.getCameraState();
                      if (!mounted) return;
                      latitude = camera.center.coordinates.lat.toDouble();
                      longitude = camera.center.coordinates.lng.toDouble();
                      lat.text = latitude.toStringAsFixed(6);
                      lng.text = longitude.toStringAsFixed(6);
                    },
                  ),
                const IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Icon(
                      Icons.location_pin,
                      size: 42,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: lat,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.t('Latitude'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lng,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.t('Longitude'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    final a = double.tryParse(lat.text),
                        b = double.tryParse(lng.text);
                    if (a == null ||
                        b == null ||
                        !a.isFinite ||
                        !b.isFinite ||
                        a.abs() > 90 ||
                        b.abs() > 180) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.t(
                              'Enter valid latitude and longitude.',
                            ),
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, (a, b));
                  },
                  child: Text(context.l10n.t('Use this location')),
                ),
                const SafeArea(top: false, child: SizedBox(height: 4)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
