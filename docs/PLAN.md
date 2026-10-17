# ADHD Tax — Product & Build Plan

## Context

The user has ADHD and struggles to **start** tasks when priorities compete or the task is unpleasant; once started, they finish. Existing tools (Todoist, Monday.com, Motion, Tiimo, Structured) are built around *organizing* tasks. This app is built around **initiation**: it removes the "what should I do?" decision, makes the first step tiny, and rewards *starting* as much as finishing.

Decisions already made with the user:
- **Personal-first** (user + a few friends/coworkers), architected so it can become a product later. No backend server.
- **Flutter** — one codebase for Android, Windows/macOS, and Web (web build matters: clinic PCs are often locked down and can't install software).
- **Google Drive** = storage/sync between devices. **Google Calendar** = planning surface.
- **Two Google accounts**: personal Gmail + a separate work Google Workspace. Personal and Work are separate workspaces, each syncing to its own account.
- **Optional AI** (Claude, user's own API key) for task breakdown and natural-language capture. Core app works fully without it.


---

## Product principles (these drive every design decision)

1. **One task, not a list.** "Pick for me" returns a single task with a giant Start button. Lists exist, but the dashboard defaults to one answer.
2. **Reward starting, not just finishing.** XP is granted the moment you press Start. That's the user's actual bottleneck.
3. **Shrink the first step.** Every task can carry a "first 2-minute step" ("open the portal and log in"), shown on the Start screen instead of the whole task.
4. **Capture in under 5 seconds.** Title only is required; everything else has smart defaults.
5. **No shame mechanics.** No red overdue walls, no streaks that reset to zero. Streaks have grace days; overdue tasks are quietly "resurfaced," not flagged.
6. **Fight time blindness.** Visual countdown timers, "you have 47 min until your 2:00 meeting," learned estimate correction.

---

## Core features (user-requested)

### Task model
| Field | Notes |
|---|---|
| title (required), notes | |
| estimateMin | Chips: 5 / 15 / 30 / 60 / 2h / custom. Default 15. |
| requiresLeavingHouse | Toggle. Optional location label ("Pharmacy", "Clinic") for errand batching. |
| priority | P1 Critical / P2 High / P3 Normal / P4 Someday. Default P3. |
| dueAt, hardDeadline | Soft vs hard deadlines weigh differently. |
| ugh (dread) 0–3 | "How much do you not want to do this?" Drives picker + bonus XP. |
| energy low/med/high | What it takes to do it. |
| firstStep | The 2-minute starter action. |
| workspace, project, tags, parentId (subtasks), recurrence (RRULE) | |
| status | inbox / todo / doing / waiting / done / archived |
| scheduledStart, calendarEventId | Set when planned onto Calendar. |
| actualMin, skipCount, lastSkippedAt, createdAt, updatedAt, completedAt | Feed the picker and insights. |

### "Pick for me" dashboard (the heart of the app)
Inputs (all one-tap): **time available** (auto-filled from Calendar free time, editable), **willing to leave the house?**, **energy right now** (optional), workspace (Personal / Work / Both).

Engine (`lib/features/picker/picker_engine.dart`, pure Dart, fully unit-tested):
1. **Filter**: estimate ≤ available time (or task is "chunkable" → offer a 25-min chunk), leave-house constraint, status todo/inbox, not waiting, not scheduled for later today, workspace match.
2. **Score** (weights tunable in settings):
   - priority weight
   - urgency: nonlinear ramp as due date approaches; hard deadlines ramp steeper
   - staleness: tasks that have sat for days gain weight (prevents avoided tasks from rotting forever)
   - fit: how well the estimate uses the time window (a 25-min task in a 30-min window beats a 5-min one)
   - energy match
   - ugh handling: high-ugh tasks get a boost in the morning / high-energy windows ("eat the frog"), dampened when energy is low
   - skip penalty that decays over ~24h (skipped tasks come back, not buried)
3. **Return one task** + a one-line reason ("Due tomorrow and fits your 40 minutes").
4. **Actions**: **Start** (big) · **Not this one** (reroll; after 2 rerolls the app gently says "pick one of these 3 and commit") · **Make it smaller** (edit first step / split / AI breakdown) · **Snooze**.
5. **Panic / Overwhelm button**: hides everything, shows one tiny task with a 5-minute timer.

### Focus session (Start screen)
- Shows only the first step, a **visual shrinking-disc timer** (Time Timer style), and a rotating quote.
- **"Just 5 minutes" mode**: commit to 5 min; at 5 min the app asks "keep going?" (most people do — that's the point).
- Android ongoing notification with timer; desktop always-on-top mini timer option.
- On finish: log actualMin (feeds estimate calibration), celebrate.

### Motivational quotes
- Bundled set of ~150 curated quotes in `assets/quotes/quotes.json`, categorized: *starting*, *self-compassion*, *momentum*, *humor*, *dread-busting*. User can add/edit/hide.
- Rotate on the dashboard (every ~20s, crossfade) and on the Start screen.
- **Context-aware**: high-ugh task → dread-busting ("You don't have to want to. You just have to start for 2 minutes."); after a skip → self-compassion; mid-session → momentum.
- Avoid toxic positivity; tone set leans practical and funny.

### Achievements, XP & celebrations
- **XP formula**: `base(estimate) × priorityMult × (1 + 0.5 × ugh)` on completion, plus a **Start bonus** awarded on pressing Start. Bonuses: first task of the day, beat your estimate, cleared a stale task (>7 days), errand run completed.
- **Levels**: smooth curve (`xpForLevel(n) = 100 × n^1.5`), with named ranks (theme-flavored: "Cadet → Operator → Commander…" for tech themes).
- **Streaks with grace**: 2 grace days per week; "comeback" bonus instead of a reset message.
- **Achievements** (~40 at launch), e.g. *Frog Eater* (10 high-ugh tasks), *Errand Runner* (3 out-of-house tasks in one trip), *Time Lord* (estimates within 10% x10), *Comeback Kid*, *Inbox Zero*, *Night Owl / Early Bird*.
- **Celebrations**: confetti/particle burst, sound, haptics (Android), full-screen level-up animation (Rive/Lottie). Intensity setting: Off / Subtle / Normal / Party — sensory overload is real for some ADHD users.
- **Reward shop**: earn coins alongside XP; spend on rewards *you* define ("coffee out", "30 min gaming"). Converts points into real dopamine.

### Google Workspace integration
**Auth**: Google sign-in per workspace (personal account → Personal workspace, work Workspace account → Work workspace). Android via `google_sign_in`; desktop via loopback OAuth (`googleapis_auth`); web via Google Identity Services.

**Drive sync** (`lib/sync/`): offline-first. Local SQLite (Drift) is the source of truth; Drive is the sync medium.
- Store in the Drive **appDataFolder** (hidden, app-only) per account.
- Each device writes its **own** state file (`state.<workspace>.<deviceId>.json`), so devices never write the same file and there are no write conflicts. (Built this way instead of the per-device change logs first planned: same guarantee, no compaction step needed.)
- Every field carries a **Hybrid Logical Clock** timestamp; merge is per-field last-writer-wins, so every device converges. Deletes are tombstones that blank the record's fields.
- XP is stored as immutable events and stats are a fold over them, so points earned on two devices add up.
- Sync on app open, a few seconds after an edit, every 3 minutes in the foreground, and on resume. Uploads happen only when there are local writes.
- Optional "Export backup to visible Drive folder" (JSON/CSV) for peace of mind.

**Calendar**:
- Read free/busy across selected calendars → auto-fills "time available" ("You have 47 min until Staff Huddle").
- **Plan My Day**: proposes a timeline of tasks in free slots (respecting energy curve, hard deadlines, errands batched together, buffers between blocks). User drags/approves, then the app creates events in a dedicated **"ADHD Tax" secondary calendar** (keeps the main calendar clean and togglable).
- Two-way: moving/deleting the event in Google Calendar updates the task's schedule.
- **Transition alerts**: "Leave in 15 min" for out-of-house tasks; 5-min heads-up before a planned block.

### Monday.com-style workspace views
- Views per workspace/project: **Focus (default)**, **List**, **Board** (Kanban by status), **Table** (sortable/filterable grid, inline editing), **Timeline** (day/week, synced with Calendar), **Calendar** month view.
- Projects, tags, saved filters, subtasks, recurring tasks, bulk edit.
- **Command palette** (Ctrl/Cmd+K), keyboard shortcuts, density toggle (comfortable/compact).

### Themes (enterprise-grade UI)
Token-based theme engine (`lib/core/theme/`): colors, typography, radii, elevation, motion, celebration style per theme. Light/dark variants where sensible.
- **Professional**: Slate (light), Graphite (dark), Clinic Calm (soft blue/teal)
- **Futuristic / tech**: Neon Grid (cyberpunk magenta/cyan), Holo Glass (glassmorphism, frosted panels), Terminal (green-on-black mono), Mission Control (HUD-style dark with amber accents)
- **Accessibility**: Low-Stim (muted, minimal motion — for overstimulated days), High Contrast
- Theme can switch automatically by workspace (e.g. Work = Graphite, Personal = Neon Grid) — a subtle context cue that helps task-switching.

---

## Added features (recommended)

Ranked by impact on *starting tasks*:
1. **Estimate calibration** — tracks estimated vs actual time and learns your personal multiplier ("you underestimate admin tasks by 1.6×"); picker and planner use corrected times. Directly fights time blindness.
2. **Quick capture everywhere** — Android home-screen widget (capture + "Pick for me" button), Android share-sheet target, desktop global hotkey (Ctrl+Shift+Space), voice capture.
3. **Brain dump mode** — type everything in your head, one per line, triage later. Clears the mental noise that blocks starting.
4. **Errand batching** — when "willing to leave the house" is on, the picker can suggest an **errand run**: all out-of-house tasks that fit the window, grouped by location.
5. **Body doubling** — ambient focus room with timer and optional lo-fi/brown noise; later, share a live session link with a friend.
6. **Waiting-for list** — tasks blocked on someone else, with a nudge date. Huge for clinic ops (waiting on a provider, an insurance callback, IT).
7. **Gentle nudges** — escalating notifications for the planned block ("Ready?" → "Just the first step?" → "Want to swap it?"). Never guilt-based.
8. **Daily shutdown & weekly review** — 3-minute guided wrap-up: celebrate wins, move leftovers, preview tomorrow. Plan My Day for tomorrow from here.
9. **Insights** — when you start best, which task types you avoid, completion by workspace. Framed as patterns, not grades.
10. **Optional AI (Claude)**: "Break this down" (generates first step + subtasks), natural-language capture ("call Medicare tomorrow 15 min high priority"), "Plan my day" explanation. Uses latest Claude model via user's API key, stored in OS secure storage.
11. Later: Wear OS / smartwatch timer, Gmail "star → task", accountability partner sharing.

---

## Critical constraints & risks (read before building)

- **PHI / HIPAA (important for clinic work)**: Patient information must not go into tasks synced to a *personal* Google account, and never to the AI feature. Mitigations:
  - Work workspace syncs only to the work Google Workspace account (data stays in the clinic's own Drive — no third-party server involved).
  - **AI is disabled by default in the Work workspace**; enabling it shows an explicit "no PHI" acknowledgement.
  - **PHI guard**: light pattern check (DOB-like dates, MRN-like numbers, "pt"/patient names pattern) in the Work workspace shows a warning chip — "Looks like patient info. Use initials or a ticket number instead."
  - Confirm with clinic compliance before using it for work.
- **Work Google Workspace admin policy**: many orgs block unapproved third-party OAuth apps. The clinic's Workspace admin may need to allow the app's OAuth client ID (Admin console → Security → API controls). Plan for Personal to work even if Work is blocked.
- **Google OAuth for a personal app**: create one Google Cloud project, enable Drive + Calendar APIs, OAuth consent screen = External. Calendar scopes are "sensitive" and the app won't be verified, so users see a "Google hasn't verified this app" warning they can click through (cap: 100 users). **Set publishing status to "In production"**, not "Testing" — in Testing, refresh tokens expire every 7 days and sync would silently break weekly.
- **Scopes (minimal)**: Phase 2 uses only `drive.appdata` + `drive.file` (both non-sensitive). Phase 3 adds `calendar.events` + `calendar.readonly` incrementally.
- **Android background limits**: sync runs on foreground + WorkManager periodic task; don't promise real-time background sync.

---

## Architecture

**Stack**: Flutter 3.x (stable) · Riverpod (state) · Drift/SQLite (local DB, web via sqlite3 wasm) · go_router · `googleapis` + `google_sign_in` + `googleapis_auth` · `flutter_local_notifications` · `home_widget` (Android widget) · `hotkey_manager` + `window_manager` (desktop) · `flutter_secure_storage` · `confetti` + `rive` (celebrations) · `rrule` (recurrence).

**Repo layout**
```
ADHD-Tax/
  README.md                     setup incl. Google Cloud OAuth walkthrough
  app/                          Flutter project
    lib/
      main.dart, app.dart
      core/        theme/ (tokens, themes/*.dart), router.dart, providers.dart, hlc.dart
      data/        db.dart (Drift schema), tables/, repositories/ (task_repo, xp_repo, …)
      sync/        drive_sync_engine.dart, op_log.dart, merge.dart, compaction.dart
      google/      auth/ (android, desktop, web), drive_client.dart, calendar_client.dart
      features/
        capture/       quick add, brain dump, NL parse
        picker/        picker_engine.dart (pure), picker_screen.dart
        focus/         focus_screen.dart, visual_timer.dart, session_repo
        planner/       plan_my_day.dart (pure slot-filler), timeline view
        views/         list, board, table, calendar
        gamification/  xp_rules.dart (pure), levels.dart, achievements.dart, rewards, celebrations/
        motivation/    quote_service.dart, quote_rotator widget
        insights/      estimate_calibration.dart (pure), insights_screen
        ai/            claude_client.dart, breakdown, nl_capture
        settings/      accounts, themes, weights, notifications, PHI guard
      widgets/     shared components (command palette, cards, chips)
    assets/  quotes/quotes.json, sounds/, rive/
    test/    unit tests mirroring lib/ (engine, merge, xp, planner, calibration)
    integration_test/
  .github/workflows/ci.yml      analyze + test + build web/android/windows
```

Pure-logic modules (`picker_engine`, `merge`, `hlc`, `xp_rules`, `plan_my_day`, `estimate_calibration`) have no Flutter imports so they're fast to test and reusable if a backend ever appears.

---

## Build phases

Each phase ends in something usable on a real device.

**Phase 1 — Usable MVP, offline (the part that changes your day)**
Flutter scaffold, Drift DB, task CRUD + 5-second capture, Pick-for-me engine + dashboard, Focus screen with visual timer and "Just 5 minutes," rotating quotes, basic XP/levels + confetti, 4 themes (Slate, Graphite, Neon Grid, Low-Stim). Android + Windows + web builds.

**Phase 2 — Google accounts & Drive sync**
Sign-in per workspace (Personal/Work), HLC op-log sync to appDataFolder, sync status indicator, backup export, PHI guard in Work.

**Phase 3 — Calendar**
Free-time detection feeding the picker, Plan My Day → events in "ADHD Tax" calendar, two-way updates, transition alerts and gentle nudges.

**Phase 4 — Workspace views & power UI**
Board, Table, Timeline, Calendar views; projects, tags, subtasks, recurrence; command palette & shortcuts; remaining themes (Holo Glass, Terminal, Mission Control, Clinic Calm, High Contrast).

**Phase 5 — Gamification depth & ADHD extras**
Full achievements, streaks with grace, reward shop, level-up animations, estimate calibration, insights, errand batching, Android widget + share target, desktop global hotkey, brain dump, waiting-for, daily shutdown/weekly review, body-doubling room.

**Phase 6 — Optional AI**
Claude key in secure storage, "Break this down," natural-language capture, Plan My Day rationale; off by default in Work.

**Phase 7 (only if going commercial)**: OAuth verification, privacy policy, Play Store listing, subscriptions.

---

## Verification

- **Unit tests** (`flutter test`): picker filtering/scoring edge cases (no fits → suggest chunk; leave-house off excludes errands; skipped tasks return after decay); HLC ordering and multi-device merge convergence (randomized op orderings must produce identical state); XP/level math; Plan My Day slot-filling around busy blocks; estimate calibration.
- **Widget tests**: capture flow, pick → start → complete → celebration, theme switching across all themes (golden tests).
- **CI**: `flutter analyze`, `flutter test`, `flutter build web`, `flutter build apk`, `flutter build windows` on GitHub Actions.
- **In this cloud environment**: build web and drive it with Playwright/Chromium for screenshots of the dashboard and each theme.
- **Manual end-to-end (user)**: sign in on Android + desktop with the same account, create a task on one, confirm it appears on the other after sync; edit the same task on both offline, reconnect, confirm they converge; run Plan My Day and see events land in the "ADHD Tax" Google Calendar; move an event in Calendar and confirm the task updates.

## Setup the user will need to do (one-time, ~20 min, documented in README)
1. Create a Google Cloud project, enable Drive API + Calendar API.
2. OAuth consent screen: External, add scopes above, set to **In production**.
3. Create OAuth client IDs: Android (needs SHA-1 of signing key), Desktop, Web.
4. For Work: ask the clinic Workspace admin to allow the client ID.
5. (Optional) Anthropic API key for AI features.
