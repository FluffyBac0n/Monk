# EuroTrex: fresh Firestore deployment and backup recovery

Verified against the live `eurotrex` project on **1 October 2026**. This runbook
creates a **separate** Firebase project; it does not overwrite the current one.
No fresh cloud database was created as part of preparing this document.

## 1. What belongs in Git

| File | Purpose |
| --- | --- |
| `www/firestore.rules` | Website/mobile authorization, including verified-admin collection-group access to lodgings |
| `www/firestore.indexes.json` | All deployed custom composite indexes and field overrides (currently both empty) |
| `www/firebase.json` | Connects the rules and indexes to Firebase CLI deployment |
| `www/firestore.settings.json` | Observed database settings and backup schedule; informational, not auto-deployed |
| `scripts/firestore-backup.mjs` and `scripts/firestore-backup-lib.mjs` | Local export, verification and guarded fresh-project restore |
| `scripts/firestore-backup-live-verify.mjs` | Read-only live count comparison at the backup snapshot time |
| `tests/firestore-backup.test.mjs` | Backup traversal, integrity and restore safety tests |
| `docs/firestore-schema.md` | Trail data structure |

Commit those files after review in the appropriate repositories. `www/` is a
separate nested Git repository: changes there appear in both repositories.
**Do not commit `private-backups/`, account data, service-account keys, local
environment files, or Firebase CLI credentials.**

The root `.firebaserc` defaults to `eurotrex-local` for emulator work. The root
`firebase.json` contains emulator configuration, not the production deployment
configuration. Always specify `--project` and `--config www/firebase.json` when
deploying from the root. Do not use the emulator-oriented `npm run firebase`
wrapper for production: it selects a different local CLI credential store.

## 2. Recorded production settings

- Project: `eurotrex`; database ID: `(default)`.
- Native mode, Standard edition, region/multi-region: `eur3`.
- Pessimistic concurrency, realtime updates enabled, App Engine integration disabled.
- No custom composite indexes, field index exemptions or TTL policies.
  Normal automatic single-field indexing still applies; an empty index file does
  **not** turn it off. The API's `__default__` field entry is service metadata,
  not a custom override to deploy.
- Existing managed backup schedule: **daily**, retained for **98 days / 14 weeks**.
- PITR and database delete protection are currently **disabled**.

Location is an important creation-time choice. Use `eur3` to match the existing
database. For a new production database, enable delete protection and consider
PITR after reviewing cost; those are explicit improvements rather than copies of
the currently disabled settings. Preparing this runbook did not enable them on
the source project.

## 3. Create the Firebase project and database

Requirements: Node.js 22+, Firebase CLI (installed by the root `pnpm install`),
and Google Cloud CLI if using the shell commands below. The Google account needs
appropriate project creation, database administration, Firebase rules and data
access IAM permissions. Client Firestore rules do not authorize administrative
OAuth backup/restore operations; IAM does.

1. In Firebase Console, create a **new Firebase project**, or add Firebase to a
   new Google Cloud project. Select billing as appropriate. Do not change the
   existing Site's private audience/access settings.
2. From the repository root, sign in and choose explicit target variables:

   ```sh
   cd "/Users/amich/Documents/Monk 2"
   pnpm install
   node node_modules/firebase-tools/lib/bin/firebase.js login
   gcloud auth login
   export EUROTREX_NEW_PROJECT="your-new-firebase-project-id"
   export EUROTREX_BACKUP="private-backups/eurotrex-2026-10-01T07-50-29-641Z"
   ```

3. Enable Firestore and create the **empty default Native database**. If you
   already created it in Firebase Console, do not run the create command again:

   ```sh
   gcloud services enable firestore.googleapis.com --project "$EUROTREX_NEW_PROJECT"
   gcloud firestore databases create \
     --project "$EUROTREX_NEW_PROJECT" \
     --database='(default)' \
     --location=eur3 \
     --type=firestore-native \
     --edition=standard \
     --concurrency-mode=pessimistic
   ```

   Use production/locked rules if creating it through the console, not open test
   mode. Firebase Authentication and administrator IAM provisioning are separate
   from creating the database.

4. Deploy the reviewed authorization and index files:

   ```sh
   node node_modules/firebase-tools/lib/bin/firebase.js deploy \
     --config www/firebase.json \
     --only firestore:rules,firestore:indexes \
     --project "$EUROTREX_NEW_PROJECT"
   ```

   Never use `--force` to remove indexes on an existing database. These commands
   are intended for the new empty project. If the index file changes later, wait
   for any new indexes to finish building before testing queries.

5. Recreate the existing daily backup policy after arranging required billing:

   ```sh
   gcloud firestore backups schedules create \
     --project "$EUROTREX_NEW_PROJECT" \
     --database='(default)' \
     --recurrence=daily \
     --retention=14w
   ```

   Inspect schedules first if recovering an already configured environment to
   avoid duplicates. A schedule is not proof that its first backup has completed;
   verify a completed managed backup in the console. For additional protection:

   ```sh
   gcloud firestore databases update \
     --project "$EUROTREX_NEW_PROJECT" \
     --database='(default)' \
     --delete-protection \
     --enable-pitr
   ```

   This last command is optional hardening; review cost/retention requirements
   before running it. It differs from the source's current settings.

## 4. Restore the local data backup

The downloaded backup contains **502 documents**, captured at
`2026-10-01T07:50:29.668753Z`. There are 496 documents under `trails` (including
subcollections), plus 6 host/admin/audit/draft/submission documents. Counts and
checksums are in `manifest.json`; private document contents are not in Git.

```sh
node scripts/firestore-backup.mjs verify --backup "$EUROTREX_BACKUP"

# Read-only plan; does not connect to or write the destination.
node scripts/firestore-backup.mjs restore \
  --backup "$EUROTREX_BACKUP" \
  --project "$EUROTREX_NEW_PROJECT"

# Restore trail content to the empty destination.
node scripts/firestore-backup.mjs restore \
  --backup "$EUROTREX_BACKUP" \
  --project "$EUROTREX_NEW_PROJECT" \
  --scope trails \
  --commit --confirm-project "$EUROTREX_NEW_PROJECT"
```

Important restore behavior:

- Default scope is `trails`, including all nested trail collections.
- Source-project restoration is forbidden. A nonempty destination is rejected;
  every write also requires that its document does not already exist.
- The script preserves typed field values, paths/IDs, field timestamps, nested
  maps/arrays, coordinates, bytes and integer strings. Same-source-database
  document references are changed to the destination database; external database
  references and ordinary strings are left unchanged.
- Firestore system `createTime`/`updateTime` are generated anew on restore.
- Restoration uses small create-only batches, not one database-wide transaction.
  If it fails after some batches, **stop** and inspect the destination. Do not
  bypass the empty-database safeguard or blindly retry. Prefer a separate fresh
  recovery target over deleting an existing database.
- Document data is read at one fixed server-provided read time. It must finish
  within the service's historical-read window; an expired read fails rather than
  silently creating an inconsistent backup. Rules/index/settings/schedule APIs
  are captured separately and are not atomic with that document snapshot.

### Full disaster recovery rather than a clean start

`--scope all` restores host profiles, submissions, drafts and audit records as
well as trails, but **still excludes `admins`**. Only use it when Firebase Auth
users have been migrated separately with their original UIDs, or you have planned
and reviewed UID/ownership mapping. Otherwise listings can become orphaned and
owners cannot access their records. Creating a new account with the same email
does not guarantee the same UID.

```sh
# Choose this instead of the trails-only restore, not afterwards.
node scripts/firestore-backup.mjs restore \
  --backup "$EUROTREX_BACKUP" \
  --project "$EUROTREX_NEW_PROJECT" \
  --scope all \
  --commit --confirm-project "$EUROTREX_NEW_PROJECT"
```

`--include-admins` is available only as an explicit additional choice for a
reviewed full-identity migration. Prefer bootstrapping named administrators anew.
Do not copy an `admins/{oldUID}` record onto an arbitrary new user. The restored
admin document would grant privileged access to whichever Auth identity has that
UID. Do not migrate test administrators into a real production launch unnoticed.

## 5. Firebase Authentication, administrators and host access

Firestore backups **do not contain Auth users, password hashes, email templates,
custom claims or provider settings**. For a clean project:

1. Enable **Email/Password** sign-in under Firebase Authentication.
2. Add the intended private-preview/production website domains and `localhost`
   if needed to the authorized domains. Configure action URLs/email templates
   for verification and password resets and test actual delivery.
3. Create the intended admin account through the normal Auth flow. The owner
   completes their password and verifies their email; do not mark unknown emails
   verified merely to bypass the gate.
4. Through Firebase Console or a trusted IAM-admin process, create
   `admins/{ACTUAL_NEW_AUTH_UID}` with `email`, `role: "administrator"` and
   `createdAt`. The document ID must be the UID in **this project's** Auth users.
   Do not enable clients to self-promote. A trusted `admin: true` Auth custom
   claim is the other supported approach.
5. Sign out/back in and open `/admin`. Verify the review queue, live listings
   collection-group query and audit log load without permission errors.
6. Hosts register company name and email, verify the email, then undergo manual
   review. Their `ownerProfiles/{UID}` starts with `accessStatus: "pending"`.
   After review, a trusted administrator sets `accessStatus` to `active`; the
   profile email must exactly match the verified Auth email. Use `disabled` for
   revocation. Host-account approval is currently a console/trusted-process step,
   not a host-accessible control.

For full identity recovery, plan a separate Firebase Auth export/import with
original UIDs and password-hash configuration, protected as credentials. No Auth
export was performed for this Firestore-only backup request.

## 6. Point website, mobile app and importer to the new project

- Register Web, iOS and Android apps in the new Firebase project. Retrieve their
  real generated configs; do not copy the old web API-key fallback as a substitute.
- Set every website `NEXT_PUBLIC_FIREBASE_*` value from the new Web app in local
  and hosting environments, plus the correct `NEXT_PUBLIC_SITE_URL`, then rebuild.
  `www/lib/firebase.ts` has old-project fallbacks: missing new settings can
  accidentally reconnect a preview to production.
- Regenerate mobile Firebase options/platform configuration for the new project,
  using the correct app package/bundle IDs. Review the generated changes.
  When launching Flutter, run from `mobile/` and always use
  `--dart-define-from-file=env.local.json`. Never print, copy or commit that file.
- Configure importer `FIREBASE_PROJECT_ID` and trusted credentials for the new
  project. The workbook importer is an alternative for trail-only seeding, not
  recovery of host/admin data. Do not combine importer overwrite operations with
  an existing restored dataset without review.
- Keep IAM service accounts least-privileged. Set App Check/IAM/API restrictions
  separately as required; none is recreated by Firestore rules or this backup.

**This is not a complete website backup.** Notify-me and Join Us submissions
are stored in Cloudflare D1 (`www/app/api/interest/route.ts`), not Firestore.
Those need a separate D1 backup/migration, including the SQL files in
`www/drizzle/`, the runtime database binding and `INTEREST_RATE_LIMIT_SECRET`.
Storage objects, website assets/deployment settings and Firebase Auth also need
their own recovery procedures. Do not change Site audience while migrating.

## 7. Verification and future backups

```sh
# Offline helper tests; no production writes.
node --test tests/firestore-backup.test.mjs

# Download a new fixed-read-time snapshot and live configuration.
node scripts/firestore-backup.mjs export --project eurotrex

# Optional independent count check while the snapshot is still in the historical-read window.
node scripts/firestore-backup-live-verify.mjs --backup "$EUROTREX_BACKUP"

# Compare live deployable index config manually before updating the Git file.
node node_modules/firebase-tools/lib/bin/firebase.js firestore:indexes --project eurotrex
```

`export` creates a new timestamped directory under root `private-backups/`,
refuses to overwrite existing directories and uses owner-only permissions.
`documents.jsonl` and `configuration.json` have SHA-256 checksums. Only a
successfully finished export has a complete `manifest.json`; keep failed partial
directories separate from usable backups. Exporting reads live documents and can
incur normal read charges. Never print private records into terminal logs.

Before accepting a fresh deployment:

- Confirm project identity on both clients; read `trails/cyprus-e4` and its stages.
- Test the slideshow/trail guide plus the mobile trail/stage/location data.
- Test public reads and denied unauthenticated writes; pending/unverified hosts
  must not read listing data or activate themselves.
- Test an approved owner's draft, submission and admin publish/reject/update/
  removal workflow; verify the app-facing lodging and corresponding audit event.
- Test one owner cannot read another owner's private submissions.
- Check the admin inventory's `collectionGroup('lodgings')` query.
- Test real verification/reset-email delivery.
- Confirm daily scheduled backups actually complete and rehearse a restore to
  an isolated project. A local checksum check is not a cloud restore drill.

The 1 October backup was downloaded and checksum-verified. Independent live
aggregation queries at its exact read time verified **all 16 collection-path
counts**, totaling **502 documents**. All 7 helper tests pass, and the restore
dry-run plan was checked. No fresh cloud project was created and no live restore was run. This
machine lacks a Java runtime, so no Firestore emulator restore drill was run.
Do **not** run `www/scripts/portal-production-smoke.mjs` against a new project as
written: it is hard-coded to the live `eurotrex` project and mutates test records.

### Format and storage limitations

This is a portable typed-JSONL snapshot, **not** a Google managed export or
Firebase emulator export. It must be restored using the supplied script, not
`gcloud firestore import` or emulator `--import`. The backup directory contains
personal/contact data and access-control records. Owner-only permissions are not
encryption. Use disk encryption and an approved encrypted off-device copy;
keeping a backup only on the same laptop is not disaster recovery. No off-device
upload was performed.

## Official references

- [Firestore REST document listing and snapshot read time](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/listDocuments)
- [Nested collection discovery](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/listCollectionIds)
- [Create a database with Google Cloud CLI](https://docs.cloud.google.com/sdk/gcloud/reference/firestore/databases/create)
- [Managed export/import and its separate format](https://firebase.google.com/docs/firestore/manage-data/export-import)
- [Daily backup schedules](https://docs.cloud.google.com/sdk/gcloud/reference/firestore/backups/schedules/create)
