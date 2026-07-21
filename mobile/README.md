# Monk Mobile

Cross-platform Flutter MVP for the Cyprus E4 trail.

## Current vertical slice

- Android and iOS Flutter targets
- Extensible trail-library home screen with Cyprus E4 as the first trail
- Riverpod application state and dependency injection
- Firestore stage reader for `trails/cyprus-e4/stages`
- Transactional SQLite stage cache
- Firestore route-chunk decoding and SQLite elevation cache
- Interactive full-trail elevation profile with touch inspection
- Mapbox Outdoors trail map using the SQLite-cached route geometry
- Tappable stage markers, stage-focused maps, and current-location controls
- Persistent Mapbox Outdoors style and Cyprus E4 corridor downloads for offline maps
- Offline download progress, storage status, retry, and removal controls
- Offline-first stage list
- Reversible trail direction and service-based stage filters
- English, German, and Spanish interface localization
- Persistent metric and imperial measurement preferences
- Empty, loading, error, and download states
- Material 3 light and dark themes

## Run locally

```bash
flutter pub get
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_public_token
```

The app can launch without a Mapbox token, but the map screen will show setup instructions
instead of map tiles. Use a public `pk…` token; do not commit a secret token.

## Connect Firebase

The app is configured for the `eurotrex` Firebase project on Android and iOS. To regenerate the
configuration after changing platforms or Firebase services, run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Generated configuration files:

```text
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
```

## Next MVP slice

1. Add trail metadata and download/version records to SQLite.
2. Cache lodgings and richer route markers.
3. Load additional trails into the trail library from Firebase.
4. Add selectable offline detail levels and storage estimates.
5. Synchronize trail progress across map and elevation views.
