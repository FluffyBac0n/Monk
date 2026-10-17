# Website feedback v3 — implementation handoff

Prepared 17 October 2026 on `codex/website-feedback-v3`, based on `main` at `9fc54e7`.

The user authorized implementation on a separate branch after the initial review. They specified that the relevant Text sheets supply the copy, that images are mockups rather than statistical evidence, and that programmes should start with descriptions and enquiries. This branch has not been merged, pushed or deployed. Production records, permissions and app releases were not changed.

## Delivered scope

| Workbook content source | Implementation |
| --- | --- |
| Hero Section v2 -Text | Revised homepage hierarchy, emotional introduction, three audience cards, Cyprus foundation, compact app and community links. |
| Explore Trails - Text | Live Cyprus guide, route/elevation figures, reference-point directory, accommodation search, reviewed notices and a constrained multi-day planner. |
| Get Inspired - Text | Motivation, eight supplied quotations, existing Cyprus imagery, approved stories and moderated text submissions. |
| The Eurotrex Initiative - Text | Mission, origins, three phases, Cyprus foundation and funding acknowledgement on the retained `/about` URL; existing founders' biographies retained. |
| Community & Support - Text | Walking pace, future expeditions, work/volunteer, collaboration and support enquiries on `/get-involved`. |
| Become a Host - Text | Eligible host types, Partner/Premium/Friends/Member descriptions and programme-specific enquiries on `/become-a-host`. |

Copy is centralized in `www/lib/website-copy.ts`. Spelling, punctuation and presentation have been adjusted while retaining the supplied meaning. The Text sheet attribution to Jake Dartington takes precedence over the conflicting mockup attribution. Existing site photographs are reused; workbook images and mock statistics were not imported. The optional government consulting item marked “not now” is omitted. ERA links provide E4 information without claiming certification of this specific recorded alignment.

Desktop, mobile and footer navigation agree. Existing portal, reporting, stage and public page URLs remain available. Store buttons appear only when their actual configured links exist; otherwise visitors see the private-testing notification option.

Host registration now accepts first name, surname, optional company, email and password confirmation. Client validation, profile models, administrator labels and Firestore rules were changed together. Existing company-only profiles remain compatible. Email verification, account activation and separate listing review remain in place. A verified listing badge derives from an approval timestamp; imported records do not receive a badge merely because they exist.

Partner, Premium, Friends and Member descriptions lead to enquiries. Submitting an enquiry does not collect payment, confer a tier, grant a discount entitlement or change listing priority.

## Database-backed trail behaviour

`www/lib/public-trail-data.ts` reads public Firestore records for `trails/cyprus-e4`: root metadata, stages, route metadata/chunks and lodgings, plus reviewed/forwarded public trail issues. It selects intended public fields, validates geometry and contact links, sorts reference points by accumulated distance, and distinguishes unavailable data from an empty collection. No private report identities or internal notes enter the notice feed.

Public records have a 60-second cache. Geometry is reused until its identifying metadata changes; polling notices does not repeatedly download the route. The notice fragment refreshes every 60 seconds in an open guide. Source dates are shown rather than implying that recorded information is current availability.

The planner supports either direction, selected endpoints, an optional exact day count, a strict maximum daily distance and recorded camping stops. It balances feasible days and displays their points, water, ascent/descent and stays. Blank lodging placeholders do not create overnight candidates. Impossible constraints return an explanation and adjustment options. Planning does not reserve rooms, confirm camping permission or synchronize an app itinerary.

Observed source-data considerations for review:

- The collection contains 193 lodging documents while its cached root count says 192. Displayed directory counts come from the collection.
- Some lodging records lack a name/contact or other useful details. They remain visibly incomplete; the site does not invent establishments.
- Recorded stage distances and the full geometry total differ slightly. Each is used for its appropriate purpose and the guide explains the difference.
- The current full route cannot be split at recorded overnight stops under the default 30 km cap. A shorter Pafos Airport–Tsada plan succeeds at 25.9 km. Improving the underlying overnight data is separate from relaxing a user's constraints.
- A reviewed public notice currently contains “test”. It is visible because it is approved source data. An authorized administrator can review its production status separately.

## Stories and privacy

Submissions use the existing D1 enquiry system. Separate publication permission records store the chosen public name, title, consent and review metadata. New stories are pending. Only approved stories with publication consent are selected publicly; private names and contact emails are excluded. React/HTML escaping prevents story or notice text from executing markup. Optional project-update consent remains separate.

The administrator **Trail stories** tab can approve or reject stories. Its API validates a Firebase token and the existing administrator role before reading or changing the queue; moderation writes require same-origin requests. Rejecting an approved story removes it from public results. No administrator role was created during this work.

## Validation completed

All checks below passed against this branch:

- TypeScript: `tsc --noEmit`.
- Production bundle: `vinext build`.
- `node scripts/website-feedback-test.mjs`: itinerary constraints/direction, incomplete data, route decoding, safe contacts, notice escaping/privacy and administrator validation.
- `node scripts/experience-smoke.mjs`: 12 public routes, enquiry/consent persistence, programme submissions, pending/approved/removed story visibility, private-field exclusion, HTML escaping, moderation rejection and notice fragments. Fixtures were local and cleaned up.
- Existing report-access, route-cache, deployment-recovery and local-preview test scripts.
- Firestore emulator `scripts/host-approval-test.mjs`: individual/business signup, legacy compatibility, pending-account restrictions, denied self-approval/forged profiles, and existing approval/audit behaviour.
- Browser review at desktop and narrow mobile widths: navigation, page layout/overflow, planner recalculation, programme enquiry selection, directory, stories consent and signup fields. No production account was created.
- `git diff --check`.

No authenticated production end-to-end write was attempted. Build output retains Vinext's route-classification limitation; a successful build does not certify every deployed integration. The existing development server was used for browser QA and stopped after capture.

## Review and later rollout

1. Review the branch diff and public copy/layout. The initial assessment remains in `website-feedback-v3-review-and-plan.md`; this handoff records the subsequently authorized scope.
2. Review existing source-data gaps and the approved test notice with the trail-data administrator. Confirm quotation attribution and funding wording before publication.
3. Through the existing website release process, apply `www/drizzle/0003_story_publication.sql` to the site's D1 `DB` binding. Runtime schema initialization also creates the table idempotently; applying the migration records the release deliberately.
4. Deploy the matching `www/firestore.rules` using the website's established Firebase configuration before making the new signup form live. Preserve the wider mobile/shared collection rules and indexes. No new public Firestore collections are required.
5. Publish only after review/merge is authorized. Verify host registration, account review and story moderation with designated test accounts in the chosen release environment, and check the production D1 binding and configured app-store URLs.

Local preview can be restarted from `www/` with `pnpm dev`. Mobile files and secrets are outside this change.
