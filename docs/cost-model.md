# Cost model

## Verified free quotas

Checked against https://firebase.google.com/pricing on 2026-10-23. The quotas are per project and apply on Spark and Blaze.

| Service | No-cost quota |
|---|---|
| Firestore reads | 50,000 per day |
| Firestore writes | 20,000 per day |
| Firestore deletes | 20,000 per day |
| Firestore storage | 1 GiB |
| Firestore egress | 10 GiB per month |
| Auth (Identity Platform tier) | 50,000 monthly active users. Phone SMS is always billed. |
| Cloud Functions | **Not available on Spark.** On Blaze: 2M invocations, 400K GB-s and 200K CPU-s per month. |
| FCM | No cost |
| App Check | No cost, within attestation-provider quotas |

**Not verified:** per-unit prices beyond the free quota. The pricing page could not be read in full. Check the rate for the chosen Firestore location before setting a budget.

**Blueprint error:** section 8.1 says "1M reads ~$600". At $0.06 per 100K reads, 1M reads cost about **$0.60**.

## What runs where

| Plan | What works |
|---|---|
| Spark (free, no card) | The whole app except functions. Rules, the auth flows, groups, chat, DMs, reports and moderation approvals all work. Member counts stay at 0, there is no audit log, roles must be set with the bootstrap script, account deletion fails, and subscriptions are unavailable. |
| Blaze | Everything. Cost stays $0 inside the quotas above. Budget alerts notify you but **do not stop spending**. |

## Design controls in the code

| Control | Where |
|---|---|
| Free guidance bundled in the app: 0 reads | `assets/content/guide.json` |
| Group list read once, not live | `listGroups` |
| One live page of 30 per open chat, detached on leave | `ChatViewModel`, `watchRecent` |
| Older history on demand only | `loadOlder` |
| Inbox capped at 30 summaries; names cached per session | `watchInbox`, `displayName` |
| No presence, typing or read receipts | — |
| One post per second per user, enforced by rules | `rateLimits` |
| One report per user per target | Deterministic report ids |
| Long text fields excluded from indexing | `firestore.indexes.json` |
| Function concurrency capped at 10 | `setGlobalOptions` |
| Push reads at most 10 devices per recipient and sends one multicast. Only DMs and moderation decisions notify, never group chatter. | `notify()` |
| Roles and premium in token claims, not extra reads | Rules helpers |

## Hidden read costs to know

Rules lookups are billed as reads:

- **A group message** costs about 5 reads: restriction, membership, profile name, group and rate limit.
- **A direct message** costs about 7 reads. With push on, the trigger adds about 4 reads (conversation, sender name, block, restriction) plus up to 10 device reads, and one function invocation.

Writes are much rarer than reads, so this is acceptable, but it is the price of server-side checks.

## Illustrative scenarios

These are formulas with assumed inputs, not measurements.

**Pilot: 300 daily users, 10 groups.**

- About 1,000 group messages a day, each seen live by about 15 open chats, gives 15,000 reads.
- Each message costs about 5 reads in rule lookups, adding about 5,000.
- 300 users opening 3 chats of 30 messages each gives 27,000 reads.
- Lists and inbox add about 5,000.
- **Total:** about 52,000 reads a day, slightly over the 50K free quota. On Blaze that costs cents a day. On Spark the app stops serving reads for the rest of the day.

**Target scale: 20,000 concurrent users.**

- Assume 1 message per second across all groups, each seen by 300 open chats.
- That gives about 26M reads a day.
- At $0.06 per 100K, that is about **$15 a day, roughly $470 a month**, from fan-out alone.
- This needs load testing on a separate staging project before any commitment.

## Gates before paid usage

1. Separate dev and prod projects.
2. Before Blaze, set a Google Cloud budget with alerts at 50%, 90% and 100% of an amount you choose.
3. Watch reads per daily user and reads per message weekly.
4. Run load tests only on a staging project with its own budget.
