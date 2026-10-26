# Open questions and owner actions

## Decisions needed

The first three block their phases. The rest have a provisional default that the code already follows. Changing a default may need code and rules changes.

| # | Question | Provisional default in the code | Blocks |
|---|---|---|---|
| Q1 | **Subscription tiers.** The prompt lists Free, Ad-free at PKR 100 and Premium at PKR 1,000. The blueprint has Premium only and never mentions ads. Ads would need an ad SDK, consent and a privacy-policy change. | The backend supports `premium` and `adFree` tiers through the `PRODUCT_TIERS` setting. There is no ad SDK and no purchase screen. | Phase 6 |
| Q2 | **Who may start direct messages?** The blueprint allows anyone to message anyone. | Only members of a shared group. Blocking supported. Links in DMs are not clickable. | Changing it |
| Q3 | **Content for signed-out users.** | Free guidance is bundled in the app. Signed-out users see only the welcome screen. | Changing it |
| Q4 | **Scope document** `Deutschhelfer_Scope_Document.docx` was not found. | Work from the blueprint and prompt | Final sign-off |
| Q5 | Can unverified users browse groups? | Rules allow reading group names. The app holds unverified users on the verify screen. | — |
| Q6 | Password policy | At least 8 characters with a letter and a digit. **Also set this as a Firebase Auth password policy** so the server enforces it. | — |
| Q7 | Display names | 2 to 40 characters, no links, no `<` or `>`. Not unique. | — |
| Q8 | What does "AI-assisted link moderation" mean? | Pattern detection plus manual review. No AI service, so no cost and no third-party data sharing. | — |
| Q9 | Who creates groups? | Owner only, from the in-app New group screen | — |
| Q10 | **Android application ID** `com.deutschhelfer.deutschhelfer` is permanent after the first Play upload. | Unchanged | Release |
| Q11 | Languages | English only. Urdu can be added with ARB files. | — |
| Q12 | Member lists | Visible to members of that group only | — |
| Q13 | Message retention | Indefinite. Deleted users' names are anonymized. | — |
| Q14 | Analytics, Crashlytics, Performance Monitoring | Not added | Phase 7 |
| Q15 | Final-year project or production launch? | Built to production standard | Planning |
| Q16 | **Repository.** This folder is untracked inside a repository with a GitHub remote. | Nothing committed | Commits |
| Q17 | Logo and app icon | Monogram placeholder and the default icon | Release |
| Q18 | **Firestore location and functions region** | `asia-south1` (Mumbai) for functions. Choose the same for Firestore when creating the project; it cannot be changed later. | Project creation |
| Q19 | **Guide content accuracy.** The bundled articles were checked against official sources on 2026-10-26 and corrected (APS, blocked account, tuition, uni-assist, IELTS). High-impact claims still need a human to confirm them. | Marked DRAFT; see [release/12-content-review.md](release/12-content-review.md) | Release |
| Q20 | Suspension power | Resolved in code: student-admins suspend students only. The owner suspends anyone except the owner. Everything is audited. | — |
| Q21 | Link detection now flags any dotted word, such as "file.pdf" or "Mr.Khan", including in display names | Accept, with false positives going to moderation | — |
| Q22 | **Push identifiers.** firebase_messaging 17 deprecates FCM tokens in favour of Firebase Installation IDs. | Keep tokens until the installation-ID flow is checked on a real device, then switch both the client and `notify()` to `fids` | Before release |
| Q23 | Which events notify? | New direct messages, and moderation decisions on your own message. Never group chatter, to keep alerts useful. Off until the user turns it on. | — |
| Q24 | May a student-admin lift a suspension the owner placed on a student? | Yes, matching who they may suspend. Only the owner lifts staff suspensions. | — |
| Q25 | **Minimum age and target audience** for Play and the privacy policy (`{{MINIMUM_AGE}}`) | Not decided. The app is not directed at children. | Play submission |
| Q26 | **Blaze upgrade.** Functions (in-app deletion, roles, audit, push, billing) need it. | Not upgraded. Recommendation: Blaze with a budget alert; see [release/free-first-architecture.md](release/free-first-architecture.md). | Real-service testing |
| Q27 | **Public identity:** developer name as on the Play listing, support email, deletion response time (placeholders in `firebase/hosting/*.html` and `SUPPORT_EMAIL`) | Not decided | Play submission |
| Q28 | **Community rules and privacy text.** Drafted in `lib/domain/models/legal.dart` and `firebase/hosting/privacy.html` from the app's actual behaviour. Not legal advice. | Draft in use | Release |

## Owner actions

| # | Action | Needed for |
|---|---|---|
| A1 | Run `flutter doctor --android-licenses`. | Release builds |
| A2 | Create `deutschhelfer-dev` and `deutschhelfer-prod` Firebase projects in the region chosen for Q18. Enable Email/Password sign-in, email enumeration protection and a password policy. | Running against real services |
| A3 | Register the Android app in each project, then copy the values into `config/dev.json` and `config/prod.json`, which are git-ignored. | Same |
| A4 | Deploy rules and indexes: `cd firebase && npx firebase deploy --only firestore --project <id>`. This works on the free plan. | Same |
| A5 | Decide on Blaze (Q-cost). Set a budget alert first. Then deploy functions: `npx firebase deploy --only functions --project <id>`. | Moderation audit, roles, deletion, subscriptions |
| A6 | Create your account in the app, verify it, then run `node scripts/set-owner.mjs --project <id> --email <you>` with admin credentials that are never committed. | Owner role |
| A7 | Turn on App Check with Play Integrity. Register the debug token printed by debug builds. Enforce it for Firestore only after testing. | Abuse protection |
| A8 | Answer Q1 to Q3, Q18 and Q19. Share the scope document if it exists. | Phases 3, 6 and release |
| A9 | For Phase 6: create a Play Console account (one-time fee), subscription products, and a service account with Play Developer API access. Set `PLAY_PACKAGE_NAME` and `PRODUCT_TIERS` for the functions. | Subscriptions |
| A10 | Connect an Android phone or create an emulator for on-device checks. | Visual and accessibility QA |
| A11 | Create a release upload key stored outside the repository, and configure release signing. The build currently signs releases with the debug key. | Play release |
| A12 | In the Firestore console, add a TTL policy on `processedEvents.expireAt`. | Storage hygiene |
| A13 | After A2 and A5, test push on a real phone: turn on notifications, send a DM from a second account, approve a pending link, sign out and confirm alerts stop. | Push release |
| A14 | Run the on-device check that was deferred: sign up, verify, guide, groups, chat, pending link, moderation, TalkBack. | Visual and accessibility QA |
| A15 | Fill in the hosting placeholders, then `cd firebase && npm run check:hosting` and `npx firebase deploy --only hosting --project <prod-id>`. Hosting is free on Spark. | Play: privacy policy and deletion URL |
| A16 | Handle web deletion requests with `firebase/functions/scripts/delete-account.mjs`, after a one-time-code email check | Play: account deletion |
| A17 | Work through [release/10-owner-actions.md](release/10-owner-actions.md) and [release/09-play-console-checklist.md](release/09-play-console-checklist.md) | Submission |
