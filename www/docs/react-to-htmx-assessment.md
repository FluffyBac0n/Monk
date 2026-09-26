# React-to-HTMX Architecture Assessment

**Status:** Phase 1 implemented and verified

**Recorded:** 25 September 2026

**Updated:** 26 September 2026

**Scope:** EuroTrex public website, Host Portal, and Admin Panel

## Executive recommendation

Do not replace React completely at this stage.

The recommended architecture is:

- Use an HTMX-first approach for the public website.
- Retain React for the Host Portal and Admin Panel.
- Keep strict DOM ownership boundaries so React and HTMX never manage the same subtree.

The public website is already largely rendered as complete server-side HTML, so removing server-side React would provide less benefit than expected. Converting the remaining public client components to HTMX or small vanilla-JavaScript modules would deliver most of the practical gains without putting the host and administration workflows at risk.

HTMX handles requests and HTML replacement; it is not itself a server renderer, router, template engine, authentication system, or data layer. A fully React-free implementation would therefore require replacing the current Vinext/Next rendering architecture as well as the React components.

## Migration suitability

| Area | HTMX suitability | Relative difficulty |
| --- | --- | --- |
| Homepage and editorial pages | Excellent | Low |
| Trail guides and stage pages | Excellent | Low |
| Get Involved form | Already mostly HTMX | Very low |
| Notify Me dialog | Good with HTMX and small vanilla JS | Low |
| Slideshow, counters, filters, and mobile menu | Vanilla JS is sufficient | Low |
| Host authentication | Possible, but requires server sessions | High |
| Accommodation wizard and autosave | Possible, but needs many fragment endpoints | High |
| Host dashboard | Possible | Medium–high |
| Admin review panel | Possible, but real-time behaviour becomes harder | High |

## Advantages

- Less client-side JavaScript on public pages.
- No React hydration or DOM-ownership conflicts with HTMX.
- Faster initial loading, particularly on mobile connections.
- Ordinary links and forms can continue working without HTMX.
- Complete server-rendered pages remain strong for SEO, GEO, and accessibility.
- One consistent interaction model for the marketing and trail-guide pages.
- Easier failure recovery because navigation can fall back to standard browser behaviour.
- Potentially simpler maintenance for predominantly editorial content.
- Server-side validation and permission checks can become more centralized.

## Disadvantages

- A complete migration would be a rewrite rather than a dependency change.
- Replacing Vinext/Next would mean rebuilding routing, metadata, social previews, image handling, sitemap generation, and other framework features.
- Complex interactions require more server endpoints and reusable HTML fragments.
- Immediate local state changes may become additional network requests.
- The four-step accommodation wizard would require dedicated endpoints for navigation, validation, autosave, trail selection, and stage selection.
- Shared UI composition and TypeScript guarantees may become less convenient.
- Sophisticated animations, keyboard behaviour, and focus management need careful vanilla JavaScript.
- A partial migration can increase complexity if React and HTMX boundaries are not explicit.

## EuroTrex-specific risks

### 1. Host authentication

The portal currently uses Firebase client authentication. An HTMX-driven portal would need authenticated server endpoints, secure session cookies, CSRF protection, authorization checks, and server-controlled logout.

Firebase's server-session model requires an ID token to be exchanged for a verified session cookie. The exchange endpoint must be protected against CSRF, and every protected request must verify the session and its claims.

### 2. Real-time host and admin data

The current portal and admin panel use Firestore snapshot listeners. These provide an initial result and subsequent updates whenever the underlying data changes.

A server-driven replacement would need one of the following:

- Refresh after each user action.
- Periodic polling.
- Server-Sent Events.
- WebSockets.

Each alternative adds either latency or infrastructure complexity.

### 3. Authorization regressions

Every owner and administrator action would need server-side ownership and role validation. High-risk operations include:

- Reading and saving drafts.
- Editing or deleting listings.
- Approving or rejecting submissions.
- Publishing or removing accommodation data.
- Reading administration audit records.

This is the highest-risk part of a full migration.

### 4. History and direct-link behaviour

Every URL used by HTMX must still return a complete page when opened directly, refreshed, shared, or restored from browser history. Fragment and full-page responses must remain consistent.

Authenticated fragments must never be placed in an HTMX history cache on shared devices.

### 5. SEO and metadata regressions

The public pages currently have route metadata, canonical URLs, Open Graph information, sitemap output, and full-page server rendering. A replacement architecture must preserve all of these features. HTMX itself neither improves nor harms SEO; the outcome depends on the server returning complete, indexable HTML for every public URL.

### 6. Image delivery

The current pages use the framework's image component. Removing the framework would require a deliberate image-sizing, responsive-source, caching, and optimization strategy.

### 7. Hosting and deployment

The website is currently structured around Vinext, Vite, Cloudflare-compatible output, and the Sites hosting configuration. A React-free architecture would need to be proven against the same deployment constraints before replacing the working stack.

## Recommended phased approach

### Phase 1 — Public client simplification

Keep React as the server-rendering layer, but remove unnecessary client-side React from the public site.

Candidate migrations:

- Mobile menu.
- Notify Me dialog.
- Trail slideshow.
- Animated counters.
- Stage filtering.
- HTMX initialization and page-transition coordination.

These can use semantic HTML, HTMX, and small framework-independent JavaScript modules.

### Phase 2 — Establish ownership boundaries

- HTMX owns public-page navigation and public fragments.
- React owns the Host Portal and Admin Panel.
- HTMX must not replace markup that React has hydrated.
- React must not reconcile markup replaced by HTMX.

This removes the current class of React/HTMX DOM reconciliation errors without requiring a portal rewrite.

### Phase 3 — Reassess the portal separately

Only consider an HTMX portal migration after these decisions are settled:

- Final host workflow and accommodation fields.
- Authentication and server-session design.
- Whether real-time updates are actually required.
- Server-side Firebase access strategy.
- Authorization and audit requirements.
- Offline or unreliable-connection expectations.

If the portal is migrated, do it as a separate project with explicit security and regression testing rather than as part of the public-site cleanup.

## Expected outcome

An HTMX-first public site with isolated React applications for the portal and administration should provide most of the desired benefits:

- Smaller and simpler public client code.
- Cleaner navigation behaviour.
- Fewer hydration and DOM reconciliation problems.
- Preserved SEO and GEO foundations.
- Lower migration risk for authenticated workflows.

A complete React removal is technically possible, but its cost and risk are not currently justified by the likely user-facing improvement.

## Implementation record — 26 September 2026

The recommended first phase has now been implemented.

### Resulting architecture

- Public pages remain complete server-rendered Vinext/React Server Component documents for direct links, search engines, metadata, and social previews.
- Public navigation and form submissions use HTMX 2.0.10, served locally from `/public/vendor` rather than a third-party CDN.
- The mobile menu, notification dialog, trail slideshow, service counters, stage filtering, focus management, and route-transition coordination use one framework-independent browser runtime in `/public/public-runtime.js`.
- The Host Portal and Admin Panel remain React applications. The public runtime and HTMX are not loaded on `/portal` or `/admin`.
- Public HTMX navigation swaps only `<main>`. The shared header, trail navigation, notification dialog, and footer remain stable around route changes.
- Route changes synchronize the document title, description, robots directive, canonical URL, Open Graph tags, and Twitter metadata from the complete server response.
- HTMX history caching is disabled so authenticated or stale page fragments are not persisted in session storage. Back and forward navigation use the live public page response, with a full-page reload as the safe fallback if restoration fails.
- Development component updates force a clean reload after an HTMX-owned swap, preventing React Fast Refresh from reconciling stale public DOM.

### Ownership boundary caveat

Vinext's current App Router hydrates the root tree, even when the authored public components are server components. A tiny `PublicHydrationBoundary` client component therefore acts only as a readiness signal: HTMX is loaded after the initial framework hydration has completed, and an early history interceptor ensures that HTMX history entries do not also reach the React router.

There is now no authored stateful React UI on the public site, and React does not update the HTMX-swapped `<main>` during normal public navigation. However, this is a pragmatic ownership boundary rather than literal removal of every React hydration instruction from the public bundle. Achieving that stricter definition would require replacing or separating the Vinext/App Router renderer, which remains outside the recommended scope.

### Verification completed

- ESLint, production compilation, browser-runtime syntax validation, and whitespace validation pass.
- The generated sitemap was crawled locally: all 128 public URLs, including all 123 Cyprus E4 stage pages, returned successful complete documents with a `<main>`, title, and canonical URL.
- Privacy, partner policy, future-trail previews, Portal, Admin, robots, public JavaScript, HTMX, and image assets were checked directly. The missing-stage path correctly returns 404, and non-indexable routes retain their robots directive.
- Desktop browser tests covered HTMX route changes, rapid trail switching, direct links, back/forward restoration, metadata synchronization, active trail state, automatic/manual slideshow behavior, exact counter completion, stage filtering, hash navigation, dialog focus/reset behavior, and both public forms.
- Mobile browser tests covered the compact navigation, section links, empty text selection, notification dialog focus restoration, trail-bar horizontal scrolling, future-trail switching, and viewport overflow.
- Portal sign-in/create-account tabs and the Admin authentication gate were checked independently. Neither route loads the public runtime or HTMX.
- The tested browser sessions completed without unhandled console errors.

### Deferred work

- Run a production smoke test after the next private deployment, because this change has intentionally not been published yet.
- If a polished no-JavaScript form journey becomes a requirement, return a full confirmation page for ordinary form posts instead of the existing JSON API response.
- Reassess a portal rewrite only after its authentication, authorization, real-time data, and workflow requirements are stable.

## References

- [HTMX documentation](https://htmx.org/docs/)
- [Firebase: Manage session cookies](https://firebase.google.com/docs/auth/admin/manage-cookies)
- [Firebase: Get data with Cloud Firestore](https://firebase.google.com/docs/firestore/query-data/get-data)
