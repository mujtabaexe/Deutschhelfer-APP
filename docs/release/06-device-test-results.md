# 06 — Device and end-to-end test results

**Environment (2026-10-26):**
- Android **emulator** "Pixel 4a" AVD (`sdk gphone64 x86 64`, API 36, `emulator-5554`).
- Firebase Emulator Suite (auth, firestore, functions) on the host, reached at `10.0.2.2`.
- **This is not a physical device**, and no real Firebase project, email delivery, App Check attestation or FCM was involved.

## How to run

```sh
cd firebase && npx firebase emulators:start --only auth,firestore,functions --project demo-deutschhelfer
# second terminal, project root, with an Android emulator running:
flutter run -d emulator-5554 -t integration_test/app_e2e_test.dart --dart-define-from-file=config/emulator.json
```

**Data warning:** the test wipes the emulators' Auth and Firestore data at the start.

It runs as a live widget test through `flutter run`. The `integration_test` plugin is not used, because its Gradle module fails to configure with this project's Android settings (AGP 9 with `android.newDsl=false`): "'kotlin-android' plugin requires one of the Android Gradle plugins".

## Automated journeys (`integration_test/app_e2e_test.dart`)

| Journey | Steps checked | Result |
|---|---|---|
| Owner creates a group | Owner (set up as `set-owner.mjs` would) signs in → rules gate (directly or via the Groups tab) → accept → New group → create → group listed → sign out | **PASS** |
| Student registration and use | Create account refused without the rules checkbox → accepted → verify-email screen → "not confirmed yet" before verification → verification link from the Auth emulator → enters the app → opens a guide article → joins the owner's group → sends a message (appears in the list) → sends a link (shown "Waiting for moderator approval") | **PASS** |
| Account deletion | Profile → Delete account (DELETE plus password, re-authentication) → back on the welcome screen → the Auth emulator shows the account disabled → Firestore profile is "Deleted user" → sign-in refused with "This account is disabled" → wrong password gives the neutral "do not match" message | **PASS** |

**Two consecutive full runs: 3 of 3 journeys passed each time** (runs 10 and 11).

## Bugs found on the device and fixed

| # | Bug | Cause | Fix | Regression coverage |
|---|---|---|---|---|
| D1 | Creating a group crashed: "There is nothing to pop" | `context.pop(id)` when the create screen was not on top of a pushable stack. It happened after the rules-gate redirect; widget tests with fakes did not reproduce it. | Pop when possible, otherwise go to the new group | The on-device journey, which failed before the fix and passes after. A widget-test guard exists but does not reproduce the crash. |
| D2 | **Every Cloud Function call from an emulator build on Android failed**: in-app deletion, lifting suspensions, role changes | `config/emulator.json` used the placeholder API key `demo-api-key`. The Android SDK rejects it: "Please set a valid API key". | Placeholder replaced with a correctly shaped, obviously fake value (`ADemoEmulatorOnlyKeyNotARealSecret00000`), deliberately not starting with `AIza` so secret scanners stay quiet | The deletion journey |
| D3 | Debug builds failed after the release-signing guard was added (my own regression) | The guard threw during Gradle configuration | The guard now runs only when a release task is scheduled | Debug and release builds |
| — | Earlier sessions | Keyboard "Next" skipped "Confirm password"; cleartext to `10.0.2.2` was blocked | Already fixed | Widget test; debug network config |

## Checks not automated on the device

| Flow | Coverage instead | Status on the device |
|---|---|---|
| Direct messages, blocking, reporting | Widget tests with fakes; rules tests in the emulator | NOT TESTED on the device |
| Staff moderation: approve a link, suspend, lift | Widget, rules and functions integration tests | NOT TESTED on the device |
| Notifications and tap navigation | Unit and widget tests. FCM has no emulator. | **BLOCKED.** Needs a real project and a physical phone (A13). |
| Real email delivery and the verification link in a mail app | Verification link taken from the Auth emulator | **BLOCKED.** Needs a real project. |
| Offline and backend failures | Widget tests with failing fakes; error mapping unit tests | NOT TESTED on the device |
| Dark mode, 200% text, 320 dp | Widget tests: guidelines, overflow and contrast in light and dark | NOT TESTED on the device |
| **TalkBack** | Semantics labels and guideline tests | **NOT TESTED.** Needs a person with TalkBack on (A14). |
| Keyboard navigation | Widget test (Next walks every field); found and fixed on the device earlier | Partially (earlier session) |

## Steps the owner must do on a physical phone

1. Install a debug build against the **dev** project (not the emulators). Register with a real address and open the email on the phone.
2. Repeat the three journeys above. Then, with two accounts:
   - send a DM;
   - block from a group message, and check the messages disappear;
   - report a message;
   - approve the link as the owner;
   - suspend and lift.
3. Turn on notifications, send a DM from the second account with the app in the background, tap the notification, and check it opens the chat (A13).
4. Turn on TalkBack and complete sign-up and send a group message by voice only. Note anything unlabelled or out of order.
5. Use dark mode and Settings → Display → font size at maximum, and look for clipped text.
6. Switch to airplane mode during a send and on a fresh launch, and check the messages are understandable.
