# Phase 03: Host Registration and Onboarding

This phase makes host registration dependable, understandable, and pleasant on mobile and desktop, then gives a newly registered owner a clear first-run landing in the existing portal. It adds an isolated Firebase-emulator path for genuine automated account testing while explicitly leaving listing management, photos, submission-state design, and administrator workflows unchanged for the user’s later work.

## Tasks

- [ ] Add an isolated local Firebase test environment for host onboarding. <!-- MAESTRO:MODEL tier="high" effort="high" reason="Authentication and Firestore isolation are security-sensitive: a configuration mistake could write test data to production, so this needs the strongest model and careful reasoning." -->
  - Search the current Firebase initialization, Firestore rules, scripts, environment conventions, and package setup before adding anything
  - Configure local Auth and Firestore emulators on deterministic ports and add development-only connection logic controlled by an explicit test environment variable
  - Add package scripts that start the emulators and Vinext app together for browser tests, using a dedicated demo project ID that cannot resolve to the production `eurotrex` project
  - Fail fast in test mode if the emulator hosts are missing, and never print secrets, use real owner credentials, or allow automated tests to fall back to live Firebase
  - Reuse the existing `firebase.json` and app initialization rather than introducing a second Firebase abstraction

- [ ] Harden account creation and owner-profile completion without expanding authentication scope:
  - Preserve email/password Firebase Authentication and `ownerProfiles/{uid}` as the source of onboarding identity
  - Add clear password requirements, confirmation matching, normalized email handling, duplicate-submit protection, and field-level error association while retaining an accessible summary message
  - Make account creation and profile creation behave as one understandable flow: on a recoverable profile-write failure, keep the authenticated account, explain the state accurately, and offer an idempotent retry instead of implying the whole registration failed
  - Map known Auth and Firestore failures to actionable, non-sensitive messages; retain a safe fallback for unknown errors
  - Do not add social providers, paid services, email-verification gates, administrator promotion, or production rule deployment

- [ ] Complete the sign-in and account-recovery experience started in Phase 01:
  - Use a real inline reset form with an explicit email field, Cancel and Send actions, predictable focus movement, disabled/busy states, and live-region feedback
  - Preserve a host’s entered email when switching among registration, sign-in, and reset modes, but never persist a password
  - Handle invalid email, disabled user, throttling, offline/network, and generic failure states consistently
  - Ensure query-driven `mode=signin` and `mode=register` links select the correct view without hydration flashes or history traps

- [ ] Refine the first-run portal orientation and responsive shell for a newly registered owner:
  - Add a concise welcome state that confirms the account is ready, explains that accommodation details can be added next, and distinguishes saved drafts from submitted or published listings
  - Reuse the existing dashboard, empty-state, metric, button, and portal-header patterns; do not change listing data structures or the wizard’s save/submit behavior
  - Make the authenticated header resilient to long email addresses and small screens, with clear Website and Sign out actions and no overlapping controls
  - Preserve admin-link authorization and all existing owner/listing watchers

- [ ] Improve onboarding accessibility and mobile ergonomics across unauthenticated and first-run authenticated states:
  - Ensure every input has a persistent visible label, useful autocomplete metadata, appropriate input mode, programmatic description, and error linkage
  - Keep focus in a logical order through tabs, reset mode, errors, retry actions, and successful transition to the portal
  - Support 200% browser zoom, 320 px width, mobile virtual-keyboard conditions, reduced motion, and minimum 44 px controls without page-level horizontal scrolling
  - Verify status is never communicated by color alone and all loading or disabled states remain understandable to assistive technology

- [ ] Write unit and rules-focused tests for registration logic as a separate implementation step:
  - Cover validation and error mapping as pure logic where possible, including password length, mismatch, email normalization, and safe unknown-error handling
  - Use the Firestore rules test environment to prove a signed-in owner can create and update only their own `ownerProfiles/{uid}` document and cannot read or write another owner’s profile
  - Prove unauthenticated profile access and owner self-promotion attempts are rejected
  - Keep fixtures deterministic and destroy emulator state after every suite

- [ ] Extend Playwright coverage through a real emulator-backed onboarding journey:
  - Register a unique test host, verify its owner profile was created in the emulator, land on the authenticated empty portal, sign out, sign back in, request a password reset, and verify the emulator received the request
  - Cover duplicate email, weak or mismatched password, invalid credentials, profile-write retry, loading-state duplicate prevention, and direct `mode` links
  - Run the core success path at desktop and phone viewports, assert no console errors or horizontal overflow, and include keyboard-only traversal of the registration form
  - Delete or clear every emulator user and document after the suite; never invoke production Firebase

- [ ] Run and repair the complete host-onboarding verification loop:
  - Run unit tests, Firestore rules tests, Playwright tests, `pnpm lint`, and `pnpm build` from `www/`
  - Confirm test logs identify the demo project and emulator endpoints, and fail the run if the production project ID appears in a write target
  - Fix all phase-introduced failures, race conditions, accessibility violations, responsive clipping, and authentication-state flicker
  - Report the commands, tested onboarding states, emulator isolation evidence, and screenshot/trace locations in the final task output
