# 05 — Test results

Final run on 2026-10-26, after every code change in this run. Windows 11, Flutter 3.47.6 / Dart 3.13.5, Node 24, firebase-tools 15.34.1. All Firebase suites use the local Emulator Suite with the `demo-deutschhelfer` project.

| Suite | Command | Baseline (start of run) | Final |
|---|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test integration_test` | 76 files, 0 changed | **83 files, 0 changed** |
| Static analysis | `flutter analyze` | No issues | **No issues** |
| Flutter unit and widget | `flutter test` | 175 passed | **199 passed, 0 failed** |
| Firestore rules | `cd firebase && npm test` | 78 passed | **88 passed, 0 failed** |
| Functions unit | `cd firebase/functions && npm test` | 25 passed | **25 passed, 0 failed** |
| Functions integration | `cd firebase/functions && FUNCTIONS_DISCOVERY_TIMEOUT=240 npm run test:integration` | 16 passed | **25 passed, 0 failed** |
| On-device E2E (Android emulator) | See [06-device-test-results.md](06-device-test-results.md) | Did not exist | **3 of 3 journeys passed, two runs in a row** |
| Dependency audit (deployed functions) | `npm audit --omit=dev` in `firebase/functions` | 0 | **0 vulnerabilities** |
| Dependency audit (local tooling) | `npm audit` in `firebase` | 16 (earlier session) | 10 (5 moderate, 5 high). Developer machine only. |
| Release bundle, final code (2026-10-27) | `$env:ALLOW_DEBUG_SIGNED_RELEASE="true"; flutter build appbundle --release` | — | **Built** in 205 s: `build/app/outputs/bundle/release/app-release.aab`, 55.5 MB, written 03:03:25 by this run. Manifest (protobuf manifest converted with `aapt2`): `targetSdkVersion` 36, `minSdkVersion` 24, not debuggable, no cleartext or network-security-config exception, `allowBackup=false`. **Signed with the debug key (`CN=Android Debug`); it must not be uploaded to Play.** |
| Signing guard, final code (2026-10-27) | `flutter build appbundle --release` without the override | — | **Fails as intended** in 7 s: "Release signing needs android/key.properties". The bundle above was left untouched. |

## Tests added in this run

| Area | Tests |
|---|---|
| Community rules (rules) | Acceptance at sign-up; partial, backdated, wrong-type or future versions refused; later acceptance; no downgrade; required to join (member and owner-added), post, start a DM (both people), send a DM and update the inbox summary |
| Review regressions (rules) | F-01, F-02, F-07, F-11, F-12 |
| Sign-up (widgets) | Refused without accepting the rules; rules and privacy readable before sign-up with the form kept; the acceptance is recorded with the profile |
| Rules gate (widgets) | Gate for a verified user who never accepted; deep links held; accept moves on; failed save explained; older version asks again; "Not now" keeps the guide and Profile with deletion; privacy readable signed out |
| Blocking (widgets and view model) | Block from a message long-press hides that sender; cancel blocks nobody; block from the member list; blocked list and unblock; paging past hidden senders (F-08) |
| Accessibility (widgets) | Tap-target, labelled-target and contrast guidelines on the gate, rules, privacy and blocked list, in light and dark; gate and rules at 320 dp with 200% text |
| Config (unit) | Production needs a contact email and both https pages; malformed values refused in every environment |
| Routing (unit) | needsRules gating; legal pages in every state |
| Deletion (functions integration) | Purge erases what is left and is idempotent; unverified accounts can delete; signed-out callers refused; the script's dry run, confirm, purge-now, unknown or malformed ids and unsafe arguments; purge isolation (F-04); audit redaction (F-06) |
| Owner tools (widget) | Guard for the group-creation pop crash. It does not reproduce the device failure; the on-device journey does. |

## Authentication test gate

Required by the brief: each category, how it is tested, and the result.

| Category | Automated (fakes) | Emulator (Auth and Firestore) | Android emulator E2E | Physical device |
|---|---|---|---|---|
| Valid registration | PASS (`auth_flow_test`, `session_flow_test`) | PASS (profile creation through rules) | **PASS** | NOT TESTED |
| Invalid or empty input, password rules, confirmation | PASS (`input_validators_test`, `auth_flow_test`) | Rules re-validate the name | Refused without the rules checkbox: **PASS** | NOT TESTED |
| Duplicate email (neutral message) | PASS (error-mapping unit test) | — | NOT TESTED | NOT TESTED |
| Keyboard navigation | PASS (Next walks every field) | — | Fixed after an earlier device session | NOT TESTED |
| Loading and double-submit | PASS (`auth_view_models_test`) | — | — | NOT TESTED |
| Network failure | PASS (mapped to an offline message) | — | NOT TESTED | NOT TESTED |
| Email verification and unverified restrictions | PASS (gate and routing) | PASS (rules require `email_verified` for writes) | **PASS** (held until the link is opened) | **BLOCKED** (real email) |
| Login and wrong password (neutral) | PASS | PASS (integration sign-ins) | **PASS** | NOT TESTED |
| Logout | PASS (push unregistered first) | — | **PASS** (owner signs out) | NOT TESTED |
| Password reset (no enumeration) | PASS | — | NOT TESTED | **BLOCKED** (real email) |
| Session persistence | PASS (session stream tests) | — | Implicit: the student stayed signed in across tests | NOT TESTED |
| Expired or revoked session | PASS (ended session forgets the push device) | PASS (demoted admin's stale token refused) | Disabled account refused at sign-in: **PASS** | NOT TESTED |
| No self-granted roles | — | PASS (rules deny role fields; `setUserRole` owner-only, never grants owner) | — | — |
| Repeated or interrupted registration and partial failure | PASS (profile save failure does not fail sign-up; fallback profile then the rules gate) | PASS (fallback-name and acceptance rules) | Both landing orders handled | NOT TESTED |
| Account deletion and cleanup | PASS (re-auth first; wrong password explained) | PASS (deletion, purge and script) | **PASS** | NOT TESTED |

**Untested:** real email delivery (verification and reset), real App Check, Firebase Auth's server password policy (a console setting), behaviour on a physical device, TalkBack.

## Run of 2026-10-27 (owner decisions, minimum age, Spark audit)

Windows 11, Flutter 3.47.6. Only code touched by this run was re-tested. The Firebase emulator suites were **not** re-run: nothing under `firebase/` changed except static hosting pages.

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues** (62 s) |
| Affected tests | `flutter test` on `auth_flow`, `session_flow`, `owner_tools`, `account_admin`, `community_safety`, `test/config` | **83 passed** (39 s) |
| Full Flutter suite | `flutter test` | **202 passed, 0 failed** (31 s). Was 199; 3 new tests. |
| Hosting placeholder check | `cd firebase; npm run check:hosting` | **"Public pages are ready to deploy."** (3 s). On a scratch copy with `{{FIREBASE_REGION}}` put back it exits 1 and names `privacy.html: {{FIREBASE_REGION}}`. |
| Bundle signer | `keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab` | **`CN=Sahibzada Ahmad Mujtaba`**, SHA-1 `7B:CF:F2:BA:65:F7:4E:16:BE:AE:1D:2A:E7:3B:A3:95:F9:E1:3C:47`, SHA-256 `32:1C:6C:EA:2D:9B:07:82:2E:34:26:07:78:D6:1B:2E:94:03:DA:78:EA:5C:3F:4B:8D:40:5C:A2:BB:51:17:03`, valid until 2054-03-14. Not the debug key. (7 s) |
| Bundle size and time | `Get-Item` on the same file | **58,188,781 bytes (55.5 MB)**, written 2026-10-27 05:07. **Built before this run's code changes and not rebuilt.** |

New or changed tests:

| Test | File |
|---|---|
| Sign-up is refused without the age confirmation, even with the rules ticked, and creates no account | `auth_flow_test.dart` |
| Helper ticks every required sign-up checkbox; the privacy notice date is checked separately from the rules date | `test/helpers/test_app.dart`, `auth_flow_test.dart` |
| Lifting a suspension with the function unreachable keeps the suspension and shows "The action failed" | `owner_tools_test.dart` |
| Appointing a moderator with the function unreachable leaves the role unchanged | `account_admin_test.dart` |

Later the same day the owner chose **`asia-southeast1` (Singapore)** instead of Mumbai. The functions region changed in `firebase/functions/index.js`, `lib/app/app_services.dart` and the integration test's client. Re-checked: `flutter analyze` **No issues**; `npm run check:hosting` **ready to deploy**; `cd firebase/functions; $env:FUNCTIONS_DISCOVERY_TIMEOUT=240; npm run test:integration` **25 passed, 0 failed, exit 0** (about 3.5 min, local emulators only). The Flutter suite was not re-run: no Dart test references the region. No cloud resource exists, so the region has not been exercised against a real project.

Not run: Firestore rules tests, functions unit tests, on-device E2E, a release build (their inputs did not change, or a build is not needed to check this run's changes). The bundle is **not uploaded to Play**; see K3 in [11-known-issues.md](11-known-issues.md).

## History in this run (failures investigated, not hidden)

- **Flutter:** the first run after the rules checkbox failed 2 registration tests, as expected. They were updated to tick the box, and new tests check the refusal.
- **Rules:**
  - 1 new test failed because of a test bug (reused a Firestore instance); fixed.
  - The review regressions failed before their fixes, were confirmed by the reviewer's PoC, and pass after.
- **Functions integration:**
  - 3 trigger tests timed out once when run against a long-running emulator instance that had been used for other work.
  - The canonical `emulators:exec` run passes them all (25/25).
- **On-device E2E:** 11 runs. The failures found:
  - 2 app bugs (D1, D2 in [06](06-device-test-results.md));
  - 1 Gradle regression of my own (D3);
  - test-harness issues: the `integration_test` plugin build, the HTTP stub in the test binding, snackbars covering taps, the test surface size, and data left over from earlier runs.
  - All were fixed. The last two runs passed fully.
