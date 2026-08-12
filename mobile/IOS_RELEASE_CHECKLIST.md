# iOS Release Checklist

Status checked: 29 July 2026

The app successfully builds in unsigned iOS release mode. The current release
build is approximately 83.2 MB.

## Current technical state

- [x] The app compiles in iOS release mode.
- [x] Xcode 26.6 and the iOS 26.5 SDK satisfy Apple's current upload
      requirement.
- [x] The minimum supported version is iOS 15.
- [x] The Firebase bundle ID matches `com.monktrail.monkMobile`.
- [x] The Mapbox access token is a public client token.
- [x] Required third-party SDK privacy manifests are packaged in the release
      build.
- [ ] Complete the release branding, signing, compliance, metadata, and
      physical-device testing below.

## Branding

- [ ] Change the installed iOS application name from `Monk Mobile` to
      `EUROTREX`.
- [ ] Replace the default Flutter launcher icon with the final EUROTREX app
      icon.
- [ ] Generate every required iPhone and iPad icon size from the final artwork.
- [ ] Confirm that the 1024 x 1024 App Store icon has no transparency.
- [ ] Replace or redesign the current launch screen with finished EUROTREX
      branding.
- [ ] Verify the icon and launch screen in light and dark appearances.

## Apple account and signing

- [ ] Confirm that the intended publisher has an active Apple Developer Program
      membership.
- [ ] Decide whether the seller will be an individual or an organization.
- [ ] If publishing as an organization, confirm its legal-entity information
      and D-U-N-S number.
- [ ] Register `com.monktrail.monkMobile` in the Apple Developer account.
- [ ] Configure the Apple development team in the Xcode project.
- [ ] Create or confirm the Apple Distribution certificate.
- [ ] Create or confirm the App Store provisioning profile.
- [ ] Ensure the Account Holder has accepted Apple's current agreements.

## Supported devices and orientations

- [ ] Decide whether the first release supports both iPhone and iPad.
- [ ] If iPad support remains enabled, test and polish all iPad layouts and
      provide the required iPad screenshots.
- [ ] If iPad is not part of the first release, change the target to iPhone
      only.
- [ ] Decide whether landscape orientation is supported.
- [ ] If landscape remains enabled, test every major screen in both landscape
      orientations.
- [ ] Otherwise, restrict the supported orientations to portrait.

## Localization

- [x] The Flutter interface supports English, German, Spanish, Italian, and
      French.
- [ ] Add Italian localization for the iOS location-permission explanation.
- [ ] Add French localization for the iOS location-permission explanation.
- [ ] Register Italian and French as iOS project localizations.
- [ ] Confirm the installed app name in every supported localization.
- [ ] Proofread every supported language on a physical device.
- [ ] Decide which languages will have localized App Store metadata and
      screenshots.

## Privacy and compliance

- [ ] Publish a public EUROTREX privacy policy.
- [ ] Add its privacy-policy URL in App Store Connect.
- [ ] Document how GPS location, Firebase, Mapbox, offline storage, and external
      links are used.
- [ ] Generate and review Xcode's combined privacy report.
- [ ] Complete the App Store privacy questionnaire, including data practices of
      third-party SDKs.
- [ ] Confirm that the app does not perform cross-app tracking. If this changes,
      implement App Tracking Transparency before collecting tracking data.
- [ ] Complete Apple's encryption and export-compliance questionnaire.
- [ ] If the app only uses exempt standard encryption, add the appropriate
      `ITSAppUsesNonExemptEncryption` value after confirming the declaration.
- [ ] Declare and verify Digital Services Act trader status for EU
      distribution.
- [ ] Provide the required public trader contact information if publishing as a
      trader.
- [ ] Confirm that Mapbox's logo and attribution access remain visible and
      functional on every Mapbox map.
- [ ] Confirm the rights and licences for trail data, GPX files, Maki icons,
      accommodation data, photographs, logos, and funding statements.

## Production services

- [ ] Review production Firestore security rules.
- [ ] Confirm that public access is limited to the intended read-only data.
- [ ] Verify Firestore indexes, production collections, data quality, quotas,
      and billing alerts.
- [ ] Confirm production Mapbox token scopes and restrictions.
- [ ] Confirm that no secret Mapbox or Firebase credentials are bundled.
- [ ] Verify lodging booking URLs, phone numbers, email addresses, and
      coordinates.
- [ ] Define a process for updating trail and accommodation data after release.

## App Store Connect

- [ ] Create the EUROTREX App Store Connect record before uploading a build.
- [ ] Select the registered bundle ID `com.monktrail.monkMobile`.
- [ ] Choose a permanent internal SKU.
- [ ] Confirm the primary language.
- [ ] Set the App Store name and subtitle.
- [ ] Select the primary and secondary categories.
- [ ] Complete the current age-rating questionnaire.
- [ ] Add the app description and keywords.
- [ ] Add a support URL that contains real contact information.
- [ ] Add the EUROTREX marketing URL.
- [ ] Add the copyright owner and year.
- [ ] Select the countries and regions where the app will be distributed.
- [ ] Confirm that the initial price is free unless a different decision is
      made.
- [ ] Prepare localized metadata for each selected language.
- [ ] Capture the required iPhone screenshots.
- [ ] Capture iPad screenshots if iPad support remains enabled.
- [ ] Add App Review contact name, phone number, and email address.
- [ ] Add review notes explaining GPS, offline-map downloads, Firestore data,
      external booking links, and any simulator limitations.
- [ ] Confirm that no demo account is required because the app has no login.
- [ ] Choose manual, automatic, or scheduled release after approval.

## Physical-device quality assurance

- [ ] Test a fresh installation on a supported physical iPhone.
- [ ] Test on the oldest supported practical iPhone and a current iPhone.
- [ ] Test on a physical iPad if iPad support remains enabled.
- [ ] Verify GPS permission granted, denied, restricted, and later changed in
      Settings.
- [ ] Verify Find My Stage while on the trail and away from the trail.
- [ ] Verify every map, stage preview, elevation view, marker, selection, and
      reverse-direction flow.
- [ ] Verify online and offline trail/map behavior.
- [ ] Verify interrupted, resumed, deleted, and repeated offline downloads.
- [ ] Verify phone links open the system dialer with the complete `+357`
      number.
- [ ] Verify email links open the configured default email application.
- [ ] Verify accommodation booking and website links.
- [ ] Test with no connection, slow connection, and restored connectivity.
- [ ] Test low-storage and interrupted-download behavior.
- [ ] Test all supported languages and both measurement systems.
- [ ] Test large text, VoiceOver, button labels, contrast, and reduced motion.
- [ ] Review performance, memory, battery use, startup time, and map stability.
- [ ] Confirm there are no crashes, red screens, debug labels, placeholder
      assets, or implementation-detail messages.

## Build and TestFlight

- [ ] Set the final marketing version and increment the build number.
- [x] Run `flutter analyze` after the shared Android/iOS fixes.
- [x] Run all 118 Flutter tests after the shared Android/iOS fixes.
- [x] Keep Mapbox Flutter 2.26.0 aligned with the installed iOS MapboxMaps
      11.26.0 pods; no Android-only dependency override is present.
- [ ] Rebuild and launch the current changes on an iOS simulator. The local
      source and pods are aligned, but this pass requires CoreSimulator access.
- [ ] Build the signed archive with the production Mapbox configuration.
- [ ] Validate the archive in Xcode Organizer.
- [ ] Review the archive's privacy report and upload warnings.
- [ ] Upload the build to App Store Connect.
- [ ] Complete export-compliance information for the uploaded build.
- [ ] Distribute first through internal TestFlight.
- [ ] Resolve every crash, warning, and tester issue.
- [ ] Complete external TestFlight review if external beta testing is required.
- [ ] Perform a final regression pass on the exact App Store candidate build.

## Submission

- [ ] Select the approved candidate build in App Store Connect.
- [ ] Recheck privacy labels, screenshots, metadata, URLs, age rating, trader
      status, export compliance, and review contact details.
- [ ] Add the version to an App Review submission.
- [ ] Submit for review.
- [ ] Monitor App Store Connect and respond promptly to review questions.
- [ ] After approval, release according to the selected release strategy.
- [ ] Verify the live App Store page and install the public build from the
      store.

## Official references

- [Apple upcoming submission requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Apple Developer Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment)
- [App privacy requirements](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [App encryption documentation](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/)
- [EU Digital Services Act trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [App Store version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Mapbox attribution requirements](https://docs.mapbox.com/help/ja/dive-deeper/attribution/)
