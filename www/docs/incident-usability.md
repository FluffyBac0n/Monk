# Incident navigation and references

Both incident columns scroll naturally with the page. The detail pane is not sticky, and the incident list has no internal scrollbar at any screen size. The address-book connector is retained. Map selection reveals and focuses its incident card; selecting a card retains the map's current zoom and only recenters a marker near/outside the viewport.

Ticket references are additive metadata (`ticketReference`, `ticketNumber`) on existing `trailReports` documents. The authenticated, App Check protected `ensureIncidentReferences` callable checks incident-manager access, validates a maximum of 50 reports, and allocates numbers transactionally from `trailReportReferenceCounters/{route-country}`. CY references use `E4-CY-00001` and grow beyond five digits if needed. Numbers are assigned when reports are loaded by the dashboard; they are stable identifiers, not chronological sorting keys. Original document IDs, review timestamps, photos, history and mobile issue IDs are unchanged. No incident migration or deletion is required. Counter documents retain default-deny client access.

Search and exported reports include ticket references. Duplicate linking accepts either the ticket reference or the original database ID and still validates same-trail access and self-link rejection. Copied incident URLs carry the original ID and selected trail. A separately authorized document subscription can load the linked incident even outside the first 50 reports. Links do not grant access.

Next Steps initially shows only the action selector. Required fields appear for the chosen action; optional notes expand on request. Saves show a short confirmation. Drafts retain their original review version, so restored stale edits cannot overwrite another review.

Drafts and selected photo Files stay in memory inside the authenticated workspace, keyed by trail and incident. They survive incident/tab/trail switches, and clear on successful save or sign-out. Refresh/closing warns about unsaved drafts; drafts are not written to browser storage or shared with other accounts.

Validation: TypeScript, production build, review interaction and fuzzy-search tests; emulator tests for concurrent allocation, idempotence, access denial, preserved report fields/history and duplicate-reference linking; local browser checks for map selection, sticky details, contextual fields, draft restoration across incidents/tabs, location picker and review save. Copy confirmation was verified; opening the clipboard URL was blocked by the browser's URL policy, so that navigation was not browser-verified.

Backend deployment: `ensureIncidentReferences` created and `reviewTrailReport` updated in Firebase project `eurotrex`, codebase `trail-reports`, region `europe-west1`, on 12 November 2026. No rules or mobile release changes.
