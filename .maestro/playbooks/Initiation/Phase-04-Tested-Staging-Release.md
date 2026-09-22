# Phase 04: Tested Staging Release

This phase converts the refined public site and host onboarding into a reproducible staging release. It closes quality, accessibility, performance, and deployment gaps; publishes through the repository’s configured OpenAI Sites project without changing its audience; and verifies the deployed build with read-only production-safe checks plus the isolated emulator-backed registration suite.

## Tasks

- [ ] Perform a staging-candidate preflight while preserving all in-progress repository work:
  - Read the workspace instructions, current Git status, `www/.openai/hosting.json`, Sites/Vinext configuration, environment example, README, and private portal testing guide before changing files
  - Use the applicable Sites building and hosting skills required by the existing `.openai/hosting.json`; inspect their current instructions before build or deployment actions
  - Search for and reuse all verification scripts and release patterns added in earlier phases
  - Confirm no phase changed generated trail facts, listing/review semantics, admin authorization, legal claims, Site audience, or production Firebase rules; repair accidental scope drift
  - Never expose environment values, credentials, access tokens, or private owner data in logs, artifacts, screenshots, or committed files

- [ ] Make staging configuration explicit and safe:
  - Validate required public environment variables with a small reusable startup/build check that reports missing variable names without printing their values
  - Preserve the existing prepared Firebase Web configuration and treat blank app-store URLs as an intentional pre-launch state with honest UI, not broken links
  - Separate browser-test emulator settings from staging settings so deployed code cannot connect to localhost or a demo project
  - Add or refine package scripts for a clean staging build, local production preview, full verification, and deployment using the repository’s existing package manager and Sites configuration
  - Keep the current Site private/owner-only and do not deploy Firestore rules or alter Firebase Authentication settings

- [ ] Add automated release-quality checks for accessibility, performance, and metadata:
  - Run axe-based checks across representative public and portal states and fail on serious or critical findings
  - Add Lighthouse CI or an equivalent reproducible audit against the local production build for the homepage, trail overview, stage directory, representative stage detail, and unauthenticated portal
  - Set realistic mobile budgets for performance, accessibility, best practices, and SEO, documenting any narrowly justified threshold below 90 in configuration comments
  - Assert canonical metadata, robots and sitemap responses, social-image availability, semantic page headings, and absence of accidental staging or localhost URLs in rendered output

- [ ] Harden the deployed surface for a staging release without breaking Firebase or Sites:
  - Add appropriate security and privacy response headers supported by the current Vinext/Sites stack, including MIME sniffing, referrer policy, frame protection, and permissions policy
  - Introduce a Content Security Policy only if it can be verified against all required first-party, Firebase Auth, Firestore, image, and Sites runtime connections; otherwise document the specific blocker in the release report rather than shipping a broken policy
  - Confirm source maps, error output, and client bundles do not expose secrets or emulator configuration
  - Verify public forms, host auth errors, and not-found states do not leak stack traces or internal identifiers

- [ ] Execute the complete local release gate and fix every regression:
  - Install dependencies from the lockfile, then run formatting checks if configured, unit tests, Firestore rules tests, the full emulator-backed Playwright suite, `pnpm lint`, and the staging production build from `www/`
  - Run the production build locally and execute the public-route matrix, onboarding success path, accessibility scan, Lighthouse audits, metadata checks, broken-link checks, image checks, and viewport-overflow checks
  - Repeat failed checks after fixes until all required gates pass; do not waive a failure merely to reach deployment
  - Save machine-readable reports and selected desktop/mobile screenshots under the project’s existing ignored test-artifact location

- [ ] Publish the verified build to the configured staging Site. <!-- MAESTRO:MODEL tier="high" effort="high" reason="Deployment targets an existing hosted project and must preserve audience controls, environment separation, and rollback safety, so a strong model with careful reasoning is warranted." -->
  - Use the Sites hosting workflow associated with `www/.openai/hosting.json` and deploy only the verified `www/` candidate
  - Confirm the target project ID and current audience/access mode before publishing, aborting rather than creating a new project or making the Site public
  - Record the resulting deployment identifier, immutable or preview URL when available, canonical staging URL, and previous deployment reference needed for rollback
  - Do not deploy Firestore rules, modify Firebase data, create production accounts, publish app-store links, or change DNS as part of this task

- [ ] Run production-safe smoke tests against the deployed staging URL:
  - Re-run the public route, link, asset, metadata, responsive-overflow, accessibility, and console-error checks against the deployed URL at desktop and phone viewports
  - Verify `/portal?mode=register`, sign-in/register switching, client-side validation, reset-mode presentation, and navigation without submitting credentials or creating a live Firebase user
  - Confirm the deployed build contains no localhost, demo-project, source-map, secret, or test-fixture leakage and that the configured Site access mode is unchanged
  - If a deployed-only defect appears, fix it, repeat the complete local release gate, redeploy, and rerun the smoke suite

- [ ] Create a structured staging release report as part of the completed release:
  - Create `www/docs/releases/staging-release.md` with YAML front matter using `type: report`, the execution date, tags for `website`, `host-portal`, `staging`, and `quality`, and `related` wiki-links to `[[Private-Host-Portal-Testing]]` and relevant existing release material
  - Record the deployment identifier and URLs, commit or working-tree reference, exact commands and results, tested routes/viewports, Lighthouse scores, accessibility results, known non-blocking limitations, artifact paths, and rollback reference
  - State explicitly that listing management, photo management, submission-status refinement, admin workflow changes, legal approval, production Firestore-rule deployment, and making the Site public were outside this playbook
  - Ensure the report contains no credentials, environment values, private user information, or test passwords

- [ ] Finish with a clean reproducibility check:
  - From a fresh dependency install based on the lockfile, rerun the documented full verification command and confirm it targets emulators for write tests and the deployed URL only for read-only smoke tests
  - Confirm generated test artifacts and local emulator state are ignored while source tests, configuration, and the structured staging report are retained
  - Review the final diff for unrelated edits, debug logging, temporary bypasses, skipped tests, focused tests, placeholder URLs presented as live, and accidental production-data changes; remove any found
  - Print a concise release handoff containing the staging URL, audience status, passing gate summary, report path, remaining out-of-scope items, and rollback reference
