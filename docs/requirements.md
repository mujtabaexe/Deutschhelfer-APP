# Requirements

Sources:

- **BP** is the Implementation Blueprint PDF in the project root.
- **PR** is the owner's project prompt of 2026-10-23.
- **SD** is `Deutschhelfer_Scope_Document.docx`, which has **not been provided**.

Status values:

- *Confirmed* means BP and PR agree.
- *Provisional* means it rests on one source or an engineering default.
- *Conflict* means the sources disagree; see [open-questions.md](open-questions.md).

Implementation states:

- **Built and tested** means code exists and automated tests pass against fakes or the emulator.
- **Boundary only** means a server-side or interface boundary exists, but there is no complete feature.
- **Not started** means no code exists yet.

None of these states means production-verified. Nothing has been deployed.

## Functional requirements

| ID | Requirement | Status | Implementation |
|---|---|---|---|
| FR-001 | Register, sign in, reset password, sign out, persistent session, neutral duplicate-email message | Confirmed | **Built and tested.** Not yet run against real Firebase Auth. |
| FR-002 | Profile at `users/{uid}`. Clients change only the display name. | Confirmed | **Built and tested.** Rules tests deny role and status fields. |
| FR-003 | Email verification. Unverified users cannot post. Throttled resend. | Confirmed | **Built and tested.** 60 s resend cooldown on the client. Firebase throttles on the server. Rules require `email_verified` for writes. |
| FR-004 | Groups up to 2,000 members. Join and leave. Owner creates groups and appoints moderators. | Confirmed (Q9 provisional) | **Built and tested.** In-app New group screen for the owner. Rules tests cover field validation and non-owner denial. |
| FR-005 | Group chat, real time, paginated | Confirmed | **Built and tested.** 30-message live page, older pages on scroll. |
| FR-006 | Direct messages, participants only | Conflict Q2, provisional default applied | **Built and tested.** Only between members of a shared group. Blocking supported. |
| FR-007 | Links held for moderation until approved | Confirmed for groups | **Built and tested.** Enforced by rules. Moderation queue screen. |
| FR-008 | Report messages and users. Staff act on reports. | Confirmed | **Built and tested.** Excerpts are checked against the stored message. One report per target. |
| FR-009 | Free guidance content | Confirmed (Q3 provisional) | **Built and tested.** Bundled draft content, search and categories. **Content needs owner review.** |
| FR-010 | Premium content via Google Play, verified server-side | Conflict Q1 | **Boundary only.** Premium bodies are server-side behind a claim. `verifyPurchase` exists. No purchase screen. |
| FR-011 | Push notifications (FCM) | Confirmed | **Groundwork built and tested.** Device registration, rules, send and prune logic, triggers for DMs and moderation decisions, and notification taps. **No push has been delivered**: FCM has no emulator, so this needs a real project and Blaze. |
| FR-012 | Roles: student, student-admin, owner. Server-assigned only. | Confirmed | **Built and tested.** Custom claims, the `setUserRole` callable, and an owner bootstrap script. |
| FR-013 | Suspension and deletion | Provisional | **Built and tested.** Staff suspend and lift from the moderation screen. Lifting goes through an audited function, and student-admins cannot lift staff suspensions. Self-service deletion with a 90-day purge. |
| FR-014 | Append-only audit log | Confirmed | **Built and tested.** Written by functions only. Clients cannot write it. |
| FR-015 | Validate all input, client and server | Confirmed | **Built and tested.** Shared limits. Rules re-validate. |
| FR-016 | Block another user | Provisional | **Built and tested** from DMs, group messages and the member list. Blocked senders' group messages are hidden; Profile lists blocked accounts. |
| FR-017 | Account deletion with purge | Provisional | **Built and tested** in the emulator, including the purge logic and an owner script for web requests. The schedule itself needs Blaze. |
| FR-018 | Community rules accepted before posting (Play UGC policy) | Added 2026-10-26 | **Built and tested.** Sign-up checkbox, a gate for accounts without acceptance, enforced by rules on joins, posts and DMs. |
| FR-019 | Privacy notice in the app; hosted privacy and deletion pages | Added 2026-10-26 | **Built.** In-app screens. Pages in `firebase/hosting` with placeholders, not deployed. |

## Non-functional requirements

| ID | Requirement | Target | Evidence |
|---|---|---|---|
| NFR-01 | Scale | 20,000 concurrent users is a long-term target | **Not assessed.** No load tests. Emulator results are not evidence of scale. |
| NFR-02 | Message latency | p95 under 2 s on staging | **Not assessed.** |
| NFR-03 | Cost | Near-free while small, alerts before paid usage | Design controls in place. See [cost-model.md](cost-model.md). |
| NFR-04 | Accessibility | WCAG AA contrast, 48 dp targets, TalkBack labels, 200% text | Contrast and tap-target tests pass for the theme and the welcome and auth screens. Not yet audited on a device with TalkBack. |
| NFR-05 | Privacy | Email and display name only | Emails are not stored in Firestore profiles. Deletion anonymizes. |
| NFR-06 | Security | App Check, least privilege, no client-trusted roles | 78 rules tests and 16 function integration tests pass. Findings from two independent reviews are fixed. App Check is wired but untested with a real attestation. |
| NFR-07 | Testability | Allowed and denied tests | See the Test table in the README. |
| NFR-08 | Platform | Android first, Material 3 | Debug APK builds. **Not run on a device or emulator.** The owner deferred that check. |

## Acceptance evidence by phase

| Phase | Result |
|---|---|
| 1. Foundation and design system | Passed: analysis, theme contrast tests, layout at 320 dp with 200% text, guideline tests |
| 2. Authentication | Passed against fakes. Rules for profiles and verification pass in the emulator. **Not run** against real Firebase Auth or email delivery. |
| 3. Guidance | Passed. Content is a **draft** that needs review against official sources. |
| 4. Groups and messaging | Passed against fakes and rules emulator. **Not run** end to end on a device. Push groundwork is tested with fakes, unit tests and emulator triggers, but no notification has been delivered. |
| 5. Moderation and administration | Passed against fakes, rules emulator and functions emulator. Includes owner group creation and lifting suspensions. |
| 6. Subscriptions | Boundary only. Blocked by Q1 and Play Console setup. |
| 7. Hardening | Partial: independent security review done and fixed. No load tests, no device accessibility audit, no release signing. |
