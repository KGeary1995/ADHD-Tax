# Decisions

Why things are the way they are. Read before "simplifying" something that looks odd. Newest first. Each entry: decision, why, and what would make us revisit it.

### 2026-10-25 — More sync services: iCloud first, then Microsoft; not Samsung
Google-only sync shut out people who live in Apple's or Microsoft's world. The owner chose **iCloud first** (iPhone users first), **Microsoft OneDrive next** (every platform, the same "hidden app folder" model as Google). **Samsung isn't possible**: Samsung Cloud has no API for other apps' data; Samsung phones are Android, so Google or Microsoft covers them. iCloud uses an **iCloud Drive container** (files), not CloudKit: the engine's one-file-per-device model maps onto it directly, there's no CloudKit schema to deploy to production, and devices never write the same file, so iCloud never has conflicts to resolve. Trade-off, stated in the app: an iCloud workspace can't reach Android, Windows or the web. Each workspace picks one service per device; Personal on iCloud and Work on Google is fine.

### 2026-10-25 — Written for everyone, not for a clinic
Before the App Store listing goes wider, the owner judged that copy about patients, clinics, insurance and "your clinic's Google Workspace account" told everyone else the app wasn't for them. User-facing text, example templates, the screenshot demo data and the privacy/terms pages are now neutral (work, home, a quarterly report). The owner's own clinic setup notes stay in README, and the "No PHI anywhere" rule for this repo stands.

### 2026-10-25 — Sensitive info check: neutral, and off unless turned on
The patient-info guard became the **Sensitive info check**: the same patterns, labelled without medical terms ("Someone's name", "Record or account number"), and off for new installs so the app never implies it's for clinics. Saved settings keep their value (the key is still `phiGuard`, so existing devices that had it on stay on). The AI helper's refusal to send Work text that looks like personal details doesn't depend on the switch. Revisit if users ask for it on by default.

### 2026-10-25 — Bring the dry wit back
The 1.1 redesign moved quotes to one grey line at the foot of Today and replaced several of the app's own lines with plainer copy; the owner missed the voice. Quotes are back under the focus timer, Today weights humor as much as "starting" lines, footnote quotes use `ink2`, the Finished card carries one dry aside, and the commit sheet keeps "it's the dread talking". The voice: dry, on the user's side, never shaming (see No shame mechanics).

### 2026-10-25 — 1.1 "Night sky" redesign, built from the owner's handoff
The owner commissioned a full high-fidelity redesign (Claude Design) and handed it over as two zips: an HTML prototype, 68 phone states in Night and Dawn, widgets, Mac/iPad, icon and store screenshots, and a spec (kept as docs/design/handoff-1.1.md). The idea: Today shows one task and one next step, and Start lights a star; Progress is a sky of the stars you've lit. It replaces the teal 2026-10-18 look entirely: Sora + Manrope, Phosphor icons, gold on deep navy (Night) or on cream (Dawn). Implemented as tokens on the existing `ThemeSpec` (old token names kept as getters) so features didn't need rewriting, only restyling. Ships as 1.1 after Apple approves 1.0, so the version under review isn't changed under it.

### 2026-10-25 — Phosphor icons vendored, not the package
`phosphor_flutter` subclasses `IconData`, which this Flutter makes final, so it doesn't compile. The three font weights are bundled and `tool/make_phosphor.py` generates `Ph` constants from the package's codepoint table: same icons, tree-shaken, no dependency.

### 2026-10-25 — Starting shows a "Started" screen; starts don't get a celebration card
The design makes the start itself the moment (the star ignites, "A new star.", 2.6 s, tap to skip). An XP card on top of that would be a second interruption at the exact moment the user has just got going, so starts show no card; an achievement or level earned by a start comes as a toast after the Started screen. Celebrations Off skips the Started screen too.

### 2026-10-25 — Mac/iPad Tasks: list + detail pane instead of a filter sidebar
The handoff's Mac board shows the list beside the selected task, with the filters as pills. That lets you read a task, tick a step or start it without opening the editor, which is the slow part on a computer. The second sidebar (workspace/project counts, Weekly reset) went: workspaces and projects are pills and the Projects sheet, and Weekly reset is still offered on Today when it's due and in the guide. The pane appears from 880 px of content, lower than other screens' 980, so an iPad in landscape gets it.

### 2026-10-25 — First-step field stays put while you add steps
The editor hides "First 2-minute step" for tasks that have a checklist (the next unticked step is the first step). Hiding it the moment the first step was added made the page jump under your finger, so it's decided once, when the editor opens.

### 2026-10-25 — App icon: the star (supersedes "tangle → arrow")
The handoff's icon: a four-point star with curved sides, 52% of the canvas, gold with a soft glow on a navy radial. iOS gets the default, dark and tinted variants (single-size 1024 asset catalog); Android gets an adaptive icon (background, foreground, monochrome) plus the old square for older launchers. All drawn by `tool/make_icons.py` from the handoff's SVG path, so they stay in step.

### 2026-10-21 — Backup files carry settings, but not per-install choices, consents or secrets
The owner asked for settings in the backup. They're replaced on restore (there's no meaningful merge for "celebrations: party"), behind a checkbox. "Show on this device" stays out because the same person restores into both the personal and the work-profile copy; "Use AI on Work tasks" stays out because it's a consent that should be given on each device; the API key and Google tokens stay out because backup files are emailed and left in Drive. Restore only accepts the allowed keys, so a hand-edited file can't plant anything else.

### 2026-10-21 — AI breakdown: user's own key, raw HTTP, off for Work, PHI never sent
"Break it down" calls the Anthropic Messages API directly from the app with a key the user pastes in, stored in the OS keychain and never synced or put in backups. No server means nothing to run or secure, and the cost lands on the person using it (a fraction of a cent a task). Dart has no official Anthropic SDK, so it's a plain HTTP call. Work tasks are excluded unless the user turns them on after a "no patient details" confirmation, and even then a Work task the PHI guard flags is never sent: the guard is a warning elsewhere but a hard stop here, because this is the one place text leaves the user's own accounts. The model is the current default Opus at low effort with structured output, so the reply is always a clean list. Revisit if a shared clinic key or a server proxy is ever wanted; that needs a BAA conversation first.

### 2026-10-21 — Company sounds are synthesized WAV loops, mixed with other audio
Brown noise, rain (pink noise) and fan are generated by `tool/make_sounds.py`: no recordings means no licensing, and they're reproducible. WAV (about 860 KB each) because MP3/AAC add silence at the loop point. The player asks for "mix with others" audio focus so it never stops the user's own music or a call. The buddy is a line of text, not a fake "N people online": pretending other people are present would be dishonest.

### 2026-10-21 — Weekly reset asks one task at a time
A list of 20 stale tasks is exactly the wall that makes people close the app. One card with four equal choices, including "Let it go" framed as a valid outcome, keeps it to a few seconds per task and avoids shame. Offered on weekends (or for a big pile after two weeks), never as a red badge.

### 2026-10-19 — Typed extras are parsed by rules, offline, with tap-to-undo chips
"Call insurance tomorrow 2pm 15 min #billing" is parsed by `capture/quick_parse.dart`, a set of regular expressions, not an AI model: it works offline, costs nothing, sends nothing anywhere (Work tasks never leave the device this way) and is predictable. Wrong guesses are the risk, so everything understood is shown as a chip and one tap puts the words back in the title (`ignore` keys), and the riskier words need context: "sat"/"sun" only count after "on", "by", "next"…; a bare number only counts as a time after "at"; a single `!` is ignored. A value the user picks by hand in the sheet beats a parsed one. A `#tag` matching a project's name files the task into that project rather than adding a tag. Revisit with the optional Claude feature (Phase 6), which could take over the messy cases.

### 2026-10-19 — A checklist is one string field; the next unticked item is the first step
`Task.checklist` is newline-separated `[ ] step` / `[x] step` text, not a list or a record per step, for the same reason as `Note.tags`: replica fields compare by value, so a list would look changed on every save. The cost is that ticking two different steps on two devices at the same moment keeps only one device's version of the list (last writer wins on the whole field); for one person, rare and harmless. Once a task has a checklist, its next unticked item replaces `firstStep` everywhere `startLine`/`nextStep` is used (Home card, focus, widget, wrap-up), since a static first step would go stale after the first tick. A repeating task's next copy starts unticked.

### 2026-10-19 — Spending coins is an XP event with negative coins
Reward-shop purchases are `ProgressKind.redeemed` events (coins < 0, no XP), never an edit to a balance, so they sync and merge like all progress and Undo is a tombstone. They don't count as an active day, don't appear in Recent XP, and can't lower XP or level: spending must never feel like losing progress. Older builds read the unknown kind as `partial`, which still subtracts the coins (they'd also count the day as active; harmless). Two devices spending the last coins at once could dip below zero; the shop just shows fewer coins until more are earned. Rewards and templates are synced records (`rewards`, `templates` collections) in the workspace they were made in.

### 2026-10-19 — "Show on this device" instead of separate apps
On Android the clinic account lives in the work profile, so the owner runs a second copy of the app there for Work. Rather than a separate build, each install can show Personal, Work or both. It filters at the providers, so every screen and background feature follows without per-screen checks, and it hides rather than deletes, so switching back is lossless. Device-local because two installs on the same phone want opposite settings.

### 2026-10-19 — Notes and projects, not Monday.com
The owner asked for note taking and "more like Monday.com". Monday's custom columns, statuses and views would turn the app into another system to maintain, the opposite of its purpose (starting, not organizing). We built what helps starting: notes that become tasks in one tap and live next to the task they're about, projects shared by tasks and notes, tags (chips plus #hashtags, because Keep/Apple Notes felt too flat to organize), and a four-column board whose columns are just task statuses, so there's nothing new to keep in sync with reality. "Pick for me" still ignores projects. Custom columns, table and timeline views were deliberately left out.

### 2026-10-19 — Devices re-upload after merging
Each device's sync file is a full copy of its replica. Before, a device only re-uploaded after its own edits, so a task deleted or moved to Work on the phone stayed readable in the PC's file in the Personal account until the PC edited something. Now a device also re-uploads after a merge that changed anything. Cost: one extra small upload per change per device; the following round merges nothing, so it settles.

### 2026-10-18 — Backup file restores by merging, not replacing
Until Google sync is set up, tasks live only on the device, so the owner asked for a backup they control. The file holds the full replicas with their clocks, and restoring is the same CRDT merge sync uses. A "replace everything" restore would silently throw away anything done since the backup, which is the kind of loss that kills motivation; merging can't lose newer work and is safe to repeat. On phones the web app saves through the share sheet rather than a download, because iPhone downloads are hard to find again.

### 2026-10-18 — Native iOS app through TestFlight
The owner chose native for iPhone and iPad once the web app's limits were clear (no reminders, widgets or Share). Distribution is TestFlight internal testing: no App Store review, $99/yr. CI signs with Xcode automatic signing through an App Store Connect API key, so no certificates live in the repo or need a Mac. The share extension queues text in the App Group and the app opens Quick add on its next resume, because extensions can't open their app. Widget taps use `unstuck://app/<route>` and Flutter's own deep linking (go_router routes, plus a `/add` redirect), while Android keeps the method channel. The web app stays as the no-account option. Supersedes "iPhone = home-screen web app".

### 2026-10-18 — Widget shows the app's last pick; it never computes
A home-screen widget can't run Dart, and re-implementing the picker in Kotlin would drift. The app pushes its current pick to the widget whenever it changes, so the widget can be a little stale (it reflects the situation the app last had). Good enough for a one-tap Start; tapping the card opens the app for a fresh pick.

### 2026-10-18 — MainActivity is singleTask
Needed so "Share → Gumption" and widget taps reach the one running app (via `onNewIntent`) instead of starting a second copy inside the sharing app's task, which could write the same replicas concurrently. Trade-off: the template's empty `taskAffinity` (a task-hijacking mitigation) is gone; acceptable for a sideloaded personal app.

### 2026-10-18 — Real task lengths use the median of the last 30 timed tasks
The median ignores the odd task left running over lunch; the window follows you as you get better at estimating. Nothing changes until 5 timed tasks, or when you're within ±15%, so the picker doesn't jitter on noise. Only focus-timer minutes count (`actualMin`); tasks marked done from the list have no timing.

### 2026-10-18 — Tomorrow's pick is device-local
The wrap-up's pinned task lives in settings, not the synced replica: it's a nudge for the phone you'll pick up in the morning, and a new synced field would have to be designed for conflicting pins across devices. Revisit if the owner wraps up on the Mac and starts on the phone.

### 2026-10-18 — One look (light + dark) instead of 9 themes
*Superseded in look by the 1.1 redesign (2026-10-25); the one-identity, two-brightness idea stands.*
The owner said the app "feels extremely AI made". A Claude Design canvas (https://claude.ai/artifact/558G1Ms1eMZAsD1UHHwFfB) explored three directions; the owner picked a mix of B (situation as one line, quiet tiles) and C (teal task card, floating pill nav), asked for a one-line headline and a white light background. Nine themes made every screen generic, so there is now one identity: Bricolage Grotesque / Geist / Geist Mono, near-black or white, one teal. Appearance is Light / Dark / Match phone; old theme choices map to light or dark so nobody's screen flips unexpectedly. Fonts are bundled (not fetched) so the app looks the same offline and on every platform.

### 2026-10-22 — Keep "Gumption" despite a pending app trademark; don't file our own
A USPTO search found a pending intent-to-use application for GUMPTION in class 9 (a kids' entrepreneurship and financial-literacy app, filed 2026-09-01), plus a registered GUMPTION for staffing and recruiting software. The goods differ from a task starter for adults, so using the name is a low-to-moderate risk, but registering it ourselves would likely fail behind the earlier filing. For a free app shared with friends that's acceptable, and a rename is cheap because user-visible names are kept separate from internal ids. Revisit before charging money. Details in docs/STORE_RELEASE.md, "Trademark check".

### 2026-10-22 — Phone declutter: fewer things on screen, nothing removed
The owner felt the phone version was busy. Tasks had four rows of filters before the first task, Quick add asked five questions, and Today showed about ten things around the one button that matters. Every control stayed reachable, one tap further away: Tasks' filters moved into a sheet, task rows show only due date, length and who it's waiting on, Quick add's priority/dread/errand went behind "More options" (remembered), the check-back banner became a badge, and the done/XP counts left Home (they're on Progress and in the level pill). **Personal/Work stays visible in Quick add on purpose**: hiding it would make it easy to file a Work task into the personal Google account. Computers were left as they are; they have the room.

### 2026-10-22 — Renamed to Gumption ("Gumption: Task Starter" in the stores)
Before going public, a search found several ADHD apps already called Unstuck ("Unstuck: ADHD Planner", "Unstuck: ADHD Focus & Tasks" and others), so the name couldn't be owned or found in the stores. The owner picked **Gumption**: an everyday word for the drive to get going, which is the exact problem the app solves, with no app found under that name. "Task Starter" after the colon is for store search and says what the app is. Same rule as the first rename: only user-visible strings changed. The Unstuck-era internal ids stay (`unstuck/android` channel, `unstuck://` scheme, the `unstuck-backup` file kind so old backups restore, iOS target folders, the `unstuck` Cloudflare project and so its web address), and CI publishes the APK as both `Gumption.apk` and `Unstuck.apk` so links already shared keep working. The icon (tangle → arrow) still fits and was kept. Dart class names were renamed (`GumptionApp`, `GumptionMark`) since nothing persists them; Swift class names were left because nothing here can compile them.

### 2026-10-18 — Renamed to Unstuck; internal ids keep "adhd tax"
The owner wanted a name that says what the app does and is neutral on a work phone at the clinic ("ADHD Tax" announced ADHD to anyone glancing at the screen). Only user-visible strings changed: app labels, window titles, in-app text, notifications, backup filenames, release asset names (`Unstuck.apk`, `Unstuck-macOS.zip`) and the Cloudflare project default (`unstuck`, set before it was ever deployed, so no iPhone data was tied to the old address). The Android applicationId, Mac bundle id, Dart package, repo name, web token key and repeat-copy id seed keep the old name: changing them would install a separate empty app, break update-over-install and the Google Android OAuth client, or make devices on different builds create duplicate repeating tasks. *Revisit only with a planned migration (e.g. before a store release).*

### 2026-10-18 — Icon: tangle → arrow
*Superseded by the star icon (2026-10-25).*
A loop straightening into an arrow ("stuck, then moving"), teal on deep teal, chosen by the owner from four drawn concepts. Generated by `app/tool/make_icons.py`, which centres and sizes the mark from its measured pixels.

### 2026-10-18 — Mac builds only on demand
macOS runners cost 10× Actions minutes on a private repo (~100 of 2,000 free monthly minutes per build). They run on `[mac]` commits, `main` and Run workflow. *Revisit if the repo goes public (free minutes) or the owner pays for Actions.*

### 2026-10-18 — iPhone = home-screen web app on Cloudflare Pages
The owner chose free over the Apple Developer Program ($99/yr). Costs: no notifications on iPhone, Google sync tokens last ~1 h, and the app needs a host. Cloudflare Pages was picked over Netlify because CI can create the project itself (only a token and account id needed, no drag-and-drop) and bandwidth is unlimited. *Revisit (TestFlight + native iOS) if reminders on iPhone become important.*

### 2026-10-18 — Generated app icon
`tool/make_icons.py` draws one design for every platform, so icons are reproducible without design tools. (First design: a timer ring around a start triangle; replaced the same day, see above.)

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

## Built-in step ideas before (and instead of) server-side AI

Competitors lead with AI task breakdown run on their own servers and paid for by subscription. The app has no server, and its AI needs the user's own Anthropic key, which most people won't have. Rather than add a server (cost per use, a subscription, and holding users' task text), the app ships a small rule-based library of first steps and checklists for common task kinds. It covers the moment that matters (a blank "first step" field), works offline and sends nothing anywhere. The AI path stays for people with a key. Revisit only together with a paid tier, and treat any server that sees task text as needing a new privacy review.

"Hold me to it" uses the phone's share sheet rather than an in-app buddy system for the same reason: no accounts, no server. A Work task's title is never put in the message, since titles can name people or cases.

## Links and Related instead of a graph view (2026-10-23)

The owner asked about an Obsidian-style graph view. It works against the product: Gumption exists to show one task and hide the rest, and a graph shows everything at once, is mostly something to admire and fiddle with (productive procrastination), and is unusable on a phone. What makes Obsidian useful is the linking, so the app got that instead: `[[links]]` in notes, a Related section on each task (one hop, as a list), and the visual reward moved to where attention is wanted: **Your sky** on Progress, a star per start. A per-project graph on desktop stays possible later but isn't planned.

Links are matched by name and stored as text, not ids, so no synced field changed and old builds degrade to visible brackets. They never cross workspaces, so a Personal note can't point into Work.
