# 10 — Owner actions, in order

Everything here needs your accounts, money, identity or judgement. The development work cannot or must not do it. **Nothing below has been done yet.** Commands are for Windows PowerShell, run from the repository root `D:\Projects\Deutschhelfer-APP` unless a step says otherwise.

Steps marked **IRREVERSIBLE** cannot be undone, or can be undone only with great effort. Every other step has a rollback note.

## 0. Decisions already made

| Item | Decision | Status |
|---|---|---|
| Developer name | Sahibzada Ahmad Mujtaba | Final. Filled in the hosting pages. |
| Support email | sahibzadaahmadmujtaba@gmail.com | Final. Filled in the hosting pages and `config/example.json`. |
| Deletion request reply time | Within 7 days | Final. Stated on `delete-account.html`. |
| Minimum age | 18 | **Assumption, please confirm.** Sign-up now requires an "I am 18 years old or older" tick. Stated in the in-app privacy notice and on `privacy.html`. |
| Firestore location | `asia-south1` (Mumbai) | **Assumption, please confirm before step A4.** Stated on `privacy.html`; the functions code also uses it. |
| Plan | Spark (free) for now | Final. Functions stay on the local emulators until you approve Blaze. |
| Subscriptions | None, launch free (Q1) | Final default. |
| Messages of deleted users | Stay visible (Q13) | Final default. |
| Direct messages, signed-out content, suspension permissions (Q2, Q3, Q24) | As documented | Unchanged. |

**If you change the age or the region**, edit `firebase/hosting/privacy.html` (and for the age, `minimumAge` in `lib/domain/models/legal.dart`), then run `cd firebase; npm run check:hosting`.

## (a) Spark phase: do these now

### A1. Sign in to Firebase from the command line

```powershell
cd D:\Projects\Deutschhelfer-APP\firebase
npm ci
npx firebase login
```

Expected: a browser opens; afterwards `Success! Logged in as sahibzadaahmadmujtaba@gmail.com` (or the Google account you chose).
Rollback: `npx firebase logout`.

### A2. Create the dev Firebase project

1. Open <https://console.firebase.google.com> → **Add project**.
2. Name it `deutschhelfer-dev`. Firebase may append a suffix to the project ID. Write down the final **project ID**; this guide calls it `<dev-id>`.
3. **Turn Google Analytics off.** The privacy policy says the app uses no analytics.
4. Leave the plan as **Spark**. Do not add billing.

Rollback: Project settings → **Delete project** (recoverable for about 30 days). **The project ID itself is IRREVERSIBLE**: it can never be renamed or reused.

### A3. Register the Android app

1. Project overview → **Add app** → Android.
2. Package name: `com.deutschhelfer.deutschhelfer`. **IRREVERSIBLE in practice** for this app: it becomes permanent on Play after the first upload (Q10).
3. Add both upload-key fingerprints (Project settings → Your apps → Add fingerprint):
   - SHA-1 `7B:CF:F2:BA:65:F7:4E:16:BE:AE:1D:2A:E7:3B:A3:95:F9:E1:3C:47`
   - SHA-256 `32:1C:6C:EA:2D:9B:07:82:2E:34:26:07:78:D6:1B:2E:94:03:DA:78:EA:5C:3F:4B:8D:40:5C:A2:BB:51:17:03`

   These match the signer of `build\app\outputs\bundle\release\app-release.aab` (checked with `keytool -printcert -jarfile`, see [05-test-results.md](05-test-results.md)). To re-check any time:
   ```powershell
   keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
   ```
4. You do not need to download `google-services.json`; the app reads its settings from dart-define files.
5. Copy the template and fill it in from Project settings → Your apps (`apiKey`, `appId`, `messagingSenderId`, project ID):
   ```powershell
   Copy-Item config\example.json config\dev.json
   notepad config\dev.json
   ```
   Keep `"APP_ENV": "development"` and `"FIREBASE_EMULATOR_HOST": ""`. `SUPPORT_EMAIL` is already filled in. `config\dev.json` is git-ignored; confirm with `git status --short` that it does not appear.

Rollback: delete the app in Project settings; delete `config\dev.json`.
Later, after your first Play upload, also add the **Play App Signing** certificate fingerprints (Play Console → Test and release → App integrity), which App Check needs.

### A4. Create Firestore in Mumbai — IRREVERSIBLE

1. Build → **Firestore Database** → **Create database**.
2. Database ID: `(default)`.
3. Location: **`asia-south1` (Mumbai)**. **The location can never be changed.** The only way out is a new project. If you are not sure about Mumbai, stop here and change the decision first (see section 0).
4. Start in **production mode**. The next step replaces the rules.

Rollback: none for the location. You can delete the database's data, or the whole project.

### A5. Enable email/password sign-in

1. Build → **Authentication** → **Get started** → **Sign-in method** → **Email/Password** → enable. Leave "Email link (passwordless)" off.
2. Authentication → **Settings** → **User actions** → turn on **Email enumeration protection**.
3. Authentication → **Settings** → **Password policy** → minimum length 8 and require a numeric character. The app itself enforces "a letter and a number" in `InputValidators.newPassword`.

Rollback: every switch can be turned off again.

### A6. Deploy Firestore rules and indexes only

```powershell
cd D:\Projects\Deutschhelfer-APP\firebase
npx firebase deploy --only firestore --project <dev-id>
```

Expected (wording may vary): `firestore: released rules firestore.rules to cloud.firestore` and `Deploy complete!`. Indexes build in the background; wait until Firestore → Indexes shows **Enabled**.

**Never run a bare `firebase deploy`.** `firebase.json` also lists Cloud Functions, which need Blaze, and the command would try to deploy them.

Rollback: Firestore → Rules → pick an earlier release in the history and publish it, or check out the earlier `firestore.rules` and deploy again. Do not weaken the rules to make a test pass.

### A7. Deploy the Hosting pages

```powershell
cd D:\Projects\Deutschhelfer-APP\firebase
npm run check:hosting
npx firebase deploy --only hosting --project <dev-id>
```

Expected: `Public pages are ready to deploy.` (already verified locally on 2026-10-27), then `Hosting URL: https://<dev-id>.web.app`. Open `/privacy` and `/delete-account` in a browser and read both.

The Play Console and `config\prod.json` need URLs that **stay online for as long as the app is on Play**. Use the final project's address. If production will be a different project, repeat this step there before submitting.

Rollback: Hosting → release history → **Rollback**. The check refuses to deploy while any `{{PLACEHOLDER}}` remains.

### A8. Run the app on a real phone with a real email

```powershell
flutter devices
flutter run -d <device-id> --dart-define-from-file=config\dev.json
```

On the phone:

1. **Student journey.** Create an account with an email you can read. Tick the age and rules boxes. Open the verification email, click the link, return to the app, open a guide article.
2. **Owner journey.** Make your own account the owner (step A9), sign out and in, accept the rules, create a group.
3. **Deletion journey.** In-app deletion **will fail on Spark** with "Could not delete your account…" because it needs a Cloud Function (the Spark audit in [11-known-issues.md](11-known-issues.md) explains this). That failure is the expected result today. Test the working path instead, the script:
   ```powershell
   cd D:\Projects\Deutschhelfer-APP\firebase\functions
   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\deutschhelfer-admin.json"
   node scripts\delete-account.mjs --project <dev-id> --email <test account email>
   ```
   The first run changes nothing and prints the account ID. Run again with `--confirm <account id>` to delete.

Record the results in [06-device-test-results.md](06-device-test-results.md). Never paste passwords or keys into the repository.

### A9. Make yourself the owner

After you have created, verified and signed in to your own account (A8), once:

```powershell
cd D:\Projects\Deutschhelfer-APP\firebase
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\deutschhelfer-admin.json"
node scripts\set-owner.mjs --project <dev-id> --email sahibzadaahmadmujtaba@gmail.com
```

The service-account key comes from Project settings → Service accounts → **Generate new private key**. Keep it outside the repository, never commit or share it, and **delete the key in Google Cloud (IAM → Service accounts → Keys) when you are done**. Alternatively run `gcloud auth application-default login` and omit the variable.
Rollback: the console does not show custom claims. In the dev project, delete the account (Authentication → Users) and create it again. Do not run this against production until you mean it.

## (b) Steps that need Blaze, later

Do not start these until you approve the Blaze plan. Until then the app works as described in [11-known-issues.md](11-known-issues.md), "Spark audit".

### B1. Set a budget alert first

Google Cloud Console → Billing → **Budgets & alerts** → **Create budget**. Choose an amount (for example $5) with alerts at 50%, 90% and 100%. **Alerts do not stop spending.**

### B2. Upgrade to Blaze — hard to reverse

Firebase console → Usage and billing → **Modify plan** → Blaze. You can return to Spark afterwards, but deployed functions stop working then, and billing already incurred stays.

### B3. Deploy the functions

```powershell
cd D:\Projects\Deutschhelfer-APP\firebase\functions
Copy-Item .env.example .env.<dev-id>
notepad .env.<dev-id>
cd ..
npx firebase deploy --only functions --project <dev-id>
```

Keep `ENFORCE_APP_CHECK=true`, `PUSH_ENABLED=true`; leave `PLAY_PACKAGE_NAME` empty and `PRODUCT_TIERS` as `{}` (no subscriptions). Expected: one `Successful create operation` line per function and `Deploy complete!`.
Rollback: `npx firebase functions:delete <name> --project <dev-id>` per function.
Also add the TTL policy on `processedEvents.expireAt` (Firestore → TTL, A12 in [open-questions](../open-questions.md)).

### B4. App Check

Register **Play Integrity** for the Android app (needs the Play App Signing fingerprints from A3), test with the debug token printed by debug builds, and only then enforce App Check for Firestore and functions. Enforcing before testing locks your own app out. Rollback: switch enforcement off in the App Check console.

### B5. Push test

Turn on notifications on a phone, send a direct message from a second account, approve a pending link, sign out and confirm alerts stop (A13).

## (c) Play Console steps

Prerequisites: a Play developer account (one-time fee), the hosted URLs from A7, and a production build. Full list: [09-play-console-checklist.md](09-play-console-checklist.md). Completing it does not guarantee approval.

1. **Production config and build.** Create `config\prod.json` (`APP_ENV` `production`, the real Firebase values, `SUPPORT_EMAIL`, `PRIVACY_POLICY_URL`, `ACCOUNT_DELETION_URL`; the last two must be https). Then rebuild. **The existing bundle predates the age checkbox and cannot be uploaded as is.**
   ```powershell
   flutter build appbundle --release --dart-define-from-file=config\prod.json
   keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
   ```
   The signer must be `CN=Sahibzada Ahmad Mujtaba` with the SHA-1 and SHA-256 from A3. Never use `ALLOW_DEBUG_SIGNED_RELEASE`. Run only one Gradle build at a time.
2. **Create the app.** Name "Deutschhelfer", English, App, Free. **The package name and "Free" are IRREVERSIBLE**: a free app can never become paid.
3. **Target audience:** choose **18 and over** only. Do not select any group under 18.
4. **Content rating:** answer the questionnaire honestly. Disclose user-generated content and messaging between users.
5. **Data safety:** use the draft in [03-privacy-data-inventory.md](03-privacy-data-inventory.md). Say account deletion is available and enter the deletion URL. Review every answer yourself; you are responsible for them.
6. **Privacy policy:** the hosted URL from A7.
7. **App access (reviewer credentials):** create a dedicated reviewer account in the production project: verified, rules accepted, not an owner. Enter its credentials **only** in the Play Console form, never in the repository or an email. Use a throwaway password.
8. **Upload to Internal testing first.** Enrol in Play App Signing, upload the AAB, add yourself and a few testers. Read the pre-launch report. Rollback: halt or remove the release in the track.
9. **Closed testing / production.** If your account is subject to a closed-test requirement, run it. Then a staged production rollout (for example 10%). A published app cannot be deleted, only unpublished; **its package name is IRREVERSIBLE.**
10. **Before production:** deploy the functions (section b). In-app account deletion must work for a production release, and it does not on Spark.
