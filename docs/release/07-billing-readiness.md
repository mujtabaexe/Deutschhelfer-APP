# 07 — Billing readiness

**Status:** **BLOCKED** by owner decision Q1. Nothing in the app can take payment today, and no price has been invented.

## What exists (inspected 2026-10-26)

| Piece | State | Evidence |
|---|---|---|
| Premium content storage | **Built.** Bodies live in `premiumContent/{id}`, never in the APK. | `firestore.rules`: read only with `isPremium()`, which needs a verified email and the `premium` claim. Rules tests cover free, unverified and string-claim reads being denied. |
| Entitlement source | **Built.** The `premium` custom claim is set only by functions after Play verification. | `applyEntitlement` in `functions/index.js`. Clients cannot write `subscriptions/*`, and rules tests deny it. |
| Server verification | **Built, not run against Play.** `verifyPurchase` callable: Play Developer API `subscriptionsv2`, account binding, one token per account, acknowledgement. | `functions/index.js`, `src/play.js`. Unit tests cover entitlement mapping and binding. The integration test shows the function refuses until it is configured. |
| Lifecycle | **Built, not run.** RTDN Pub/Sub handler `onPlayNotification` and the daily `reconcileSubscriptions`. | Same |
| Client purchase flow | **Not built.** No Play Billing Library, no purchase screen, no restore button. | `pubspec.yaml` has no `in_app_purchase` |
| UI gating | Premium articles show a lock for free users. | Widget tests in `session_flow_test.dart` |
| Ad-free tier | Backend tier mapping only. **No ad SDK** exists, so "ad-free" currently means nothing. | `PRODUCT_TIERS` |

**Trust model:** premium is enforced by Firestore Rules on the server, not by hiding UI. A modified app cannot read `premiumContent` without the claim.

## Requirements that will apply

Read 2026-10-26:
- [Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- [Billing Library deprecation FAQ](https://developer.android.com/google/play/billing/deprecation-faq)

| Requirement | Applies | Plan |
|---|---|---|
| Digital content and subscriptions must use Google Play Billing, unless an alternative-billing programme applies | Yes, for premium articles | `in_app_purchase` with its Android implementation, which bundles the Play Billing Library |
| New apps and updates must use **Play Billing Library 8 or later** from 31 August 2026 (extension to 1 November 2026) | Yes, as soon as billing is added | Choose an `in_app_purchase_android` version that bundles PBL 8+. Check the merged manifest for `com.google.android.play.billingclient.version`. |
| Clear, accurate terms and pricing; in-app prices must match Play's billing screen | Yes | Show prices from `ProductDetails`, never hard-coded |
| No steering users to outside payment | Yes | Do not mention other ways to pay |
| Alternative billing in Pakistan | **Not determined.** The policy page does not list eligible countries. | Owner question; default to Play Billing |

## Decisions the owner must make

**Q1.** Quoted from `docs/open-questions.md`: "**Subscription tiers.** The prompt lists Free, Ad-free at PKR 100 and Premium at PKR 1,000. The blueprint has Premium only and never mentions ads. Ads would need an ad SDK, consent and a privacy-policy change."

Still open:
1. Tiers: Premium only, or Premium plus Ad-free. Ad-free needs ads first, which brings an ad SDK, a consent flow, Data safety changes and a privacy-policy change.
2. Prices per tier and period (monthly or yearly). These are set in Play Console, not in code.
3. Free trial or introductory offer, if any.
4. What Premium unlocks. Today that is the two premium IELTS articles, which have no content yet.
5. Whether to start billing at launch, or launch free and add billing later.

**Recommended default:** launch without billing, as a free app with premium articles hidden or shown as "coming soon". This avoids the Billing Library requirement, the Payments-profile setup and Data safety financial disclosures until the content exists.

## When Q1 is answered: implementation steps

1. Owner: create the Play Console app and the subscription products. Grant the functions' service account Play Developer API access. Create the `play-rtdn` Pub/Sub topic and link it in Play Console. Set `PLAY_PACKAGE_NAME` and `PRODUCT_TIERS`.
2. Code:
   - Add `in_app_purchase` behind a `BillingRepository` interface with a fake for tests.
   - Build the purchase screen with prices from Play.
   - Call `verifyPurchase` with the purchase token.
   - Refresh the ID token for the new claim.
   - Add a restore-purchases button.
   - Link to Play's subscription centre for cancellation.
3. Test with Play license testers on internal testing. The `testPurchase` flag is already stored.
4. Update the Data safety form (financial info: purchase history) and the privacy policy.

Nothing in this list has been done, because each step depends on Q1 or on Play Console access.
