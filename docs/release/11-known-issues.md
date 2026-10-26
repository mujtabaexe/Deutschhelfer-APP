# 11 — Known issues and remaining risks

| # | Issue | Severity | Status and next step |
|---|---|---|---|
| K1 | Nothing has run against a real Firebase project: Auth email delivery, App Check, FCM, Play Billing, Cloud Scheduler | High for release | Owner actions 10 to 18 |
| K2 | In-app account deletion, roles, the audit log and push need Blaze | High for release | Q26 |
| K3 | No upload key exists. The final code builds a release bundle (2026-10-27, 55.5 MB, target SDK 36, not debuggable, no cleartext), but only with `ALLOW_DEBUG_SIGNED_RELEASE=true`, which signs it with the **debug key: never upload it to Play**. Without the override the build refuses, as intended. | High for release | Owner action 19: create the upload key and `android/key.properties`, then rebuild and check the signer |
| K4 | Guide content is DRAFT. APS and the blocked-account amount are high-impact. | Medium | [12-content-review.md](12-content-review.md) |
| K5 | Privacy notice, community rules and hosted pages are drafts by the development assistant, not a lawyer. Placeholders remain on the pages. | Medium | Q27, Q28 |
| K6 | FCM tokens use the deprecated `firebase_messaging` 17 token API (Q22) | Low | Switch to installation IDs after a real-device push test |
| K7 | Group blocking hides messages locally; it fails open if the block list cannot be read | Low | Accepted |
| K8 | Link detection is pattern-based ("example dot com" passes) and flags harmless dotted words | Low | Accepted (Q21) |
| K9 | No load test; scale estimates are formulas ([free-tier-cost-estimate.md](free-tier-cost-estimate.md)) | Medium for growth | Staging load test before scaling |
| K10 | Local tooling (`firebase-tools` and others) has 10 npm advisories (5 moderate, 5 high). Deployed functions have 0. | Low | Developer machine only; re-check after `npm update` |
| K11 | Concurrent joins can slightly exceed the 2,000-member cap | Low | Accepted |
| K12 | Messages of deleted users stay, under "Deleted user" (Q13) | Policy | Owner decision |
| K13 | Bumping the rules version needs the rules deploy and the app update together. The server accepts only the current version, so older apps cannot record acceptance until updated. | Low | Release process note |
| K14 | TalkBack was not exercised by a human. Automated semantics, tap-target and contrast checks pass. | Medium | Owner action 17 |
| K15 | Subscriptions have no client flow | N/A until Q1 | [07-billing-readiness.md](07-billing-readiness.md) |
