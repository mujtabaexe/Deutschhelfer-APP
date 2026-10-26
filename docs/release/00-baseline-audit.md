# 00 — Baseline audit

Date: 2026-10-26. Everything below was checked in the repository or by running the command shown. Earlier progress summaries were treated as clues and re-verified.

## Repository state

| Item | Finding |
|---|---|
| Location | `D:\Projects\Deutschhelfer-APP`, inside the parent Git repository `Flutter-Source-Code` (GitHub remote, branch `main`) |
| Tracking | **Untracked on purpose.** The project's own `.gitignore` ends with `.`; `git status -- .` shows `?? ./`. Nothing from this project has been committed (open question Q16). |
| Other uncommitted work | The parent repository has many staged files under `../class_Task/`. They belong to another project and were not touched. |
| Stack | Flutter 3.47.6 stable, Dart 3.13.5, Firebase Auth, Firestore, Cloud Functions 2nd gen (Node 22), App Check, FCM (`firebase_messaging` 17.0.0) |
| Architecture | MVVM with `ChangeNotifier` view models, repository interfaces with fakes, `go_router` with a pure `redirectFor` guard, gen-l10n strings |
| Android | Package `com.deutschhelfer.deutschhelfer`. `compileSdk` and `targetSdk` come from the Flutter defaults, which are 36. `minSdk` is 24 (read from `FlutterExtension.kt` in the Flutter SDK). Release builds are signed with the **debug key**. |
| CI | None. No workflow files exist. |
| Blueprint | `Deutschhelfer — Implementation Blueprint.pdf` (BP). The scope document is still missing (Q4). |

## Open questions requested verbatim

Quoted from `docs/open-questions.md` as found at the start of this run:

- **Q2:** "**Who may start direct messages?** The blueprint allows anyone to message anyone." Provisional default: "Only members of a shared group. Blocking supported. Links in DMs are not clickable."
- **Q3:** "**Content for signed-out users.**" Provisional default: "Free guidance is bundled in the app. Signed-out users see only the welcome screen."
- **Q18:** "**Firestore location and functions region**" Provisional default: "`asia-south1` (Mumbai) for functions. Choose the same for Firestore when creating the project; it cannot be changed later."
- **Q22:** "**Push identifiers.** firebase_messaging 17 deprecates FCM tokens in favour of Firebase Installation IDs." Provisional default: "Keep tokens until the installation-ID flow is checked on a real device, then switch both the client and `notify()` to `fids`."
- **Q24:** "May a student-admin lift a suspension the owner placed on a student?" Provisional default: "Yes, matching who they may suspend. Only the owner lifts staff suspensions."

## Feature inventory (inspected in code)

| Area | State at baseline |
|---|---|
| Registration, sign-in, reset, verify email, sign-out | Built. Neutral errors, 60 s resend cooldown, double-submit guard. |
| Profile and display names | Built. Clients change only the name, one rename an hour. |
| Guide | Built. Bundled `assets/content/guide.json`, marked DRAFT. |
| Groups, membership, owner group creation | Built. Cap of 2,000 members enforced by rules. |
| Group chat | Built. 30-message live page, older pages on demand, links held as `pending`. |
| Direct messages | Built. Members of a shared group only. Block and report available inside a conversation. |
| Reports, moderation queue, suspensions, lifting | Built. Audited through functions. |
| Push | Groundwork built. Off in emulator builds; nothing delivered. |
| Account deletion | In-app path through the `deleteMyAccount` callable, with a 90-day purge. **No web deletion resource.** |
| Subscriptions | Server boundary only (`verifyPurchase`, RTDN, reconcile). No purchase screen, no Billing Library. |
| Community rules or terms acceptance | **Missing.** No terms, rules or privacy text anywhere in `lib/`. |
| Blocking from group context | **Missing.** Block exists only inside a DM conversation. |
| Privacy policy in the app | **Missing.** |
| Release signing | **Missing.** Uses the debug key. |

## Baseline checks (run 2026-10-26, before any change)

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | No issues |
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | 76 files, 0 changed |
| Flutter unit and widget | `flutter test` | **175 passed**, 0 failed |
| Firestore rules (emulator) | `cd firebase && npm test` | **78 passed**, 0 failed |
| Functions unit | `cd firebase/functions && npm test` | **25 passed**, 0 failed |
| Functions integration (emulator) | `FUNCTIONS_DISCOVERY_TIMEOUT=60 npm run test:integration` | **16 passed**, 0 failed |

The README listed 174 Flutter tests. The extra test is the keyboard Next-key regression added after the last device session.

## Environment limitations

- **No real Firebase project.** Everything runs against the Emulator Suite with the `demo-deutschhelfer` project, so real email delivery, App Check attestation and FCM delivery cannot be tested.
- **No Play Console access and no upload key.**
- **Emulators only.** An Android emulator (Pixel 4a AVD) is available. No physical device is connected.
- **Emulator log:** `firebase/firestore-debug.log` is git-ignored. A pattern scan for private keys, Google API keys, refresh tokens and "password" found no matches.
