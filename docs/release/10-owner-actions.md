# 10 — Owner actions, in priority order

Everything here needs your accounts, money, identity or judgement. The development work cannot or must not do it. Nothing below has been done yet.

## 1. Decisions (no cost; unblock the rest)

1. **Q26 Blaze.** Decide whether to upgrade the production project to Blaze. If yes:
   - set the budget alert first;
   - Google Cloud Console → Billing → Budgets & alerts → Create budget;
   - choose an amount, for example $5, with alerts at 50%, 90% and 100%.
   - Alerts do not stop spending.
2. **Q27 Public identity.** Choose the developer name exactly as it will appear on Play, a support email address you will monitor, and a reply time for deletion requests.
3. **Q25 Age.** Choose the minimum age and the Play target audience.
4. **Q1 Billing.** Launch free, or decide tiers and prices. The recommended default is to launch free; see [07-billing-readiness.md](07-billing-readiness.md).
5. **Q13 Message retention** after account deletion: keep (the current behaviour) or remove.
6. **Q18 Region.** Confirm `asia-south1` before creating the database; it cannot be changed later.

## 2. Reviews (no cost)

7. Read the community rules and privacy notice (`lib/domain/models/legal.dart`, `firebase/hosting/privacy.html`). Ideally have a lawyer check them (Q28).
8. Confirm the guide's high-impact claims with official sources ([12-content-review.md](12-content-review.md)), especially APS and the blocked-account amount. Then change `reviewStatus` in `assets/content/guide.json`.
9. Provide a real app icon and logo (Q17).

## 3. Firebase setup (free on Spark; functions need Blaze)

10. Create the `deutschhelfer-dev` and `deutschhelfer-prod` projects in the chosen region (A2). Then:
    - enable Email/Password sign-in;
    - enable email enumeration protection;
    - set a password policy: 8+ characters with a letter and a number.
11. Register the Android app in each project. Fill `config/dev.json` and `config/prod.json` (git-ignored) from `config/example.json`. Add `SUPPORT_EMAIL`, `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL` to prod.
12. Deploy rules and indexes: `cd firebase && npx firebase deploy --only firestore --project <id>`.
13. Fill the hosting placeholders, then run `npm run check:hosting` and `npx firebase deploy --only hosting --project <prod-id>`.
14. After Blaze:
    - copy `firebase/functions/.env.example` to `.env.<project-id>`;
    - `npx firebase deploy --only functions --project <id>`;
    - add the TTL policy on `processedEvents.expireAt` (A12).
15. Create your account in the app, verify it, accept the rules, then run `set-owner.mjs` (A6).
16. App Check: register Play Integrity. Enforce it for Firestore and functions after testing (A7).

## 4. Real-service testing

17. Install a dev build on a real phone. Repeat [06-device-test-results.md](06-device-test-results.md) against the dev project with real email delivery. Also test push (A13) and TalkBack.
18. Test account deletion end to end in dev, in the app and through the script.

## 5. Release

19. Create the upload key and `android/key.properties` ([08-release-build.md](08-release-build.md)). Back both up.
20. Build the production bundle with `config/prod.json`.
21. Play Console: work through [09-play-console-checklist.md](09-play-console-checklist.md). Start with internal testing, then closed testing if your account requires it, then a staged production rollout.
