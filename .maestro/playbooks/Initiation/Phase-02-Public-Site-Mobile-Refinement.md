# Phase 02: Public Site Mobile Refinement

This phase carries the visual language proven in Phase 01 across the complete public website, making the Cyprus E4 guide and supporting pages easy to scan, navigate, and use on phones as well as desktops. It preserves the project’s existing facts and route data while turning the public site into a coherent, test-covered experience rather than a polished homepage surrounded by inconsistent secondary pages.

## Tasks

- [ ] Reassess the public route inventory after Phase 01 and map existing patterns to every page before editing:
  - Inspect `/`, `/trails/cyprus-e4`, `/trails/cyprus-e4/stages`, representative stage-detail routes, `/get-involved`, `/partnerships`, `/privacy`, and `/partner-terms`
  - Search for reusable header, footer, card, form, metadata, HTMX navigation, loading, empty, and error patterns already present in `www/`
  - Identify duplicated markup or styles that would cause the same public element to behave differently across breakpoints, then consolidate only where it reduces inconsistency
  - Preserve generated trail data and its generation script; never hand-edit route facts merely to improve presentation

- [ ] Refine the shared public shell and navigation across all routes:
  - Make header state, mobile menu, language-preview control, skip link, footer, and current-page cues consistent on every public page
  - Prevent open menus from obscuring content or remaining open after navigation, Escape, or an outside interaction
  - Keep host registration and host sign-in destinations unambiguous, with `/portal` navigation excluded from HTMX where the existing architecture requires it
  - Ensure landmark structure, heading hierarchy, focus restoration, tap targets, safe-area spacing, and long-label wrapping work from 320 px upward

- [ ] Refine the Cyprus E4 overview and stage-directory experience for mobile trail research. <!-- MAESTRO:MODEL tier="high" effort="high" reason="Dense route facts, stage navigation, and responsive hierarchy must remain accurate while becoming scannable on small screens, which calls for strong design and information-architecture reasoning." -->
  - Improve the presentation and responsive ordering of route identity, distance and elevation facts, stage previews, service summaries, and calls into the app
  - Make the full stage directory easy to scan and traverse with clear sequence, names, distances, pagination or grouping behavior already supported by the data, and useful empty states
  - Preserve every route value sourced from `lib/cyprus-e4-data.ts` and avoid implying live conditions, safety guarantees, or unavailable app-store downloads
  - Eliminate overflow from long place names, metrics, cards, and navigation at phone widths

- [ ] Refine representative stage-detail pages and their route-to-route navigation:
  - Improve information hierarchy for location, distance, elevation, services, accommodation context, adjacent stages, and route breadcrumbs using the existing data model
  - Make dense fact groups readable without tiny text, sideways page scrolling, or hover-only disclosure
  - Provide helpful, accessible states for missing optional values rather than rendering misleading placeholders
  - Keep previous/next and directory links usable with keyboard, touch, and HTMX-enhanced navigation

- [ ] Bring supporting public pages and interactive forms into the same polished responsive system:
  - Refine `/get-involved` and `/partnerships` layouts, cards, form controls, success/error states, and calls to action without inventing promises, pricing, contacts, or partnership terms
  - Apply the shared typography and narrow-screen layout to privacy and partner-terms pages while preserving their existing copy and placeholder/legal status
  - Refine the notify dialog for mobile keyboard use, focus trapping/restoration, dismissal, validation, and clear submission feedback
  - Confirm long content remains readable at browser zoom and no footer or dialog action is hidden behind a small-screen viewport

- [ ] Optimize public-page media and loading behavior without changing the established art direction:
  - Audit existing Next Image usage, responsive `sizes`, priority loading, intrinsic dimensions, and alt text across public routes
  - Reserve layout space to avoid avoidable shifts, prioritize only above-the-fold media, and keep decorative imagery out of the accessibility tree
  - Remove unused public CSS and duplicated rules only after confirming all affected selectors and responsive states
  - Preserve reduced-motion behavior and avoid animations that delay access to content

- [ ] Extend Playwright tests into a public-route responsive and accessibility matrix:
  - Cover every public route listed in this phase at desktop and phone viewports, including at least the first, a middle, and the last available stage-detail route
  - Assert successful rendering, one clear page heading, working internal navigation, usable menu/dialog interactions, no page-level horizontal overflow, no broken first-party images, and no unexpected console errors
  - Add automated accessibility scanning for representative pages and fail on serious or critical violations, documenting narrowly justified exclusions in test code
  - Add focused screenshots for the trail overview, stage directory, a stage detail, get-involved form, and notify dialog at their most relevant viewports

- [ ] Run and repair the complete public-site verification loop:
  - Run `pnpm lint`, `pnpm build`, and the entire browser suite from `www/`
  - Exercise the generated production build locally rather than relying only on hot-reload behavior
  - Fix all phase-introduced failures, broken links, asset errors, console exceptions, serious accessibility findings, clipped layouts, and viewport overflow
  - Report the tested routes, viewport set, command results, and screenshot/artifact locations in the final task output
