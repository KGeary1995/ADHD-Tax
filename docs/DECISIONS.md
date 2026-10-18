# Decisions

Why things are the way they are. Read before "simplifying" something that looks odd. Newest first. Each entry: decision, why, and what would make us revisit it.

### 2026-10-18 — Mac builds only on demand
macOS runners cost 10× Actions minutes on a private repo (~100 of 2,000 free monthly minutes per build). They run on `[mac]` commits, `main` and Run workflow. *Revisit if the repo goes public (free minutes) or the owner pays for Actions.*

### 2026-10-18 — iPhone = home-screen web app on Cloudflare Pages
The owner chose free over the Apple Developer Program ($99/yr). Costs: no notifications on iPhone, Google sync tokens last ~1 h, and the app needs a host. Cloudflare Pages was picked over Netlify because CI can create the project itself (only a token and account id needed, no drag-and-drop) and bandwidth is unlimited. *Revisit (TestFlight + native iOS) if reminders on iPhone become important.*

### 2026-10-18 — Generated app icon
`tool/make_icons.py` draws one design (a timer ring around a start triangle) for every platform, so icons are reproducible without design tools.

### 2026-10-18 — Reminders only on Android
`flutter_local_notifications` would also work on Mac, but couldn't be tested on a Mac from the build environment, and the focus timer is on screen there anyway. iPhone web apps can't schedule notifications. *Revisit for the Mac once someone can test it.*

### 2026-10-18 — Exact alarms via USE_EXACT_ALARM
"Time's up" must be on time. `USE_EXACT_ALARM` is granted without a prompt for timer/alarm apps on Android 13+. It's restricted on the Play Store, but this app is sideloaded. *Revisit if publishing to Google Play.*

### 2026-10-18 — Repeating tasks: next copy on completion, deterministic id
Creating the next copy when one is finished (rather than materializing a schedule) keeps one open copy at a time and needs no background job. The uuid v5 of the finished task's id means two devices finishing offline converge on one copy. Undo deletes that copy.

### 2026-10-18 — Undo instead of confirm dialogs
One-tap actions with a 6-second Undo (Done, Archive, Delete) are faster and less anxiety-inducing than "are you sure?" dialogs. Undo reverts XP by tombstoning the event.

### 2026-10-17 — Wrapping chips instead of SegmentedButton
Four-option segmented buttons squeezed labels on 360dp phones at larger text sizes. `ChoiceGroup` (wrapping `ChoiceChip`s) is used everywhere, with section labels.

### 2026-10-17 — Pin shared_preferences_android / path_provider_android; build with --no-shrink
Newer versions use Pigeon JNI, which crashed release builds before the first frame. R8 also stripped plugin code that's only called from Dart. A sideloaded app doesn't care about a few MB. *Revisit when upgrading Flutter: test a release APK on a real phone before removing the pins.*

### 2026-10-17 — Never fail silently at startup
`runZonedGuarded` + `StartupErrorApp` + `ErrorWidget.builder`. The owner can't attach a debugger, so the error must be readable and copyable on the phone.

### 2026-10-17 — Sideload signing key committed to the repo
Every CI build must share one signature to install as an update and keep local data, and Google Sign-In's Android client is tied to its SHA-1. Acceptable for a private, personal app. *Revisit before any public release.*

### 2026-10-17 — Fixed release tags (`android-latest`, `macos-latest`)
The owner installs from a phone, so the download link must never change. CI deletes and recreates the release with the new asset each time.

### 2026-10-17 — Sync: one file per device per workspace, field-level LWW CRDT with HLC
No server. Devices never write the same file, so there are no write conflicts; merge is deterministic, so all devices converge. Per-field clocks keep concurrent edits to different fields. XP is append-only events so points from two devices add up. `lastLocalWrite` stops devices from re-uploading merged data back and forth. *Deviation from docs/PLAN.md*, which proposed an append-only op log and Drift/SQLite: whole-state files are simpler and fast enough at this data size.

### 2026-10-17 — Separate Google accounts per workspace; only non-sensitive scopes
Personal and Work sync to different accounts, so clinic data stays in the clinic's Workspace. Moving a task between workspaces tombstones it on the old side. `drive.appdata` + `drive.file` need no Google verification and can't read the rest of Drive.

### 2026-10-17 — shared_preferences instead of Drift/SQLite
The data set is small (hundreds of tasks). One JSON replica per workspace in a key/value store is simpler, works on every platform including web, and matches the sync file format. *Revisit if task counts reach the thousands or search becomes slow.*

### Initial — Flutter, personal-first, optional AI
One codebase for Android, desktop and web (clinic PCs are locked down, so the web build matters). Built for the owner and a few friends first; AI (Claude, user's own key) is optional and off by default for Work because of PHI. See docs/PLAN.md.
