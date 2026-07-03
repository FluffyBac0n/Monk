# Firestore Schema Reference

This file documents the Firestore collections written by the Monk importer.

All trail data is stored under one top-level trail document:

```text
trails/{trailId}
```

For the current Cyprus E4 import, `trailId` is `cyprus-e4`.

The importer uses stable document IDs and Firestore `set(..., merge=True)` by default, so rerunning the import updates existing documents with the same IDs. Documents written by the importer also receive an `updatedAt` timestamp, except import audit documents, which receive `createdAt`.

## Collection: `trails`

Path:

```text
trails/{trailId}
```

Example document ID:

```text
cyprus-e4
```

Purpose:

Stores trail-level summary data and acts as the parent for all trail subcollections.

Keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `id` | string | Stable trail ID. Usually same as the document ID. | `cyprus-e4` |
| `name` | string | Human-readable trail name. | `Cyprus E4` |
| `country` | string | Trail country. | `Cyprus` |
| `stageCount` | number | Number of stage documents imported. | `123` |
| `lodgingCount` | number | Number of lodging documents imported. | `192` |
| `routePointCount` | number | Number of route GPS/elevation points. | `23107` |
| `totalDistanceKm` | number | Full route distance in kilometers. | `558.091042780747` |
| `startStageId` | string | Stage ID at the start of the route. | `124-pafos-airport` |
| `startStageName` | string | Human-readable start stage name. | `Pafos Airport` |
| `endStageId` | string | Stage ID at the end of the route. | `1-larnaka-airport` |
| `endStageName` | string | Human-readable end stage name. | `Larnaka Airport` |
| `routeVersion` | number | Version number for route data. Increment if route geometry changes. | `1` |
| `updatedAt` | timestamp | Last time this document was written by the importer. | `2026-06-30T18:16:05Z` |

Example:

```json
{
  "id": "cyprus-e4",
  "name": "Cyprus E4",
  "country": "Cyprus",
  "stageCount": 123,
  "lodgingCount": 192,
  "routePointCount": 23107,
  "totalDistanceKm": 558.091042780747,
  "startStageId": "124-pafos-airport",
  "startStageName": "Pafos Airport",
  "endStageId": "1-larnaka-airport",
  "endStageName": "Larnaka Airport",
  "routeVersion": 1
}
```

## Collection: `trails/{trailId}/stages`

Path:

```text
trails/{trailId}/stages/{stageId}
```

Example document ID:

```text
124-pafos-airport
```

Purpose:

Stores the ordered route stages and the services available at each stage.

Keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `sequence` | number | Stage order/number from the workbook. | `124` |
| `name` | string | Human-readable stage name. | `Pafos Airport` |
| `distanceFromPathKm` | number or null | Distance from the main E4 path, if applicable. | `0.0` |
| `accumulatedDistanceKm` | number or null | Accumulated trail distance at this stage. | `0.0` |
| `segmentLengthKm` | number or null | Distance to the next/related segment. | `0.0` |
| `elevationUpM` | number or null | Elevation gain in meters for the stage/segment. | `0.0` |
| `elevationDownM` | number or null | Elevation loss in meters for the stage/segment. | `0.0` |
| `altitudeM` | number or null | Altitude at the stage marker. | `2.0` |
| `services` | map | Boolean service availability flags. | See below |
| `updatedAt` | timestamp | Last time this document was written by the importer. | `2026-06-30T18:16:05Z` |

`services` keys:

| Key | Type | Meaning |
| --- | --- | --- |
| `lodging` | boolean | Lodging is available. |
| `tent` | boolean | Tent/camping option is available. |
| `food` | boolean | Food is available. |
| `grocery` | boolean | Grocery/supplies are available. |
| `drinkableWater` | boolean | Drinkable water is available. |
| `nonDrinkableWater` | boolean | Non-drinkable water is available. |
| `toilets` | boolean | Toilets are available. |
| `medical` | boolean | Medical service is available. |
| `pharmacy` | boolean | Pharmacy is available. |
| `atm` | boolean | ATM is available. |
| `busStop` | boolean | Bus stop/public transport access is available. |

Example:

```json
{
  "sequence": 124,
  "name": "Pafos Airport",
  "distanceFromPathKm": 0.0,
  "accumulatedDistanceKm": 0.0,
  "segmentLengthKm": 0.0,
  "elevationUpM": 0.0,
  "elevationDownM": 0.0,
  "altitudeM": 2.0,
  "services": {
    "lodging": true,
    "tent": true,
    "food": true,
    "grocery": true,
    "drinkableWater": true,
    "nonDrinkableWater": false,
    "toilets": true,
    "medical": false,
    "pharmacy": false,
    "atm": true,
    "busStop": true
  }
}
```

## Collection: `trails/{trailId}/lodgings`

Path:

```text
trails/{trailId}/lodgings/{lodgingId}
```

Example document ID:

```text
124-pafos-airport-timi-picnic-site
```

Purpose:

Stores lodging, campsite, picnic-site, and accommodation-related records. A lodging may link to a stage through `stageId`.

Keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `stageId` | string or null | Related stage document ID. Query this to get lodgings for a stage. | `124-pafos-airport` |
| `stageSequence` | number or null | Related stage sequence number. | `124` |
| `stageName` | string or null | Related stage name from the workbook. | `Pafos Airport` |
| `name` | string or null | Lodging/accommodation name. | `Timi Picnic Site` |
| `type` | string or null | Lodging type/category. | `Picnic site` |
| `village` | string or null | Nearby village/locality. | `Timi` |
| `minPriceText` | string or null | Original price text from the workbook. | `0` |
| `priceMinEur` | number or null | Parsed minimum price in EUR. | `0.0` |
| `priceMaxEur` | number or null | Parsed maximum price in EUR. | `0.0` |
| `distanceFromTrailKm` | number or null | Distance from the trail in kilometers. | `0.0` |
| `location` | geopoint-like map or null | Latitude/longitude for maps. | `{ "latitude": 34.706816, "longitude": 32.496087 }` |
| `address` | string or null | Street/address text. | `Agiou Georgiou 12` |
| `contact` | map | Contact and link fields. | See below |
| `openingTime` | string or null | Opening time in `HH:MM` format when available. | `08:00` |
| `closingTime` | string or null | Closing time in `HH:MM` format when available. | `20:00` |
| `monthsOpen` | string or null | Months/season open. | `Apr-Oct` |
| `capacityPeople` | number or null | Capacity in people. | `12` |
| `checkInTime` | string or null | Check-in time in `HH:MM` format. | `14:00` |
| `checkOutTime` | string or null | Check-out time in `HH:MM` format. | `11:00` |
| `updatedAt` | timestamp | Last time this document was written by the importer. | `2026-06-30T18:16:05Z` |

`contact` keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `phone` | string or null | Phone number. | `+357 99123456` |
| `whatsapp` | string or null | WhatsApp contact. | `+357 99123456` |
| `email` | string or null | Email address. | `info@example.com` |
| `website` | string or null | Website URL. | `https://example.com` |
| `googleMapsUrl` | string or null | Google Maps listing/link. | `https://maps.app.goo.gl/rextyQ1nn68xRjrj8` |

Example:

```json
{
  "stageId": "124-pafos-airport",
  "stageSequence": 124,
  "stageName": "Pafos Airport",
  "name": "Timi Picnic Site",
  "type": "Picnic site",
  "village": "Timi",
  "minPriceText": "0",
  "priceMinEur": 0.0,
  "priceMaxEur": 0.0,
  "distanceFromTrailKm": 0.0,
  "location": {
    "latitude": 34.70681628675817,
    "longitude": 32.49608724544
  },
  "address": null,
  "contact": {
    "phone": null,
    "whatsapp": null,
    "email": null,
    "website": null,
    "googleMapsUrl": "https://maps.app.goo.gl/rextyQ1nn68xRjrj8"
  },
  "openingTime": null,
  "closingTime": null,
  "monthsOpen": null,
  "capacityPeople": null,
  "checkInTime": "00:00",
  "checkOutTime": "00:00"
}
```

Common query:

```text
lodgings where stageId == "1-larnaka-airport"
```

## Collection: `trails/{trailId}/routeMetadata`

Path:

```text
trails/{trailId}/routeMetadata/main
```

Purpose:

Stores summary data needed before loading route chunks. The mobile app should read this first to know how many chunks/points exist and how to decode the flat route point arrays.

Keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `version` | number | Route data version. | `1` |
| `pointCount` | number | Total number of route points after expanding chunks. | `23107` |
| `chunkCount` | number | Number of route chunk documents. | `47` |
| `chunkSize` | number | Target number of route points per chunk. | `500` |
| `totalDistanceKm` | number | Full route distance in kilometers. | `558.091042780747` |
| `minAltitudeM` | number | Minimum altitude in meters. | `-1.69999999999891` |
| `maxAltitudeM` | number | Maximum altitude in meters. | `1732.0009266133` |
| `bounds` | map | Route bounding box. | See below |
| `pointFormat` | array of strings | Field order inside every chunk's flat `points` array. | `["lat", "lng", "altitudeM", "distanceKm", "reverseDistanceKm"]` |
| `pointStride` | number | Number of values per point in `routeChunks.points`. | `5` |
| `reverseDistanceAvailable` | boolean | Whether reverse distance values are present. | `true` |
| `updatedAt` | timestamp | Last time this document was written by the importer. | `2026-06-30T18:16:05Z` |

`bounds` keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `minLat` | number | Southern route latitude. | `34.7107765` |
| `maxLat` | number | Northern route latitude. | `35.0888349` |
| `minLng` | number | Western route longitude. | `32.2740918` |
| `maxLng` | number | Eastern route longitude. | `34.0766693` |

Example:

```json
{
  "version": 1,
  "pointCount": 23107,
  "chunkCount": 47,
  "chunkSize": 500,
  "totalDistanceKm": 558.091042780747,
  "minAltitudeM": -1.69999999999891,
  "maxAltitudeM": 1732.0009266133,
  "bounds": {
    "minLat": 34.7107765,
    "maxLat": 35.0888349,
    "minLng": 32.2740918,
    "maxLng": 34.0766693
  },
  "pointFormat": ["lat", "lng", "altitudeM", "distanceKm", "reverseDistanceKm"],
  "pointStride": 5,
  "reverseDistanceAvailable": true
}
```

## Collection: `trails/{trailId}/routeChunks`

Path:

```text
trails/{trailId}/routeChunks/{chunkId}
```

Example document ID:

```text
0000
```

Purpose:

Stores route GPX/elevation points in small ordered documents. The app should query these ordered by `chunkIndex`, expand the flat `points` array using `routeMetadata.pointStride`, and cache the expanded route locally for offline map/elevation display.

Keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `chunkIndex` | number | Zero-based chunk order. | `0` |
| `startPointIndex` | number | Global point index of the first point in this chunk. | `0` |
| `endPointIndex` | number | Global point index of the last point in this chunk. | `499` |
| `startDistanceKm` | number | Distance at the first point in this chunk. | `0.0` |
| `endDistanceKm` | number | Distance at the last point in this chunk. | `16.5360907970227` |
| `bounds` | map | Bounding box for this chunk only. | See below |
| `points` | array of numbers | Flat point data. Every point uses `pointStride` values. | See below |
| `updatedAt` | timestamp | Last time this document was written by the importer. | `2026-06-30T18:16:05Z` |

`points` format:

```text
[lat, lng, altitudeM, distanceKm, reverseDistanceKm, lat, lng, altitudeM, distanceKm, reverseDistanceKm, ...]
```

With `pointStride = 5`, the first point is `points[0:5]`, the second point is `points[5:10]`, and so on.

Example:

```json
{
  "chunkIndex": 0,
  "startPointIndex": 0,
  "endPointIndex": 499,
  "startDistanceKm": 0.0,
  "endDistanceKm": 16.5360907970227,
  "bounds": {
    "minLat": 34.7107765,
    "maxLat": 34.7998585,
    "minLng": 32.4576734,
    "maxLng": 32.5310431
  },
  "points": [
    34.710992,
    32.4823083,
    2.26161129476575,
    0.0,
    558.091042780747,
    34.7109785,
    32.482302,
    1.7908336288622,
    0.00160550156852901,
    558.089437279178
  ]
}
```

Common query:

```text
routeChunks order by chunkIndex ascending
```

## Collection: `trails/{trailId}/routeMarkers`

Path:

```text
trails/{trailId}/routeMarkers/{routeMarkerId}
```

Example document IDs:

```text
124-pafos-airport
route-marker-00795
```

Purpose:

Stores named points along the route. Some markers are linked to a stage through `stageId`; others are route labels/waypoints from the route sheet and do not link to a stage.

Keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `stageId` | string or null | Linked stage ID. Null means this is an unlinked waypoint/label. | `124-pafos-airport` |
| `stageName` | string | Display name from the route sheet. | `Pafos Airport` |
| `pointIndex` | number | Global route point index where this marker sits. | `0` |
| `distanceKm` | number | Distance from route start. | `0.0` |
| `reverseDistanceKm` | number | Distance remaining to route end. | `558.091042780747` |
| `location` | geopoint-like map | Marker latitude/longitude. | `{ "latitude": 34.710992, "longitude": 32.4823083 }` |
| `altitudeM` | number | Altitude at the marker. | `2.26161129476575` |
| `updatedAt` | timestamp | Last time this document was written by the importer. | `2026-06-30T18:16:05Z` |

Linked marker example:

```json
{
  "stageId": "124-pafos-airport",
  "stageName": "Pafos Airport",
  "pointIndex": 0,
  "distanceKm": 0.0,
  "reverseDistanceKm": 558.091042780747,
  "location": {
    "latitude": 34.710992,
    "longitude": 32.4823083
  },
  "altitudeM": 2.26161129476575
}
```

Unlinked marker example:

```json
{
  "stageId": null,
  "stageName": "Minthis Resort (Minthis Monastery)",
  "pointIndex": 795,
  "distanceKm": 23.1576857257825,
  "reverseDistanceKm": 534.933357054963,
  "location": {
    "latitude": 34.8244411,
    "longitude": 32.4983815
  },
  "altitudeM": 517.754349411381
}
```

Common query:

```text
routeMarkers order by pointIndex ascending
```

## Collection: `trails/{trailId}/imports`

Path:

```text
trails/{trailId}/imports/{importId}
```

Example document ID:

```text
20260630T181605Z
```

Purpose:

Stores an audit record for each import run.

Keys:

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `createdAt` | timestamp | Time this import audit document was created. | `2026-06-30T18:16:05Z` |
| `stageCount` | number | Number of stages written during the import. | `123` |
| `lodgingCount` | number | Number of lodgings written during the import. | `192` |
| `routePointCount` | number | Number of route points in the import. | `23107` |
| `routeChunkCount` | number | Number of route chunks written. | `47` |
| `routeMarkerCount` | number | Number of route markers written. | `122` |
| `warnings` | array of strings | Non-fatal import warnings. | `["LODGING row 14: unknown stage '...'"]` |

Example:

```json
{
  "createdAt": "2026-06-30T18:16:05Z",
  "stageCount": 123,
  "lodgingCount": 192,
  "routePointCount": 23107,
  "routeChunkCount": 47,
  "routeMarkerCount": 122,
  "warnings": []
}
```

## Relationship Summary

```text
trails/{trailId}
  stages/{stageId}
  lodgings/{lodgingId}          -> stageId references stages/{stageId}
  routeMetadata/main
  routeChunks/{chunkId}         -> ordered by chunkIndex
  routeMarkers/{routeMarkerId}  -> optional stageId references stages/{stageId}
  imports/{importId}
```

For app usage:

- Read `trails/{trailId}` for trail summary.
- Read `stages` ordered by `sequence` for stage lists.
- Query `lodgings` by `stageId` to show lodging for a stage.
- Read `routeMetadata/main`, then fetch `routeChunks` ordered by `chunkIndex` to draw the route and elevation profile.
- Read `routeMarkers` ordered by `pointIndex` to place labeled points on the route/elevation UI.
