# Trail reports — first release

## User flow

- Mobile: map or stage warning menu → **Report trail problems**. Choose problem type and passability, describe it (500 characters), use GPS or a manually selected location, attach up to three photos, and optionally supply an email. Sending confirms the displayed coordinates without a separate checkbox. Report screens, categories, statuses and error messages support all app languages (English, German, Spanish, Italian and French).
- Drafts, coordinates, and processed images are stored on the device. **Send report** queues a stable report ID. Upload resumes while the app is open after connectivity returns. A report is shown as received only after server acknowledgement. **My reports** holds local drafts and submission receipts.
- Website: `/trail-reports`. Verified trail users see only assigned trails. Admins can see every trail, assign/revoke trail access, review status/priority, and record forwarding or resolution notes.
- Forwarding is manual: download a self-contained printable HTML report (open it and Print / Save as PDF), an `.eml` with attached photos, or copy forwarding text. Nothing is sent automatically. Exports omit contact email and internal notes.

## Firebase structure and boundaries

All collections below are at the database root, outside the publicly readable `trails` subtree:

- `trailReports/{reportId}`: `trailId` (required), optional `stageId`, category, description, passability, latitude/longitude and GeoPoint, location source/accuracy, observation timestamp, optional contact email, reporter UID, app version, photo manifest, upload state, status, priority, authority/reference, duplicate ID and timestamps.
- `trailReports/{reportId}/events/{eventId}`: append-only submission/review audit history. Server writes only.
- `trailReportAccess/{uid}`: verified account email and an array of assigned `trailIds`. Only admin callables can change it. A user may get their own membership, but cannot list other members.
- `trailReportAccessAudit/{id}`: admin-only membership change log.
- `trailReportQuotas/{id}`: server-only daily submission counters.

Firestore allows report reads only for verified admins or verified users assigned to that report's trail, and only once the upload is complete. All report and review writes go through callable Functions. Reporters have no collection read permission; an owner-only callable returns a limited receipt/status.

Private Storage paths:

- `trail-report-uploads/{uid}/{reportId}/{photoId}/photo.jpg`: owner-only immutable staging uploads, limited to the reserved photo manifest, JPEG and less than 2 MiB.
- `trail-report-media/{reportId}/{photoId}.jpg` and `-thumb.jpg`: server-generated images, available only to assigned reviewers/admins. The website retrieves image bytes through an authorized callable; there are no public download links.

The server validates input, strips unknown fields, decodes/re-encodes images without EXIF, creates thumbnails, and finalizes the report atomically. Stable IDs and fingerprints prevent duplicate retries. Daily limits are ten reports per anonymous UID and 1,000 total. Callable concurrency is capped at two requests per instance to bound photo-processing memory. Anonymous identity resets can evade the per-UID limit; App Check and the global cap provide additional protection.

A scheduled task removes incomplete upload files after 14 days and retries failed cleanup. It does not delete completed reports. Establish a retention policy before broad rollout; Firestore backups and Storage photo backups must be planned separately. Deleting a local receipt does not delete a received report.

## Production requirements

Production callables always enforce Firebase App Check. Only the isolated Functions Emulator omits attestation. Enable `firebaseappcheck.googleapis.com` and `recaptchaenterprise.googleapis.com`; the generated App Check service identity needs its standard `roles/firebaseappcheck.serviceAgent` role.

The six Firebase callables require `roles/run.invoker` for `allUsers` at the Cloud Run transport layer: `beginTrailReport`, `finalizeTrailReport`, `trailReportReceipt`, `trailReportPhoto`, `reviewTrailReport` and `setTrailReportAccess`. Firebase clients send Firebase Auth tokens rather than Cloud IAM invocation tokens. The handler still enforces App Check and signed-in identity; report ownership, verified trail membership and admin checks continue to govern data access. The scheduled cleanup function stays private. The six service policies were updated and verified after deployment on 8 October 2026. This workspace’s Firebase CLI/Functions SDK combination does not apply the callable invoker option during an update; verify the Cloud Run policy after deployment rather than relying on deployment success alone.

- iOS: App Attest, registered Apple team `5B7KGRSAGA`, production App Attest entitlement. Real-device signed testing is required; simulators cannot provide production attestation.
  - Local simulator testing against live Firebase can use an explicitly registered private App Check debug token in ignored `mobile/firebase-debug.local.json` under `FIREBASE_APP_CHECK_IOS_DEBUG_TOKEN`. Launch from `mobile/` with both `--dart-define-from-file=env.local.json` and `--dart-define-from-file=firebase-debug.local.json`. Only debug builds can select this provider; release/profile builds always use App Attest. Never print, share or commit the token. A private local simulator token was registered and its App Check exchange verified on 8 October 2026. Its registration reference is stored privately in `.firebase-config/trail-report-simulator.json` for later revocation.
- Android: Play Integrity. For Google Play testing/installations, register the **app signing certificate** SHA-256 from Play Console, not just the local upload certificate. Link Play Integrity to the same Cloud project in Play Console as required by Google. Validate a submission from a Play-installed build before rollout.
  - On 8 October 2026, the supplied Play app-signing SHA-256 (`6A:6A:7F:CE:7C:F8:62:23:42:33:7E:6D:30:89:46:36:CD:A2:F3:AA:7F:C9:BA:9C:27:75:08:6F:19:B3:8D:4D`) was registered and verified alongside the existing upload certificate. The Play Integrity API was enabled in project `eurotrex` (`893185124081`). The owner confirmed the Play Console link to `eurotrex` (`893185124081`) under **Protected with Play → Play Integrity API** on 8 October 2026. The connected browser account cannot independently inspect that developer account.
- Web: domain-restricted reCAPTCHA Enterprise provider, registered with Firebase App Check. The public site key is in `www/lib/firebase.ts`; it is not a secret.
- Anonymous and email/password Firebase Authentication must be enabled. Trail reviewers must verify their email before an admin grants membership.
- The Sites website remains private. Each new trail reviewer needs both a Sites audience invitation and a Firebase trail assignment. These are independent access gates.

No existing trail-user assignments are inferred or granted by this implementation.

## Deployment and tests

Deploy using the dedicated config so existing root emulator configuration remains intact:

```sh
node node_modules/firebase-tools/lib/bin/firebase.js deploy \
  --config firebase.reports.json --project eurotrex \
  --only functions:trail-reports,firestore,storage
```

Functions use Node 22, a pnpm lockfile, explicit Functions Framework dependency and package-scoped build approvals. Publish `www` with its existing Sites workflow and preserve the current private audience.

Isolated backend tests (from repository root; Java must be available):

```sh
node node_modules/firebase-tools/lib/bin/firebase.js emulators:exec \
  --config firebase.reports.json --project demo-eurotrex \
  --only auth,firestore,storage,functions \
  'cd functions && node --test --test-concurrency=1 test/*.test.js'
```

Tests cover validated input, private photos, upload overwrite denial, retries, review history, cross-trail denial, self-grant denial and access revocation.

For native integration tests, start these emulators and seed `trails/cyprus-e4` in the **demo-eurotrex** emulator. Run from `mobile/`:

```sh
flutter test integration_test/trail_reports_test.dart -d <simulator-id> \
  --dart-define-from-file=env.local.json
```

The test uses emulator Firebase services and native SQLite/file/image/upload plugins. It checks form validation, saved photo drafts, queued submissions and server receipts. It does not test a physical camera, actual GPS, Play Integrity or App Attest. Integration tests uninstall their test app; restore the regular app with the same environment-file flag.

For website UI tests only, start `www` in development with `NEXT_PUBLIC_REPORTS_EMULATOR=true`; this targets `demo-eurotrex` on localhost and cannot activate in a production build. Test accounts and fixture reports must stay in the emulator. Production has no test-account access bypass.

## Verification recorded for this implementation

- Backend emulator security and complete submission/review/revocation flow: passed (5 tests).
- Draft persistence/validation: passed (2 Flutter tests).
- Forwarding export privacy, HTML escaping and UTF-8 email attachments: passed.
- Android and iOS native form → persistent photo draft → emulator Firebase → receipt: passed.
- Website TypeScript and production build: passed; admin review/photo/history and forwarding text checked against emulator data.
- Firebase functions/rules/indexes deployed; private Sites version 60 published.
- 8 October 2026: six callable Cloud Run invocation policies verified, scheduled cleanup confirmed private, and all six callables rejected unauthenticated live requests both with and without valid App Check.
- 8 October 2026: private simulator App Check token registered and exchanged successfully. Two previously failed iOS simulator reports retried successfully; both have live Firestore `uploadState: complete` and `receivedAt`, and both local receipts show `sent` / `new`.
- A successful report submission from the latest Play-installed Internal Testing build remains a release prerequisite; the supplied Play signing fingerprint is registered and the owner confirmed the project link.

The normal iOS simulator app was restored after testing. No Google Play/TestFlight upload was performed. The Firebase CLI reported a build-image cleanup warning after otherwise successful deployments; retained build images may need an Artifact Registry cleanup policy.
