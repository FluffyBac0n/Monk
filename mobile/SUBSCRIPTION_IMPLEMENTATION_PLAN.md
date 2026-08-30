# EuroTrex Monthly Subscription Implementation Plan

Last researched: 30 August 2026

## Recommendation

Use a freemium model with one auto-renewing entitlement:

- Subscription: **EuroTrex Premium Monthly**
- Target price: **€4.99/month in euro markets and US$4.99/month in the US**
- RevenueCat entitlement: `premium`
- All purchases processed by Apple In-App Purchase or Google Play Billing
- No annual plan, free trial, or multiple premium tiers initially
- No required EuroTrex account for the first release

Do not use Stripe or a website checkout inside the initial mobile implementation. Offline maps, Route Planner, and personalized calculations are digital app features, so the lowest-risk global approach is to use the native stores. Region-specific alternative-payment programs add policy, reporting, and operational complexity that is not justified for the first release.

References:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818)

## Premium feature boundary

| Capability | Free | Premium |
| --- | :---: | :---: |
| Browse trails, stages, and services | ✓ | ✓ |
| Online trail map | ✓ | ✓ |
| Standard elevation profile | ✓ | ✓ |
| Basic Naismith walking-time estimate | ✓ | ✓ |
| Locally cached route, stages, and elevation data | ✓ | ✓ |
| Download Mapbox background maps |  | ✓ |
| Navigate using a downloaded offline map |  | ✓ |
| Route Planner |  | ✓ |
| Saved route plans | Preserved but locked | ✓ |
| Personalized walking-time calculation |  | ✓ when implemented |
| Settings, legal information, accommodation, filters, and direction reversal | ✓ | ✓ |

The app currently stores route geometry, stages, and elevation offline separately from the Mapbox tile download. Those basic trail-data caches should remain free. Only the downloadable background map and navigation using that offline map should be premium.

The normal online map should remain free.

## Subscription-policy consideration

Apple and Google require subscriptions to provide continuing value rather than functioning as a one-time feature unlock. Google requires sustained or recurring value, and Apple expects continuing services, content, or substantive updates.

The subscription is defensible if EuroTrex continues to provide:

- Updated downloadable maps
- Updated trail geometry and stage information
- Continued Route Planner access and improvements
- Future personalized walking-time calculations
- Ongoing compatibility with Mapbox, mobile operating systems, and new trail regions

If those services will not receive ongoing maintenance or data updates, a one-time premium purchase may be more appropriate than a subscription.

Do not advertise personalized walking-time calculation as a current subscription benefit until it is implemented. Its entitlement can be reserved in the architecture, but the launch paywall should only present benefits that are available at launch.

References:

- [Google subscription policy](https://support.google.com/googleplay/android-developer/answer/9900533)
- [Apple subscription guidance](https://developer.apple.com/app-store/subscriptions/)

## Why RevenueCat is recommended

The app currently has no purchase dependency, user authentication, or subscription backend. A direct StoreKit and Google Play Billing implementation would require EuroTrex to build and maintain:

- Apple transaction validation
- App Store Server Notifications V2
- Google purchase-token verification
- Google Real-time Developer Notifications
- Purchase acknowledgement
- Grace-period and account-hold handling
- Refund and revocation handling
- Restore Purchases behavior
- Cross-device entitlement reconciliation

Google recommends secure backend verification and real-time lifecycle processing instead of trusting only the client.

RevenueCat wraps StoreKit and Google Play Billing and exposes a normalized entitlement state through its Flutter SDK. Its published pricing currently provides a free allowance up to $2,500 in monthly tracked revenue and then charges 1% of tracked revenue.

References:

- [RevenueCat Flutter SDK](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [RevenueCat pricing](https://www.revenuecat.com/pricing)
- [Google billing backend integration](https://developer.android.com/google/play/billing/backend)
- [Google subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle)

Proposed entitlement flow:

```text
Apple App Store / Google Play
              │
              ▼
        RevenueCat backend
              │
              ▼
      premium entitlement
       ┌──────┼──────────────┐
       ▼      ▼              ▼
 Offline map  Route Planner  Personalized time
```

RevenueCat should remain behind EuroTrex-owned Dart interfaces so feature code is not coupled directly to a vendor.

## Proposed Flutter architecture

Add a subscription feature area:

```text
lib/features/subscription/
  domain/
    entitlement.dart
    premium_feature.dart
    subscription_status.dart
  data/
    subscription_repository.dart
    revenuecat_subscription_repository.dart
  presentation/
    subscription_controller.dart
    paywall_screen.dart
    premium_badge.dart
    subscription_settings_card.dart
```

Suggested domain types:

```dart
enum PremiumFeature {
  offlineMapDownload,
  offlineMapNavigation,
  routePlanner,
  personalizedWalkingTime,
}

enum EntitlementStatus {
  loading,
  active,
  gracePeriod,
  expired,
  unavailable,
}
```

The application should query a central feature-access provider rather than checking store product identifiers:

```dart
ref.watch(featureAccessProvider(PremiumFeature.routePlanner))
```

### Defensive enforcement

Each premium feature needs checks in two layers:

1. Presentation layer: show a lock or Premium badge and open the paywall.
2. Operation or destination layer: prevent deep links or programming mistakes from bypassing the paywall.

Current integration points include:

- Route Planner navigation in `lib/features/stages/presentation/stages_screen.dart`
- Offline-map UI in `lib/features/map/presentation/map_screen.dart`
- Offline-map Settings controls in `lib/features/settings/presentation/settings_screen.dart`
- The actual download operation in `lib/features/map/presentation/offline_map_controller.dart`

The controller must verify entitlement before starting a Mapbox download. UI checks alone are insufficient.

## Subscription lifecycle behavior

| Store state | Premium access |
| --- | :---: |
| Purchase completed | Yes |
| Trial or introductory period | Yes |
| Canceled but paid period has not ended | Yes |
| Billing grace period | Yes |
| Google pending purchase | No |
| Google account hold | No |
| Expired | No |
| Refunded or revoked | No |
| Temporarily unable to contact store | Use cached verified status until its known expiration |

RevenueCat's cached entitlement should allow an active subscriber to use the offline map without a connection. Once the locally verified expiration time has passed, access should not continue indefinitely.

### Existing downloads after expiration

Recommended behavior:

- Cancellation does not remove anything immediately.
- Access continues until the paid period expires.
- On confirmed expiration or refund, remove the Mapbox tile region at the next connected app launch.
- Do not delete route geometry, stages, elevation, preferences, or saved route plans.
- Explain that the offline background map requires Premium.
- If entitlement status is merely unavailable, do not delete anything.

Saved Route Planner data should remain local when the subscription expires. Re-subscribing should restore access without losing plans.

## Paywall and Settings experience

Premium entry points should remain visible instead of disappearing:

- Route Planner button: small lock or Premium badge
- Offline Map button: existing state plus a Premium badge
- Tapping a locked feature: contextual paywall
- Personalized estimate controls: visible as premium only after implementation

The paywall should include:

- EuroTrex Premium title
- Only the benefits currently implemented
- A statement that everything else in EuroTrex remains free
- Store-supplied localized price
- Monthly duration
- Automatic-renewal disclosure
- Subscribe button
- Restore Purchases button
- Terms of Use link
- Privacy Policy link
- Manage Subscription link for existing subscribers
- Clear loading, success, canceled, and error states

The displayed price must come from StoreKit or Google Play through RevenueCat. Do not hardcode `5 EUR/USD`; storefront currencies, taxes, and price tiers differ.

Apple requires the subscription name, duration, provided services, full renewal price, and a restore or sign-in mechanism on the sign-up screen. Terms and Privacy Policy links must be present in the app and store metadata.

Google requires clear cost, billing frequency, automatic-renewal terms, and an easy route to subscription management or cancellation.

References:

- [Apple subscription requirements](https://developer.apple.com/app-store/subscriptions/)
- [Google subscription requirements](https://support.google.com/googleplay/android-developer/answer/9900533)

## User accounts and cross-platform access

For the first release, do not require a EuroTrex account.

Benefits:

- No sign-up friction
- No Firebase Authentication expansion
- No account-deletion workflow
- Purchases can be restored with the same Apple or Google store account
- Smaller privacy footprint

Limitation:

- An iOS purchase will not automatically unlock Premium on Android.
- The entitlement follows the user's store account within its platform.

If one subscription must work across iOS and Android, implement a stable EuroTrex identity first:

- Firebase Authentication
- Sign in with Apple
- Google sign-in and possibly email sign-in
- Firebase UID passed to RevenueCat as `appUserID`
- Subscription source recorded so the app presents the correct management link
- In-app and web account deletion
- Privacy Policy and Data Safety updates

Apple and Google both require account deletion when an app supports account creation.

References:

- [Apple account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Google account deletion](https://support.google.com/googleplay/android-developer/answer/13327111)

## Apple requirements

1. Ensure the Paid Applications Agreement, tax details, and banking details are active.
2. Enable the In-App Purchase capability for `com.eurotrex.e4`.
3. Create subscription group `EuroTrex Premium`.
4. Create auto-renewable product `eurotrex_premium_monthly`.
5. Set the duration to one month.
6. Configure approximately €4.99 and US$4.99 using storefront price points.
7. Add localized names and descriptions for English, German, Spanish, Italian, and French.
8. Add the subscription review screenshot.
9. Connect production and sandbox server notifications through RevenueCat.
10. Configure an appropriate billing grace period.
11. Include Privacy Policy and Terms links in App Store metadata.
12. Explain the premium features and review path in App Review notes.
13. Provide Restore Purchases and Manage Subscription controls.

Apple subscriptions must last at least seven days, provide ongoing value, and be available across the user's supported devices.

Reference: [Apple Review Guideline 3.1.2](https://developer.apple.com/app-store/review/guidelines/)

## Google Play requirements

1. Complete the Play payments profile, tax, and merchant configuration.
2. Create subscription `eurotrex_premium`.
3. Create base plan `monthly`.
4. Set auto-renewing monthly billing.
5. Configure prices and regional availability.
6. Add localized descriptions.
7. Connect Google Play to RevenueCat using the required service credentials.
8. Configure Real-time Developer Notifications through RevenueCat.
9. Configure grace period and account hold.
10. Add an in-app link to Google Play's subscription-management page.
11. Update the Data Safety declaration for purchase and RevenueCat data.
12. Test through an internal track with license testers.

Google requires completed purchases to be verified and acknowledged. Pending purchases must not receive access.

Reference: [Google billing integration](https://developer.android.com/google/play/billing/integrate)

## Pricing and fees

Recommended storefront pricing:

- Eurozone: €4.99/month
- United States: US$4.99/month
- Other countries: store-generated localized price tiers

Current published fee considerations:

- Google lists a 15% fee for automatically renewing subscriptions.
- Apple Small Business Program participants receive 85% of the subscription price minus applicable taxes.
- Without the Apple Small Business Program, Apple's published structure is generally 70% during the subscriber's first year and 85% afterward.
- RevenueCat currently charges 1% of tracked revenue after its free threshold.
- VAT, withholding, currency conversion, and Cyprus accounting requirements need confirmation from an accountant.

References:

- [Google service fees](https://support.google.com/googleplay/android-developer/answer/112622)
- [Apple subscription proceeds](https://developer.apple.com/app-store/subscriptions/)
- [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/)

## Implementation phases

### Phase 1: Product and store foundation

- Confirm subscription name and benefit copy.
- Decide whether cross-platform entitlement is required.
- Decide how existing users will be treated.
- Create Apple and Google subscription products.
- Connect both stores to RevenueCat.
- Create RevenueCat `premium` entitlement and default monthly offering.
- Prepare localized store metadata.

### Phase 2: Subscription domain layer

- Add the RevenueCat Flutter SDK.
- Create the repository interface and RevenueCat implementation.
- Add entitlement and offering providers.
- Support purchase, restore, refresh, and manage-subscription operations.
- Add cached-state handling.
- Keep RevenueCat public SDK keys separate by platform.
- Never put Apple private keys, Google service credentials, or RevenueCat secret keys in `env.local.json`.

### Phase 3: Paywall and subscription settings

- Build the localized paywall.
- Use the store-provided price string.
- Add Restore Purchases.
- Add a Settings card showing Active, Renews, Canceled, Billing Issue, or Expired.
- Add Manage Subscription.
- Add Terms and Privacy links.
- Add purchase success and failure feedback.

### Phase 4: Feature gates

- Gate both the Route Planner entry point and its screen.
- Gate Map and Settings offline-download actions.
- Gate `OfflineMapController.download()` itself.
- Preserve existing local data.
- Implement confirmed-expiration cleanup for Mapbox tiles.
- Reserve the future personalized-time entitlement without exposing unfinished UI.

### Phase 5: Lifecycle and operations

- Configure Apple and Google lifecycle integrations in RevenueCat.
- Add a RevenueCat webhook to a small Firebase or Cloud Run endpoint for audit and support events.
- Log entitlement transitions without logging purchase secrets.
- Add a support workflow for identifying a RevenueCat customer and diagnosing restore problems.
- Add analytics for paywall shown, purchase started, purchase completed, restore, and feature unlock.

### Phase 6: Testing

Unit and widget coverage:

- Free versus active entitlement
- Canceled-but-not-expired access
- Grace-period access
- Pending-purchase denial
- Expired and refunded access denial
- Route Planner deep-link protection
- Offline controller refusing unauthorized downloads
- Existing data preserved after expiration
- Store price rendered from product data
- All five supported languages

Store integration scenarios:

- Successful purchase
- User-canceled purchase
- Purchase failure
- Pending Android purchase
- Renewal
- Billing failure
- Grace period
- Account hold
- Expiration
- Refund or revocation
- Restore after reinstall
- Offline launch with cached active entitlement
- Offline launch after known expiration
- Switching store accounts

References:

- [StoreKit Test](https://developer.apple.com/documentation/StoreKitTest)
- [TestFlight subscription testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight)
- [Google Play Billing testing](https://developer.android.com/google/play/billing/test)

## Launch strategy

1. Do not introduce an annual plan initially.
2. Do not introduce a free trial until normal purchase and renewal behavior is stable.
3. Ship a prior update announcing that Offline Maps and Route Planner will become Premium.
4. Give existing users a clearly communicated transition period.
5. Do not delete existing downloaded maps before the premium launch date and a confirmed inactive entitlement.
6. Launch the entitlement on iOS and Android together.
7. Add personalized walking-time calculation to the paywall only when it is implemented.

## Decisions required before implementation

Recommended defaults:

- Billing provider: RevenueCat
- Price: €4.99/US$4.99 monthly
- Account required: No
- Cross-platform entitlement: No for version one
- Free trial: No initially
- Online map: Free
- Basic Naismith estimate: Free
- Existing saved plans: Preserve but lock
- Expired offline tiles: Remove only after confirmed expiration
- Existing-user transition: Announce in advance and provide a temporary grace period
- Future personalized estimate: Reserve the entitlement now and advertise it only after implementation

