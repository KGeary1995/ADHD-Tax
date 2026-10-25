# Store listing copy and form answers (drafts)

Drafts for Google Play Console and App Store Connect (the App Store answers were entered from a copy-paste sheet on 2026-10-23). Edit the wording to taste, but keep the facts: every claim here matches what the app does today (docs/ARCHITECTURE.md). Avoid medical words (*treat*, *therapy*, *symptoms*, *diagnosis*); they trigger health-app review on both stores.

Shared facts:

| Field | Value |
|---|---|
| Developer | Individual account |
| Price | Free, no in-app purchases, no ads |
| Support email | info@ophthalmicacademy.com |
| Website | https://unstuck-4o8.pages.dev/about/ |
| Support URL | https://unstuck-4o8.pages.dev/support/ |
| Privacy policy URL | https://unstuck-4o8.pages.dev/privacy/ |
| Terms of use URL | https://unstuck-4o8.pages.dev/terms/ (optional on both stores; Apple otherwise uses its standard licence agreement) |
| Category | Productivity |

## Google Play

**App name** (30): `Gumption: Task Starter`

**Short description** (80): `Can't start? Gumption picks one task, shrinks it to a first step and times it.`

**Full description** (4,000):

```
Stuck staring at your to-do list? Gumption is a task starter. It doesn't add another list to manage. It picks the one task that fits right now and makes starting it easy.

ONE TASK, PICKED FOR YOU
Tell it how much time you have, whether you can leave the house and how much energy you've got. Gumption picks one task and says why: due soon, fits your 30 minutes, been sitting a week. Not feeling it? Tap "Not this one".

A FIRST STEP SMALL ENOUGH TO START
Every task can have a two-minute first step, like "find the number and put it on screen". Stuck on what that should be? Gumption suggests ideas for common tasks like calls, forms, bills and errands. It works offline, with no AI account needed.

A TIMER THAT MAKES STARTING THE GOAL
Start the full task or just five minutes. A visual timer runs down, and you can stop when it ends. That still counts.

XP FOR STARTING, NOT JUST FINISHING
Starting earns XP. So do finishing, dreaded tasks and getting through an errand run. Spend coins on rewards you choose. Streaks have grace days and never reset to zero.

MADE FOR PEOPLE WITH A REAL JOB
• Personal and Work kept apart, each syncing to its own Google account
• Waiting on someone? Park it and get a nudge to check back
• Errand runs group the tasks you can do while you're out
• Learns how long your tasks really take
• Evening wrap-up picks tomorrow's first task tonight

CAPTURE IN FIVE SECONDS
Type "call the bank tomorrow 2pm 15 min urgent" and it fills itself in. Brain dump a whole list at once, speak it, or share text from another app. Home-screen widgets show your next task with a Start button.

PRIVATE BY DESIGN
No account, no ads, no tracking, and no server. Your tasks stay on your phone. Turn on sync and they go to your own iCloud, Google Drive or OneDrive, in a folder only Gumption uses.

Also on iPhone, iPad, Mac, Windows and the web.
```

**App category:** Productivity. **Tags:** to-do list, productivity, time management.

**Graphics (made 2026-10-23):** 512×512 icon (`app/web/icons/Icon-512.png`); 1024×500 feature graphic (headline "Don't decide. Just start." beside a phone showing Today, drawn with the app's bundled fonts); five phone screenshots at 1242×2208 (`shoot.mjs … 414 736 --scale 3`). Play rejects screenshots whose long side is more than twice the short side, so the App Store's 6.3" set (1206×2622) can't be reused. No tablet screenshots yet. **For 1.1:** the new icon is `docs/store/icon-512.png` (drawn by `make_icons.py`); the feature graphic and Play screenshots still show the old look and need redoing before 1.1 goes to Play.

**Full description on Play:** the last line reads `Also on iPhone, iPad, Mac and the web.` (Windows dropped: it's an unpublished artifact).

### App content answers (Policy → App content)

| Form | Answer |
|---|---|
| Privacy policy | https://unstuck-4o8.pages.dev/privacy/ |
| App access | All functionality is available without special access (Google sign-in is optional and only for sync) |
| Ads | No ads |
| Content rating | Category: *Utility, Productivity, Communication or Other*. No violence, sexual content, language, controlled substances or gambling. Users can't talk to each other in the app (Hold me to it uses the phone's own share sheet). No location sharing, no purchases. Expect **Everyone** |
| Target audience | 18 and over. Not designed for children |
| News app | No |
| Health apps | None of the health features apply. It's a productivity app |
| Financial features | None |
| Government app | No |
| Data safety | See below |

### Data safety (draft)

Play counts anything sent off the phone as "collected", even when it goes to the user's own Google account. We declare it rather than argue the point: under-declaring is what gets apps pulled.

| Question | Answer |
|---|---|
| Does the app collect or share any of the required user data types? | **Yes** |
| Is all collected data encrypted in transit? | **Yes** (HTTPS to Google and Anthropic) |
| Do you provide a way for users to request that their data be deleted? | **Yes**: https://unstuck-4o8.pages.dev/privacy/#deleting (the "Deleting your data" section). The developer holds no copy |

Data types:

| Type | Collected | Shared | Optional? | Purpose | Why |
|---|---|---|---|---|---|
| Personal info → Email address | Yes | No | Optional | App functionality | Shown so you know which Google or Microsoft account sync uses; stored in your own Drive or OneDrive sync file |
| App activity → Other user-generated content | Yes | No | Optional | App functionality | Tasks and notes, sent only to your own Google Drive, OneDrive or iCloud when sync is on, and one task's text to Anthropic when you use the AI helper with your own key (a user-initiated request, so not "sharing") |

Not collected: location, contacts, photos, audio (voice typing uses the phone's speech service; the app never receives audio), app interactions, diagnostics, identifiers.

### Sensitive permissions

**Exact alarms (`USE_EXACT_ALARM`).** Declaration text: *Gumption's core feature is a focus timer. When a timed session ends the user must be alerted at that moment, including with the screen off; a late alert breaks the session. The app schedules only user-started timers and the reminders the user turns on.* If Google refuses, switch to `SCHEDULE_EXACT_ALARM` (asks the user once) — see docs/STORE_RELEASE.md.

## Apple App Store

| Field | Text | Limit |
|---|---|---|
| Name | `Gumption: Task Starter` | 22/30 |
| Subtitle | `Start tasks. Built for ADHD.` | 28/30 |
| Keywords | `adhd,focus,timer,todo,planner,procrastination,productivity,routine,executive function,habit,start` | 97/100 |
| Promotional text | `Stuck staring at your list? Gumption picks the one task that fits your time and energy, shrinks it to a two-minute first step, and gives you XP just for starting.` | 162/170 |
| Description | The Google Play full description with two changes: "stay on your device" (not "phone"), and the last line reads `Also on Mac and the web.` (Apple rejects metadata naming other platforms, guideline 2.3.10) |  |
| Category | Productivity (secondary: Lifestyle) |  |
| Age rating | Answer "None" throughout. Expect **4+** |  |
| Copyright | `2026 Kyle Geary` (the name on the Developer ID certificate) |  |
| Version | `1.0.0` (1.1 builds say `1.1.0`; create version 1.1.0 in App Store Connect for them), matching the build's `CFBundleShortVersionString` from `pubspec.yaml`; App Store Connect defaults to "1.0", which hides the build |  |
| Screenshots | App Store Connect (Oct 2026) requires the **6.3" iPhone** set, 1206×2622 (`shoot.mjs … 402 874 --scale 3 --iphone`); 1290×2796 was rejected there as "File dimensions are invalid". 6.9" (1320×2868: `440 956 --scale 3`) is optional. iPad 13" 2048×2732 (`… 1024 1366`) is required because the app runs on iPad |  |
| Screenshots for 1.1 | The redesign's captioned set (`app/tool/screenshots/store_frames.py`, steps in its header): six iPhone frames at 1206×2622 (Today, Started, Smaller, Focus, Progress, and the sync chooser: "Syncs to your cloud. Not ours.") and three landscape iPad frames at 2732×2048. Remade 2026-10-25 evening from the current app: the Settings gear on Today, the iCloud / Google / OneDrive chooser, and neutral demo data throughout (the iPad Tasks list no longer shows a prescription or dentist task). Upload them with the next version (1.1 or later), not before: 1.0 shows the old look |  |
| What's New (1.1) | `A whole new look: Today shows one task and its next step, starting lights a star, and your progress fills a night sky. New icon, widgets that follow light and dark mode, and on iPad, Tasks shows the selected task beside the list.` |  |
| iPhone Duo | Left empty for 1.0.0 (optional until April 2027, for apps built with the iOS 27.1 SDK or later). Sizes: outer 1398×2034, inner 2007×2853. Add them once the layout has been seen on a real Duo, before that deadline |  |

### App Privacy (draft)

Apple's labels follow the same reasoning as Play's Data safety.

| Data type | Collected | Linked to the user | Used for tracking | Purpose |
|---|---|---|---|---|
| Contact Info → Email Address | Yes (only with Google sync) | Yes | No | App Functionality |
| User Content → Other User Content | Yes (sync and the optional AI helper) | Yes | No | App Functionality |

Everything else: not collected.

### Review notes (App Review Information → Notes)

```
Gumption needs no account. Everything works on the device straight away.

Sync (Settings → Sync) is optional and only stores the user's own tasks in their own iCloud (no sign-in), Google Drive (a hidden app folder) or OneDrive (the app's own Apps/Gumption folder). There is no Gumption account and no server, so Sign in with Apple isn't applicable: the Google or Microsoft sign-in grants access to that storage, it doesn't create an account.

The AI helper (Settings → AI helper) needs the user's own Anthropic API key and can be skipped. Without a key, "Suggest steps" uses suggestions built into the app.

The microphone is used only while the mic button in Quick add is on, to type a task with the system speech recognizer.

To see the app with sample data: Settings → Help → Try with example tasks.
```

### Answer to Apple's "Information Needed" (Guideline 2.1, 2026-10-23)

Apple asked a new developer account for a screen recording on a physical device plus six written answers, and wants the same text in App Review Information → Notes for future submissions. This replaced the shorter review notes above.

```
Hello, and thank you for reviewing Gumption.

1. Screen recording
The attached recording was made on an iPhone running the latest iOS and starts by launching the app. It shows the typical flow: Today picks one task, the user starts it, the focus timer runs, and finishing it awards XP; adding a task with Quick add; the Tasks list; Progress and the reward shop; and the optional Google sign-in in Settings → Sync, followed by disconnecting.

Gumption has no account registration. The only sign-in is the optional "Connect" in Settings → Sync, which lets the app keep the user's tasks in a hidden app-data folder in their own Google Drive. It creates no account with us, and we run no server, so there is no account to delete. Disconnecting is shown in the recording, and the privacy policy explains how to remove the synced copy from Google Drive: https://unstuck-4o8.pages.dev/privacy/#deleting

Nothing is shared between users: tasks and notes are private to the person who wrote them, so there is no user-generated content to report or block. There is no paid content and no in-app purchase.

2. Purpose and audience
Gumption is a task starter for adults who find it hard to begin tasks, including people with ADHD. Instead of another long to-do list, it picks the one task that fits the time and energy the user has right now, shrinks it to a two-minute first step, and runs a visual focus timer. Starting earns XP, so the reward comes at the hardest moment: getting going. It is a general consumer productivity app, not built for a specific business or organization, and it makes no medical claims.

3. How to use it
No login, credentials or sample files are needed. Everything works offline on the device.
- Sample data: Settings → Help → Try with example tasks.
- Today shows one task. Tap Start (or 5 min) to run the focus timer, then Done to finish and earn XP. "Not this one" picks another task.
- The + button adds a task. Typing "call the bank tomorrow 2pm 15 min urgent" fills in the date, length and priority.
- Tasks, Notes, Progress and Settings are in the bottom bar.
- Optional: Settings → Sync → Connect, with any Google account, syncs tasks between the user's devices.
- Optional: Settings → AI helper needs the user's own Anthropic API key and can be skipped. "Suggest steps" in a task works without it.
- Home Screen widget: touch and hold the Home Screen → Edit → Add Widget → Gumption.

4. External services
- Google Sign-In and the Google Drive API (the drive.appdata scope only): optional sync of the user's own tasks to a hidden app folder in their own Google Drive.
- (From 1.2) iCloud Drive: optional sync to a hidden folder of the user's own iCloud, with no sign-in. Microsoft sign-in and Microsoft Graph (Files.ReadWrite.AppFolder, User.Read): optional sync to the app's own Apps/Gumption folder in the user's OneDrive.
- Anthropic API: the optional "Break it down" helper, only when the user enters their own API key. The text of one task is sent when the user taps the button.
- Apple's Speech framework for voice entry in Quick add, and local notifications for the focus timer and reminders.
There are no analytics, advertising or payment services, and no servers of our own.

5. Regions
The app works the same in all regions. It is in English.

6. Regulated industries and third-party material
Not applicable. Gumption is a general productivity app. It is not in a regulated industry, gives no medical or financial advice, and contains no protected third-party material; the motivational quotes were written for the app.
```
