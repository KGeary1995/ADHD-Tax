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

`Task` fields: id, title, notes, firstStep, estimateMin, requiresLeavingHouse, location, priority (p1–p4), dueAt, hardDeadline, ugh (0–3 dread), energy, workspace (personal/work), status (inbox/todo/doing/waiting/done/archived), chunkable, scheduledStart (hidden from the picker until then), createdAt, updatedAt, startedAt, completedAt, actualMin, skipCount, lastSkippedAt, repeat (none/daily/weekdays/weekly/biweekly/monthly), repeatFromDone, waitingOn and followUpAt (who a waiting task waits on, and when to check back), projectId, checklist, tags and reviewedAt (when the weekly reset last kept it).

- `checklist` (`data/models/checklist.dart`, pure): one string, one item per line, `[ ] text` or `[x] text`. `Task.steps` parses it; `Task.nextStep` is the first unticked item (or `firstStep` when there's no checklist, or '' when all are ticked) and `startLine` falls back to the title. `TasksController.toggleStep` ticks one. `nextOccurrence` resets the boxes.
- `tags`: comma-separated lowercase tags without `#`, a scalar like `Note.tags`. `tagList` splits it; `TaskMeta` shows them.

`Task.fromJson` defaults every field, so data written by older or newer builds still loads. Records that fail to parse are skipped (`taskFromRecord`), never fatal.

## Local storage

`KeyValueStore` (`data/storage/key_value_store.dart`) is a string key/value seam: `PrefsStore` (shared_preferences) in the app, `MemoryStore` in tests. Keys:

| Key | Contents |
|---|---|
| `device.id` | This install's id (uuid). Stamps writes and names its sync files. |
| `replica.v1.personal`, `replica.v1.work` | The full CRDT replica per workspace (tasks, XP events, meta, notes, projects, rewards, templates). |
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
- Collections: `tasks` (record id = task id), `events` (XP events, append-only), `meta` (`progress` record holding `resetAt`), `notes`, `projects`, `rewards`, `templates`. Notes, projects, rewards and templates bump `ReplicaSet.docsVersion`; `docFromRecord`/`docFields` in `replicas_controller.dart` read and write them.
- `lastLocalWrite` = clock of the newest write made *on this device*. Merges don't change it, so sync only uploads when there's something new of ours. This avoids devices bouncing the same data back and forth.
- `ReplicasController` holds one replica per workspace, persists on every change, and exposes version counters (`tasksVersion`, `eventsVersion`, per-workspace local-write counts) that providers watch.
- **Moving a task between workspaces** tombstones it on the old side (`TasksController._write`), so Work data doesn't linger in the Personal Google account.

## Sync (`sync/sync_engine.dart`, `sync/sync_controller.dart`, `google/`, `icloud/`)

- **Where:** each workspace syncs through one service, chosen on this device at first Connect and saved as `sync.service.v1.<workspace>` (missing means Google, as before 1.2): **Google** (`google/`: Drive's hidden appDataFolder, any platform), **OneDrive** (`microsoft/`: Graph's app folder, `Apps/Gumption/Sync/`, every platform) or **iCloud** (`icloud/icloud_store.dart` + `ICloudBridge` in `ios/Runner/AppDelegate.swift`: a hidden `Sync/<workspace>/` folder of the app's iCloud Drive container `iCloud.com.adhdtax.adhdTax`, iPhone/iPad app only). All three implement `AccountRemoteStore` (list/read/create/update), so the engine below doesn't know which it talks to; Google and Microsoft sign-ins both implement `AccountAuth` (`sync/account_auth.dart`), picked by `SyncController._auth` from the workspace's service. `availableSyncServicesProvider` lists what this build offers (iCloud on iPhone/iPad, Google and Microsoft when their client ids are set); the Connect chooser shows only those.
- **OneDrive details:** `microsoft/onedrive_store.dart` (pure Dart over `http`): list `approot:/Sync:/children` (404 = nothing yet), checksum `cTag`, read via `@microsoft.graph.downloadUrl` with a plain client, write by path (`approot:/Sync/<name>:/content`) or id, upload sessions above 4 MB, 401 → `NeedsReconnect`, other errors → `OneDriveError` with a readable message (403 explains admin approval). `microsoft/microsoft_auth.dart`: PKCE against `login.microsoftonline.com/common`, scopes `Files.ReadWrite.AppFolder User.Read offline_access`, `prompt=select_account`, refresh token per workspace in the keychain (`microsoft.credentials.<ws>`), access token renewed a minute before expiry (concurrent requests share one renewal; Microsoft rotates the refresh token and the new one is saved). The browser step is a `RedirectCatcher`: `microsoft/auth_io.dart` (loopback server, or on Android the `gumption://auth` link arriving as `AuthRedirect` through `features/outside/`) or `microsoft/auth_web.dart` (a pop-up that lands on the static `web/auth/microsoft/index.html`, which hands the address back by `postMessage`, a `BroadcastChannel` and local storage, polled each second; the refresh token is kept in local storage as `gumption.microsoft.credentials.<ws>`). `offline.js` never caches `/auth/` pages.
- **iCloud details:** no sign-in; the "email" is `icloud:<hash>`, a hash of `ubiquityIdentityToken`, re-checked every round so a different Apple ID throws `WrongAccount` instead of syncing into it; shown as "iCloud" (`WorkspaceSync.accountLabel`). Listing uses `NSMetadataQuery` (finds files not downloaded yet and starts downloading them), reads wait for the download, reads and writes go through `NSFileCoordinator`, and the checksum is modification time + size. Outside `Documents`, so the Files app doesn't show the folder. No "Back up to Drive" for iCloud workspaces.
- Each device writes exactly **one file per workspace**: `state.<workspace>.<deviceId>.json` in that Google account's hidden **appDataFolder** (or that workspace's iCloud folder). The file is the device's whole replica JSON (`{v, node, clock, local, c: {collection: {id: {f: fields, t: clock(s)}}}}`).
- A round (`syncOnce()` in `sync_engine.dart`, with bookkeeping in `SyncState`): list files with the workspace prefix → download the ones whose md5 changed since last merge → merge → upload our own file if `lastLocalWrite` is newer than our last upload, **or if the merge changed anything** (so our file doesn't keep stale copies of things since deleted, edited or moved to the other workspace; the next round merges nothing, so it can't ping-pong). Devices never write the same file, so there are no write conflicts. Unreadable remote files are skipped and retried.
- `SyncController(ws)` triggers a round on start, 4 s after local edits, every 3 min in the foreground, on app resume (`SyncBootstrap`), and on demand. Its phases are notConfigured, disconnected, connecting, syncing, synced, error and needsReconnect, and `SyncBadge` / Settings show them.
- **Backup**: "Back up to Drive" writes a readable JSON file to the visible Drive root (`drive.file` scope).

### Backup file (no Google needed) (`sync/backup_file.dart`, `features/settings/backup_*.dart`)

- **Save a backup file** writes `{app, kind: "unstuck-backup", v: 1, exportedAt, workspaces: {personal: <replica JSON>, work: <replica JSON>}, settings: {key: raw value}}`, clocks included. `BackupFile` is pure Dart. `settings` holds only `backupSettingKeys` (`backup_group.dart`): `settings.v1`, `tasks.view`, `focus.sound`, `focus.buddy`, `hotkey.enabled`. Never `device.workspaces` (per install), `ai.allowWork` (consent) or secrets (keychain). Files without `settings` (older builds) decode to an empty map; non-string values are dropped.
- **Restoring settings** is optional ("Also restore its settings", on by default when the file has some): `restoreSettings` writes only the allowed keys, whatever the file contains, and invalidates the providers that read them. Unlike data, settings are replaced, not merged.
- **Restore** is `ReplicasController.restore()`: a CRDT merge of each workspace, the same as receiving a sync file, so an old backup never overwrites newer edits, deletions made after the backup stay deleted, and restoring twice is a no-op. Restored data is stamped as a local write so sync uploads it.
- File I/O goes through `BackupFiles` (`backupFilesProvider`; tests use a fake). Native: `file_picker`'s save and open dialogs (macOS needs the `files.user-selected.read-write` entitlement). Web on a phone: the Web Share sheet with the file (`web_share.dart`), because a plain download is easy to lose on an iPhone; desktop browsers download. The JSON is built before any `await`, because Safari only opens the share sheet straight after the tap.
- `backup.lastSavedAt` (device-local key) drives "Last saved …" in Settings.
- **Scopes**: only `drive.appdata` and `drive.file`, both non-sensitive, so the Google app needs no verification.

### Sign-in per platform (`google/auth_*.dart`, chosen by `auth_factory.dart`)

| Platform | How | Session length |
|---|---|---|
| Android | `google_sign_in` v7 (Credential Manager) to pick the account, then `clientAuthorizationTokensForScopes` with that email. Needs the **web** client id as `serverClientId`, and an **Android** OAuth client registered for package `com.adhdtax.adhd_tax` with the sideload key's SHA-1. | Silent refresh |
| Mac / Windows / Linux, and **iPhone/iPad** (native app) | `googleapis_auth` loopback + PKCE. Computers open the system browser; iPhone opens an in-app Safari sheet (`LaunchMode.inAppBrowserView`) and closes it after the redirect. One refresh token per workspace refresh token in the OS keychain (`flutter_secure_storage`; macOS uses the login keychain because ad-hoc signed builds can't use the data-protection keychain). Uses the **Desktop** client id + secret. | Long-lived |
| Web (incl. the iPhone home-screen web app) | Google Identity Services token client (popup), **web** client id; the origin must be listed in the client's JavaScript origins. Token kept in localStorage until expiry. | ~1 hour, then "Reconnect" |

Client ids come from `--dart-define`s (`google/google_config.dart`): `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_SECRET`. Empty means "not configured": the Accounts panel says so and the app works offline. **Personal and Work can be different Google accounts**: sign-in is per workspace, with the email remembered as a hint. A Work workspace on an @gmail.com account shows a warning.

- **Why iPhone doesn't use `google_sign_in`:** on iOS it keeps one signed-in account and ignores the email asked for (`google_sign_in_ios` authorizes the current user). Signing in to Work made Personal sync through the Work account. iOS has used the Desktop client's browser flow since 2026-10-24; the iOS OAuth client is no longer used for sync.
- **Wrong-account guard** (all platforms): the first sync with a restored client checks `accountEmail()` against the workspace's stored email and stops with `WrongAccount` ("Signed in to Google as X. Reconnect with Y.") instead of writing anything. Not retried quietly.
- **Quiet retries only where they help:** `GoogleAuth.restoreMayRecover` is true only on Android, whose silent sign-in can come back empty just after an update. Elsewhere an empty restore means no saved sign-in, so the row shows Reconnect at once.
- **Stuck sign-in:** `connect()` times out after 5 minutes, and the row shows **Cancel** while waiting; a sign-in that finishes after Cancel is ignored.

## Progress / XP (`features/gamification/`)

- Progress is a **fold over immutable `ProgressEvent`s** (`progress_event.dart`, `progress_stats.dart`). Each event carries deltas (XP, coins, started/completed counts, focus minutes…). Devices only add events, so XP earned on two devices adds up instead of overwriting.
- Events are stored in the workspace of the task that earned them. "Reset progress" writes a `resetAt` marker, and older events are ignored.
- `xp_rules.dart`: XP for starting (the hard part), finishing (scaled by estimate, priority and dread), bonuses (first win of the day, beat your estimate when timed, old task cleared, got out the door), partial credit. Levels follow `100 × (n−1)^1.5`.
- `achievements.dart`: 18 achievements, evaluated in the fold.
- `ProgressStats.startsByDay` (yyyy-mm-dd → starts, carryover events excluded) feeds **Your sky** (`constellation.dart`): the last 12 calendar weeks, one small constellation per week in a 4- or 6-column grid, a star per start (up to 4 a day), lines between days in a row. Shapes are seeded by the week number, so a week looks the same every time. Drawn once with a `CustomPainter`; no animation, so `pumpAndSettle` stays safe.
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
- **`[[links]]`** (`data/models/links.dart`, pure; UI in `notes/note_links.dart`): a link is plain text in a note, matched by name like a wiki, so nothing new syncs and older builds just show the brackets. It resolves only inside the note's workspace: an unfinished task first, then a finished one with that title, then a note by its heading, else "missing" (the editor offers **Make task**). `LinkTextController` colors links while typing (plain text during IME composition). Typing `[[` shows `LinkSuggestionBar` above the keyboard; picking one calls `completeLink()`. `NoteLinksPanel` lists the targets and the notes linking to this note's title. `Note.heading`/`preview` show links without brackets. Renaming a task doesn't rewrite links to it (same as Obsidian without its rename setting).
- **Related** on the task editor (`_Related`): `notesLinkingTo(task.title)` (minus notes already attached by `taskId`) and `relatedTasks()`: unfinished tasks in the same workspace sharing a tag (2 points each) or the project (1), then soonest due. Hidden when empty.
- **Show on this device** (`settings/device_workspaces.dart`): `tasksProvider`, `notesProvider` and `projectsProvider` drop the hidden workspace at the source, so lists, the picker, widgets, reminders and wrap-up all follow. The picker's workspaces, Quick add's and the editors' defaults use `DeviceWorkspaces.primary`, and their workspace switches are hidden. Hidden data stays in the replica (and syncs if that account was connected); progress XP still counts all events.
- **Tasks**: `taskProjectFilterProvider` (public: Quick add files new tasks into it), project pills with rename/delete, and `taskViewProvider` (List/Board, saved as `tasks.view`). On a phone all three sit in one sheet (`_showFilterSheet`) behind the 'Show tasks' square; a pill under the header says what's active. Rows use `TaskMeta(compact: true)`. From 880 px of content (an iPad in landscape and up), the list view is the list plus `TaskDetailPane` (`task_detail_pane.dart`): All/Personal/Work and Projects pills above the list, tapping a row selects it (`selectedTaskProvider`; the first open task until you pick), and the pane shows workspace and project, 5 min and Start, the title, tickable steps, a two-column details grid and linked notes, with **Edit task** (or a double tap on the row) for the full editor. The board stays full width.
- **Board** (`tasks/task_board.dart`): columns from status (inbox+todo → To do; archived hidden; Done = last 14 days). `LongPressDraggable` cards and `DragTarget` columns, plus a ⋮ "Move to…" menu for phones where the target column is off-screen. `moveTask()` goes through the normal paths: Done → `markDoneWithUndo` (XP), Waiting → the waiting sheet, Doing → `markStarted`. Four columns side by side when they fit (≥ ~900 px). Narrower (`_TabbedBoard`): one row of four column tabs with counts, one column at full width; tap or swipe to switch; the tabs are `DragTarget`s, so a held card dropped on a tab moves there. (A sideways-scrolling row of columns was tried first and was hard to use on a phone.)

## Capture extras, rewards, templates

- **Typed extras** (`capture/quick_parse.dart`, pure): `parseQuickAdd(text, now, ignore:)` returns the cleaned title, `dueAt`, `estimateMin`, `priority`, `workspace` (`#work`/`#personal`), `tags`, and `bits` for the preview chips. Order: tags, length, time, day, priority; each rule blanks the words it used. A date without a time is due at 5 pm (like the editor), a time without a date is today or, if already past, tomorrow. Quick add (`_resolve`) merges this with the sheet: hand-picked values win, a `#tag` matching a project's name sets the project, and tapping a chip adds its key to `ignore`. Brain dump parses each line. On a single-workspace device `#work`/`#personal` are plain words.
- **Reward shop** (`gamification/rewards_controller.dart`, `reward_shop.dart`, `data/models/reward.dart`): `Reward{name, cost, workspace}` records; `redeem()` writes a `ProgressKind.redeemed` event with negative coins (refused when short); `unredeem()` tombstones it. `applyEvent` only changes coins for that kind. `redemptionsProvider` lists them for "Last treat".
- **Templates** (`features/templates/`, `data/models/template.dart`): `Template{kind: task|note, name, workspace, title, body, checklist, estimateMin, tags}`. Using a task template opens `/task/new` with an unsaved draft (`taskDraft`); Quick add's **Template** creates it straight away (`createTask`); a note template creates the note and opens it. `fillTemplate` replaces `{date}` and `{weekday}`. `exampleTemplates` are offered while there are none. Routes `/templates` and `/template/:id` (`new?kind=task|note`), outside the shell.

## Desktop layout

`SidebarLayout` (`widgets/ui.dart`) puts a 248 px filter sidebar (`SideSection` / `SideItem`) beside the main column when the content area is at least `sidebarBreakpoint` (980 px), centered and capped at 1240 px; narrower, it is the phone layout. Notes uses it (tiles in 2–3 columns, `_NoteGrid`) and Settings; Tasks has its own list + detail pane layout (above). `showQuickAdd` uses a centered `Dialog` at `wideBreakpoint` and up (and 640 px tall), the bottom sheet otherwise.

The other pages use `ResponsiveColumns(main, side, sideWidth)` (a `Row` of an expanding main column and a fixed side column, stacking below `breakpoint`) when the window is at least 1000 px, capped at about 1180 px; below that each keeps its original phone layout and order (they branch on width rather than relying on `ResponsiveColumns`' stacking, which would reorder sections). Home is the exception: a `SliverFillRemaining` page (no `LayoutBuilder` inside, which would break its intrinsic sizing) with `_DesktopHeader` ("Sunday morning", level), the large pick (`_Pick(large: true)`) and the quote on the left, and on the right `_RightNowPanel`: live `SituationControls` (the same widget the phone's "Right now" sheet uses), the reminders, and Started today / XP today / Day streak. Progress: level, stats, achievements (a 2-column `Wrap` from 600 px) left; reward shop, estimates, recent XP right. Settings uses `SidebarLayout`: section `SideItem`s on the left, the open section (state `_section`) on the right; narrower it is the original single list. Task editor: title, first step, steps and notes left; the Details rows (each opening its own sheet) right. Wrap-up: a Today summary strip (`_DoneChip`s), in-progress items two across, tomorrow's candidates in a 2-column grid, then the first-step field beside Done for today.

Every bottom sheet goes through `showAppSheet` (`widgets/ui.dart`): a modal bottom sheet on a phone, a centered `Dialog` at `wideBreakpoint` and up (and 640 px tall) with 24 px of top padding standing in for the drag handle. Builders are written as sheet content (own side padding, `Navigator.pop` to close). Quick add keeps its own dialog path (`QuickAddSheet.dialog`). Focus, note editor, weekly reset and errand run stay single-column. `test/widget/desktop_layout_test.dart` checks the side-by-side placement at 1440×900.

## Weekly reset, errand runs, company, hotkey, AI

- **Weekly reset** (`tasks/weekly_reset.dart`, pure; `weekly_reset_screen.dart`): `staleTasks` = todo/inbox, not repeating, not snoozed, `reviewedAt ?? createdAt` older than 7 days, oldest first. `resetDue` offers it on weekends unless done in the last 6 days, and on weekdays only for 5+ stale tasks and no reset in 14 days. The screen snapshots the queue on open; Keep / Make it smaller set `Task.reviewedAt` (a new nullable field), Not this week also sets `scheduledStart` +7 days, Let it go archives. Back restores the task as it was. Finishing stores `reset.lastAt` (device-local) and records a 20 XP bonus event (`ProgressController.recordBonus`, kind `partial`). Route `/reset`; Home banner and a Tasks pill.
- **Errand run** (`picker/errand_run.dart`, pure; `errand_run_screen.dart`): open errands (`requiresLeavingHouse`) in the picker's workspaces, grouped by `location` (trimmed, case-insensitive), stops ordered by urgency (priority weight + due-date ramp), greedily filled into the available time with `travelPerStop` = 10 min each ("2h+" counts as 4 h). Needs at least two errands. Home shows the banner only with "Can go out" on; `/errands` freezes the run when opened and ticks tasks off through `markDoneWithUndo` (so XP and Errand Runner count).
- **Company** (`focus/company.dart`, `company_widgets.dart`): `companyProvider` (device-local `focus.sound`, `focus.buddy`). `AmbientPlayer` (audioplayers, looping, `mixWithOthers` audio focus; every failure is silent) plays synthesized WAV loops from `assets/sounds/` (made by `tool/make_sounds.py`; WAV because compressed formats gap at the loop point). The focus screen plays on start, pauses/resumes with the timer and stops on dispose. `BuddyLine` rotates `buddyLines` every 4 minutes of elapsed time.
- **Desktop hotkey** (`outside/desktop_hotkey*.dart`): conditional import so web never sees `dart:io`, `hotkey_manager` or `window_manager`. On Mac/Windows (not in tests), `DesktopHotkey` registers Ctrl+Shift+Space system-wide; the handler restores/shows/focuses the window and sets `quickAddRequested`, which `OutsideBootstrap` already turns into Quick add. `hotkey.enabled` is device-local. The Linux runner would need `keybinder-3.0`; Linux isn't built.
- **AI breakdown** (`ai/breakdown.dart`, `ai_settings.dart`, `ai_settings_group.dart`): raw HTTP to the Messages API (there's no Dart SDK) with the user's key from `flutter_secure_storage` (`AiKeyStore`). Model `claude-opus-5-5` at `effort: low`, structured output (`output_config.format` JSON schema `{steps: string[]}`), `fallbacks: "default"` with the `server-side-fallback-2026-07-01` beta, and the `anthropic-dangerous-direct-browser-access` header for the web app. Handles `stop_reason: "refusal"`, 401/402/429/5xx and network errors with plain messages. `aiBlockReason` gates every call: key required; Work tasks only with `ai.allowWork` (device-local, confirmation dialog) and never when `scanForPhi` finds anything. Only title, notes and estimate are sent; steps are appended to the editor's checklist unsaved.

## First-step ideas and "Hold me to it"

- `capture/first_steps.dart` (pure): `stepIdeasFor(title)` matches whole words (plurals too) against an ordered list of task kinds (call, email, paperwork, bills, writing, cleaning, errands, planning, study, exercise, cooking, fixing; first match wins, so "call insurance" is a call) and returns three first-step ideas plus a checklist. The task editor shows the ideas under an empty first step; "Suggest steps" appends the checklist when `aiBlockReason` says the AI can't be used (no key, Work not allowed, PHI), otherwise it asks Claude.
- `focus/hold_me.dart`: `holdMeMessage` (Work tasks say "a work task", never the title) and `shareTextProvider`, which wraps `share_plus` and is overridden in tests. The button anchors the share popover to itself for iPad and Mac.

## Guide and example tasks (`features/guide/`)

`GuideScreen` (`/guide`) is static copy in sections, each with an optional button to the real screen (`go` for tabs, `push` for `/reset`, `showQuickAdd`). Android-only and desktop-only sections show only on those platforms. `ExamplesController` creates sample tasks, notes and a "Home" project in the device's primary workspace through the normal controllers (so they sync like anything else) and remembers their ids device-locally under `examples.ids` (`t:`/`n:`/`p:` prefixes). `remove()` deletes only those ids; XP earned on them stays (events are never rewritten). `examplesShowingProvider` drives the Today banner and the button labels. Entry points: the empty Today panel, Settings → Help, the guide itself.

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
- **Share → Gumption**: an `ACTION_SEND text/plain` intent becomes a `SharedText` request; `taskFromShare` turns the subject or first line into the title and the rest into notes, and Quick add opens prefilled.
- **Home-screen widgets** (`PickWidget.kt`, `res/layout/pick_widget*.xml`, `res/xml/pick_widget*_info.xml`): RemoteViews versions of Today's pick in the 1.1 look, in four sizes, each its own provider so the launcher lists them: `PickWidgetSmall` 2×1, `PickWidgetSquare` 2×2, `PickWidget` 4×2 (the original class name, so placed widgets survive), `PickWidgetLarge` 4×3 with "Next up" (`nextUpProvider`, two more that fit). One renderer fills whichever views a layout has; RemoteViews skips the rest. They never compute anything; `OutsideBootstrap` pushes the current pick (`updateWidget`) whenever it changes, so they show the last pick from when the app was open. Taps open `/` (card), `/focus/<id>?min=N` (Start, 5 min, or a Next-up row) or `/add` (+, or the medium widget's Add a task tile) through the same channel. Colours are resources in `values/` and `values-night/widget_colors.xml`, so widgets follow the phone's dark mode. The data (`OutsideBootstrap._cardData`) keeps the pre-1.1 keys `meta` and `step` beside the new `header`, `length`, `line1`/`line2` (the step you're on and the next), `work`, `fiveRoute` and `streak`; both native widgets fall back to the old keys, so a widget drawn from an older build's data still reads sensibly.
- Elsewhere `NoDeviceBridge` does nothing. Tests use a fake bridge.

## Capture (`features/capture/`)

- **Quick add** (bottom sheet): a title, How long? and Personal/Work; on a phone Priority, dread and Leave the house sit behind **More options** (open/closed remembered as `quickadd.more`), and typed extras fill them in anyway. The computer window always shows everything. A mic button (`voice_input.dart`, `speech_to_text`) dictates into the title, or new lines in Brain dump; it works on Android, Mac and in Chrome/Safari, and says so elsewhere. Its buttons are pinned above the keyboard and the nav bar. **Brain dump** creates one task per line. **Full task form** opens the editor with the draft.
- **Task editor**: every field, plus repeat settings and status.
- The sensitive info check (`PhiWarning`, Settings → Sensitive info check, off unless turned on) warns on Work tasks that look like someone's personal details. The AI helper refuses such Work text regardless of the switch.

## Theming (`core/theme/app_themes.dart`)

The 1.1 "Night sky" design (docs/design/handoff-1.1.md) in two brightnesses: `darkSpec` (Night) and `lightSpec` (Dawn). `ThemeSpec` holds the handoff's tokens (`bg`/`bgTop`, `raised`, `sheet`, `ink`/`ink2`/`ink3`, `line`/`line2`, `star`/`starDeep`/`starSoft`/`glow`, `accentText`, `personal`/`work`, `danger`, toast colours) plus older names kept as getters so untouched code still compiles (`background`, `surface`, `primary` = `accentText`, `accent` = `star`…). `nightSpec` is Night regardless of appearance, for the Progress sky. `AppSettings.appearance` (Dawn / Night / Match phone) picks `ThemeMode`. Text helpers: `display()` (Sora), `body()`, `caption()`, `overline()`, `button()`, `stat()`, `timer()` and `mono()` (Manrope with tabular figures); spacing `Gap.s1`–`s9`, radii `Radii`. Fonts are bundled TTFs in `app/assets/fonts/` (OFL, registered with `LicenseRegistry` in `main.dart`). Icons are Phosphor (Regular/Fill/Bold fonts, MIT) through the generated `Ph` constants in `core/theme/ph.dart` (`tool/make_phosphor.py`); `Icons.*` isn't used. Reduced motion follows the OS (`context.reduceMotion`).

Every route sits on `SkyBackground` (the bgTop → bg gradient with a faint dust of stars); scaffolds are transparent.

Shared pieces live in `widgets/ui.dart`: buttons (`PrimaryButton` with its 4 px pressed edge, `OutlineButton`, `QuietAction`, `SquareIconButton`), choices (`Pill`, `ChoiceGroup`, `Segmented`, `WorkspaceOption`, `OptionRow`/`OptionButton`, `SheetChoice`), sheet and dialog parts (`SheetTitle`, `OptionLabel`, `sheetPadding`, `ConfirmDialog`, `topBar`), lists (`Panel`, `Group`/`GroupRow`/`SwitchRow`, `RowValue`, `SectionTitle`, `FieldLabel`, `PageHeader`), `StarCheck` (the task check), `StarMark`/`Wordmark` (the four-point star drawn in code) and `navClearance()`. `widgets/task_chips.dart` has `TaskMeta` (the one-line meta: workspace dot, due date in `accentText`, length…) and date/duration formatters.

Navigation (`app.dart`): phones get the divider-tab bar (2 px `line2` rule, four hanging tabs, the active one raised and outlined with the Fill icon, and a 54 px "+" primary square); it stays on Settings with no tab lit. Settings opens from a gear at the top right of every tab (`features/settings/settings_button.dart`); `goToSettings` adds `?from=<tab>` so Settings' back and Android back return to that tab. At ≥ `wideBreakpoint` (760 px) a 220 px sidebar: wordmark, Add a task, the tabs, Settings, sync status. Tabs have tooltips (tests find them with `find.byTooltip('Tasks')`).

**Start → Focus**: `FocusScreen` first shows `StartedView` (`started_view.dart`: the star ignites, two rings, "A new star.") for 2.6 s (1.2 s with Reduce Motion, skipped when celebrations are Off; a tap skips it), then the session. The timer is `OrbitTimer` or `BlockTimer` (`timers.dart`, Settings → Focus timer, `AppSettings.timerBlocks`). Celebrations (`celebration_overlay.dart`) are cards in order: Finished, Level up, Achievement; starts show no card (the Started screen is the celebration) unless they bring an achievement or level, which come as a toast.

## Web and iPhone specifics (`app/web/`, `core/safe_area/`)

- `index.html`: home-screen metadata (`apple-mobile-web-app-*`, `apple-touch-icon.png`) and registers `offline.js`.
- `offline.js`: network-first service worker that falls back to the saved copy after 4 s or when offline. It never serves stale code when the network works.
- `flutter_bootstrap.js`: custom, so Flutter's deprecated service worker isn't registered. That worker unregisters all workers and reloads the page.
- `WebSafeArea`: Flutter web reports no safe-area insets and rewrites the viewport tag, dropping `viewport-fit=cover`. `insets_web.dart` re-adds `viewport-fit=cover`, measures `env(safe-area-inset-*)` with a hidden element, and feeds the values into `MediaQuery`.

## Tests (`app/test/`)

| Folder | What |
|---|---|
| `core/`, `data/`, `features/` | Pure logic: HLC, Task JSON, picker scoring, XP, achievements fold, quotes, sensitive info check (`phi_guard.dart`), recurrence, nudge/follow-up/wrap-up planning, estimate calibration, share-to-task parsing |
| `sync/` | Replica merge laws, sync engine against `FakeRemote` (multi-device convergence, ping-pong, offline edits, corrupt files), sync controller with a fake auth |
| `widget/` | Full-app flows (`pumpApp`), waiting → check back, wrap-up pin, share/widget requests with a fake bridge (`new_features_test.dart`), light/dark/system on a phone, settings migration, phone-width overflow at 1.0×/1.3× text, back navigation, Quick add → full form, reminders with `FakeReminders`, Mark done/Delete with Undo, startup error screen |

Inject time with `clockProvider` and storage with `keyValueStoreProvider` (`MemoryStore`).
