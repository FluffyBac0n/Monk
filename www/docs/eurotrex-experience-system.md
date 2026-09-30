# EuroTrex experience system

## Shared identity

- Company: EuroTrex Ltd. Team: Pavlos Christofides and Andreas Michaelides. Do not invent roles or biographies.
- Product: EuroTrex. Trail labels: **Cyprus-E4**, **Crete-E4**, **Peloponnese-E4**. Database IDs and URLs remain `cyprus-e4`, etc.
- Sand `#F4F2EC` canvas, navy `#303E4E` headings, blue `#2D5DD3` actions, pale blue `#E2EBEE` supporting surfaces, gold `#F2C94C` trail accents.
- Navigation gradient: `#38516C` → `#2D619B`. White cards are working surfaces, not alternate page backgrounds.
- Controls use 14px corners and at least 44px touch areas. Blue primary actions; outlined secondary actions; gold is not a second primary-action language.
- Green is semantic success/offline/on-trail state, not decorative brand color.
- Keep native platform fonts; align hierarchy, weights and spacing rather than forcing one font everywhere.
- Photography establishes places and real experiences. Illustrations explain participation. App screenshots demonstrate functionality.
- Stage-point service icons use the same metaphors as the app: bed, camping shelter, food, groceries, water, toilets, medical, pharmacy, bank and bus.

## Vocabulary and promises

- Stage points are reference locations, not walking days.
- App availability: private testing until confirmed store links exist.
- Account approval and listing approval are separate. Both normally take 1–3 days (confirmed by the owner).
- Published means available to hikers. A submitted update is not the published version until approved.
- Dataset update dates are not field-check dates. Never infer current service availability from a boolean flag.
- Trail detail accommodation comes from the recorded snapshot; it is not a claim that those entries passed the new host approval workflow.
- Contact enquiry processing is separate from optional project updates. Persist consent, scope and timestamp in `interest_preferences`; historical enquiries have no inferred marketing consent.

## Release checks and remaining content

- Verify guide → directory → point → overview navigation, trail switching, Back/Forward, anchor links and modal focus on desktop/mobile.
- Apply `drizzle/0002_interest_preferences.sql` before deploying the new form handler. No production data has been changed by local work.
- Crete uses Robert Linsdell’s Samaria Gorge photograph (CC BY 2.0); Peloponnese uses Herbert Ortner’s Taygetos photograph (CC BY 3.0). Source and licence links appear beside each photograph. Both are destination landscapes, not verified route evidence; resized to 1280px and cropped by the layout.
- Add named-place photographs and editorial terrain/transport notes only when location/source is verified. The current locator is a route schematic with an external location-map link, not a replacement for navigation maps.
- Confirm team biographies and operational company details before adding them.
- Universal/app links require confirmed public domain, iOS application association and Android signing identity plus on-device tests. Do not show a nonfunctional “Open in app” control. Preserve trail/point IDs when this release integration is implemented.
- OS app icon redesign remains a coordinated app-release asset task; do not replace it silently with a website-only logo.
- The help page is `/help`; connect the app to the verified production domain once the website release is approved. Do not direct released app users to an owner-private preview.

## Local-first review

Leave changes uncommitted, as requested. The current Sites publishing workflow commits/pushes source; do not run it until the user has reviewed and authorized that step.

## Validation of this implementation

- Website TypeScript check, ESLint and production build pass. The build still warns about a client chunk larger than 500 kB; this is not evidence of a measured performance improvement.
- `node scripts/experience-smoke.mjs` passes for 10 local routes, correction context, optional consent persistence, trail-scoped subscriptions, deduplication, invalid email/scope, same-origin rejection and HTMX error responses. Synthetic local records are removed by the test.
- 51 Flutter tests passed across localization, shared chrome/theme and widgets. No simulator was launched and no environment file was read.
- Browser checks covered stage directory → detail → overview, future-trail switching and Back, scoped Notify modal, mobile anchors without text selection, About, Help, sign-in/create-account toggle and password-reset layout. No browser errors were captured during those checks.
- At 390px width, the homepage measured 8,109px tall versus the earlier 9,437px audit measurement (~14% shorter); hikers begins around 1,747px rather than 2,340px. No horizontal overflow was found on the checked mobile screens.
- Authenticated owner/admin submission and publication were not re-run against production. Those flows still need an approved test session; no production users, listings or access permissions were changed by this validation.
