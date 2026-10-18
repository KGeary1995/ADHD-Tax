# Changelog

What changed in each build, newest first. Build number = CI run number (= Android `versionCode`). Update this with every change the owner would notice.

## Next build — 2026-10-18 — renamed to **Unstuck** (Android, Mac)
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
