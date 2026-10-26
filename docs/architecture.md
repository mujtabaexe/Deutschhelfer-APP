# Architecture

## Decisions

| Decision | Choice | Why |
|---|---|---|
| App pattern | MVVM: views, `ChangeNotifier` view models, repository interfaces | Flutter's recommended architecture. Every repository has a fake for tests. |
| Dependency injection | Constructor injection from `AppServices` through the router | No extra package needed |
| Routing | `go_router` with a `StatefulShellRoute` of four tabs and a pure `redirectFor` function | Redirects are unit-tested. Tabs keep their own stacks. |
| Session | `SessionController` combines the auth session, the account restriction and the profile | One place decides splash, verify, restricted or active |
| Backend | Firebase Auth, Firestore, Cloud Functions (2nd gen), App Check | Per blueprint. Functions need Blaze. |
| Roles and premium | Auth custom claims set only by functions or the bootstrap script | Rules check claims without a billed read |
| Free content | Bundled JSON asset | No reads, works offline, nothing to scrape (Q3) |
| Premium content | `premiumContent/{id}` behind the `premium` claim | Bodies never ship in the APK |
| Environments | `--dart-define-from-file`, a `demo-` project for emulators | Real config never committed; production refuses emulators |
| Functions region | `asia-south1` (provisional) | Nearest to Pakistan. Must match the Firestore location (Q18). |

## Layers

```text
View -> ViewModel (ChangeNotifier) -> Repository interface -> Firebase SDK
                                   -> domain validation (shared limits)
Cloud Functions (Admin SDK) <- callables and triggers -> Firestore
```

## Data model

| Path | Fields | Writers |
|---|---|---|
| `users/{uid}` | `displayName`, `createdAt`, `updatedAt`, optional `rulesVersion` and `rulesAcceptedAt` | Self, with a validated name and server timestamps. One rename an hour. Only the current rules version can be accepted, at server time. Readable one document at a time, never listed. |
| `users/{uid}/blocked/{otherUid}` | `createdAt` | Self |
| `users/{uid}/devices/{fcmToken}` | `token`, `platform`, `updatedAt` | Self only, and only while verified and unrestricted. The id must equal `token`. Functions keep one owner per token (newest wins), trim to the 10 newest, and delete tokens FCM rejects. |
| `accountRestrictions/{uid}` | `status` (`suspended` or `deleted`), `reason`, `updatedBy`, `updatedAt` | Staff suspend. Functions lift suspensions and mark deletions. |
| `rateLimits/{uid}` | `lastPostAt`, `lastMessageId` | Self, in the same batch as exactly one message. At most one per second. |
| `staff/{uid}` | `role` | Functions and the bootstrap script only. Lets rules protect staff from suspension by student-admins. Student-admin powers also require this marker, so a demotion takes effect at once rather than when the old ID token expires. |
| `processedEvents/{eventId}` | `expireAt` | Functions only. Makes member-count triggers idempotent. Needs a TTL policy. |
| `groups/{groupId}` | `name`, `description`, `category`, `createdBy`, `createdAt`, `isActive`, `memberCount` | Owner, from the in-app New group screen. The id `new` is reserved for that route. `memberCount` is maintained by functions only. |
| `groups/{g}/members/{uid}` | `uid`, `role`, `displayName`, `joinedAt` | Self joins as member. Owner sets roles. Moderators remove members. |
| `groups/{g}/messages/{id}` | `senderId`, `senderName`, `text`, `createdAt`, `status`, `moderatedBy`, `moderatedAt` | Members create. Moderators approve or remove. Senders withdraw. |
| `conversations/{a_b}` | `participants`, `groupId`, `createdAt`, `updatedAt`, `lastMessage` | Participants who share the group and have not blocked each other |
| `conversations/{a_b}/directMessages/{id}` | `senderId`, `text`, `createdAt` | Participants |
| `reports/{reporter_type_target}` | target, reason, details, exact `excerpt`, status, resolution | Verified users create once. Staff resolve. |
| `premiumContent/{id}` | `blocks`, `sources` | Console or owner tooling only |
| `subscriptions/{uid}` | tier, status, Play state, product, expiry | Functions only |
| `purchaseTokens/{sha256}` | `uid`, token, product | Functions only. One token unlocks one account. |
| `deletionQueue/{uid}` | `requestedAt`, `purgeAfter` | Functions only |
| `auditLogs/{id}` | `actorId`, `action`, target, details, `createdAt` | Functions only |

Message status values are `visible`, `pending`, `removed` and `withdrawn`.

Direct messages use the subcollection name `directMessages`, unlike group `messages`. The owner's cross-group moderation query therefore can never reach private messages.

## Messaging data flow

1. Opening a chat attaches one listener for the newest 30 visible messages. A second, usually empty, listener covers the user's own pending messages.
2. Scrolling up loads older pages with one-off queries.
3. Leaving the chat detaches both listeners.
4. Sending writes the message and the rate-limit document in one batch. The message appears at once as "Sending…" and the composer never waits on the network.
5. The client and the rules use the same link pattern. A link forces `pending`, so others never see it before approval.
6. The inbox listens to at most 30 conversation summaries. Names come from one cached profile read per contact.

## Trusted backend (Cloud Functions)

| Function | Kind | Purpose |
|---|---|---|
| `onMemberCreated`, `onMemberDeleted` | Trigger | Keep `memberCount` in step |
| `onGroupMessageModerated`, `onRestrictionWritten`, `onReportResolved` | Trigger | Audit log. Moderation decisions also notify the sender. |
| `onProfileUpdated` | Trigger | Sync display names into memberships |
| `setUserRole` | Callable, owner | Grant or remove student-admin. Never owner. |
| `liftSuspension` | Callable, staff | Lift and audit. Student-admins can lift only students' suspensions, matching who they may suspend. |
| `onDirectMessageCreated` | Trigger | Notify the recipient: sender name only, never the text. Skipped if the recipient blocked the sender or is restricted. |
| `onDeviceRegistered` | Trigger | Remove the same token from any other account (newest registration wins) and trim the user's devices to 10 |
| `deleteMyAccount` | Callable, self | Anonymize, leave groups, disable login, queue purge |
| `purgeDeletedAccounts` | Daily | Delete data after 90 days. One failing account does not block the rest. Redacts free text in audit entries about the account. |
| `scripts/delete-account.mjs` | Owner-run Admin SDK script | Web deletion requests. Dry run first, then `--confirm <uid>`. Works on Spark. Shares `src/account.js` with the two functions above. |
| `verifyPurchase` | Callable, self | Verify with Google Play, bind token to account, set the claim |
| `onPlayNotification`, `reconcileSubscriptions` | Pub/Sub and daily | Keep entitlements current |

Every callable checks App Check (switchable only in the emulator), sign-in, email verification and role, then validates input. Errors never include tokens or message text. `maxInstances: 10` caps concurrency and cost.

## Push notifications

1. On the Profile tab, the user turns on **Message notifications**. The app asks for the Android 13+ permission and stores the device's FCM token at `users/{uid}/devices/{token}`. Nothing is asked at first launch.
2. A new direct message or a moderation decision on the user's own message triggers a function. It reads at most 10 device documents and sends one multicast.
3. Payloads carry the sender's display name and a fixed sentence, never message text, because lock screens are visible to other people.
4. Tapping a notification opens the conversation or group chat. `routeForPush` checks the ids first, and the usual route guards still apply. A tap that launches the app waits until the session is known, opens the chat only if someone is signed in, and is never replayed for a later sign-in.
5. Any end of a session invalidates this device's token, whether through the app's sign-out, the verify screen, a revoked or disabled account, or a failed refresh. The app's own sign-out also deletes the device document, without waiting on the network, so it never hangs offline. When the next account on a shared phone registers, the server removes the token from the previous account. Account deletion and the purge remove all device documents, page by page.
6. Tokens FCM reports as unregistered or invalid are deleted after each send. Other errors, such as an outage, keep the token.

firebase_messaging 17 deprecates FCM tokens in favour of Firebase Installation IDs (`register()` and `onRegistered`). The app still uses tokens, because the new flow has not been checked on a device. The Admin SDK supports both. See open question Q22.
