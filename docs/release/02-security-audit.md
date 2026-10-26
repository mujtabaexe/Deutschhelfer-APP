# 02 — Security audit (release run, 2026-10-26)

This continues [docs/security.md](../security.md), which holds the threat model, trust boundaries and the two earlier reviews (F1–F9 and R2-F1–F5).

## What changed in this run

| Change | Security relevance |
|---|---|
| Community rules acceptance | New profile fields and rules checks on joins, group posts, DMs and inbox summaries |
| Blocking from groups | Client-side hiding plus the existing server-side DM blocks |
| Deletion module, owner deletion script, purge hardening | Privileged Admin SDK code, run on the owner's computer |
| Hosted privacy and deletion pages | Public pages; CSP and security headers |
| Production config requires contact URLs | Startup guard |
| Release signing | Upload key from a git-ignored file. Release builds fail without it. |

## Independent review

A separate review agent read today's changes. It wrote its own proof-of-concept rules tests and ran them against a local Firestore emulator. It did not edit the repository. Every finding was then fixed and covered by a regression test, which was re-run.

| ID | Severity | Finding | Fix | Regression test | Status |
|---|---|---|---|---|---|
| F-01 | Medium | DMs and inbox summaries skipped the rules-acceptance check. A conversation could be opened with someone who never accepted. Confirmed by the PoC. | `acceptedRules(uid())` on DM create and conversation update; both participants on conversation create | Rules: a member who never accepted cannot send a DM or summary, and can after accepting; an accepted member cannot open a conversation with one who never accepted | **Fixed** |
| F-02 | Low | A client could accept future versions (up to 100) and skip re-consent. Confirmed by the PoC. | Only `rulesVersion == minRulesVersion()` is accepted. `maxRulesVersion` removed. | Rules: versions 2 and 100 denied | **Fixed** |
| F-03 | Low–Medium | The rules gate also blocked the guide and in-app account deletion | Only `/groups`, `/messages` and moderation are gated. A "Not now" button opens the guide. | Routing unit test; widget test reaching "Delete account" while declined | **Fixed** |
| F-04 | Low–Medium | One failing purge blocked every later purge | Errors are caught per account, with `attempts` and `lastErrorCode`. The uid is validated before any write. | Integration: a malformed queue entry is recorded and the next account is still purged | **Fixed** |
| F-05 | Low | Deletion script: a mistyped uid gave false success; path-like uids; email and uid together; `--purge-now false`; no dry run; half-configured emulator variables; weak identity guidance | Looks up the account first and writes nothing if it is unknown; uid pattern; exactly one target; strict flags; dry run by default with `--confirm <uid>`; refuses half emulator settings; one-time-code identity check on the page | Integration: dry run changes nothing; unknown and malformed uids write nothing; unsafe arguments exit 2 | **Fixed** |
| F-06 | Low | The privacy text overstated deletion: suspension reasons kept forever; reports about the user not disclosed; "anonymous" was really pseudonymous | The purge redacts `details` on audit entries about the account. The notices now say "pseudonymous", disclose that reports are kept, and say free text is removed after 90 days. | Integration: the suspension reason is redacted at purge | **Fixed** |
| F-07 | Low | The "Student" fallback exception allowed a second rename each hour. Confirmed by the PoC. | Exception only while `updatedAt == createdAt` | Rules | **Fixed** |
| F-08 | Low | Hiding blocked senders could stall "load older" or throw when everything loaded was hidden | The cursor comes from all loaded messages | View-model test | **Fixed** |
| F-09 | Low | `.gitignore` missed `*-firebase-adminsdk-*.json`, `*.p12`, `*.pfx` and `*.pem` | Added | Checked with `git check-ignore` | **Fixed** |
| F-10 | Info | Release builds silently fell back to the debug key | The build fails unless `ALLOW_DEBUG_SIGNED_RELEASE=true` is set | Verified: release build without a key fails with a clear message | **Fixed** |
| F-11 | Info | The owner could add a member who never accepted. Confirmed by the PoC. | Acceptance required in the owner branch too | Rules | **Fixed** |
| F-12 | Info | Suspended or deleted accounts could still create blocks and rate-limit records with an unexpired token. Confirmed by the PoC. | `!isRestricted()` on those writes | Rules | **Fixed** |

**Accepted, informational:**
- The client gate fails open while the profile is loading or errors. The server still enforces.
- Group blocking is local, and fails open if the block list cannot be read.
- A moderator who blocks someone also stops seeing their group messages.
- The hosting placeholder check scans only `.html` files.

## Checks performed in this run

| Area | Check | Result |
|---|---|---|
| Authorization | Rules suite, with new allowed and denied tests | See [05-test-results.md](05-test-results.md) |
| Input validation | Rules re-validate every client field; uid pattern in Admin SDK code | PASS |
| Injection | No string-built queries. Firestore paths come from validated ids in rules and functions. The script validates uids before building paths. | PASS (code review) |
| Secrets | Pattern scan by the reviewer: no keys, tokens or service accounts in the project; `.gitignore` hardened | PASS |
| Logs | Function logs carry counts and codes only. The script never prints the email, only a masked form. | PASS (code review) |
| Push payload | DM notifications carry the sender name only, never the text | PASS (unit test) |
| Release manifest | No cleartext config, not debuggable, `allowBackup=false` | PASS (`aapt2`) |
| Web pages | Strict CSP (`default-src 'none'`), nosniff, no-referrer, HSTS; no scripts | PASS (config review; not deployed) |
| Dependencies | `npm audit --omit=dev` in `firebase/functions` | See [05-test-results.md](05-test-results.md) |

## Not assessed

- Real Firebase Auth, App Check attestation, FCM delivery and Play Billing. No project exists.
- Load and abuse at scale.
- iOS. Not a target.
- Whether the privacy texts are legally adequate. They need a legal review.
- Dart package vulnerabilities. No Dart advisory scanner was run.

**Completion state: Partially verified.** Rules, functions and client logic pass allowed and denied tests in the emulator, and the reviewer's findings are fixed and re-tested. Production configuration, real services and scale are not verified.
