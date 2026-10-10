import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/eurotrex_palette.dart';

enum MapBackground {
  terrain('Terrain', MapboxStyles.OUTDOORS, Icons.terrain_outlined),
  streets('Streets', MapboxStyles.MAPBOX_STREETS, Icons.map_outlined),
  satellite('Satellite', MapboxStyles.SATELLITE, Icons.satellite_alt_rounded),
  satelliteLabels(
    'Satellite with labels',
    MapboxStyles.SATELLITE_STREETS,
    Icons.satellite_outlined,
  );

  const MapBackground(this.label, this.styleUri, this.icon);
  final String label;
  final String styleUri;
  final IconData icon;
}

class MapBackgroundSheet extends StatelessWidget {
  const MapBackgroundSheet({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final MapBackground selected;
  final ValueChanged<MapBackground> onSelect;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF4F2EC),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.layers_outlined, color: EurotrexPalette.navy),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.t('Map layers'),
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
            for (final background in MapBackground.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selected == background
                          ? EurotrexPalette.blue
                          : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    key: ValueKey('map-background-${background.name}'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minVerticalPadding: 12,
                    leading: Icon(background.icon, color: EurotrexPalette.navy),
                    title: Text(
                      context.l10n.t(background.label),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: selected == background,
                    selectedColor: EurotrexPalette.blue,
                    trailing: Icon(
                      selected == background
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected == background
                          ? EurotrexPalette.blue
                          : Colors.grey,
                    ),
                    onTap: () => onSelect(background),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              context.l10n.t(
                'Terrain is included in offline downloads. Other layers need an internet connection.',
              ),
              style: const TextStyle(
                color: EurotrexPalette.navy,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
