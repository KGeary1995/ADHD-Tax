# Changelog

What changed in each build, newest first. Build number = CI run number (= Android `versionCode`). Update this with every change the owner would notice.

## Next build — 2026-10-18 (Android)
- **Widget sizes**: besides the 4×2 card, pick **Unstuck start** (2×1: the task and a Start button), **Unstuck square** (2×2) or **Unstuck card + next up** (4×3: two more tasks that fit right now, each one tap to start). All can be resized.

## Build 31 — 2026-10-18 (dfb4094) — follow-ups, wrap-up, widget (Android, Mac)
- **Waiting on someone**: say who it's waiting on and when to check back. On the day it jumps to **Check back** at the top of Tasks (Home shows a reminder line, Android notifies): back to your list, still waiting, or done.
- **Real task lengths**: after 5 tasks timed with the focus timer, Unstuck learns how long things really take you and picks tasks that truly fit your time. Progress shows "Tasks take you about 1.6× your guess".
- **Evening wrap-up** (8:30 PM reminder on Android, or **Wrap up** on Home after 5 pm): today's wins, what's still open, and tomorrow's first thing, which shows first on Home the next morning. Settings → Reminders to change the time or turn it off.
- **Share → Unstuck** (Android): share text from any app; the first line becomes the task, the rest its note.
- **Voice**: tap the mic in Quick add and say the task (Android, Mac, Chrome/Safari). Android and Mac ask for microphone permission the first time.
- **Home-screen widget** (Android): the current pick with Start, and + to add.

## Build 29 — 2026-10-18 (ab500f5) (Android, Mac)
- The rotating quote is back on Home, between the task and the bottom bar. Tap it for the next one; it switches to dread-busting quotes when the pick is one you rated "Ugh" or worse.

## Build 27 — 2026-10-18 (dafab77) — new look (Android, Mac)
- Redesigned from scratch: one calm look in **light and dark** (Settings → Appearance: Light / Dark / Match phone). Your old theme choice carries over as light or dark.
- Home: "One thing. Right now.", your situation on one line (tap to change), the task as a big teal card with **Start** and **5 min**, then **Not this one / Smaller / Later**.
- Floating bottom bar with the **+** button to add a task (replaces "Quick add").
- Tasks: tap the circle to mark done; due dates in amber.
- Focus: a ring timer, Pause / +5 / Done.
- Settings: grouped Reminders, Sync and Feel sections. Progress: level card and stats.
- New bundled fonts (Bricolage Grotesque, Geist, Geist Mono).

## Build 25 — 2026-10-18 (3819fb9) — renamed to **Unstuck** (Android, Mac)
- New name everywhere you see it (formerly ADHD Tax). Tasks, XP and settings carry over: the internal ids didn't change.
- New icon: a tangle straightening into an arrow.
- Downloads are now `Unstuck.apk` and `Unstuck-macOS.zip`. The release pages (`android-latest`, `macos-latest`) are the same.
- Mac: after installing **Unstuck**, delete the old **ADHD Tax** app.

## 2026-10-18 — Docs for AI sessions
- `AGENTS.md` / `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/DEPLOYMENT.md`, `docs/TROUBLESHOOTING.md`, `docs/DECISIONS.md`, this changelog.
- `app/tool/check.sh` (the CI checks in one command) and `app/tool/screenshots/` (Playwright screenshots of the web build).

## Build 21 — 2026-10-18 (595756a) — Android, Mac
- Google sign-in keys are read from repository secrets in every build (sync stays off until they're added).
- Web/iPhone: Google sign-in remembered for its one-hour lifetime.
- First published Mac build (`macos-latest` release).

## Build 19 — 2026-10-18 (0217ca2) — Android
- iPhone support: installable home-screen web app with safe-area handling and offline copy (publishes once Cloudflare is set up).
- New app icon on every platform.
- CI: manual runs and pushes no longer cancel each other.

## Build 14 — 2026-10-18 (2deab8f) — Android
- Repeating tasks (daily, weekdays, weekly, every 2 weeks, monthly; fixed schedule or from when finished) with a **Coming up** section.
- **Mark done** from the task list; Undo for Done, Archive, Delete (also takes back XP).
- Android: focus countdown in notifications, "time's up" alert in the background, check-in nudges (Settings → Reminders).

## Build 12 — 2026-10-17 (ecc2cfc) — Android
- Quick add: headers for every option group, "Need to leave the house" as its own switch, buttons pinned above the keyboard, **Full task form** button.
- Task editor and dashboard fit 360dp phones at larger text sizes.
- Android back goes to Home instead of closing the app.

## Build 9 — 2026-10-17 (418168f) — Android
- Fixed the startup crash (shared_preferences Pigeon JNI). First build confirmed working on the owner's phone.

## Build 8 — 2026-10-17 (1295524) — Android
- Startup errors are shown on screen instead of a black screen. Impeller disabled.

## Build 6 — 2026-10-17 (503fed0) — Android
- First build on the fixed `android-latest` download link.

## Phase 2 — 2026-10-17 (6f623a9)
- Google sign-in per workspace and Drive sync (CRDT), backup to Drive, sync badge.

## Phase 1 — 2026-10-17 (1723c8f)
- Offline app: Pick for me, focus timer, Just 5 minutes, Overwhelmed, quick add / brain dump, XP and levels, 18 achievements, celebrations, 114 quotes, 9 themes, PHI guard.
