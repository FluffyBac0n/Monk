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
