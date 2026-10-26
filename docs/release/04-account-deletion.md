# 04 — Account deletion

Policy: [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111), read 2026-10-26.

Play requires three things:
- an in-app path to delete the account and its data;
- a web resource where people can ask for deletion without the app;
- deletion of the associated data, with any retention disclosed.

## The three paths

| Path | How | Where | Plan |
|---|---|---|---|
| In the app | Profile → Delete account. The user types DELETE and the password; the app re-authenticates; the `deleteMyAccount` callable runs. | `lib/ui/features/profile/profile_screen.dart`, `firebase/functions/index.js` | Blaze (functions) |
| Web request | The public page `delete-account.html` gives an email address. The owner confirms the request came from the account's address, then runs `node scripts/delete-account.mjs --project <id> --email <address>`. | `firebase/hosting/delete-account.html`, `firebase/functions/scripts/delete-account.mjs` | Any plan. The script runs on the owner's computer. |
| Purge after 90 days | Daily scheduled function `purgeDeletedAccounts`. On Spark, run the script with `--purge-now` instead. | `firebase/functions/src/account.js` | Blaze for the schedule |

All three share `firebase/functions/src/account.js`, so they delete the same data.

## What happens to each piece of data

| Data | At the request | After 90 days |
|---|---|---|
| Firebase Auth user (email, password hash) | Disabled; refresh tokens revoked | **Deleted** |
| `users/{uid}` profile (name, rules acceptance) | Replaced with "Deleted user"; the acceptance record is removed | **Deleted** |
| Group memberships | **Deleted** | — |
| Name on past group messages | Replaced with "Deleted user" | — |
| Text of past group messages and DMs | **Kept** for the other members (Q13) | Kept |
| DM inbox summary (`lastMessage`, up to 120 characters) | Kept | Kept |
| Block list | **Deleted** | — |
| Push devices | **Deleted** (paged) | Any new ones deleted |
| Rate-limit record | **Deleted** | — |
| Reports this user filed | Kept | **Deleted** |
| Reports about this user | Kept for safety | Kept |
| Subscription and purchase-token records | Kept, so billing disputes can be checked | **Deleted** |
| Restriction marker `deleted` | Written (blocks re-use) | **Deleted** |
| Staff marker | Kept | **Deleted** |
| Audit log entries | Kept with the bare uid | Kept, uid only |

The in-app privacy notice, `privacy.html` and `delete-account.html` all describe this table. The same facts appear in three places, so keep them in step.

## Verification

All runs used the Firebase emulators on 2026-10-26.

| Check | Result |
|---|---|
| `deleteMyAccount` anonymizes, removes memberships, disables the login, queues the purge, removes devices | PASS (integration test) |
| Unverified accounts can delete themselves | PASS (integration test, new) |
| Signed-out callers are refused | PASS (integration test, new) |
| Purge: not due → nothing; due → auth user, profile, restriction, queue, filed reports and purchase tokens erased; group message keeps "Deleted user"; `account.purged` audited; second run harmless | PASS (integration test, new; the purge had never been run before) |
| Owner script: deletes by email, `--purge-now` erases, audited as `owner-deletion-script` | PASS (integration test, new) |
| Owner script: an unknown email changes nothing and is not echoed; no target → exit code 2 | PASS (integration test, new) |
| In-app deletion end to end on an Android emulator | See [06-device-test-results.md](06-device-test-results.md) |
| Against a real project | **NOT TESTED.** No project exists. |
| Web page live | **BLOCKED.** The owner must fill the placeholders and deploy Hosting. `npm run check:hosting` refuses while placeholders remain. |

## Open points for the owner

1. **Message text after deletion (Q13).** It is kept now. If deleted users' messages should disappear, change `deleteAccountNow` to set `status: 'removed'` and blank the text, then update the three notices.
2. **Retention window.** 90 days before the purge is a design choice. Play asks for completion "within a reasonably quick period" and for the retention to be disclosed, which the notices do.
3. **Identity check for web requests.** The page asks people to write from the account's address. The owner must check the sender, and must never delete on a request from another address without further proof.
4. **Subscriptions.** Deletion does not cancel Google Play billing. The page says so. Once billing exists, consider showing this in the app too.
