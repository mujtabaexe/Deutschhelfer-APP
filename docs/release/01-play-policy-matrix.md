# 01 — Google Play policy matrix

Policies read on 2026-10-26:
- [User Generated Content](https://support.google.com/googleplay/android-developer/answer/9876937)
- [Account deletion](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Target API](https://developer.android.com/google/play/requirements/target-sdk)
- [Payments](https://support.google.com/googleplay/android-developer/answer/9858738)
- [Billing Library deprecation](https://developer.android.com/google/play/billing/deprecation-faq)

**Status values:**
- PASS: verified in code or tests.
- FAIL: a requirement is not met.
- BLOCKED: needs the owner or an external service.
- NOT TESTED.
- N/A.

This is an engineering checklist. **It does not guarantee Play approval.**

| # | Requirement | Code-level status | Evidence | Owner-only work |
|---|---|---|---|---|
| P1 | UGC: users accept terms or rules before creating content | **PASS** (fixed this run; FAIL at baseline) | The sign-up checkbox, plus a gate for accounts without acceptance. Rules refuse joins, posts and new DMs without `rulesVersion`. 6 rules tests and 7 widget tests. | Review the rules text in `lib/domain/models/legal.dart` |
| P2 | UGC: define objectionable content | **PASS** | Community rules cover harassment, hate, scams, fraud and fake documents, privacy, sexual or violent content, and impersonation | Same |
| P3 | UGC: in-app reporting of users and content | **PASS** | Report message (group and DM) and report user, with deterministic ids and excerpt checks | — |
| P4 | UGC: in-app blocking of users, including 1:1 | **PASS** (group blocking added this run; FAIL at baseline) | Block from a DM, a group message long-press or the member list. Blocked senders' group messages are hidden. Blocked accounts are listed in Profile with Unblock. | — |
| P5 | UGC: ongoing moderation and action | **PASS** in code | Moderation queue, link pre-approval, suspensions, an audited lift, removal | Staff must actually moderate. Appoint moderators. |
| P6 | In-app account deletion | **PASS** in code and emulator; **BLOCKED** for real (needs Blaze) | [04-account-deletion.md](04-account-deletion.md) | Blaze decision |
| P7 | Web deletion resource | **BLOCKED** | `firebase/hosting/delete-account.html` is ready, with placeholders. The deploy is guarded. | Fill placeholders, deploy Hosting, enter the URL in Data safety |
| P8 | Delete associated data; disclose retention | **PASS** in code; disclosure written | Purge tested in the emulator. Retention is disclosed in the app and on both pages. | Approve retention (Q13) |
| P9 | Privacy policy, in the app and in Play Console | **PASS** in the app (notice screen); **BLOCKED** online | `privacy.html` has placeholders. Production builds refuse to start without `PRIVACY_POLICY_URL`. | Publish; enter the URL |
| P10 | Data safety form accurate | **BLOCKED** | Draft answers in [03-privacy-data-inventory.md](03-privacy-data-inventory.md) | Submit in Play Console |
| P11 | Target API 36 for new apps from 31 August 2026 | **PASS** | `aapt2 dump badging`: `targetSdkVersion:'36'` | — |
| P12 | Billing through Google Play; PBL 8+ | **N/A** until billing is built | [07-billing-readiness.md](07-billing-readiness.md) | Q1 |
| P13 | Permissions declared and justified | **PASS** | INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, POST_NOTIFICATIONS, C2DM RECEIVE, READ_GSERVICES (from Firebase), and a dynamic-receiver permission. No sensitive or restricted permissions. | — |
| P14 | Content rating questionnaire | **BLOCKED** | Users can interact and exchange messages, and UGC is moderated | Answer in Play Console |
| P15 | Target audience and children | **BLOCKED** | Not directed at children. Minimum age 18 (assumption, awaiting the owner); sign-up requires a confirmation. | Decide; complete the questionnaire |
| P16 | App access for reviewers | **BLOCKED** | Login is required, so reviewers need a test account | Create a reviewer account in prod. Give the credentials only through Play Console's App access form. |
| P17 | Deceptive behaviour and impersonation | **PASS** in content | "Not affiliated with the German government, DAAD, any embassy or any university" in Profile → About and on `index.html`. The guide links official sources. | Store listing must not use official logos |
| P18 | Financial and immigration advice accuracy | **BLOCKED** | Guide stays DRAFT; [12-content-review.md](12-content-review.md) | Human review of the high-impact claims |
| P19 | App signing with an upload key | **BLOCKED** | Gradle reads `android/key.properties`. The current build is debug-signed. | Create the key; enrol in Play App Signing |
| P20 | Testing requirement for new personal developer accounts (closed test before production) | **NOT TESTED** | Not verified today. Check Play Console for your account type. | Run the required closed test |
