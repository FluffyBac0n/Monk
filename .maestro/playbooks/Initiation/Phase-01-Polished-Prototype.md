# Phase 01: Polished Public-to-Host Prototype

This phase establishes a reliable browser-testing foundation and delivers a visibly refined, runnable slice from the public homepage to host registration. It is fully autonomous: it reuses the existing EuroTrex brand, content, Firebase configuration, and Sites/Vinext architecture; makes no production data changes; and finishes with verified desktop and mobile screenshots of the working prototype.

## Tasks

- [ ] Establish the website quality baseline from `www/` without changing product scope:
  - Read the repository instructions, `www/README.md`, `.openai/hosting.json`, package scripts, public layout/components, portal authentication components, and existing responsive CSS before editing
  - Search for and reuse existing EuroTrex design tokens, component patterns, navigation helpers, images, and accessibility conventions rather than creating a parallel design system
  - Run the current `pnpm lint` and `pnpm build` from `www/`, recording any pre-existing failures in the command output and fixing only blockers needed for this phase
  - Keep listing creation/editing, photo management, submission status behavior, administration, legal-copy approval, and production Firebase data outside this phase

- [ ] Add a maintainable browser-test and preview foundation to `www/`:
  - Add Playwright as a development dependency, a configuration that starts the existing Vinext app on a deterministic local port, and package scripts for browser tests and screenshot generation
  - Configure Chromium projects for a current desktop viewport and a small-phone viewport near 390 px wide, with traces and screenshots retained on failure
  - Keep generated reports, browser artifacts, and local preview state ignored by Git without weakening existing ignore rules
  - Ensure tests never create Firebase users or write to Firestore; unauthenticated portal coverage must stop before network-backed submission

- [ ] Consolidate the public and portal visual foundations in the existing styles and shared components:
  - Refine the existing color, typography, spacing, radius, shadow, focus, and motion tokens so public and portal screens feel like one EuroTrex product
  - Preserve the current wordmark, imagery, editorial trail character, semantic HTML, reduced-motion behavior, and minimum 44 px interactive targets
  - Remove one-off styling conflicts and horizontal-overflow risks at 320 px through wide desktop sizes
  - Avoid a wholesale redesign or new UI framework; make focused changes that improve hierarchy, readability, consistency, and touch usability

- [ ] Refine the homepage’s first-screen experience and public-to-host journey. <!-- MAESTRO:MODEL tier="high" effort="high" reason="This task requires coherent visual judgment across brand hierarchy, conversion flow, responsive composition, and accessibility; the strongest tier with deeper reasoning reduces the risk of a polished but inconsistent redesign." -->
  - Improve the header, hero, primary calls to action, section rhythm, and mobile navigation using existing content and assets
  - Make the hiker and host paths immediately distinguishable without adding unsupported claims or changing the product’s launch status
  - Strengthen the host section’s route into `/portal?mode=register`, while keeping sign-in available for returning hosts
  - Ensure images use appropriate responsive sizing, text remains readable over media, menus close predictably, and focus order follows the visual order

- [ ] Turn the unauthenticated portal into a clear, reassuring onboarding entry point:
  - Refine `AuthPanel`, `PortalHeader`, and the surrounding `/portal` layout for strong mobile and desktop presentation
  - Clearly explain who the portal is for, that listings are reviewed, what a host needs to begin, and what happens immediately after account creation
  - Preserve the existing email/password Firebase flow and owner-profile write; improve field hints, password requirements, loading states, error recovery, and accessible status announcements
  - Replace the blocking `window.prompt` password-reset interaction with an inline, keyboard-accessible reset flow that uses the entered email when available
  - Do not add social sign-in, email verification requirements, listing-workflow changes, or dependencies on new credentials

- [ ] Write Playwright coverage for the Phase 01 prototype as a separate implementation step:
  - Cover homepage rendering, primary navigation, mobile-menu operation, the host call to action, registration-mode deep linking, sign-in/register switching, native form validation, inline password-reset UI, focus visibility, and absence of horizontal overflow
  - Assert key accessible names and landmarks instead of brittle CSS-only selectors
  - Capture deterministic full-page reference screenshots for the homepage and registration screen at both configured viewports, disabling animation and masking only genuinely nondeterministic content
  - Keep assertions independent of live Firebase writes and current production records

- [ ] Run and repair the complete Phase 01 verification loop:
  - Run `pnpm lint`, `pnpm build`, and the new Chromium browser suite from `www/`
  - Start the built or development app locally, verify `/` and `/portal?mode=register` return successfully, and regenerate the four reference screenshots
  - Fix all regressions introduced by this phase, including console errors, failed requests for first-party assets, clipped content, inaccessible controls, and viewport overflow
  - Leave the local prototype runnable through the documented package script and print the exact local URL plus screenshot paths in the final task output
