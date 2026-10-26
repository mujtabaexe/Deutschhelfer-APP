# Free-first architecture

Checked 2026-10-26 against:
- [Firebase pricing](https://firebase.google.com/pricing)
- [Firebase Auth limits](https://firebase.google.com/docs/auth/limits)
- [Firestore billing](https://firebase.google.com/docs/firestore/pricing)

Per-unit Google Cloud prices could not be read in full, so the dollar amounts in [free-tier-cost-estimate.md](free-tier-cost-estimate.md) are marked as assumptions.

## Recommendation

**Launch on the Blaze plan, with a budget alert, and keep usage inside the no-cost quotas.** The expected bill is $0 for a small pilot, but no setting guarantees it stays at $0.

Spark alone cannot run this app in a way that is both secure and compliant. Blaze is a billing plan, not a paid tier. Each quota below is free on Blaze exactly as on Spark, and you pay only for usage above it.

- **Cloud Functions are not available on Spark.** They are this app's trusted backend: roles, the audit log, lifting suspensions, account deletion, member counts, push sending and purchase verification.
- **Moving those powers into the app to avoid fees would be insecure.** The app is untrusted, and anyone can call the database directly. This was ruled out.
- **Google Play requires in-app account deletion.** On Spark, `deleteMyAccount` cannot run.

**Owner approval is needed before upgrading.** Blaze needs a payment card. Budget alerts only notify; they do not stop spending. Nothing has been upgraded or created.

## What works on each plan

| Capability | Spark (no card) | Blaze, inside quotas | Note |
|---|---|---|---|
| Sign-up, sign-in, reset, verify email | Yes | Yes | Spark email caps: 1,000 verification and 150 password-reset emails a day. Spark Identity Platform projects: 3,000 daily active users. |
| Guide (bundled) | Yes | Yes | 0 reads |
| Groups, chat, DMs, reports, link moderation, suspending | Yes | Yes | Enforced by Firestore Rules |
| Community rules acceptance, blocking | Yes | Yes | Rules only |
| Owner role | Bootstrap script only | Yes | `set-owner.mjs` runs on your computer with the Admin SDK |
| Appointing student-admins | No | Yes | `setUserRole` function |
| Lifting suspensions | No | Yes | `liftSuspension` function. The audit trail requires it. |
| Audit log | No | Yes | Triggers |
| Member counts | Stay at 0, so the 2,000 cap is never reached | Yes | Triggers |
| In-app account deletion | **No.** The button fails. | Yes | `deleteMyAccount` |
| Deletion requested from the web page | Yes | Yes | `functions/scripts/delete-account.mjs`, run by the owner from a computer. Added in this run. |
| 90-day purge | Manual, with the same script and `--purge-now` | Daily schedule | Cloud Scheduler has a free allowance of 3 jobs per billing account. This app uses 2. This figure was not re-checked today. |
| Push notifications | No | Yes | FCM itself is free, but the triggers that send are functions |
| Subscriptions | No | Yes | Purchase verification must be server-side |
| Public privacy and deletion pages | Yes | Yes | Firebase Hosting: 10 GB storage, 360 MB/day transfer |

## Cost controls already in the design

These are listed in [cost-model.md](../cost-model.md) and verified in code:

- **Bundled guide:** 0 reads.
- **Live chat page:** 30 messages, detached when you leave the chat.
- **Inbox:** 30 summaries.
- **Group list:** read once, not live.
- **Posting rate:** one post per second, enforced by rules.
- **Reports:** one per target.
- **Functions:** `maxInstances: 10`.
- **Push:**
  - only for DMs and moderation decisions;
  - at most 10 devices read per send.
- **Not built:** presence, typing indicators and read receipts.
- **Notifications:** off until the user turns them on.

## Additional controls the owner must set up

These are console settings, not code:

1. **Budget alert.** Before Blaze, set a Google Cloud budget on the billing account, for example $5 a month, with alerts at 50%, 90% and 100%. It warns but does not cap.
2. **Hard stop, optional.** The Cloud Billing documentation describes a pattern (not re-checked today) in which a Pub/Sub budget notification triggers a function that disables billing. This takes the whole app offline and is not set up here. Decide whether an outage is better than a bill.
3. **Firestore TTL policy** on `processedEvents.expireAt`, to keep storage small.
4. **App Check enforcement** for Firestore and functions after testing. This stops scripted clients from running up reads.
5. **Separate projects.** Use separate dev and prod projects, and run load tests only in a staging project with its own small budget.
6. **Weekly checks.** Watch reads per daily user and function invocations in the Usage tab.

## Alternatives considered

| Option | Verdict |
|---|---|
| Spark only, with deletion handled through the web page and the owner script | Possible for a closed pilot. In-app deletion, push, staff appointments, lifting suspensions and the audit log would be missing or manual. **Not Play-ready**, because the in-app deletion path would fail. |
| Move privileged logic into the app | **Rejected.** It would let any user grant roles, erase other people's data or fake purchases. |
| Another backend (Supabase or a self-hosted server) | A rewrite of a working, tested backend. The free tiers have similar caps or pause idle projects. Not justified. |
| A paid push provider | Not needed. FCM is free. |
| Analytics or crash reporting | Not added. Each would need a privacy-policy and Data safety update (Q14). |

## Region (Q18)

`asia-south1` (Mumbai) is the provisional choice, nearest to Pakistan. Two caveats:
- The free Cloud Storage quota applies only in US regions, but this app uses no Cloud Storage.
- Firestore's per-unit price varies by location; re-check it when you choose.

The Firestore location cannot be changed after the database is created.
