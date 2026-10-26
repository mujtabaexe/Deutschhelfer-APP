# UI design system

The palette is the owner's proposed direction from the project prompt. It is not taken from the scope document, which has not been provided. All values live in `lib/ui/core/theme/app_tokens.dart`. Widgets read colours only from `Theme.of(context).colorScheme`.

## Colour roles

| Role | Light | Dark | Use |
|---|---|---|---|
| primary | `#173F35` forest | `#A8D5BF` | Primary buttons, links, focus rings |
| onPrimary | `#FFFFFF` | `#0B2A22` | Text on primary |
| primaryContainer | `#DCECE5` | `#24503F` | Icon tiles, nav indicator, info banners |
| secondary | `#D9A441` amber | `#E8C27A` | Accent fills only. See the restriction below. |
| surface (page) | `#F7F8F5` | `#101713` | Scaffold background |
| raised surface | `#FFFFFF` | `#19221D` | Cards and text fields |
| onSurface | `#17211D` | `#E3E9E5` | Body text |
| onSurfaceVariant | `#596760` | `#B5C2BA` | Secondary text, helper text |
| outline | `#74817A` | `#8B988F` | Field borders |
| outlineVariant | `#D5DCD7` | `#3A4640` | Dividers, card borders (decorative) |
| error | `#B3261E` | `#F2B8B5` | Error text and borders |

**Amber restriction.** Amber on white has a contrast ratio of 2.25:1. That fails both the 4.5:1 text minimum and the 3:1 minimum for icons and borders. In light mode, use amber only as a fill behind dark text, where the ratio is 7.3:1, or as decoration. A test enforces this.

## Measured contrast

Checked by `test/ui/core/theme/app_theme_test.dart` with the WCAG 2.x formula.

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Body text on page | 15.5 | 14.8 | 4.5 |
| Secondary text on page | 5.6 | 8.8 on raised surface | 4.5 |
| Label on primary button | 11.7 | 9.5 | 4.5 |
| Error text on raised surface | 6.5 | 9.6 | 4.5 |
| Field border on page | 3.8 | 6.1 | 3.0 |

## Scales

| Token | Values |
|---|---|
| Spacing | 4, 8, 12, 16, 24, 32, 48 |
| Page margin | 16 below 360 dp wide, 24 otherwise |
| Max content width | 560 dp, centered on tablets and in landscape |
| Radius | 8 for chips and snackbars, 12 for buttons and fields, 16 for cards, 28 for dialogs |
| Touch target | 48 dp minimum. Full-width buttons are 52 dp. |

## Typography

System Roboto, Material 3 scale with these overrides.

| Style | Size / line height | Weight | Use |
|---|---|---|---|
| headlineLarge | 32 / 40 | 600 | Welcome headline |
| headlineMedium | 28 / 36 | 600 | Page titles |
| titleLarge | 22 / 28 | 600 | App bar, empty and error titles |
| titleMedium | 17 / 24 | 600 | List and card titles |
| bodyLarge | 17 / 26 | 400 | Article text |
| bodyMedium | 16 / 24 | 400 | Default body |
| bodySmall | 14 / 20 | 400 | Helper and error text |
| labelLarge | 16 / 20 | 600 | Buttons |

## Elevation and surfaces

Flat by default. Cards use elevation 0 with a 1 px `outlineVariant` border. The app bar gains elevation 1 only when content scrolls under it. Dialogs use `surfaceContainerHigh`. Material 3 surface tint is disabled, so colours stay exactly as specified.

## Components

| Component | File | Rules |
|---|---|---|
| `AppButton` | `widgets/app_button.dart` | Variants: primary, secondary, text. Loading shows a spinner, keeps the label and blocks taps. |
| `AppTextField`, `AppPasswordField` | `widgets/app_text_field.dart` | Persistent label, autofill hints, length enforced, validation after first interaction. The password toggle has a tooltip label. |
| `PageBody` | `widgets/page_layout.dart` | Safe area, scrolls under the keyboard, responsive margins, max width. |
| `PageActions` | same | Pins primary actions above the system navigation bar. |
| `PageHeader` | same | Title marked as a heading for TalkBack, plus optional subtitle. |
| `LoadingView`, `EmptyView`, `ErrorView` | `widgets/state_views.dart` | Icon plus text, never colour alone. The error view offers a retry. |
| `InlineMessage` | same | Form-level error or info. It is a live region, so TalkBack announces it. |
| `OfflineBanner` | same | Ready, but needs a connectivity source in Phase 2. |
| `BrandMark` | `widgets/brand_mark.dart` | Placeholder monogram until a real logo exists. |

## Screen rules

1. Every screen handles loading, empty, error and, where data is remote, offline states.
2. Primary actions stay visible without scrolling on a 390 × 844 phone.
3. Every screen must work on 320 × 568 at 200% text, in light and dark themes. Tests enforce this for the welcome, sign-in and create-account screens.
4. Every visible string comes from `lib/l10n/app_en.arb`.
5. Icons that carry meaning have a label. Decorative icons are excluded from semantics.
6. Errors name the problem and the fix in plain language. They never show raw exception text.

## Screen inventory

| # | Screen | Status |
|---|---|---|
| 1 | Splash and initialization | **Built.** Brand mark and spinner while the session loads. A startup error screen offers a retry. |
| 2 | Welcome | **Built** |
| 3 | Sign up | **Built** |
| 4 | Sign in | **Built** |
| 5 | Forgot password | **Built** |
| 6 | Email verification | **Built.** Resend cooldown, check button, re-check on return to the app. |
| 7 | Home | **Built** as four tabs: Guide, Groups, Messages and Profile |
| 8–9 | Guide library, search, article | **Built** |
| 10 | IELTS and premium lock | **Built.** Premium articles lock without the server claim. No purchase screen (Q1). |
| 11 | Groups list | **Built.** The owner also sees a New group button. |
| 12 | Group details and membership | **Built.** Join, leave, member list, message a member, report. Owner can appoint moderators. |
| 13 | Group chat | **Built.** Bubbles, pending badge, link notice, long-press actions. |
| 14 | Message inbox | **Built** |
| 15 | Private conversation | **Built.** Block and unblock, report. Links are not clickable. |
| 16 | Notifications | **Groundwork built.** A switch on the Profile tab, a permission request only when the user turns it on, and notification taps that open the chat. Not delivered yet: needs a real project. |
| 17 | Profile and settings | **Built.** Rename, private email, message notifications, blocked accounts, community rules, privacy notice, about, sign out, delete account. |
| 18 | Subscription plans and status | Not started (Q1) |
| 19 | Report flow | **Built** as a bottom sheet |
| 20 | Student-admin moderation | **Built.** Tabs for pending links, reports and suspended accounts. Approve, remove, dismiss, suspend, and lift a suspension after confirming. The tabs are fixed on normal phones and scroll on screens under 360 dp or with large text. |
| 21 | Owner administration | **Built.** New group screen with name, category and description. Moderator appointment is in the member list. |
| 22 | Community rules and privacy notice | **Built** (2026-10-26). Readable before sign-up, from the sign-up checkbox, the rules gate and Profile. Contact details come from build config. |
| 23 | Rules gate | **Built.** Shown before groups and messages to accounts that have not accepted the current rules. "Not now" keeps the guide and Profile. |
| 24 | Blocked accounts | **Built.** Profile → Blocked accounts, with unblock. Blocking is also on group message long-press and the member list. |
| — | Account restricted | **Built** |

## Interaction safety rules

1. Destructive actions confirm first. Account deletion requires typing DELETE.
2. Links in group messages open only after a dialog that shows the destination host. Links in private messages never open.
3. User content is always plain text. Nothing is rendered as HTML or markdown.
4. Moderation screens show reported text as selectable plain text, never as links.