# Equipex — Frontend Refinement Plan (UI/UX Polish Pass)

**Scope:** Frontend only. No backend, API, or business-logic changes except where a note is purely about *who* can see a button (role gating in the existing UI layer).
**Status:** Plan only — nothing in this document has been applied yet.
**Project root:** `lib/` inside `eq-master`.

---

## 1. What I understood

Your notes are a punch-list from a design review of the Flutter app. Read as a whole, they are not 50 unrelated bugs — they are roughly **8 systemic problems** that each surface in many screens, plus a handful of screen-specific fixes.

The single most important finding from reading the code: **there is no shared input / card / button component.** Each screen builds its own `InputDecoration`, its own card `Container`, and its own button `shape`. That is the direct cause of most of your "make everything the same" notes:

- "remove all strokes of inputs in all screens" — 31 files each declare their own `OutlineInputBorder` / `BorderSide`.
- "all app input fields should be the same as cards colors with opacity 75%" — no single place defines what an input looks like.
- "inconsistent roundness through app buttons" — `borderRadius` is hardcoded per-button (you have 30, 24, 12, etc. scattered around).
- "stats fields should be the same size (for all)" — each stat field is laid out ad hoc.

So the plan is structured in two layers:

1. **Foundation layer (do this first).** Extend `lib/core/design_tokens.dart` with a real design system — a radius scale, card/input/overlay colors at the right opacity, and 3–4 reusable widgets (`AppCard`, `AppInput`, `AppButton`, `AppEmptyState`). This makes ~60% of your notes a "replace the local widget with the shared one" mechanical task, and guarantees consistency going forward.
2. **Screen layer.** Apply the foundation per screen, plus the screen-specific fixes (calendar height, role gating, rebound math, Google logo, etc.).

`design_tokens.dart` today only has 5 colors and a spacing scale — it is the natural home for all of this.

---

## 2. Foundation layer (build first — unblocks everything else)

### 2.1 Extend `lib/core/design_tokens.dart`
Add the missing tokens so screens stop hardcoding values.

- **Radius scale:** `AppRadius.sm = 8`, `md = 12`, `lg = 16`, `pill = 999`. Pick one as the app default (recommend `md = 12` for cards/inputs, `pill` for primary action buttons). This resolves "inconsistent roundness."
- **Surface colors with 0.75 opacity:** a single `AppColors.cardFill` (card background at 75% opacity) and `AppColors.inputFill` that **equals** the card fill (your note: inputs = card color @ 75%). Define both light/dark variants.
- **Outline/stroke color:** `AppColors.outline = AppColors.success` (green) for outlined buttons; `Colors.transparent` for input borders (since strokes are being removed).
- **Overlay color:** a token for the editing-screen overlay so the "floating overlay on cancel button" can be tuned in one place.

### 2.2 Create shared widgets (new files under `lib/core/`)

- **`AppCard`** — `Container` with `color: AppColors.cardFill`, `borderRadius: AppRadius.md`, no gradient, optional padding. Replaces every hand-rolled card. (Covers "Cards 75% opacity background all pages" and "team card gradient removal".)
- **`AppInput`** — wraps `TextField`/`TextFormField` with a shared `InputDecoration`: `filled: true`, `fillColor: AppColors.inputFill`, **`border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: AppRadius.md)`** for enabled/focused/error states (focused can keep a subtle green). This is the one place that kills "all strokes of inputs" and makes "all input fields the same."
- **`AppButton`** — `.primary` (filled green, `AppRadius.pill`), `.outlined` (transparent fill, **green stroke**, `AppRadius.pill`). Replaces ad-hoc `ElevatedButton.styleFrom(... borderRadius ...)`. Covers "outlined button stroke should be green," "add plan button should be rounded," and roundness consistency.
- **`AppEmptyState`** — icon + title + subtitle, e.g. "No videos yet." Reusable for all empty lists. Covers the entire "Empty States" section.
- **`AppOptionsMenu`** — a `⋮` `PopupMenuButton` with Edit / Delete entries, with an `onEdit`/`onDelete` callback. Covers "add ⋮ (options) for editing and deleting in all edit/delete in app."

### 2.3 Refactor pass
Once the widgets exist, sweep the 31 files containing `InputDecoration`/`OutlineInputBorder`/`BorderSide` and the card containers to use the shared widgets. This is mechanical but large — budget real time for it and verify each screen visually.

---

## 3. Screen editings (onboarding & auth)

Files: `lib/onboarding/UniteSquadView.dart`, `TacticalInsightsView.dart`, `PeakConditionView.dart`, `lib/auth/LoginView.dart`, `SignUpView.dart`, `CompleteProfileView.dart`, `lib/auth/auth_widgets.dart`, `lib/core/app_background.dart`.

- **Onboarding container heights** — The onboarding screens use `Spacer()` + an image at `ResponsiveSystem.height(context) * 0.3` (see `UniteSquadView`). On small/large devices the content jumps. Fix: wrap content in a fixed-max-width/centered column with consistent vertical rhythm (e.g. `SafeArea` + `LayoutBuilder` clamping the image to a min/max), so all three onboarding screens share the same container height and the image doesn't drift.
- **Consistent background colors overall** — `app_background.dart` uses different gradients for `authStyle` vs normal and for light/dark. Decide on one background system and apply it everywhere via `AppBackground`. Audit screens that build their own `Scaffold` background instead of using `AppBackground`.
- **Remove all input strokes** — covered by `AppInput` (2.2). Specifically affects the auth text fields.
- **Forgot password (underlined)** — There is currently **no** "Forgot Password" string in the codebase (grep found none). This needs to be **added** to `LoginView.dart` as an underlined `TextButton`/`Text` with `TextDecoration.underline` under the password field. (Frontend stub/navigation only — confirm whether a reset flow exists on the backend.)
- **Google icon correction** — The Google "G" is hand-painted in `auth_widgets.dart` (`_GoogleGPainter`). The painter's arc sectors/leg don't match the official mark. Fix: replace the `CustomPaint` with the official multi-color Google "G" asset (SVG/PNG) in `assets/`, or correct the sector angles. Asset is the safer, pixel-accurate route.
- **Outlined button stroke green** — `GoogleAuthButton` uses `side: BorderSide(color: Color(0xFFDDDDDD))`. More broadly, route all outlined buttons through `AppButton.outlined` with the green outline token.
- **Background image less opacity** — `app_background.dart` has `static const double imageOpacity = 0.15`. Your "background balls take less opacity" note means lower it (e.g. `0.08–0.10`). One-line change in the token.

---

## 4. General app

### Navbar — icons overflow on different devices
File: `lib/navigation/MainNavigation.dart` (`_buildBottomNav`, `_navItem`).
The bottom nav is a fixed `SizedBox(height: 64)` `Row` of 5 `Expanded` items, each with a selected-state circle that grows to 46px and slides up `-0.18`. On short devices the lift + label can overflow the 64px. Fix: make the height responsive (use `ResponsiveSystem`), reduce icon/circle sizes proportionally, and/or clip the slide. Verify on small (e.g. 360×640) and large screens. ("Bottom overflow on different devices" in the notes is the same issue.)

### Cards — 75% opacity background (all pages)
Covered by `AppCard` (2.2). Sweep all card containers.

---

## 5. Events page & calendar
Files: `lib/event/EventView.dart`, `lib/home/HomeView.dart`, `lib/home/DayEventsDetailView.dart`, `lib/addevent/AddEventView.dart`. The calendar is hand-built from `DateTime` math (no `table_calendar` package).

- **Fixed height each month** — Months with 5 vs 6 week-rows change the grid height, so the page jumps when you change month. Fix: render the month grid in a fixed-height container sized for 6 rows always (pad short months with trailing/leading days), so switching months never resizes. **Test month-change explicitly.**
- **Days correction (Sun/Mon)** — Verify the weekday header labels line up with the actual first-day-of-week offset. The note's struck-through "Sun Mon" suggests the header is offset by one. Fix: confirm `DateTime.weekday` (Mon=1..Sun=7) mapping vs. the header order and the leading blank cells.
- **Remove "add event" for all except manager** — Event creation is triggered from the FAB in `MainNavigation` (`addEvent` action) and possibly inline on the events page. Currently the FAB role map (`_buildRoleActions`) does **not** include an Add Event action for any role shown — confirm where "add event" actually appears and gate it to `ClubManager`/`TeamManager` only. Use the existing `permission_service.dart` / role keys.

---

## 6. Coach flow
Files: `lib/settings/SettingsView.dart`, `lib/team/TeamView.dart`, `lib/teamstats/TeamStatsView.dart`, `AddStatsView.dart`, `lib/members/MemberDetailView.dart`.

- **Settings — components margin from top** — Add top padding/`SafeArea` spacing so the first component isn't flush to the app bar.
- **Team (members) — injured players only highlight on click** — Currently tapping an injured player navigates/opens detail. Note wants it to **only highlight** (select state) instead. Fix in `TeamView` member-tile `onTap`: toggle a highlighted/selected visual state rather than navigate (marked "(Try)", so treat as experimental).
- **Remove "Add Stats" button from Coach** — In `TeamStatsView`/`AddStatsView`, gate the add-stats entry point so it is hidden for the `Coach` role. (Matches "remove add stats button from Coach" in two places in your notes.)
- **Inconsistent roundness** — covered by `AppButton`/`AppRadius`.
- **Match team stats — correct [cumulative]** — In the match/team stats view, the cumulative total is being computed/labelled incorrectly. Fix the aggregation so cumulative = sum across the relevant games (see Stats section for the rebound case). File: `lib/match/MatchDetailView.dart` + `lib/teamstats/stats_bloc.dart`.

---

## 7. Stats (correctness + sizing)
Files: `lib/teamstats/TeamStatsView.dart`, `AddStatsView.dart`, `stats_bloc.dart`, `StatsChartSelector.dart`, `lib/members/PlayerProfileView.dart`, `MemberDetailModel.dart`.

- **Fields should be the same size (all)** — Stat input/display fields are laid out per-screen with different widths. Fix: use a uniform grid (`GridView`/`Wrap` with fixed `aspectRatio`) so every stat cell is identical. Combine with the "make stats fields rounded" note → apply `AppRadius` + `AppCard` to each cell.
- **Total rebounds ≠ offensive rebounds** — There is a data/label bug where total rebounds is showing the offensive-rebounds value (or vice versa). Your note "could be off rebounds" suggests the field currently labelled total is actually offensive. Fix: confirm the stat keys in `stats_bloc.dart`/`MemberDetailModel.dart` and ensure `totalRebounds = offensiveRebounds + defensiveRebounds`, and label each field correctly. **Verify with sample numbers.**
- **Stats fields rounded** — apply `AppRadius` to all stat cells (covered by foundation).

---

## 8. Team plans / formation
Files: `lib/plans/PlansView.dart`, `lib/addplans/AddPlansView.dart`, `lib/plans/plans_bloc.dart`.

- **Coach "Add Plan" button rounded** — route through `AppButton` (pill radius).
- **⋮ options for edit/delete** — Add `AppOptionsMenu` to each plan card (and reuse for events and other edit/delete lists app-wide).
- **Formation court background** — The plans list card uses a different court image than the add-plans editor, and it's being compressed. Fix: use the **same** court asset as `AddPlansView`, and in the card use `BoxFit.cover` with clipping (so it's *cut* to a preview, not squished). Don't `BoxFit.fill`/`contain`.

---

## 9. Empty states
Files: all list-bearing screens — `lib/gamehistory/`, `lib/members/UploadVideoView.dart`, `UploadPdfView.dart`, `MedicalRecordView.dart`, team/plans/events lists, messages, search.

- Replace every bare empty list with `AppEmptyState` (2.2): e.g. Game stats page → "No files yet" / "No videos yet," medical records → "No records yet," etc. Note explicitly: "don't leave it empty."

---

## 10. Editing screens & UI fixes
- **Cut screen problem** — content is being clipped on some editing screens. Likely an unscrollable fixed `Column` under the keyboard/app bar. Fix: wrap in `SingleChildScrollView` + `SafeArea`, and use the existing `smooth_keyboard_mixin.dart`.
- **Team card gradient removal** — remove the gradient `Container` decoration on the team card; use flat `AppCard`.
- **Editing back button** — add/standardize the back button on editing screens (consistent leading `IconButton`).
- **Increase editing (pen) button size** — bump the edit-pencil `IconButton` `iconSize`/tap target.
- **Floating overlay on cancel button** — in the editing screen, the cancel button shows a stuck floating overlay (likely an `InkWell`/`Material` ripple or a leftover `Positioned` overlay). Fix: remove the stray overlay layer / set `overlayColor` transparent.

---

## 11. Chat & misc (from extended notes)
Files: `lib/chat/ChatView.dart`, `ChatInputBar.dart`, `lib/messages/`, `lib/profile/ProfileView.dart`, `lib/appbar/CustomAppBar.dart`, `lib/search/SearchView.dart`.

- **Chat: tap name → open user profile** — wire the name tap in the chat header to push `PlayerProfileView`/`ProfileView`.
- **Message input like app input fields** — route `ChatInputBar` through `AppInput`.
- **Add Terms of Privacy** — add a Terms/Privacy entry (Settings + signup), frontend link/stub.
- **Search/notification/editing icons** — the leftover trailing icons in these app bars should be removed or shown as highlighted/active. Fix in `CustomAppBar.dart`.

---

## 12. UI & functionality checks
- **Keyboard background scaling (search & others)** — when the keyboard opens, the background rescales awkwardly. Fix: set `resizeToAvoidBottomInset` appropriately and ensure `AppBackground` doesn't resize with the inset. Use `smooth_keyboard_mixin.dart`.
- **Search focus cannot be removed** — tapping away doesn't unfocus the search field. Fix: wrap with a `GestureDetector` → `FocusScope.unfocus()` (the nav already has `_dismissKeyboard`; replicate on the search page).
- **Assign last test/biometrics date for player; height 195cm → 15th May** — add date fields for testing/biometrics in the player/medical form (frontend field; confirm backend support).
- **Medical record page — high margin from screen** — reduce excessive page padding in `MedicalRecordView.dart`.

---

## 13. Manager flow
Files: `lib/auth/SignUpView.dart`, `lib/addclub/AddClubView.dart`, `lib/addteam/AddTeamView.dart`, `lib/addmembers/AddMembersView.dart`, `lib/addevent/AddEventView.dart`, `lib/event/EventView.dart`, `lib/jointeam/`, `lib/home/HomeView.dart`.

- **Signup phone — country code + flag** — add an international phone field with country-code picker + flag in `SignUpView`/`CompleteProfileView` (a package like `intl_phone_field` is typical; confirm before adding deps).
- **Create club page — content has no margin** — add page padding in `AddClubView`.
- **Remove "Allow" button in add team pages** — remove the stray allow/permission button in `AddTeamView`/`AddMembersView`.
- **Add event — date not assigned inside the time input field** — the date isn't being shown/bound in the time field on `AddEventView`. Fix the field to display the selected date.
- **Training recurring event not on home page** — recurring training events aren't rendered on `HomeView`. Fix the home event list to include recurring instances.
- **Add members — margin from title** — spacing fix in `AddMembersView`.
- **Events page card — remove divider white lines** — remove the divider/stroke between extended event card sections in `EventView`.
- **Floating button overlaying event card** — the FAB (from `MainNavigation`, `bottom: 88`) overlaps the last event card. Fix: add bottom list padding equal to FAB height on the events list.
- **Accepting invitation — card doesn't disappear / multiple accepts** — after accept, the invite card stays, allowing repeat accepts. Fix in `lib/jointeam/incoming_requests_view.dart` / `join_team_bloc.dart`: remove the card from state on success and disable the button while pending.
- **Popups linger ("joined team," "cannot add event")** — too many/long-lived `SnackBar`s. Fix: shorten duration / `clearSnackBars()` before showing, debounce.
- **"No members yet" should be centered (team manager)** — center the empty message (use `AppEmptyState`).
- **Player invitation not completed** — finish the player-invite flow UI.
- **Check title margins app-wide** — standardize screen-title top/left margins (tie to a shared screen header / `AppSpacing`).

---

## 14. Doctor flow
Files: `lib/members/AddMedicalRecordView.dart`, `MedicalRecordView.dart`, `lib/members/fitness_bloc.dart`, `lib/services/fitness_service.dart`.

- **Medical inputs not on app theme** — route the add-medical inputs through `AppInput`.
- **No units in fitness records → add unit selection** — add a unit dropdown/selector next to fitness-record numeric fields (kg/cm/etc.). Frontend field + persist via existing model.

---

## 15. Suggested execution order
1. **Foundation** (§2) — tokens + `AppCard`/`AppInput`/`AppButton`/`AppEmptyState`/`AppOptionsMenu`.
2. **Global sweep** — replace inputs/cards/buttons app-wide; background opacity; navbar overflow.
3. **Auth/onboarding** (§3) — Google icon, forgot password, container heights.
4. **Events/calendar** (§5) — fixed height, day labels, role gating, FAB overlap.
5. **Stats correctness** (§7) — rebounds + cumulative + field sizing.
6. **Coach/Manager/Doctor flows** (§6, §13, §14).
7. **Empty states + editing polish + chat/misc** (§9, §10, §11, §12).
8. **Verification pass** — run the app on a small and a large device profile; screenshot each touched screen; confirm month-change, rebound math, and role-gated buttons.

## 16. Open questions before coding
- Forgot-password and player-invitation: do backend endpoints exist, or are these frontend stubs?
- Phone country-code: OK to add a dependency (`intl_phone_field`), or build custom?
- Light vs dark: which is the canonical theme to standardize backgrounds/cards against?
- "Injured players only highlight": should tapping still open detail via a second action, or purely highlight?
