# Map Improvements

Proposed improvements for EuroTrex, recorded on 13 October 2026. The optional 3D stage preview now has a mobile prototype for review (14 October 2026). The other items remain suggestions.

The priorities are helping hikers stay on the trail, understand what lies ahead and use the app without reception. Some features are provided directly by Mapbox; others combine Mapbox with EuroTrex’s GPS, trail and report data.

## Recommended first release

1. **Off-trail alerts** — warn when a hiker consistently moves away from the official trail.
2. **Issues ahead** — surface approved problems before the hiker reaches them.
3. **Hiking progress** — show distance, ascent and estimated arrival for the selected destination.

These build on existing functionality and would be useful during most hikes.

## Suggestions

| Priority | Feature | Proposed behaviour and value |
| --- | --- | --- |
| High | Off-trail alerts | Warn when someone consistently moves away from the official trail, with a vibration and distance back to it. Use GPS accuracy and several readings to avoid false alarms. Implement using GPS and the downloaded trail geometry. |
| High | Issues ahead | Show messages such as “Rockfall ahead — 800 m” along the selected trail direction, before the hiker reaches the warning triangle. Calculate distance along the trail rather than straight-line distance. |
| High | Hiking progress on the map | Add a compact panel showing distance remaining, ascent remaining and estimated arrival at the selected stage or lodging. Visually distinguish completed and remaining trail sections using Mapbox layers. |
| High | More useful offline downloads | Let hikers download their planned stages and choose terrain or satellite imagery, with download size and coverage clearly shown. Include POIs and approved issues, with a “last updated” date. Mapbox map resources and EuroTrex report data need separate offline storage. |
| Medium | Explicit “Follow me” mode | Keep the hiker centred, optionally facing their direction of travel. Dragging the map pauses following; tapping GPS resumes it. Preserve the chosen zoom to avoid the reset problem previously fixed. |
| Medium | Grouped POIs and issues | When zoomed out, show grouped markers such as “4 lodgings” or “3 issues”. Tapping expands them. This makes busy areas easier to read. |
| Medium | Optional 3D stage preview | Let hikers tilt the terrain to understand an upcoming climb, valley or descent before starting. Keep the normal hiking view simple and make 3D an optional preview. |
| Later | “What can I reach in 30 minutes?” | Show a walking-reach area around the hiker to help find nearby villages or services. Mapbox walking isochrones provide estimates and do not automatically account for EuroTrex’s reported trail damage. |

## 3D preview prototype

Open **3D stage preview** from stage details or the expanded stage card on the map. A separate screen shows that stage's trail section over Mapbox terrain at natural elevation, with 2D/3D comparison, pan, zoom, rotation and a reset control. The normal map retains its own state. This first version needs an internet connection for terrain data.

## Routing and reported problems

Displaying an approved obstruction on the EuroTrex map does **not** automatically make Mapbox directions avoid it. Mapbox’s routing service is separate from the Firebase report collection.

The recommended first step is to warn hikers when a suggested route intersects a reported problem. Verified alternative routes can be considered afterwards.

## Mapbox references

- [Map layers](https://docs.mapbox.com/flutter/maps/guides/styles/work-with-layers/)
- [Offline maps](https://docs.mapbox.com/flutter/maps/examples/offline/)
- [Location-following camera](https://docs.mapbox.com/flutter/maps/api/latest/mapbox_maps_flutter/FollowPuckViewportState-class.html)
- [Point clustering](https://docs.mapbox.com/flutter/maps/api/latest/mapbox_maps_flutter/GeoJsonSource/cluster.html)
- [Flutter Maps SDK and 3D terrain](https://docs.mapbox.com/flutter/maps/guides/)
- [Walking isochrones](https://docs.mapbox.com/api/navigation/isochrone/)
- [Directions API](https://docs.mapbox.com/api/navigation/directions/)
