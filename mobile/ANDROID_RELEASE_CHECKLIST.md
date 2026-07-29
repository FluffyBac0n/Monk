# Android Release Checklist

Status checked: 29 July 2026

Android work is intentionally deferred until the iOS version of EUROTREX is
finalized.

## Current state

- The Flutter application already contains an Android project.
- Firebase is configured through `android/app/google-services.json`.
- Mapbox is provided through the Flutter Mapbox package.
- Coarse and precise location permissions are declared.
- The existing application ID is `com.monktrail.monk_mobile`.
- The application ID and source/package names must remain unchanged unless a
  separate decision is made to rename them.
- This development Mac does not currently have the Android SDK installed.
- No Android Virtual Device (AVD) is currently configured.
- Release builds currently use the debug signing key.

## Development environment

- [ ] Install Android Studio.
- [ ] Install the Android SDK, command-line tools, platform tools, and a current
      Android platform.
- [ ] Accept the Android SDK licences with `flutter doctor
      --android-licenses`.
- [ ] Create a representative Pixel Android emulator in Android Studio.
- [ ] Confirm that `flutter doctor -v` reports a working Android toolchain.
- [ ] Confirm that `flutter emulators` lists the new AVD.

## Android project configuration

- [ ] Add `android.permission.INTERNET` to the main Android manifest so release
      builds can use Mapbox, Firebase, booking links, and email links.
- [ ] Set the Android-facing application label to `EUROTREX`.
- [ ] Keep the current application ID unless an explicit package-renaming
      decision is made.
- [ ] Review the minimum and target Android SDK versions selected by Flutter.
- [ ] Confirm the Mapbox token is loaded with
      `--dart-define-from-file=env.local.json`.
- [ ] Verify that Firebase starts correctly on Android.
- [ ] Review the Android launcher icon and splash screen.

## Functional verification

- [ ] Explore Trails and all trail navigation.
- [ ] Map rendering, route colours, stage markers, start/finish flags, and
      accommodation markers.
- [ ] Map camera positioning, stage selection, and reverse direction.
- [ ] Stage map previews.
- [ ] Elevation chart and stage selection.
- [ ] GPS permission flow and Find My Stage.
- [ ] Offline trail and map downloads, including deletion and restored states.
- [ ] Accommodation loading from Firestore.
- [ ] Booking and website links.
- [ ] Phone links open the Android dialer with the full `+357` number.
- [ ] Email links open the user's default email application.
- [ ] All supported languages and measurement settings.
- [ ] Layout at small and large Android screen sizes and increased text scale.

## Release preparation

- [ ] Create and securely store an Android release keystore.
- [ ] Configure Gradle release signing without committing secrets.
- [ ] Build and test an Android App Bundle:
      `flutter build appbundle --release
      --dart-define-from-file=env.local.json`.
- [ ] Run the complete Flutter test suite and static analysis.
- [ ] Test the release build on a physical Android phone.
- [ ] Prepare the Play Console listing, screenshots, privacy information,
      content rating, data-safety declaration, and testing track.
- [ ] Upload first to an internal Play Store testing track.

