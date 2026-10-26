# 08 — Release build

## Builds run on 2026-10-26

| Build | Command | Result | Output |
|---|---|---|---|
| App bundle | `flutter build appbundle --release` | **Built** | `build/app/outputs/bundle/release/app-release.aab` (55.5 MB) |
| APK | `flutter build apk --release` | **Built** | `build/app/outputs/flutter-apk/app-release.apk` (55.1 MB) |

**These builds predate the last changes of the run**: the review fixes, the signing guard, the API-key and group-creation fixes. After those changes:
- `flutter build appbundle --release` without a key **failed as intended**, in 5 s: "Release signing needs android/key.properties".
- A rebuild with `ALLOW_DEBUG_SIGNED_RELEASE=true` was stopped before it finished on 2026-10-26. **On 2026-10-27 it was re-run on the final code and succeeded**: 55.5 MB, target SDK 36, not debuggable, no cleartext exception, debug-signed. It must not be uploaded. See [05-test-results.md](05-test-results.md).
- The final code did build and run in **debug** on the Android emulator (two passing E2E runs).

Re-run `$env:ALLOW_DEBUG_SIGNED_RELEASE="true"; flutter build appbundle --release`, or better, build with the real upload key.

Both were built with **no dart-defines**, so they are development builds with no backend configured. Nobody can sign in with them. They prove the release toolchain works: R8, resource shrinking, manifest merge and signing. They are not a production artefact. A production build needs `--dart-define-from-file=config/prod.json`, and the app refuses to start unless that includes a real, non-demo Firebase project and the contact details.

## Checked in the built APK (`aapt2` from build-tools 36.1.0)

| Check | Result |
|---|---|
| Package | `com.deutschhelfer.deutschhelfer` (Q10: permanent after the first upload) |
| Version | `versionCode=1`, `versionName=1.0.0`, from `pubspec.yaml` |
| `targetSdkVersion` | **36**. Meets the requirement for new apps and updates from 31 August 2026. |
| `minSdkVersion` | 24 |
| `debuggable` | Not set (release) |
| `allowBackup` | `false`. Data-extraction rules exclude everything. |
| Network security config | **None in release.** The cleartext exception for `10.0.2.2`, `localhost` and `127.0.0.1` exists only in `src/debug`. |
| Permissions | INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, POST_NOTIFICATIONS, `c2dm.permission.RECEIVE`, `READ_GSERVICES`, and `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. All come from the app and Firebase; none are sensitive or restricted. |
| Exported components | The launcher activity, and Firebase's messaging receiver, which is protected by the C2DM permission |
| Signer | **`CN=Android Debug`.** No upload key existed. Gradle now refuses release builds without one unless `ALLOW_DEBUG_SIGNED_RELEASE=true` is set (review F-10). **Do not upload a debug-signed build;** Play rejects them. |

## Signing setup (prepared, needs the owner)

`android/app/build.gradle.kts` reads `android/key.properties`, which is git-ignored, as is `*.jks`. The template is `android/key.properties.example`.

1. Create the upload key outside the repository:
   ```powershell
   keytool -genkeypair -v -keystore C:\secure\deutschhelfer-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/key.properties.example` to `android/key.properties` and fill in the paths and passwords. Never commit it, and never share the passwords.
3. Back up the keystore and passwords somewhere safe. With Play App Signing, a lost upload key can be reset, but only through Play support.
4. Build with `flutter build appbundle --release --dart-define-from-file=config/prod.json`.
5. Check the signer with `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`. It must not say "Android Debug".

No key was generated in this run. A key made by the assistant would not be the owner's to control.

## Production configuration safety

| Guard | Where | Tested |
|---|---|---|
| Production refuses a `demo-` project or an emulator host | `FirebaseConfig.parse` | Unit tests |
| Production needs a Firebase config | `createServices` | Unit tests |
| Production needs `SUPPORT_EMAIL` and https `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL` | `AppConfig.parse` | Unit tests (new) |
| App Check uses Play Integrity in production and the debug provider otherwise | `createServices` | Not testable without a project |
| Functions enforce App Check unless `ENFORCE_APP_CHECK=false`, which is set only in `.env.local` for the emulator | `index.js`, `.env.example` | Integration tests run with it off |
| Debug banner hidden in production | `app.dart` | — |

## Warnings seen during the build

- Several plugins use deprecated Android APIs (javac notes). These are upstream and harmless today.
- "Expected to find fonts for CupertinoIcons". The app's own code does not reference `CupertinoIcons`, so this comes from a dependency. No icons are missing in the app.
- Flutter asks plugin authors to migrate to built-in Kotlin. This is upstream.
