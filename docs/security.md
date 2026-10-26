# Security

The release-readiness audit of 2026-10-26, including a third independent review (F-01 to F-12), is in [release/02-security-audit.md](release/02-security-audit.md).

## Assets

- User accounts and sessions.
- Email addresses.
- Private messages, membership and block lists.
- Roles and account status.
- Premium entitlements and purchase tokens.
- The audit trail.
- The owner's Firebase bill.

## Threat actors

- Spammers and phishers with bot accounts.
- Curious or malicious students.
- Users trying to get premium for free or by reusing tokens.
- A compromised or abusive student-admin.
- Cost attackers.

## Trust boundaries

| Component | Trust | Notes |
|---|---|---|
| Flutter app, any client | Untrusted | Route guards and client validation are convenience only |
| Firebase Auth ID token | Identity, `email_verified` and custom claims | Claims are set only by functions or the owner bootstrap script |
| Firestore Security Rules | Enforcement for all client data access | `firebase/firestore.rules` |
| Cloud Functions (Admin SDK) | Trusted; bypasses rules | Every callable re-checks App Check, sign-in, verification, role and input |
| Google Play Developer API | Source of purchase truth | Called only from functions |
| User content: names, messages, links | Untrusted | Plain text only. Links moderated in groups, never clickable in DMs. |

## Key controls

| Threat | Control | Evidence |
|---|---|---|
| Role escalation | Roles only in claims. `setUserRole` is owner-only and never grants owner. | Rules tests: profile writes cannot add fields. Integration: students and staff refused. |
| Premium bypass | Premium bodies only in `premiumContent`, behind a verified premium claim. Entitlement set only after Play verification. | Rules tests: free, unverified and string-claim reads denied. Clients cannot write subscriptions. |
| Purchase token sharing | Token bound to the account hash. Each token hash maps to one uid. | Unit tests |
| Link spam and phishing | The server forces `pending` for links. Only group moderators approve, never their own. | Rules tests, including uppercase and multi-line links |
| Impersonation | `senderId` must equal the caller. `senderName` must equal the profile name. Report excerpts must match stored text. | Rules tests |
| Reading private messages | Participants only. Staff and the owner are denied. DMs sit outside the `messages` collection group. | Rules tests with third party, staff and owner |
| Flooding and cost | One post per second through `rateLimits`, one report per target, function concurrency capped | Rules tests |
| Suspended users | Writes need `canPost()`, which checks restrictions. Suspension shows instantly through a listener. | Rules and widget tests |
| Account enumeration | One message for wrong email or wrong password. Reset always "sent". | Unit and widget tests. **Also enable email enumeration protection in the console.** |
| Data in backups | `allowBackup=false` and data-extraction rules exclude everything | Manifest |
| Secrets in git | `.gitignore` covers Firebase config, keystores, `.env` files, service accounts and real `config/*.json` | `git check-ignore` verified |
| Unsafe links | Guide sources must be https. Chat links need confirmation and show the host. | Unit tests |

## Test inventory

| Suite | Count | Result on 2026-10-24 |
|---|---|---|
| Firestore rules (emulator) | 78 | All passed |
| Functions unit | 25 | All passed |
| Functions integration (emulator: auth, Firestore, functions) | 16 | All passed, on two consecutive runs |
| Flutter unit and widget | 174 | All passed |

For the new regression tests, the fix was reverted temporarily to confirm the test then fails, and restored afterwards. This was done for the demoted-admin and staff-suspension lift tests, the session-ended push test and the launch-tap test.

## Dependency and secret scans

- **Deployed function dependencies:** `npm audit --omit=dev` found 0 vulnerabilities.
- **Local tooling:** 16 advisories, 0 critical, in `firebase-tools`, `@grpc/grpc-js`, `braces` and others. These packages run only on the developer machine for emulators and tests, never in the app or in deployed functions. Re-check after `npm update`.
- **Flutter packages:** `flutter pub get` reported no advisories, including for the new `firebase_messaging` 17.0.0. No dedicated Dart vulnerability scanner was run.
- **Re-run on 2026-10-24:** `npm audit --omit=dev` in `firebase/functions` found 0 vulnerabilities. No function dependency changed; push uses `firebase-admin/messaging`, which was already installed.
- **Secrets:** a pattern scan for Google API keys, private keys, client secrets and inline passwords found nothing. `config/emulator.json` holds placeholder values for a `demo-` project by design.

## Findings

| ID | Severity | Finding | Status |
|---|---|---|---|
| S1-01 | Medium | The project lives inside a repository with a GitHub remote | Mitigated by `.gitignore`. Owner decision Q16. |
| S1-02 | Medium | Android backup would copy sessions | Fixed |
| S1-03 | Low | Account enumeration | Mitigated. Console setting still needed. |
| S1-04 | Low | Production build without a backend | Fixed: startup refuses |
| S2-01 | Medium | Lifting a suspension by direct delete left no record of who did it | **Fixed:** clients can no longer delete restrictions. The `liftSuspension` function audits it. Rules test added. |
| S2-02 | Low | Staff could turn a deleted account back into a suspension | **Fixed:** updates only allowed while suspended. Rules test added. |
| S2-03 | Medium | Any student-admin could suspend any user, including the owner and other staff | **Fixed** (review F1). See the review table below. |
| S2-04 | Low | `memberCount` could drift when a trigger is retried | **Fixed** (review F5). Concurrent joins can still slightly exceed 2,000. |
| S2-05 | Info | Link detection is pattern-based. Obfuscated links ("example dot com") pass. | Accepted. Reports and moderators cover it. |
| S2-06 | Low | The suspend dialog used its text controller after disposal, which could crash | Fixed. Found by a widget test. |

## Independent review (2026-10-23)

A separate review agent read the rules, functions, client code and manifest, without running anything. Every finding was then fixed and covered by a regression test, except where noted.

| ID | Severity | Finding | Fix | Test |
|---|---|---|---|---|
| F1 | Medium | A student-admin could suspend the owner or other staff. Suspended staff kept their powers. A demoted admin kept the role for up to an hour. | Staff checks now require the staff account to be unrestricted. A server-written `staff/{uid}` marker blocks student-admins from suspending staff and everyone from suspending the owner. Staff callables refuse restricted callers. Demotion revokes sessions. | Rules, plus a functions integration test |
| F2 | Medium | A blocked user could keep pushing text into the other person's inbox preview | Summary updates must respect blocks and ride with a rate-limited message | Rules |
| F3 | Medium | A leaked purchase token could be claimed by the wrong account, locking out the buyer | Account binding is checked before any write. The token mapping is written in a transaction. | Unit test for binding. Not testable end to end without Play. |
| F4 | Low–Medium | Unlimited renames fanned out writes to every membership | One rename an hour, except replacing the sign-up fallback name | Rules |
| F5 | Low | `memberCount` drifted on retried triggers | Each event applies once through a `processedEvents` marker. Give it a TTL policy in the console. | Integration test, count unchanged |
| F6 | Low | Link detection missed `discord.gg`, `.ru`, short links and look-alike dots | Any dotted word with a two-letter ending, and Unicode dots, now counts as a link. More false positives go to moderation by design. | Rules and Dart tests |
| F7 | Low | Any signed-in account could list every profile | `users` allows single reads only | Rules |
| F8 | Low | Suspended users could still file reports | Reports require `canPost()` | Rules |
| F9 | Low | Deletion worked with a stale token. The purge missed purchase tokens and filed reports. | Deletion needs a sign-in from the last 5 minutes, and the app re-checks the password first. The purge now removes tokens, reports, staff and rate-limit records. | Unit and widget tests |
| S1 | Low | One rate-limit write could cover several messages in a batch | The rate-limit document names the single message it covers | Rules |
| S2 | Info | A report could confirm the text of a message hidden from the reporter | Group-message reports require a visible message | Rules |
| S3 | Info | A rename racing with deletion could cause an unhandled rejection | Bulk-writer errors are handled | — |
| Info | **High for release** | The main Android manifest had no `INTERNET` permission, so release builds could not connect | Permission added | Manifest |
| Info | Release | Release builds are signed with the debug key | **Open.** Owner action: create an upload key stored outside the repository. | — |

Still open after the review:

- Joins are not rate-limited.
- Direct messages have no link moderation, by design (Q2).
- Deleted users' direct messages are retained for the other participant (Q13).
- At most about 3 pending link messages can exist per batch window. This is accepted.

## Second independent review (2026-10-24): push, group creation, lifting suspensions

A separate review agent read the new code without running anything. Each confirmed finding was then fixed and tested.

| ID | Severity | Finding | Fix | Test |
|---|---|---|---|---|
| R2-F1 | Medium | When a session ended without the app's sign-out (revoked or disabled account, the verify screen), the device kept receiving the previous account's alerts on a shared phone | Any end of a session invalidates the token. A server trigger removes a token from every other account when it is registered, with the newest registration winning by stored time, not trigger order. | Flutter test, plus an integration test that registers back to back. It caught an ordering bug in the first version. |
| R2-F2 | Medium | Sign-out could hang offline, because Firestore writes wait for the server | The device delete is not awaited, token calls time out after 5 s, and sign-out caps push cleanup at 8 s | Flutter test with cleanup that never finishes |
| R2-F3 | Low–Medium | A demoted student-admin kept powers until the old ID token expired, up to about an hour | Rules and `liftSuspension` also require the `staff/{uid}` marker, which demotion deletes | Rules test and integration test with a stale claim |
| R2-F4 | Low | Unlimited device documents could slow account deletion and the purge | `recursiveDelete` pages through them, and a trigger trims each user to 10 with a bounded read | Integration test with 13 devices |
| R2-F5 | Low | A tap that launched the app lost its target | The route is held until the session is known, then opened only if signed in | Two Flutter tests |
| R2-I2 | Info | Restricted and unverified accounts could register devices. Moderation alerts went to restricted accounts. | Device rule requires `canPost()`. The moderation trigger skips restricted senders. | Rules test |
| R2-I6 | Info | The suspended list had no order, so older entries could show instead of newer ones | Server-side `orderBy(updatedAt desc)` with a composite index | Rules test uses the app's query |
| R2-I7 | Info | Group names were checked for shape only on the client | Rules now require trimmed names with no `<`, `>` or links, matching the client | Rules and Dart tests |

Accepted or open after this review:

- **Shared-phone edge case:** if sign-out happens fully offline, the token may stay valid until the next account on that phone turns notifications on. Alerts show a sender name, never the text.
- **Token planting:** someone who learned another device's FCM token could register it under their own account, which moves that device's alerts to them. Tokens are not exposed by the app or the rules.
- **Sender names on the lock screen** are chosen by the sender. Links and `<>` are blocked, and posting is rate-limited.
- **Duplicate pushes:** retried triggers can send twice. A notification tag collapses them.
- **Stale tray notifications** from a previous account route to a screen the new account cannot read. The rules deny the read.
- **Device registration bursts** each start a trigger. This is bounded by the function concurrency cap and free invocation quota, and needs a verified account.
- Policy question Q24, lifting suspensions of students.

## Not yet assessed

- Real Firebase Auth behaviour, email delivery and App Check attestation. No project exists.
- Push delivery. FCM has no emulator, so no notification has been sent or received. Payload building, pruning, device rules and triggers are tested.
- The app on a device or emulator, including notification permission prompts. The owner deferred this.
- Load and abuse at scale. No load tests have been run.
- On-device TalkBack and accessibility.
- Play Billing end to end.

**Completion state:** *Partially verified.* Rules and functions behave as designed in the emulator, with allowed and denied tests. Production configuration, deployment and scale are not verified.

## Privacy

- Firestore stores only the display name. Email stays in Firebase Auth, and only the user sees it in the app.
- Account deletion anonymizes the name immediately, including on past group messages. It removes memberships, blocks and the login. Remaining records are purged after 90 days. Audit entries keep only the bare uid.
- No analytics, crash reporting or ad SDKs are included. Adding any of them needs a privacy-policy update (Q14, Q1).
- Logs from functions contain no message text, emails or purchase tokens.
