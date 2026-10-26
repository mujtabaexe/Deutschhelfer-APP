# Free-tier cost estimate

These are estimates from stated assumptions, **not measurements**. No load test has been run. Re-check them against the Usage tab after the first weeks of real use.

## Verified free quotas (2026-10-26)

Sources:
- [firebase.google.com/pricing](https://firebase.google.com/pricing)
- [Auth limits](https://firebase.google.com/docs/auth/limits)

| Service | Free on Spark and Blaze | Above the quota (Blaze only) |
|---|---|---|
| Firestore reads | 50,000 per day | Google Cloud price by location |
| Firestore writes | 20,000 per day | Same |
| Firestore deletes | 20,000 per day | Same |
| Firestore storage | 1 GiB | Same |
| Firestore egress | 10 GiB per month | Same |
| Cloud Functions | Not available on Spark. On Blaze: 2M invocations, 400K GB-s, 200K CPU-s and 5 GB egress per month, plus 120 Cloud Build minutes a day and 500 MB of Artifact Registry | $0.40 per million invocations; the rest at Google Cloud prices |
| FCM | No cost | — |
| App Check | No cost, within attestation-provider quotas | — |
| Hosting | 10 GB storage, 360 MB/day transfer | $0.026/GB storage, $0.15/GB transfer |
| Auth emails | Spark: 1,000 verification and 150 password-reset emails a day. Blaze: 100,000 and 10,000. | — |
| Auth daily active users | Spark, for "Firebase Authentication with Identity Platform": 3,000 a day ("Tier 1") | Blaze: Google Cloud pricing above 50K MAU |

**Unit prices (assumption, not verified today).** The Google Cloud Firestore pricing page could not be read. These estimates use the upper bounds of $0.06 per 100K reads, $0.18 per 100K writes and $0.18 per GiB-month. Confirm them for your Firestore location before setting a budget.

## Billing facts that shape the estimate

From the Firestore billing documentation:

- **Listeners:** one read for every document added to or updated in the result set.
- **Reconnects:** after more than 30 minutes disconnected, reconnecting costs as much as a brand-new query.
- **Rules lookups:** these are billed. Each referenced document is billed once per request, even if the rules read it more than once. The community-rules check therefore adds no read to group posts, which already read the profile.

## Assumptions

Each row is a separate scenario at peak.

| Assumption | Value |
|---|---|
| Daily active users (DAU) | 5 × peak concurrent users |
| Average concurrency over the day | 40% of peak |
| Share of concurrent users with a chat open | 50% |
| Groups | 10, 30 or 100 |
| Per DAU per day | 3 chats opened (30 messages each), group list (one read per group), inbox (30 summaries plus 5 names), 4 session reads |
| Messages per DAU per day | 5 group messages, 2 direct messages |
| Rules reads per message | Group: 5. DM: 7. |
| Writes per message | Group: 2 (message and rate limit). DM: 3 (message, summary and rate limit). |
| Push | 25% of recipients turned it on; about 6 reads per notification |
| Function invocations | 1 per DM, plus moderation and join triggers |
| Stored message size | About 1 KB, including indexes |

## Results

| Peak concurrent users | 100 | 1,000 | 20,000 |
|---|---|---|---|
| Daily active users | 500 | 5,000 | 100,000 |
| Reads: opening screens | 71,000 | 710,000 | 14,200,000 |
| Reads: rules checks on sends | 19,500 | 195,000 | 3,900,000 |
| Reads: live fan-out | 5,500 | 171,700 | 20,100,000 |
| Reads: push | 1,500 | 15,000 | 300,000 |
| **Reads per day** | **~97,500** | **~1.09M** | **~38.5M** |
| Writes per day | ~8,000 | ~80,500 | ~1.61M |
| Function invocations per month | ~33,000 | ~330,000 | ~6.6M |
| New message storage per month | ~0.1 GB | ~1 GB | ~21 GB |
| **Plan needed** | Blaze. Reads exceed the 50K free reads on most days. | Blaze | Blaze, after a load test |
| **Estimated Firestore bill** | ~$0.03/day, **~$1/month** | ~$0.73/day, **~$22/month** | ~$26/day, **~$780/month** |
| Functions above the free quota | $0 | $0 | ~$2 for invocations, plus compute, likely under $10 |
| Storage | $0 | $0 in the first months | Grows about 21 GB a month: roughly $45/month after a year at the assumed rate |
| Auth | Free | Free on Blaze | 100K DAU suggests over 50K MAU. If the project uses Identity Platform, MAU above 50K is billed. **Not costed: verify.** |

## What this means

- **100 concurrent users is about 500 daily users.** On Spark, the app would hit the 50,000 free reads by mid-afternoon most days. Firestore then refuses reads until the daily reset, which is an outage. On Blaze, the same usage costs about $1 a month.
- **"Free" holds only up to roughly 250 daily active users** under these assumptions. Usage patterns move this number a lot.
- **20,000 concurrent users cannot be served for free.** Live fan-out dominates: 40 open chats per group seeing every message. Costs that would matter at that scale:
  - smaller live pages;
  - archiving old messages;
  - capping active groups;
  - a load test on a staging project before committing.
- **Spark's Auth caps** (3,000 daily active users with Identity Platform, 150 reset emails a day) also rule Spark out above the pilot stage.

## Cost-control checklist

1. Budget alert before Blaze. Alerts do not stop spending; see [free-first-architecture.md](free-first-architecture.md).
2. Enforce App Check on Firestore and functions after testing.
3. Add a TTL policy on `processedEvents`.
4. Watch reads per DAU weekly. Over about 200, look for a screen re-reading data.
5. Consider a message retention period (Q13) if storage grows.
