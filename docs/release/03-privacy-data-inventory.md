# 03 — Privacy data inventory

Built from the code on 2026-10-26, not from intentions. **Every row needs owner review before the Play Data safety form is filled in.** This is engineering input, not legal advice.

## Data the app collects

| Data | Where stored | Why | Who can read it | Collected when | Retention |
|---|---|---|---|---|---|
| Email address | Firebase Auth only, never in Firestore | Account, sign-in, verification and reset emails | The user (Profile); the owner via the Firebase console | Sign-up | Until the purge, 90 days after deletion |
| Password | Firebase Auth, hashed by Google | Sign-in | Nobody, not even the owner | Sign-up | Same |
| Display name | `users/{uid}`, copied into memberships and group messages | Shown to other members | Signed-in users, one profile at a time | Sign-up; Profile | Replaced at deletion; profile erased at purge |
| Community rules acceptance (version, time) | `users/{uid}` | Play UGC policy | The user; the owner | Sign-up or the rules gate | Removed at deletion |
| Group messages | `groups/{g}/messages` | Core feature | Group members (visible messages); moderators of that group (pending ones) | When posting | Kept (Q13); name anonymized at deletion |
| Direct messages | `conversations/{a_b}/directMessages` | Core feature | The two participants only. Staff and the owner are denied by rules. | When sending | Kept for the other participant (Q13) |
| DM inbox summary | `conversations/{a_b}.lastMessage` (up to 120 characters) | Inbox preview | The two participants | When sending | Kept |
| Group memberships and roles | `groups/{g}/members/{uid}` | Access control | Members of that group | Joining | Deleted at deletion |
| Block list | `users/{uid}/blocked` | Safety | The user | Blocking | Deleted at deletion |
| Reports filed | `reports/{id}` (reason, details, excerpt of the reported message) | Moderation | Staff | Reporting | Erased at purge; reports about a user are kept |
| Account restriction | `accountRestrictions/{uid}` (status, reason, who and when) | Moderation | The user; staff | Suspension or deletion | Erased at purge |
| FCM push token, platform | `users/{uid}/devices/{token}` | Notifications the user turned on | The user; functions | Turning notifications on | Removed at sign-out, deletion and purge; stale tokens pruned |
| Purchase records (tier, state, expiry, token hash) | `subscriptions/{uid}`, `purchaseTokens/{sha256}` | Unlock premium; prevent token sharing | The user (own subscription); functions | Purchase (not built yet) | Erased at purge |
| Audit log | `auditLogs` (actor uid, action, target uid, reason) | Accountability for staff actions | The owner | Staff actions, deletion | Kept; uid only after the purge |
| Rate-limit record | `rateLimits/{uid}` (last post time and id) | Anti-spam | The user | Posting | Deleted at deletion |

## Data collected by SDKs and Google services

| SDK or service | Data | Purpose | Notes |
|---|---|---|---|
| Firebase Auth | Email, password hash, IP address, sign-in times | Authentication | Google is the processor |
| Cloud Firestore and Functions | Request metadata, including IP addresses | Serving data | Function logs contain no message text, emails or tokens; checked in `index.js` |
| Firebase App Check (Play Integrity in production) | Device integrity verdict, app identity | Abuse prevention | Debug builds use the debug provider |
| Firebase Cloud Messaging | Firebase installation identifiers, push tokens | Notifications | Only after the user opts in on the Profile tab |
| Google Play Billing | Purchase data | Subscriptions | Not built (Q1) |

**Not present** (checked in `pubspec.yaml`): analytics, Crashlytics, advertising SDKs, location, contacts, camera, files or photos.

## Permissions

These come from the merged release manifest. See [08-release-build.md](08-release-build.md) for the exact list read from the built APK.

## Data safety form: draft answers

For the owner to confirm in Play Console.

| Question | Draft answer | Basis |
|---|---|---|
| Collects or shares user data? | Collects. **Shares: no.** Google acts as a service provider, which Play does not count as sharing. | Inventory above |
| Personal info | Email address (account management, required); name (display name: app functionality, required); user IDs (account management) | Auth, profile |
| Messages | Other in-app messages: group and direct messages (app functionality) | Firestore |
| App info and performance | Not collected; no crash logs or analytics | `pubspec.yaml` |
| Device or other IDs | Yes: push tokens and installation IDs if notifications are on (app functionality); App Check device integrity | FCM, App Check |
| Financial info | Purchase history, **only once subscriptions exist** | Q1 |
| Encrypted in transit | Yes. Firebase SDKs use HTTPS, and release builds block cleartext. | Manifest and network config |
| Users can request deletion | Yes: in the app, and through the web URL | [04-account-deletion.md](04-account-deletion.md) |
| Data deleted or retained | Partially retained: message text kept in shared conversations; audit uid kept | Same |

## Gaps the owner must close

1. Fill in and publish the privacy policy (`firebase/hosting/privacy.html`). Use the same URL in Play Console and in `PRIVACY_POLICY_URL`.
2. Decide the minimum age (`{{MINIMUM_AGE}}`) and the target audience. If under-18s are in scope, Play's Families or teen policies may apply; check before submitting.
3. Confirm with a legal adviser whether Pakistani law (for example the Prevention of Electronic Crimes Act) or the GDPR applies to you, and what it requires. **This has not been assessed.**
