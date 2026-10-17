# Website feedback v3 — private review publication

Published 17 October 2026 following the user's explicit request to publish privately.

- Review URL: https://eurotrex.andreasmic332452.chatgpt.site
- Site version: 69.
- Deployment: `appgdep_6ad350ed485081918561e21768a5b7aa`; status `succeeded`.
- Published website source commit: `447464a7e5217ea5f19e5b01c436ad36f9f7aa9b` in the separate Sites source repository.
- Application review branch: `codex/website-feedback-v3`; implementation commit `9b2ca46`. No merge into the application's `main` branch was performed.

The existing custom access policy was preserved: the owner and the previously invited reviewer can access the site. It was not made public. This publication updates the existing restricted EuroTrex site.

The archive includes the new story-publication D1 migration. Sites reported a successful deployment. The published homepage was opened and the revised content confirmed in the browser; no production enquiry, story or host account was created for verification.

The production Firestore rules update was initially rejected by automatic approval review as outside private-publication authorization. The user then explicitly approved that update. Before deployment, the live rules were confirmed to match the previous website source and a local rollback copy was saved outside Git. Firebase compiled and successfully released the new rules to project `eurotrex`. The change adds individual-host signup fields while retaining email verification, pending access, administrator approval and listing-review restrictions.

The [implementation handoff](website-feedback-v3-implementation.md) records scope, tests and known data gaps as of the earlier local-only handoff. This record supersedes its statements that publication and the matching rules deployment were still pending. Subsequent application merge remains a separate user decision.
