# 09 — Play Console submission checklist

For the owner. Code-level status is in [01-play-policy-matrix.md](01-play-policy-matrix.md). Nothing here has been done in Play Console; this run had no access and published nothing. **Completing this list does not guarantee approval.**

## Before you open Play Console

- [ ] Decide on Blaze and create the production Firebase project (A2, A5). Set a budget alert first.
- [ ] Fill the placeholders in `firebase/hosting/*.html`, then `cd firebase && npm run check:hosting`.
- [ ] Deploy Hosting: `npx firebase deploy --only hosting --project <prod-id>`. Note the privacy and deletion URLs.
- [ ] Create the upload key and `android/key.properties` ([08-release-build.md](08-release-build.md)).
- [ ] Create `config/prod.json` with `APP_ENV=production`, the Firebase values, `SUPPORT_EMAIL`, `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL`.
- [ ] Build: `flutter build appbundle --release --dart-define-from-file=config/prod.json`.
- [ ] Have the guide's high-impact claims reviewed ([12-content-review.md](12-content-review.md)), then remove DRAFT.

## App setup in Play Console

- [ ] **App details:** create the app named "Deutschhelfer", default language English, App (not game), Free.
- [ ] **Store listing:**
  - short and full description;
  - 512 px icon and 1024×500 feature graphic (Q17: the icon is still the default);
  - at least 2 phone screenshots;
  - contact email;
  - no official German government, DAAD or embassy logos.
- [ ] **Privacy policy:** the hosted URL.
- [ ] **App access:** "All or some functionality is restricted". Create a dedicated reviewer account in the prod project. It must be verified and have accepted the rules, so the reviewer can reach groups. Enter its credentials only in this form, never in the repository or by email.
- [ ] **Ads:** "No, my app does not contain ads".
- [ ] **Content rating:** complete the questionnaire. Disclose user interaction, user-generated content and messaging.
- [ ] **Target audience and content:** choose age groups from your minimum-age decision. If you include under-18s, read the policy for that audience first.
- [ ] **Data safety:** use the draft answers in [03-privacy-data-inventory.md](03-privacy-data-inventory.md). Answer "Yes" to deletion and give the deletion URL.
- [ ] **Government apps:** No. **Financial features:** none. **Health:** none.
- [ ] **News app:** No.

## Release

- [ ] Enrol in **Play App Signing**. Upload the AAB signed with your upload key.
- [ ] **Internal testing** track first, with your own testers.
- [ ] **Closed testing:** if your developer account needs a closed test with a minimum number of testers and days before production, run it. Check the requirement shown in your Play Console; it was not verified today.
- [ ] Read the **pre-launch report** and fix crashes and accessibility warnings.
- [ ] **Production** with a **staged rollout** (for example 10%), watching Firebase usage and the budget.

## After launch

- [ ] Weekly: Firebase usage (reads per DAU), reports queue, Play vitals.
- [ ] Before each update: target API, Billing Library version (if billing exists), policy changes.
