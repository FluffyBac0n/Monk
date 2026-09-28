# EuroTrex website

The EuroTrex marketing site and accommodation partner portal. The public site sends hikers to the mobile app; authenticated website accounts are reserved for accommodation owners and administrators.

## Stack

- Next.js 16 / React 19, built with Vinext for OpenAI Sites
- Firebase Authentication for owner and admin sign-in
- Cloud Firestore for submissions, audit records and app-facing lodgings
- Static assets and native CSS for a low client footprint

## Local development

1. Copy `.env.example` to `.env.local` if local values need to differ from the
   prepared Firebase Web app configuration.
2. Run `pnpm install --ignore-workspace` and `pnpm dev` from this folder.

The checked-in Firebase fallback points to the existing `eurotrex` project so this site and the mobile app share the same trail data. Firebase API keys identify the project; Firestore rules provide authorization.

## Data flow

1. A prospective host creates an account with a company name and email. The site creates a tightly limited `ownerProfiles/{uid}` request with `accessStatus: "pending"`; clients cannot activate or edit that status.
2. The owner verifies their email. A trusted administrator reviews the request and changes `accessStatus` to `active`; unverified or pending accounts cannot read or write host listing data.
3. Their form writes only to `accommodationSubmissions/{id}` with an awaiting-review status.
4. An administrator approves the submission. One atomic batch publishes a mobile-compatible record to `trails/{trailId}/lodgings/{id}`, updates the submission and records `accommodationAudit/{id}`. Public records do not expose owner or private submission identifiers.
5. Approved owner edits become `pending_update`; the existing app record stays unchanged until re-approved.
6. Admin removal deletes the app record, preserves the submission as `removed`, and records the reason.

The admin inventory uses a Firestore collection-group query so it covers lodgings across all trails, including imported records that have no website owner.

## Administrator setup

Create a document at `admins/{firebaseAuthUid}` for each administrator, or issue a custom auth claim of `admin: true`. The dashboard accepts either. Admin documents should only be created through a trusted Firebase console or server process.

Host account requests are created through the portal with `accessStatus: "pending"`. Review each request in Firebase Console or another trusted server process, confirm the company and email, then set `accessStatus` to `active`. The profile email must exactly match the verified Authentication email. Set `accessStatus` to `disabled` to revoke portal access without deleting the account or its audit history.

Deploy the included rules after reviewing them alongside the project's existing production rules:

```sh
firebase deploy --only firestore:rules --project eurotrex
```

Do not replace broader production rules blindly; merge if the mobile app relies on additional collections.

## Private testing and release

Follow [the private host-portal testing checklist](docs/private-host-portal-testing.md)
to create an owner account, bootstrap an administrator, exercise the approval
flow, and run the self-cleaning production smoke test.

## Release checklist

- Replace the placeholder partner policy and privacy notice with counsel-approved documents.
- Add the final App Store, Google Play and production site URLs as environment variables.
- Verify the Firestore trail/stage names and run owner approval/removal tests.
- Keep the website owner-only until these launch checks are complete.
