# Android Release Checklist

Status checked: 12 August 2026

Android development is now active. The local toolchain and a representative
Android emulator are ready, and the current app has completed its first Android
debug and unsigned release builds.

## Current state

- The Flutter application contains a working Android project.
- The existing application ID remains `com.monktrail.monk_mobile`.
- Firebase is configured through `android/app/google-services.json`, and its
  Android package matches the application ID.
- Mapbox is supplied through `--dart-define-from-file=env.local.json`.
- Coarse location, precise location, and internet permissions are declared.
- The Android-facing application label is `EuroTrex`.
- Release builds no longer fall back to the debug signing key. Until an upload
  keystore is configured, release bundles are intentionally unsigned.

## Development environment

- [x] Install Android Studio Quail 3 (2026.1.3 Patch 1).
- [x] Install and configure OpenJDK 17 for Flutter.
- [x] Install Android SDK command-line tools and platform tools.
- [x] Install Android API 36 and Build Tools 36.0.0.
- [x] Install the Android emulator and Google Play ARM64 API 36 system image.
- [x] Install build dependencies discovered by the first app build: NDK
      28.2.13676358, CMake 3.22.1, Android Platform 34, and Build Tools 35.0.0.
- [x] Accept all Android SDK licences.
- [x] Create and boot `EuroTrex_Pixel_8_API_36` (Android 16/API 36).
- [x] Confirm that `flutter doctor -v` reports a working Android toolchain.
- [x] Confirm that `flutter emulators` lists the EuroTrex Pixel AVD.

`flutter doctor` only reports missing Chrome. Chrome is not required for
Android development and is not an Android release blocker.

## Android project configuration

- [x] Add `android.permission.INTERNET` to the main Android manifest so release
      builds can use Mapbox, Firebase, booking links, and email links.
- [x] Confirm the Android-facing application label is `EuroTrex`.
- [x] Keep the current application ID and source/package names unchanged.
- [x] Review Flutter's effective SDK versions: minimum 24, target 36, compile
      36.
- [x] Configure Flutter and `android/local.properties` to use the standard
      Android SDK location and Java 17.
- [x] Confirm the Mapbox token is loaded with
      `--dart-define-from-file=env.local.json`.
- [x] Verify Firebase starts and Firestore trail data downloads on Android.
- [x] Review the Android launcher and adaptive icons on the Pixel launcher.
- [ ] Add and visually verify a branded Android launch screen, including the
      Android 12+ splash-screen path and dark mode.
- [ ] Investigate the Mapbox optional-class `ClassNotFoundException` warnings
      printed during Android startup. Map rendering works, but the dependency
      versions should be checked before release.
- [ ] Fix and retest the Stage Info map-preview initial camera on Android. A
      preview displayed Mapbox's default Corsica location instead of Cyprus
      during the first emulator smoke test; the full Trail Map camera worked.

## Build verification completed

- [x] Build, install, and launch the debug APK on the Pixel 8 emulator with
      `env.local.json`.
- [x] Load the 123 Cyprus E4 stages from Firebase on Android.
- [x] Render the Cyprus trail and basemap in the full Mapbox Trail Map.
- [x] Build an unsigned release App Bundle at
      `build/app/outputs/bundle/release/app-release.aab` (79.7 MB).
- [x] Verify the generated package metadata: application ID, `EuroTrex` label,
      minimum API 24, target API 36, and required permissions.
- [x] Verify the bundle contains ARM64, ARMv7, and x86-64 native libraries.
- [x] Run `flutter analyze` with no issues.
- [x] Run all 118 Flutter tests successfully.

## Functional verification still required

- [ ] Explore Trails and all trail navigation on Android.
- [ ] Map route colours, stage markers, start/finish flags, accommodation,
      excursion, and detour markers.
- [ ] Map camera positioning, stage selection, and reverse direction.
- [ ] Stage map and elevation previews, including the Android camera issue
      recorded above.
- [ ] Elevation chart, stage selection, and GPS position.
- [ ] GPS permission flow for denied, approximate, precise, and permanently
      denied states, plus Find My Stage.
- [ ] Offline trail and map downloads, including deletion and restored states.
- [ ] Accommodation loading, filtering, and map selection.
- [ ] Booking and website links.
- [ ] Phone links open the Android dialer with the full `+357` number.
- [ ] Email links open the user's default email application.
- [ ] All supported languages and metric/imperial settings.
- [ ] Android system back navigation and predictive-back behaviour.
- [ ] Layout at small and large Android screen sizes, landscape orientation,
      increased text scale, and light/dark system modes.

## Release signing and artifact preparation

- [ ] Create a dedicated Android upload keystore with user-chosen secure
      passwords; store it securely outside source control and back it up.
- [x] Configure Gradle to load release signing from ignored
      `android/key.properties` only when it exists.
- [x] Add the safe template `android/key.properties.example`.
- [ ] Copy the template to `android/key.properties` and add the real upload-key
      details.
- [ ] Enrol in Play App Signing and securely retain the upload certificate and
      fingerprints.
- [ ] Build and verify a **signed** Android App Bundle:
      `flutter build appbundle --release
      --dart-define-from-file=env.local.json`.
- [ ] Increment `version`/`versionCode` from the current `1.0.0+1` before each
      Play Console upload.
- [ ] Decide whether to enable R8 resource/code shrinking and verify the release
      build if enabled.
- [ ] Verify 16 KB page-size compatibility for native Flutter and Mapbox
      libraries using Play Console checks or an Android 15+ test device.
- [ ] Review Play Console's generated download size and asset-delivery limits;
      the local universal AAB is currently 79.7 MB before device splits.
- [ ] Retain mapping/native debug-symbol artifacts for each release if
      obfuscation or symbol splitting is enabled.

## Device and Play Console release

- [ ] Test the signed release build on at least one physical Android phone.
- [ ] Test on the minimum supported API and the latest supported API.
- [ ] Prepare the Play Console application record and enable Play App Signing.
- [ ] Prepare the store title, short/full descriptions, icon, feature graphic,
      phone/tablet screenshots, category, and contact details.
- [ ] Provide a public privacy-policy URL covering precise/approximate location,
      Firebase data, offline storage, external booking links, and email/phone
      intents.
- [ ] Complete the Data safety, app access, content rating, ads, target audience,
      and permissions declarations.
- [ ] Explain location use in-app before Android's permission prompt where
      needed, and confirm the request is limited to foreground location.
- [ ] Run the Play pre-launch report and resolve crashes, accessibility issues,
      security warnings, and device-compatibility findings.
- [ ] Upload first to an internal Play testing track and complete tester
      installation/update testing before promoting the release.
