# EUROTREX TestFlight Guide

Last updated: 10 August 2026

This guide explains how to install and test EUROTREX on a physical iPhone
through Apple's TestFlight service.

## Current project configuration

- Flutter project: `/Users/amich/Documents/Monk 2/mobile`
- iOS bundle identifier: `com.monktrail.monkMobile`
- Current Flutter version: `1.0.0+1`
- Signing style: Automatic
- Development Team: Not yet configured in the Xcode project
- Installed iOS display name: `Monk Mobile`
- Mapbox configuration file: `env.local.json`

The installed display name should be changed to `EUROTREX` before distributing
the beta if the TestFlight build should use the final product name. This does
not require changing the source package name or bundle identifier.

## Requirements

- An active Apple Developer Program membership.
- Access to App Store Connect.
- The bundle ID `com.monktrail.monkMobile` registered in the intended Apple
  Developer account.
- An App Store Connect app record for EUROTREX.
- An Apple Account added as an App Store Connect user for internal testing.
- The TestFlight app installed on the target iPhone.

## 1. Configure signing in Xcode

Open the iOS workspace:

```bash
cd "/Users/amich/Documents/Monk 2/mobile"
open ios/Runner.xcworkspace
```

In Xcode:

1. Select the `Runner` target.
2. Open **Signing & Capabilities**.
3. Enable **Automatically manage signing**.
4. Select the intended Apple Developer Team.
5. Confirm that the bundle identifier is `com.monktrail.monkMobile`.

## 2. Create the App Store Connect record

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com/).
2. Open **Apps**.
3. Select **+**, then **New App**.
4. Select iOS as the platform.
5. Enter `EUROTREX` as the app name.
6. Select `com.monktrail.monkMobile` as the bundle ID.
7. Choose a permanent internal SKU, such as `eurotrex-ios-001`.
8. Confirm the primary language and create the app record.

The App Store Connect record must exist before uploading the first build.

## 3. Prepare the build

Before creating a TestFlight build:

```bash
cd "/Users/amich/Documents/Monk 2/mobile"
~/flutter/bin/flutter analyze
~/flutter/bin/flutter test
```

Each App Store Connect upload needs a unique build number. The current project
uses build number `1`, so the next upload can use build number `2`.

Build the signed archive and IPA with the production Mapbox configuration:

```bash
cd "/Users/amich/Documents/Monk 2/mobile"

~/flutter/bin/flutter build ipa \
  --release \
  --dart-define-from-file=env.local.json \
  --build-name=1.0.0 \
  --build-number=2
```

Flutter creates:

- The Xcode archive under `build/ios/archive/`.
- The uploadable IPA under `build/ios/ipa/`.

Increase `--build-number` for every subsequent upload. The marketing version
can remain `1.0.0` for multiple beta builds.

## 4. Upload the build

### Option A: Xcode Organizer

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **Any iOS Device (arm64)** as the destination.
3. Select **Product**, then **Archive**.
4. When Organizer opens, select the new archive.
5. Select **Distribute App**.
6. Select **App Store Connect**, then **Upload**.
7. Complete Xcode's validation and upload steps.

This is the recommended approach for the first upload because Xcode presents
signing and validation problems directly.

### Option B: Transporter

1. Build the IPA using `flutter build ipa`.
2. Install and open Apple's Transporter app on the Mac.
3. Sign in with an authorized App Store Connect account.
4. Add the IPA from `build/ios/ipa/`.
5. Select **Deliver**.

## 5. Process the uploaded build

Apple processes the uploaded build before it becomes available in TestFlight.
An email is sent when processing finishes.

In App Store Connect:

1. Open **Apps**, then **EUROTREX**.
2. Open the **TestFlight** tab.
3. Select the uploaded build.
4. Resolve any **Missing Compliance** or export-encryption questions.
5. Review and resolve upload warnings.
6. Enter the beta description and **What to Test** information when requested.

## 6. Configure internal TestFlight testing

Internal testing is the quickest way to install the app on the owner's iPhone.
Internal testers must be users of the App Store Connect account.

1. In the app's **TestFlight** tab, select **+** beside Internal Testing.
2. Create an internal group, such as `EUROTREX Internal`.
3. Enable automatic distribution if desired.
4. Add the processed build to the group.
5. Invite the required App Store Connect users to the group.

Apple supports up to 100 internal testers. External testers do not need App
Store Connect access, but external distribution may require TestFlight beta
review.

## 7. Install EUROTREX on the iPhone

1. Install **TestFlight** from the iPhone App Store.
2. Sign in using the Apple Account that received the invitation.
3. Open the TestFlight invitation email or accept the invitation in TestFlight.
4. Select **Install** beside EUROTREX.
5. Accept location access when testing GPS and nearby-stage functionality.

TestFlight builds remain available for 90 days. Upload a new build with a new
build number to continue testing after a build expires or to distribute new
changes.

## Internal and external testing

### Internal testers

- Must be App Store Connect users.
- Maximum of 100 testers.
- Best for the project owner and development team.
- Can normally begin once the build is processed and compliance information is
  complete.

### External testers

- Do not need App Store Connect access.
- Can be invited by email or public link.
- Supports up to 10,000 testers.
- The first external build requires TestFlight beta review; later builds may
  also be reviewed.

## Common blockers

- No Apple Developer Team selected in Xcode.
- The bundle ID is not registered in the selected developer account.
- The App Store Connect app record does not exist.
- The build number was already uploaded.
- The Account Holder has not accepted the latest Apple agreements.
- Export compliance information is missing.
- The IPA was built without `env.local.json`, leaving Mapbox unconfigured.
- App Store Connect reports signing, provisioning, privacy, or SDK validation
  errors.

## Project-specific items to confirm before the first beta

- Change the installed display name from `Monk Mobile` to `EUROTREX`.
- Confirm the final EUROTREX launcher icon and launch screen.
- Select and store the correct Apple Development Team.
- Confirm whether the first beta supports both iPhone and iPad.
- Verify the location-permission explanation in every supported language.
- Confirm that `env.local.json` contains the intended production-safe Mapbox
  public token.
- Test GPS, offline maps, booking links, phone links, email links, and Firebase
  data on the physical iPhone.

For the complete release-readiness list, see
[`IOS_RELEASE_CHECKLIST.md`](IOS_RELEASE_CHECKLIST.md).

## Official references

- [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Apple: Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)
- [Apple: Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Flutter: Build and release an iOS app](https://docs.flutter.dev/deployment/ios)
