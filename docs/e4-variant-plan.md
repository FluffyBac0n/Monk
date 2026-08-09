# E4 Variant — Analysis and Integration Plan

Last reviewed: 2026-08-09

## Source Data

- Variant workbook: `/Users/amich/Downloads/E4 Variant.xlsx`
- Variant sheet: `E4 Variant-csv`
- Current E4 workbook: `data/Cyprus_E4_Data_v4 - Cleaned-nopass.xlsx`
- Current route sheet: `Map & Elevation`
- Current stage sheet: `E4 Cyprus STAGES`

The supplied variant workbook contains raw route geometry only:

| Column | Meaning |
| --- | --- |
| `Latitude` | GPS latitude |
| `Longitude` | GPS longitude |
| `Altitude` | Elevation in metres |

It contains 6,039 route points. It does not currently include a variant ID,
name, stage boundaries, services, accommodation, descriptive text, or route
status.

## Calculated Variant Metrics

| Metric | Calculated value |
| --- | ---: |
| Route distance | 45.766 km |
| Elevation ascent | 2,065 m |
| Elevation descent | 1,705 m |
| Minimum altitude | 120 m |
| Maximum altitude | 1,139 m |
| Direct endpoint separation | 21.707 km |
| Naismith walking estimate | 756 minutes / 12 h 36 min |

The walking estimate is a route comparison value, not a recommended daily
itinerary. Elevation totals are calculated from the supplied raw altitude data
and may require smoothing if the source contains GPS elevation noise.

## Connections to the Main E4

### Start connection

| Field | Value |
| --- | --- |
| Variant location | `34.79023685, 32.52940035` |
| Variant altitude | 139.5 m |
| Distance from the E4 | 0.0019 km / approximately 2 m |
| Main-trail distance | 14.750 km from the Pafos start |
| Main E4 leg | Agia Varvara (Stage 121) → Episkopi Pafou (Stage 120) |
| Closest stage endpoint | Episkopi Pafou (Stage 120) |

### Finish connection

| Field | Value |
| --- | --- |
| Variant location | `34.931821, 32.693193` |
| Variant altitude | 499.1 m |
| Distance from the E4 | 0.0052 km / approximately 5 m |
| Main-trail distance | 188.977 km from the Pafos start |
| Main E4 leg | Cedar Valley (Stage 82) → Kykkos Monastery (Stage 81) |
| Closest stage endpoint | Cedar Valley (Stage 82) |

The variant therefore branches and rejoins in the middle of existing E4 legs,
not directly at stage endpoints.

## Comparison with the Main E4

| Metric | Main E4 section | Variant | Difference |
| --- | ---: | ---: | ---: |
| Distance | 174.227 km | 45.766 km | -128.461 km |
| Elevation ascent | 6,495 m | 2,065 m | -4,430 m |
| Elevation descent | 6,136 m | 1,705 m | -4,430 m |
| Naismith estimate | 2,740 min / 45 h 40 min | 756 min / 12 h 36 min | -1,984 min |

The replaced main-route section contains 39 E4 stage endpoints, covering Stage
120 through Stage 82. The variant rejoins during the following leg toward Stage
81.

Sampled separation from the main E4:

| Statistic | Distance |
| --- | ---: |
| Minimum | 0.002 km |
| Median | 5.934 km |
| 90th percentile | 9.634 km |
| Maximum | 11.093 km |

This confirms that the route is a substantial alternative corridor. It is not
an excursion and is too large to present like the current short detour.

## Recommended Classification

Introduce a dedicated `variant` route type.

The importer can share the geometry and comparison calculations already used
for detours:

- Project the first and last points onto the main E4.
- Calculate start and finish connections.
- Calculate the replaced main-route distance and elevation.
- Calculate distance, elevation, and walking-time differences.
- Determine the affected E4 stages.
- Produce ordered, chunked geometry for Firestore.

The app presentation should remain distinct from detours because this variant
replaces a multi-day, 39-stage section.

## Proposed Firestore Structure

```text
trails/{trailId}/variants/{variantId}
  routeChunks/{chunkId}
  stages/{variantStageId}        # optional until stage data is available
```

Suggested variant document fields:

```text
id
trailId
nameByLocale
descriptionByLocale
officialStatus
routeType                       # oneWay
displayType                     # variant
routeVersion
startConnection
endConnection
routeDistanceKm
elevationUpM
elevationDownM
estimatedWalkingTimeMinutes
replacedMainTrailDistanceKm
replacedElevationUpM
replacedElevationDownM
replacedEstimatedWalkingTimeMinutes
distanceDifferenceKm
elevationUpDifferenceM
elevationDownDifferenceM
estimatedWalkingTimeDifferenceMinutes
averageDistanceFromTrailKm
maximumDistanceFromTrailKm
affectedStageIds
affectedStageSequences
affectedStageNames
pointCount
chunkCount
chunkSize
pointFormat
pointStride
bounds
```

Route chunks should use the existing five-value route format:

```text
[lat, lng, altitudeM, distanceKm, reverseDistanceKm, ...]
```

The importer should preserve the full source geometry for offline navigation
and may also create a simplified display geometry if map performance requires
it.

## Recommended Stages Experience

At the branch point, show a route-choice panel:

```text
MAIN E4
174.2 km · 39 stage endpoints

E4 VARIANT
45.8 km · 2,065 m ascent · 12 h 36 min estimated walking
```

Recommended behavior:

1. Keep the Main E4 selected by default.
2. Let the user select the variant explicitly.
3. When selected, replace the bypassed E4 section in the timeline with the
   variant's stages.
4. Reconnect the timeline to the main E4 automatically near the Kykkos leg.
5. Remember the selection for GPS, maps, elevation, filtering, offline data,
   and reverse direction.
6. Avoid rendering the main route and variant side-by-side for all 39 affected
   stages. A compact choice followed by a selected timeline is clearer.

Until real variant stages are supplied, the route can appear as one summary
card. This should be considered an interim presentation only.

## Recommended Map and Elevation Experience

- Add a localized `Variants` show/hide control.
- Draw variants with a distinctive dashed light-blue or cyan line.
- Mark the split and rejoin locations.
- When the variant is selected, keep it prominent and visually mute the
  replaced Main E4 section.
- Fit the camera to the selected route and its two connections.
- Provide an elevation comparison between Main E4 and Variant.
- Ensure the selected route is included in offline map downloads.
- Use the selected geometry for GPS proximity and nearest-stage calculations.
- Reverse the connections, elevation direction, and variant stages when the
  main trail direction is reversed.

## Filtering and Trail Information

- Add `Variants` to Points of Interest filtering as a route-related option.
- Show a variant badge on affected main-route stages.
- Explain that selecting the variant bypasses the listed Main E4 section.
- Keep all application labels localized.
- Store imported display text using localization maps or localization keys;
  do not introduce English-only UI strings.

## Suggested Workbook Format

For integration into the main E4 workbook, add a `Variants` sheet using a
simple structure similar to `Detours`:

| Column | Required | Notes |
| --- | --- | --- |
| `Variant ID` | Yes | Stable identifier repeated for every point |
| `Variant Name` | Yes | Source name; localized names can be added separately |
| `Latitude` | Yes | Raw GPS latitude |
| `Longitude` | Yes | Raw GPS longitude |
| `Altitude` | Yes | Raw elevation in metres |

The importer should calculate all connection, distance, elevation, comparison,
affected-stage, bounds, and route-chunk fields. These should not be manually
maintained by the third-party workbook provider.

Optional future columns:

- `Variant Stage ID`
- `Variant Stage Name`
- `Marker Type`
- `Marker Name`

These should only be added when authoritative stage boundaries or route markers
are available.

## Information Still Required

Before presenting the variant as a complete alternative journey, request:

- Official variant name
- Whether it is an official, recommended, seasonal, or temporary alternative
- Recommended direction or confirmation that both directions are supported
- Recommended overnight stops
- Variant stage boundaries and names
- Services, accommodation, water, and transport points
- Safety, access, and seasonal notes
- Any descriptive text and required translations

## Suggested Delivery Phases

### Phase 1 — Route preview

- Import route geometry and calculated metadata.
- Show it on the map and elevation profile.
- Add a route summary and branch/rejoin points.
- Keep Main E4 as the default timeline.

### Phase 2 — Selectable route

- Add the route-choice panel.
- Persist the selected route.
- Update GPS, offline maps, elevation, and reverse direction.

### Phase 3 — Full variant journey

- Add authoritative variant stages.
- Add services and accommodation.
- Integrate variant stages into filtering, Stage Info, and offline guidance.

