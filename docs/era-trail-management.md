# ERA trail management

Implemented on `codex/era-trail-management` in the workspace and nested website repository.
Production rollout was explicitly approved on 25 October 2026 and is deployed. All eight Firestore indexes are confirmed READY.

## Workspace and permissions

`/era` replaces Trail Reports in navigation. `/trail-reports` redirects to `/era`.
The existing verified-email sign-in and portal styling are reused. Trail selection controls
Incidents, Trail Data, Verification, Published Versions, Audit Log and Access.

EuroTrex administrators confirm organisations and assign trail scope. Organisation
administrators manage verified accounts within that scope. Editor, verifier, incident
manager and viewer roles are independent. Existing incident assignments remain valid
and can be revoked from Access. Organisation suspension and role revocation remove access.

## Revisions and releases

- `eraOrganisations/{id}`: confirmed organisation, active state and permitted trail IDs.
- `eraMembers/{uid}`: organisation and roles per trail. Client writes are denied.
- `eraWorkspaces/{trailId}`: latest draft revision ID.
- `eraWorkspaces/{trailId}/revisions/{id}`: immutable content reference, hashes,
  source, contributors, base release, validation summary and workflow state.
- `era-private/{trailId}/{revisionId}/`: original GeoJSON and revision payload in
  Storage. Only authorised callable functions read these private objects.
- `trails/{trailId}/releases/{releaseId}`: complete immutable public release manifest,
  with route chunks, stages, markers and included excursion/detour snapshots below it.
  Staged children remain unreadable until their manifest is published.
- `trails/{trailId}.publishedReleaseId`: atomic pointer to the active complete release.
- `eraAudit/{eventId}`: immutable server audit entries, queried by trail.

Each save creates a new revision and checks the expected latest revision. The original
upload is retained with its SHA-256 hash. The editor supports map point selection,
movement/insertion, numeric coordinates/elevation, point removal, segment reversal and
reordering, explicit endpoint snapping, main/alternative classification, undo/redo and
unsaved-change warnings. Alternative segments remain in private revisions; published
main-route readers consume the validated main alignment.

Validation rejects unsupported geometry, invalid coordinates, duplicates, long missing
legs and disconnected main segments. It flags major distance/geographic changes.
Missing main-route elevation blocks submission: supply elevation-enriched GeoJSON and
record its source. Automatic third-party terrain enrichment is not implemented.

Stage IDs, services and accommodation links are retained. Existing stage/route-marker
locations are projected onto the proposed geometry. Managers can place missing pins,
select a leg at crossings and confirm off-route stops. Geometry edits clear connection
confirmations. Distances/elevation metrics are recalculated. Excursion/detour anchors and
route-dependent comparisons are recalculated; unresolved branches must be corrected or
explicitly excluded from the release. Exclusion preserves source records.

Workflow: draft → submitted → changes requested or approved → published.
Contributors cannot approve or publish their revision, including EuroTrex administrators.
Content is frozen at submission. Publication rechecks content/trail-record hashes, current
permissions, organisation state, latest revision, approval and the base release. The active
pointer changes only after all release documents are prepared. Rollback requires a reason
and expected current pointer and restores a previously approved complete release.

## Incidents and audit

Organisation incidents record origin, creator, trail/release, map-selected or numeric
location, observation date, category, passability, priority, optional stage and up to three
photos. Photo uploads are retryable, backend-normalised and checked with SHA-256; mobile
MD5 manifests remain supported. Creation does not publish a warning. Review includes an
explicit public-warning checkbox. Public projections exclude identities, contact details,
notes and photos. Existing incident review, forwarding, resolution and histories remain.

Hiker drafts retain the device's route release, including offline submissions. Older app
builds remain supported. Incidents keep their original coordinates/release after changes.
Successful changes and audit entries commit together. Photo retrieval is audited. Audit
filters cover date, user, action and record, with older-event loading. No outbound messages
are sent by the workflow.

## Website and mobile readers

The website's route/map/itinerary readers resolve a release before reading compatible
geometry and stages. Cache keys include the release ID. Trails without releases retain
legacy data paths.

Mobile stages/elevation watch one shared release snapshot. Downloads check chunk order,
counts, coordinates, distances and stage positions before committing geometry, stages,
release ID and provenance in one SQLite transaction. Failed downloads preserve the previous
complete dataset. Excursion/detour readers use the locally activated release. Stage cache
keys include the trail ID, with migration of existing data. Published trails appear in the
library; selected trail IDs propagate to data, maps, incidents and offline map regions.
Saved itineraries retain trail/release IDs; changed-release plans prompt for a new plan
instead of silently recalculating. Trail information shows source and verifying organisation.

Distributed mobile builds retain their legacy reader. The updated mobile code must be
installed/released before those devices consume the new releases. Native distribution
was not part of this implementation run.

## Verification — 25 October 2026

- Website TypeScript and production build passed.
- Flutter analysis and all 245 shared tests passed.
- 15 backend/model/security cases passed across the main suite and targeted legacy-rule
  rerun, covering validation, stable IDs, related routes, approval, stale writes, publication,
  rollback, organisation photos, warning publication, revocation and private-data boundaries.
- Legacy host approval rules passed.
- Existing website access, itinerary and geometry-cache regression scripts passed.
- Browser QA using isolated demo-eurotrex data verified sign-in, trail selection, revision
  editing/save/submission, contributor approval denial and organisation incident creation.
- No native simulator/device run or mobile store distribution was performed. The final offline-map/cache checks also passed.

The original workbook's recorded Desktop path is no longer present. Existing portal
components/styles and retained workbook-derived copy were used as the design references.
Public editorial copy and database statistics were preserved.

## Production activation

The user explicitly approved production rollout on 25 October 2026 after automatic
approval review requested confirmation. All 15 callable/scheduled functions deployed
successfully to `eurotrex` in `europe-west1`. Firestore rules and both additional index
definitions were deployed, preserving all six existing indexes.

The website was published with owner-only access preserved:

- URL: https://eurotrex.andreasmic332452.chatgpt.site/era
- Website source: `e900f8dd2d3a845c76f44482dc4bd2eb4f6f65a6`
- Deployment: `appgdep_6addbd8ce0c0819184c95e94d6519112` (succeeded).
- Saved version: `appgprj_6a99c4a0be9c8191af329ab9c4eaa1ed~appgver_d1c184b76b3c81919c06ee8401606250`.
- Archive: `output/era/era-site.tar.gz`.

Live checks confirmed the ERA page loads and the currently signed-in account is correctly
shown as having no assigned trails. Unauthenticated requests to `getEraAccess` and
`saveEraRevision` return HTTP 401. No test fixtures or trail revisions were published.

The Firebase CLI reported an automatic build-image cleanup warning after all function
operations succeeded. It does not affect deployment; no existing cloud images were deleted
manually. All eight indexes, including `eraAudit` and `releases`, were subsequently confirmed READY.

Configure the real organisation and its initial administrator in Access.
Use separate editor/verifier accounts for the Cyprus pilot. Missing elevations and unresolved
stage/related-route connections remain publishing blockers until the team resolves them.

## ERA tab styling — 25 October 2026

Replaced the pill-style navigation with the existing Explore Trails tab strip classes:
sand background, separators, flat labels and the blue active underline. The strip uses
horizontal scrolling on narrow screens. Tab switching and unsaved-change confirmation
are preserved. TypeScript and the production build passed; live checks confirmed tab
selection, a 3 px active underline, square corners and no page overflow.

Published privately with owner-only access preserved. Website source:
`ff35585e695b709e05d3103c225729b4da291013`; deployment:
`appgdep_6addbffc8bb481919c319a5042f3650e` (succeeded).

## Header and organisation access UX — 25 October 2026

Removed the ERA WORKSPACE eyebrow from the workspace and ERA sign-in screen. The trail
selector now sits to the left of the horizontally scrolling tabs, and the repeated role
summary is removed. Incident creation uses a labelled, circular plus control; expanding
the form changes it to a close control.

Access now has an organisation overview and a separate member list scoped to the selected
organisation and trail. Organisation IDs are generated internally rather than entered by
the user. Organisation and member forms open only when adding/editing, member responsibilities
have concise explanations, and removal has a clear confirmation that focuses Cancel.
Unsaved form changes are guarded when changing trail, tab or organisation. Existing server
permission checks are unchanged.

TypeScript and the production build passed. Isolated browser QA verified selector placement,
no page overflow, plus/close behaviour, organisation creation, member addition/edit/removal,
and removal-confirmation focus. The live page confirms the workspace label and role summary
are absent. Test accounts and organisation records were confined to demo-eurotrex emulators.

Published privately with owner-only access preserved. Website source:
`95865545b3e5e7e0a5097eff08875ff4642bbf88`; deployment:
`appgdep_6addf38aef148191be9a6961500e8d95` (succeeded).

## Integrated navigation and visible incident map — 25 October 2026

The trail selector now uses a flat tab appearance within the shared navigation strip,
with matching height, typography and separators. The Trail Management heading uses
the existing yellow section rule and Title Case. The incident map opens automatically
and stays visible; a circular incident-creation control occupies the former map-toggle
position in the filter panel. Incident creation remains scoped to the ERA workspace.

TypeScript, whitespace checks and the production build passed. Isolated emulator browser
QA verified the dropdown, matching selector/tab heights, no page overflow, plus/close
behaviour, and successful incident creation while the main map remained visible. Route
geometry and the incident were synthetic demo-eurotrex fixtures only. The live page
confirmed the corrected heading; its signed-in account has no assigned trails.

Published privately with owner-only access preserved. Website source:
`5f1ba53c085782011c1d37c06af51813d8e2d11a`; deployment:
`appgdep_6addf9e66dac81919263d4927122b4ae` (succeeded).

## Status-linked map and concise tab content — 25 October 2026

Removed repeated Trail Data, Verification, Published Versions and Audit Log headings,
and the redundant Organisation & access title. Named sections and useful subheadings
remain. Both incident and route maps place Fit trail inside the map and their legends
below it. Route fitting also supports the published line when no draft is present.

Incident markers now use the existing status-badge palette and include status in their
accessible labels and tooltips. Selection keeps the status colour. The bottom legend
filters the map and report list through the same state as the Status selector; selecting
the current legend entry or All statuses clears the status filter.

TypeScript, whitespace checks and the production build passed. Browser QA on isolated
demo-eurotrex fixtures verified all six status colours, legend-to-selector and
selector-to-legend synchronisation, filtered marker/list counts, marker selection,
bottom legend placement, in-map Fit trail controls, no horizontal page overflow, and
removal of repeated titles across all ERA tabs. No live incident data was modified.

Published privately with owner-only access preserved. Website source:
`40858582b9f8ca7138d7d187c39ed940dc196717`; deployment:
`appgdep_6addfe887ed08191b1dfff770aad6a87` (succeeded).

## Mobile fit control and visual status selector — 25 October 2026

Fit trail is now an icon control below the zoom buttons on the right, aligned to their
width. It reuses the exact Material fit_screen_rounded glyph used by the Flutter app.
The incident legend retains only the trail name and line swatch; status buttons and the
selection helper caption are removed. Status-selector choices use the same warning
symbol and palette as map markers, and the selected control border reflects the status.
Filtering still updates the map and incident list together.

TypeScript, whitespace and production-build checks passed. Browser QA confirmed right
alignment below zoom, colour equality between the selected status icon and its marker,
a single matching filtered marker/report, legend removal, no overflow and working Fit.

Downloaded the unmodified Cyprus E4 GeoJSON through Waymarked Trails' route download:
https://hiking.waymarkedtrails.org/#route?id=2376091&type=relation
The source identifies Cyprus as E4 rather than the requested E5. The export contains
five MultiLineString features and 23,234 two-dimensional points (551,807 bytes), with
OpenStreetMap attribution/licence in its metadata. File: output/era/cyprus-e4-waymarked.geojson.

The actual browser upload and Save & validate revision were tested only in the loopback
demo-eurotrex trail. The saved draft has 23,232 normalised points and 601.8 km; validation
correctly flags missing elevation, gaps before segments 4/5, a leg over 5 km, and the
synthetic fixture's unconfirmed stage connections. No live route was imported or released.

Published privately with owner-only access preserved. Website source:
`9567409ee283f041e6ea3cd786319983d9e3a01e`; deployment:
`appgdep_6ade02058af481918922f58c365f022d` (succeeded).

## Map-control edge alignment — 25 October 2026

Matched Fit trail to the installed Mapbox zoom controls at 32 × 32 px, preserving
their right inset and a 10 px gap below the zoom group. Browser measurements confirmed
zero difference at both left and right edges; the production build passed.
Website source: `f9721d9fc35ace1d7448db2579cfc6cddbbb5043`; private deployment
`appgdep_6ade0388ee808191aa103501b5e76021` succeeded with owner-only access preserved.

## Neutral All statuses option — 25 October 2026

Gave the All statuses icon an explicit neutral palette so it cannot inherit the selected
status's colour from the selector wrapper. Browser QA with Received selected confirmed
a grey All statuses option and yellow Received trigger/option/map marker. TypeScript,
whitespace and production-build checks passed. Website source:
`9489f4f7cd9bb864acf43a708b34d79a65bfb3d6`; private deployment
`appgdep_6ade08f6bf28819190e891478a14e32a` succeeded with owner-only access preserved.
