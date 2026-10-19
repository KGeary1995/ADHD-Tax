# Architecture

How the app works, for anyone changing it. Paths are relative to `app/lib/` unless noted. Read `AGENTS.md` first for commands and rules.

## Big picture

```
            ┌──────────────── one Flutter app (app/lib) ────────────────┐
 UI         │ dashboard · focus · task list · editor · quick add ·      │
 (features/)│ progress · settings                                       │
            ├───────────────────────────────────────────────────────────┤
 State      │ Riverpod 3 Notifiers: tasksProvider, progressProvider,    │
            │ pickerInputsProvider, settingsProvider, syncProvider(ws)… │
            ├───────────────────────────────────────────────────────────┤
 Storage    │ ReplicasController: one CRDT Replica per workspace        │
            │ (Personal, Work), saved in shared_preferences             │
            ├───────────────────────────────────────────────────────────┤
 Sync       │ SyncController(ws) → syncOnce() → DriveRemoteStore        │
            │ per-workspace Google account, hidden appDataFolder        │
            └───────────────────────────────────────────────────────────┘
```

No server. Every device holds the full data for each workspace it has, and devices exchange whole-state files through Google Drive.

## Startup (`main.dart`, `app.dart`)

1. `runZonedGuarded` → `_start()`: `SharedPreferences.getInstance()` and load `assets/quotes/quotes.json`. Any failure shows `StartupErrorApp` (`startup_error.dart`), a plain MaterialApp with the error text, **Copy details** and **Try again**. `ErrorWidget.builder` is replaced by `BuildErrorPanel`, so a widget that throws shows a readable error instead of a grey box.
2. `ProviderScope` overrides `keyValueStoreProvider` (`PrefsStore`) and `quoteServiceProvider`.
3. `AdhdTaxApp` builds `MaterialApp.router` (go_router). The `builder` wraps every route in:
   `WebSafeArea` → `SyncBootstrap` → `ReminderBootstrap` → `CelebrationOverlay` → page.

Routes (`app.dart`): a `ShellRoute` with the bottom bar / side rail (`AppShell`) holds `/` (dashboard), `/tasks`, `/progress` and `/settings`. Outside the shell are `/focus/:id?min=&five=1&panic=1` and `/task/:id` (`id = new` creates; `state.extra` may carry a draft `Task` from Quick add). Tabs use `go()`, so `AppShell` has a `PopScope` that sends Android back to `/` before exiting.

## Data model (`data/models/task.dart`, pure Dart)

`Task` fields: id, title, notes, firstStep, estimateMin, requiresLeavingHouse, location, priority (p1–p4), dueAt, hardDeadline, ugh (0–3 dread), energy, workspace (personal/work), status (inbox/todo/doing/waiting/done/archived), chunkable, scheduledStart (hidden from the picker until then), createdAt, updatedAt, startedAt, completedAt, actualMin, skipCount, lastSkippedAt, repeat (none/daily/weekdays/weekly/biweekly/monthly), repeatFromDone, waitingOn and followUpAt (who a waiting task waits on, and when to check back).

`Task.fromJson` defaults every field, so data written by older or newer builds still loads. Records that fail to parse are skipped (`taskFromRecord`), never fatal.

## Local storage

`KeyValueStore` (`data/storage/key_value_store.dart`) is a string key/value seam: `PrefsStore` (shared_preferences) in the app, `MemoryStore` in tests. Keys:

| Key | Contents |
|---|---|
| `device.id` | This install's id (uuid). Stamps writes and names its sync files. |
| `replica.v1.personal`, `replica.v1.work` | The full CRDT replica per workspace (tasks, XP events, meta, notes, projects). |
| `device.workspaces` | `both`, `personal` or `work`: which workspaces this install shows (`DeviceWorkspaces`). Device-local. |
| `tasks.view` | `list` or `board` for the Tasks tab. Device-local. |
| `sync.v1.<ws>` | Sync bookkeeping: connected email, remote checksums already merged, last upload marker, lastSyncedAt. |
| `backup.lastSavedAt` | When this device last saved a backup file. Device-local. |
| `settings.v1` | `AppSettings` JSON (theme, celebrations, reminders…). Device-local, not synced. |
| `tasks.v1`, `progress.v1` | Legacy Phase-1 format. Migrated into the replicas once on launch, then removed. The screenshot tool seeds demo data this way. |

On the web these live in `localStorage` with a `flutter.` prefix. The web Google token is stored separately as `adhdtax.googleToken.<ws>` until it expires.

## CRDT replicas (`core/hlc.dart`, `sync/replica.dart`, `sync/replicas_controller.dart`)

- **Hybrid Logical Clock**: millis + counter + node id, packed into a lexicographically sortable string. `send()` stamps local writes; `receive()` advances past remote clocks.
- **Replica**: collections → records → fields. **Every field carries the HLC of its last write.** Merging takes the later clock per field, which is commutative, associative and idempotent, so devices converge whatever order they see each other in. Editing the title on the phone and the priority on the Mac keeps both.
- Deletes are **tombstones** (`deleted: true`, other fields blanked so nothing sensitive lingers). Writing the record again with `deleted: false` revives it, which is how Undo works.
- Collections: `tasks` (record id = task id), `events` (XP events, append-only), `meta` (`progress` record holding `resetAt`), `notes`, `projects`. Notes and projects bump `ReplicaSet.docsVersion`.
- `lastLocalWrite` = clock of the newest write made *on this device*. Merges don't change it, so sync only uploads when there's something new of ours. This avoids devices bouncing the same data back and forth.
- `ReplicasController` holds one replica per workspace, persists on every change, and exposes version counters (`tasksVersion`, `eventsVersion`, per-workspace local-write counts) that providers watch.
- **Moving a task between workspaces** tombstones it on the old side (`TasksController._write`), so Work data doesn't linger in the Personal Google account.

## Sync (`sync/sync_engine.dart`, `sync/sync_controller.dart`, `google/`)

- Each device writes exactly **one file per workspace**: `state.<workspace>.<deviceId>.json` in that Google account's hidden **appDataFolder**. The file is the device's whole replica JSON (`{v, node, clock, local, c: {collection: {id: {f: fields, t: clock(s)}}}}`).
- A round (`syncOnce()` in `sync_engine.dart`, with bookkeeping in `SyncState`): list files with the workspace prefix → download the ones whose md5 changed since last merge → merge → upload our own file if `lastLocalWrite` is newer than our last upload, **or if the merge changed anything** (so our file doesn't keep stale copies of things since deleted, edited or moved to the other workspace; the next round merges nothing, so it can't ping-pong). Devices never write the same file, so there are no write conflicts. Unreadable remote files are skipped and retried.
- `SyncController(ws)` triggers a round on start, 4 s after local edits, every 3 min in the foreground, on app resume (`SyncBootstrap`), and on demand. Its phases are notConfigured, disconnected, connecting, syncing, synced, error and needsReconnect, and `SyncBadge` / Settings show them.
- **Backup**: "Back up to Drive" writes a readable JSON file to the visible Drive root (`drive.file` scope).

### Backup file (no Google needed) (`sync/backup_file.dart`, `features/settings/backup_*.dart`)

- **Save a backup file** writes `{app, kind: "unstuck-backup", v: 1, exportedAt, workspaces: {personal: <replica JSON>, work: <replica JSON>}}`, clocks included. `BackupFile` is pure Dart.
- **Restore** is `ReplicasController.restore()`: a CRDT merge of each workspace, the same as receiving a sync file, so an old backup never overwrites newer edits, deletions made after the backup stay deleted, and restoring twice is a no-op. Restored data is stamped as a local write so sync uploads it.
- File I/O goes through `BackupFiles` (`backupFilesProvider`; tests use a fake). Native: `file_picker`'s save and open dialogs (macOS needs the `files.user-selected.read-write` entitlement). Web on a phone: the Web Share sheet with the file (`web_share.dart`), because a plain download is easy to lose on an iPhone; desktop browsers download. The JSON is built before any `await`, because Safari only opens the share sheet straight after the tap.
- `backup.lastSavedAt` (device-local key) drives "Last saved …" in Settings.
- **Scopes**: only `drive.appdata` and `drive.file`, both non-sensitive, so the Google app needs no verification.

### Sign-in per platform (`google/auth_*.dart`, chosen by `auth_factory.dart`)

| Platform | How | Session length |
|---|---|---|
| Android | `google_sign_in` v7 (Credential Manager) to pick the account, then `clientAuthorizationTokensForScopes` with that email. Needs the **web** client id as `serverClientId`, and an **Android** OAuth client registered for package `com.adhdtax.adhd_tax` with the sideload key's SHA-1. | Silent refresh |
| Mac / Windows / Linux | `googleapis_auth` loopback + PKCE in the system browser; refresh token in the OS keychain (`flutter_secure_storage`; macOS uses the login keychain because ad-hoc signed builds can't use the data-protection keychain). Uses the **Desktop** client id + secret. | Long-lived |
| Web / iPhone | Google Identity Services token client (popup), **web** client id; the origin must be listed in the client's JavaScript origins. Token kept in localStorage until expiry. | ~1 hour, then "Reconnect" |

Client ids come from `--dart-define`s (`google/google_config.dart`): `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_SECRET`. Empty means "not configured": the Accounts panel says so and the app works offline. **Personal and Work can be different Google accounts**: sign-in is per workspace, with the email remembered as a hint. A Work workspace on an @gmail.com account shows a warning.

## Progress / XP (`features/gamification/`)

- Progress is a **fold over immutable `ProgressEvent`s** (`progress_event.dart`, `progress_stats.dart`). Each event carries deltas (XP, coins, started/completed counts, focus minutes…). Devices only add events, so XP earned on two devices adds up instead of overwriting.
- Events are stored in the workspace of the task that earned them. "Reset progress" writes a `resetAt` marker, and older events are ignored.
- `xp_rules.dart`: XP for starting (the hard part), finishing (scaled by estimate, priority and dread), bonuses (first win of the day, beat your estimate when timed, old task cleared, got out the door), partial credit. Levels follow `100 × (n−1)^1.5`.
- `achievements.dart`: 18 achievements, evaluated in the fold.
- Undoing a completion **tombstones the event** (`ProgressController.revoke`); never edit events.
- `CelebrationQueue` + `CelebrationOverlay`: a big card plus confetti for focus-session finishes, and a toast for starts and for quick "Mark done" (so the Undo bar stays reachable). Intensity comes from settings.

## Picking a task (`features/picker/`)

`picker_engine.dart` (pure) filters open tasks (workspace, leave-house, `scheduledStart` not in the future, fits the time or is chunkable) and scores them with tunable `PickerWeights`: priority, urgency (hard deadlines ramp sooner), staleness, fit to the time window, energy match, dread (boosted in the morning / high energy), skip penalty decaying over ~24 h, and in-progress. It returns one suggestion with a human reason. The dashboard limits rerolls ("Not this one" twice → pick one of three). **Overwhelmed** picks one easy task for 5 minutes.

- **Real task lengths** (`features/insights/estimate_calibration.dart`, pure): the median of actual ÷ estimated minutes over the last 30 tasks finished with the timer, per workspace when it has ≥5, otherwise overall. Ignored until 5 samples or when within ±15% of 1×. `PickerContext.calibration` makes the engine fit tasks by `realMinutes` and plan the session for that long; Progress shows the factor.
- **Pinned pick**: the evening wrap-up stores tomorrow's first task in `AppSettings.pinnedTaskId/pinnedDay` (device-local). `pickResultProvider` returns it first on that day until it's done or passed on with "Not this one".

## Notes and projects (`features/notes/`, `data/models/note.dart`)

- `Note` (pure): workspace, title, body, pinned, `projectId`, `taskId` (the task it's about), `tags`. Tags are stored as one comma-joined string, because replica fields compare by value and a list would look changed on every save. `allTags` adds `#hashtags` found in the title/body. `taskLinesOf()` strips list markers for "Make tasks".
- `Project` (pure): name, workspace, color index (`ThemeSpec.projectColor`). A task's or note's `projectId` must be a project of the same workspace; editors clear it when the workspace changes. Deleting a project clears `projectId` on its tasks and notes.
- `NotesController` / `ProjectsController` read both replicas like `TasksController`; moving a note to the other workspace tombstones it on the old side.
- **Notes tab** (`notes_screen.dart`): search (title, body, tags), Personal/Work, project and tag filters (`notesFilterProvider`), pinned first. **+** on this tab opens a new note filed under the current filters.
- **Note editor** (`note_editor_screen.dart`): autosaves 600 ms after typing and on close; a new note is only stored once it has text. "Project & tags" sheet; "Make tasks" sheet; PHI warning on Work notes. The controller is captured in `initState` because the last save runs in `dispose`.
- **Show on this device** (`settings/device_workspaces.dart`): `tasksProvider`, `notesProvider` and `projectsProvider` drop the hidden workspace at the source, so lists, the picker, widgets, reminders and wrap-up all follow. The picker's workspaces, Quick add's and the editors' defaults use `DeviceWorkspaces.primary`, and their workspace switches are hidden. Hidden data stays in the replica (and syncs if that account was connected); progress XP still counts all events.
- **Tasks**: `taskProjectFilterProvider` (public: Quick add files new tasks into it), project pills with rename/delete, and `taskViewProvider` (List/Board, saved as `tasks.view`).
- **Board** (`tasks/task_board.dart`): columns from status (inbox+todo → To do; archived hidden; Done = last 14 days). `LongPressDraggable` cards and `DragTarget` columns, plus a ⋮ "Move to…" menu for phones where the target column is off-screen. `moveTask()` goes through the normal paths: Done → `markDoneWithUndo` (XP), Waiting → the waiting sheet, Doing → `markStarted`. Four columns side by side when they fit (≥ ~900 px). Narrower (`_TabbedBoard`): one row of four column tabs with counts, one column at full width; tap or swipe to switch; the tabs are `DragTarget`s, so a held card dropped on a tab moves there. (A sideways-scrolling row of columns was tried first and was hard to use on a phone.)

## Tasks, repeating, undo (`features/tasks/`)

- `TasksController` reads tasks from all replicas and writes through `ReplicasController`.
- `complete()` marks the task done and, if it repeats, writes the next copy from `recurrence.dart`:
  - The next copy's **id is a uuid v5 of the finished task's id**, so two devices finishing it offline create the same copy.
  - With a due date, the copy is due one period later (skipping missed dates) and hidden until `leadDays` before (0/0/2/4/7 days for daily/weekdays/weekly/biweekly/monthly).
  - Without a due date, it's hidden until its next day.
  - `repeatFromDone` counts from the finish date instead of the schedule.
- The task list shows hidden tasks (snoozed, next copies) under **Coming up**.
- **Waiting on someone** (`waiting_sheet.dart`): records who it waits on and a check-back date (9 am tomorrow / in 3 days / next week / a date). When the date comes the task moves to **Check back** at the top of Tasks (Back to my list / Still waiting / Done), Home shows a one-line banner, and Android notifies.
- `task_actions.dart`: Mark done, Archive and Delete, each with an Undo snackbar. Task rows swipe right to mark done and left to delete (`SwipeActions` in `widgets/ui.dart`); note tiles swipe left to delete (`deleteNoteWithUndo`). Everything needed for the undo is captured before the change, because the tile may be gone by then.

## Focus session (`features/focus/`)

`FocusScreen` tracks elapsed time from timestamps (not tick counting), so it stays correct when the app is in the background. "Just 5 minutes" asks to keep going at 5 minutes. At time up, a dialog offers Done / +10 min / Stop. Start XP is recorded on entry. `PopScope` confirms before abandoning a session.

## Reminders (`features/reminders/`)

- `Reminders` interface; `DeviceReminders` (flutter_local_notifications) on real Android and iOS devices, `NoReminders` everywhere else, including `flutter test`, which runs on the host. The platform switch is a conditional import (`platform_io.dart` / `platform_stub.dart`).
- **Focus**: an ongoing notification with a countdown chronometer, plus a "time's up" alert scheduled with an exact alarm (`USE_EXACT_ALARM` on Android 13+, `SCHEDULE_EXACT_ALARM` on Android 12). On time-up in the foreground both are cleared, since the dialog is the alert. In the background the alert stays.
- **Nudges**: `nudge_plan.dart` (pure) computes absolute times for the next 14 days from settings (times, weekdays only), skipping 90 minutes after `lastActiveAt`. The same scheduled set also holds follow-ups on waiting tasks (`planFollowUps`) and the evening wrap-up (`planWrapUps`). Each `Nudge` carries a route; tapping the notification opens it (`Reminders.opened`). `ReminderBootstrap` re-plans on launch, resume and relevant changes, and asks for notification permission once on first launch. Times are absolute UTC instants, so no time-zone database is needed and daylight-saving changes are handled by re-planning.
- Status-bar icon: `android/app/src/main/res/drawable/ic_stat_focus.xml`, kept from resource shrinking by `res/raw/keep.xml`.

## Evening wrap-up (`features/wrapup/`)

`/wrapup` (full screen; from the Android reminder or the "Wrap up" link on Home after 5 pm): today's finishes and XP, tasks still in progress (Done / Keep for tomorrow / Back to the list), and tomorrow's first thing chosen from the picker's top candidates for tomorrow morning, with an optional first step. "Done for today" pins it.

## Outside the app (`features/outside/`, Android)

`DeviceBridge` (`device_bridge.dart`) is the Dart end of the `unstuck/android` method channel on both phones (the name predates iOS). `OutsideBootstrap` acts on its requests, polls it on resume, and pushes the current pick for the widgets.

**iOS** (`ios/Runner/AppDelegate.swift`, `ios/UnstuckWidget`, `ios/UnstuckShare`):
- The share extension (Apple's compose sheet) queues `{subject, text}` in the App Group `group.com.adhdtax.adhdTax`; `takeLaunchRequest` hands one over per call, and the app opens Quick add with it on resume.
- `updateWidget` stores the pick in the App Group and reloads WidgetKit timelines. The SwiftUI widget (small, medium, large with "Next up") only displays it.
- Widget taps open `unstuck://app/<route>`, which Flutter's deep linking hands to go_router directly; `/add` is a redirect that sets `quickAddRequested`.
- Notifications use the same `DeviceReminders` as Android (no ongoing countdown on iOS; at most 60 scheduled, soonest first, because iOS keeps 64).

**Android** — `MainActivity.kt` (launchMode `singleTask`, Flutter deep linking off) talks to Dart over the channel:
- **Share → Unstuck**: an `ACTION_SEND text/plain` intent becomes a `SharedText` request; `taskFromShare` turns the subject or first line into the title and the rest into notes, and Quick add opens prefilled.
- **Home-screen widgets** (`PickWidget.kt`, `res/layout/pick_widget*.xml`, `res/xml/pick_widget*_info.xml`): RemoteViews copies of Home's teal card in four sizes, each its own provider so the launcher lists them: `PickWidgetSmall` 2×1, `PickWidgetSquare` 2×2, `PickWidget` 4×2 (the original class name, so placed widgets survive), `PickWidgetLarge` 4×3 with "Next up" (`nextUpProvider`, two more that fit). One renderer fills whichever views a layout has; RemoteViews skips the rest. They never compute anything; `OutsideBootstrap` pushes the current pick (`updateWidget`) whenever it changes, so they show the last pick from when the app was open. Taps open `/` (card), `/focus/<id>?min=N` (Start, or a Next-up row) or `/add` (+) through the same channel.
- Elsewhere `NoDeviceBridge` does nothing. Tests use a fake bridge.

## Capture (`features/capture/`)

- **Quick add** (bottom sheet): a title plus labelled chip groups (Workspace, How long?, Priority, dread, an Errand switch). A mic button (`voice_input.dart`, `speech_to_text`) dictates into the title, or new lines in Brain dump; it works on Android, Mac and in Chrome/Safari, and says so elsewhere. Its buttons are pinned above the keyboard and the nav bar. **Brain dump** creates one task per line. **Full task form** opens the editor with the draft.
- **Task editor**: every field, plus repeat settings and status.
- The PHI warning appears for Work tasks that look like patient info.

## Theming (`core/theme/app_themes.dart`)

One look in two brightnesses: `darkSpec` and `lightSpec` (`ThemeSpec` tokens: background, surface, hairline, outline, text levels, teal `accent` fill vs `primary` teal text, the near-black `ink` of the Start button, nav colors). `AppSettings.appearance` (Light / Dark / Match phone) picks `ThemeMode`; old `themeId` values map to light or dark on load. Widgets read tokens via `context.spec`, plus `s.display(size)` (Bricolage Grotesque) and `s.mono(size)` (Geist Mono); body text is Geist. Fonts are bundled TTFs in `app/assets/fonts/` (OFL, registered with `LicenseRegistry` in `main.dart`). Reduced motion follows the OS (`context.reduceMotion`).

Shared pieces live in `widgets/ui.dart`: `Panel` (card), `Group`/`GroupRow`/`SwitchRow` (settings-style lists), `Pill`/`ChoiceGroup` (wrapping single choice), `Segmented`, `PageHeader`, `SectionTitle`, `FieldLabel`, `UnstuckMark`/`Wordmark` (the logo drawn in code), `navClearance()`. `widgets/task_chips.dart` has `TaskMeta` (the one-line "Due 5 pm · 1h · Critical" summary) and date/duration formatters.

Navigation (`app.dart`): phones get a floating pill nav (`extendBody`, so screens pad with `navClearance`) with the teal Add button; at ≥760 px a slim rail. Tab buttons are icon-only with tooltips (tests find them with `find.byTooltip('Tasks')`).

## Web and iPhone specifics (`app/web/`, `core/safe_area/`)

- `index.html`: home-screen metadata (`apple-mobile-web-app-*`, `apple-touch-icon.png`) and registers `offline.js`.
- `offline.js`: network-first service worker that falls back to the saved copy after 4 s or when offline. It never serves stale code when the network works.
- `flutter_bootstrap.js`: custom, so Flutter's deprecated service worker isn't registered. That worker unregisters all workers and reloads the page.
- `WebSafeArea`: Flutter web reports no safe-area insets and rewrites the viewport tag, dropping `viewport-fit=cover`. `insets_web.dart` re-adds `viewport-fit=cover`, measures `env(safe-area-inset-*)` with a hidden element, and feeds the values into `MediaQuery`.

## Tests (`app/test/`)

| Folder | What |
|---|---|
| `core/`, `data/`, `features/` | Pure logic: HLC, Task JSON, picker scoring, XP, achievements fold, quotes, PHI guard, recurrence, nudge/follow-up/wrap-up planning, estimate calibration, share-to-task parsing |
| `sync/` | Replica merge laws, sync engine against `FakeRemote` (multi-device convergence, ping-pong, offline edits, corrupt files), sync controller with a fake auth |
| `widget/` | Full-app flows (`pumpApp`), waiting → check back, wrap-up pin, share/widget requests with a fake bridge (`new_features_test.dart`), light/dark/system on a phone, settings migration, phone-width overflow at 1.0×/1.3× text, back navigation, Quick add → full form, reminders with `FakeReminders`, Mark done/Delete with Undo, startup error screen |

Inject time with `clockProvider` and storage with `keyValueStoreProvider` (`MemoryStore`).
