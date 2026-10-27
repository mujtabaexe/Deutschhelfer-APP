# 11 — Known issues and remaining risks

| # | Issue | Severity | Status and next step |
|---|---|---|---|
| K1 | Nothing has run against a real Firebase project: Auth email delivery, App Check, FCM, Play Billing, Cloud Scheduler | High for release | Owner actions 10 to 18 |
| K2 | In-app account deletion, roles, the audit log and push need Blaze | High for release | Q26 |
| K3 | **Upload key exists; bundle not uploaded.** The owner's upload key was recreated and `android/key.properties` exists (git-ignored; its contents were never read or printed). `build/app/outputs/bundle/release/app-release.aab` (55.5 MB, written 2026-10-27 05:07) is signed by `CN=Sahibzada Ahmad Mujtaba`, SHA-1 `7B:CF:F2:BA:…:3C:47`, verified with `keytool -printcert -jarfile` on 2026-10-27. **It is not uploaded, and must not be yet:** (1) it predates the age-confirmation change made later the same day, so it must be rebuilt; (2) no production Firebase project, hosting URLs or `config/prod.json` exist, and a production build refuses to start without them; (3) uploading needs the owner's Play Console account. | High for release | [10-owner-actions.md](10-owner-actions.md), section (c) |
| K4 | Guide content is DRAFT. APS and the blocked-account amount are high-impact. | Medium | [12-content-review.md](12-content-review.md) |
| K5 | Privacy notice, community rules and hosted pages are drafts by the development assistant, not a lawyer. Developer name, support email, 7-day reply time, minimum age 18 and Mumbai are now filled in; the age and the region are **assumptions** awaiting the owner. The placeholder check passes. | Medium | Q25, Q28 |
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
| K16 | **Minimum age 18 is an assumption.** Sign-up has a required "I am 18 years old or older" box; the in-app privacy notice and `privacy.html` say the same. It is a self-declaration, not age verification. The community rules text does not mention age: changing it would bump the rules version and need a coordinated rules deploy (K13). | Medium | Owner confirms Q25 |
| K17 | **Firestore region `asia-south1` is provisional and irreversible once created.** The privacy policy names it. | Medium | Owner confirms before step A4 |

## Spark (free plan) audit: what depends on Cloud Functions

Checked by reading `firebase/functions/index.js` and the app's `AccountRepository`, and by widget tests with a failing fake. **Not verified against a real Spark project.** In a Spark-only project nothing in `functions/` is deployed (deploying needs Blaze), so every callable is unreachable and every trigger is silent.

| Function | Kind | Purpose | In a Spark-only project | App behaviour |
|---|---|---|---|---|
| `deleteMyAccount` | callable | In-app account deletion | **Does not work**; the account stays. The web path works: the owner runs `firebase/functions/scripts/delete-account.mjs` on their computer (Admin SDK). | Snackbar "Could not delete your account. Check your connection and try again."; user stays signed in. Tested before this run. |
| `purgeDeletedAccounts` | schedule | Erases accounts 90 days after deletion | **Never runs.** Workaround: the script's `--purge-now`. The 90-day promise on the policy pages is not kept automatically. | None. |
| `setUserRole` | callable | Owner appoints or removes a student-admin | **Does not work.** The owner role itself is set by `set-owner.mjs` and works. | "Make moderator" shows "The action failed…"; role unchanged. Test added in this run. |
| `liftSuspension` | callable | Staff lift a suspension | **Does not work.** Workaround: delete the `accountRestrictions/<uid>` document in the console (writes no audit entry). | "The action failed…"; suspension stays listed. Test added in this run. |
| `verifyPurchase`, `onPlayNotification`, `reconcileSubscriptions` | callable, Pub/Sub, schedule | Play subscriptions | No effect: launching free, no client flow (K15). | None. |
| `onMemberCreated`, `onMemberDeleted` | triggers | Maintain `groups.memberCount` | **Silent.** The count stays 0, so lists show 0 members and the 2,000-member cap never trips. | Cosmetic, and the cap. |
| `onProfileUpdated` | trigger | Copies a renamed display name into memberships | **Silent.** Member lists keep the old name. | Cosmetic. |
| `onGroupMessageModerated`, `onRestrictionWritten`, `onReportResolved` | triggers | Write the audit log; notify the moderated sender | **Silent.** Moderator actions are not recorded in `auditLogs`, so "every moderation action is logged" in the community rules is untrue on Spark. | Rules text inaccurate on Spark. |
| `onDeviceRegistered`, `onDirectMessageCreated` | triggers | Device-token hygiene; push for new DMs | **Silent.** No push. | The Profile switch still stores a token; nothing is sent. |

Conclusions:
- Spark is enough for internal testing of sign-up, verification, guide, groups, chat, reporting, blocking, suspending and the web deletion path.
- **Deploy the functions (Blaze) before production on Play.** In-app deletion must work, and the audit log, the 90-day purge and suspension lifting are promised in user-facing text.
- Failure handling: all callable call sites catch every error, show a message and leave state unchanged. A missing function most likely reaches the app as `not-found`, which maps to the generic failure. That mapping has no unit test, because the Firebase client cannot be faked without a project.
- Known wording flaw, not changed (no redesign): if a missing function ever surfaced as `permission-denied`, the lift screen would say "Only the owner can lift a suspension of a staff member", which would mislead.
