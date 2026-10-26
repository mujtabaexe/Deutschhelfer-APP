# Deutschhelfer

Android-first Flutter app that helps students in Pakistan prepare for German university admission. It combines guidance content, IELTS preparation, moderated student groups, direct messages and subscriptions.

**Status (2026-10-26):** Release-readiness run complete for everything that can be done locally. All suites pass against the Firebase Emulator Suite, and release AAB and APK builds succeed. The app is not yet deployed: there is no real Firebase project, upload key or Play Console app. Verdict: **READY FOR OWNER REVIEW**. Start with [docs/release/10-owner-actions.md](docs/release/10-owner-actions.md).

## Requirements

| Tool | Version used | Notes |
|---|---|---|
| Flutter | 3.47.6 stable | Dart 3.13.5 |
| Android SDK | API 36 | Accept licenses with `flutter doctor --android-licenses` |
| JDK | 21 | Needed by Gradle and the Firestore emulator |
| Node.js | 24 (functions target Node 22) | For the emulators and backend tests |

Firebase tooling is installed per project, not globally:

```sh
cd firebase && npm install
cd functions && npm install
```

## Run the app

Without Firebase, the app runs with sign-in disabled:

```sh
flutter run
```

Against local emulators, with no real project, data or cost:

```sh
cd firebase
npx firebase emulators:start --project demo-deutschhelfer
# in another terminal, from the project root:
flutter run --dart-define-from-file=config/emulator.json
```

`config/emulator.json` points the Android emulator at `10.0.2.2`. For a physical phone, change `FIREBASE_EMULATOR_HOST` to your computer's LAN address.

Push notifications are off in emulator builds, because FCM has no emulator. The Profile tab hides the notification switch there, and `firebase/functions/.env.local` sets `PUSH_ENABLED=false`.

Against a real Firebase project, copy `config/example.json` to `config/dev.json`, fill in the values from the Firebase console, and run with `--dart-define-from-file=config/dev.json`. Real config files are git-ignored. Production builds refuse to start with a demo project or emulator host.

## Test

| Suite | Command | Last result |
|---|---|---|
| Flutter unit and widget | `flutter test` | 199 passed |
| Static analysis | `flutter analyze` | No issues |
| Firestore rules (emulator) | `cd firebase && npm test` | 88 passed |
| Functions unit | `cd firebase/functions && npm test` | 25 passed |
| Functions integration (emulator) | `cd firebase/functions && npm run test:integration` | 25 passed |
| On-device E2E (Android emulator) | see [docs/release/06-device-test-results.md](docs/release/06-device-test-results.md) | 3 of 3 journeys, two runs in a row |
| Android build | `flutter build apk --debug --dart-define-from-file=config/emulator.json` | Built |
| Release bundle | `flutter build appbundle --release` (needs `android/key.properties`; see docs/release/08-release-build.md) | Built, debug-signed toolchain check |

On a slow first start, the Functions emulator may time out while loading. Set `FUNCTIONS_DISCOVERY_TIMEOUT=60` in the environment before the integration tests.

## Project layout

```text
lib/
  app/        app widget, router and redirects, session controller, services
  config/     build-time configuration (no secrets)
  data/       repositories: Firebase implementations and unconfigured stand-ins
  domain/     models and validation rules (shared limits with the server)
  l10n/       ARB strings; app_localizations*.dart is generated
  ui/core/    design tokens, theme, shared widgets
  ui/features/<feature>/{views,view_models,widgets}
assets/content/guide.json   bundled free guidance (DRAFT, needs owner review)
config/       dart-define files; only emulator.json and example.json are committed
firebase/
  firestore.rules, firestore.indexes.json, firebase.json
  test/rules.test.mjs        rules tests
  functions/                 Cloud Functions (trusted backend) and tests
  scripts/set-owner.mjs      one-time owner bootstrap
  scripts/check-hosting.mjs  refuses to deploy pages with placeholders
  hosting/                   public privacy policy and account-deletion pages
  functions/scripts/delete-account.mjs  owner-run deletion for web requests
integration_test/  on-device end-to-end journeys against the emulators
docs/         requirements, architecture, design system, security, cost, open questions
```

## Generated files

Do not edit by hand: `lib/l10n/app_localizations*.dart`, `pubspec.lock`, `package-lock.json` files, `.metadata` and Gradle wrapper files.

## Documentation

- [docs/requirements.md](docs/requirements.md) covers requirements, status and acceptance evidence.
- [docs/architecture.md](docs/architecture.md) covers layers, data model and data flow.
- [docs/ui-design-system.md](docs/ui-design-system.md) covers tokens, components and the screen inventory.
- [docs/security.md](docs/security.md) covers trust boundaries, rules, tests and findings.
- [docs/cost-model.md](docs/cost-model.md) covers verified quotas, cost drivers and controls.
- [docs/open-questions.md](docs/open-questions.md) covers decisions and owner actions.
- [docs/release/](docs/release/) holds the release-readiness reports (00 to 12), the free-first architecture and the cost estimate.
