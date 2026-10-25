# Gumption

*Formerly "Unstuck", and before that "ADHD Tax". The GitHub repo keeps its old name. In the app stores it will be **Gumption: Task Starter**.*

**Pick one task. Start it. Level up.**

A task app built for ADHD brains that struggle to *start*. Most to-do apps help you organize. This one makes the decision for you, shrinks the first step until it's easy, and rewards you the moment you begin, not only when you finish.

Runs on Android, iPhone (as a home-screen web app), Mac, Windows and the web from one Flutter codebase. The full product plan and roadmap are in [docs/PLAN.md](docs/PLAN.md).

## What works today (Phase 1)

| Feature | What it does |
|---|---|
| **Pick for me** | Tell it how much time you have, whether you can leave the house, your energy, and Personal/Work. It returns **one** task with a reason ("Due in 19 hours · Critical priority"). |
| **Smart scoring** | Priority, deadline urgency (hard deadlines ramp sooner), staleness (avoided tasks resurface), how well the task fills your window, energy match, "eat the frog" boost for dreaded tasks in the morning, and a skip penalty that wears off within a day. |
| **Reroll limit** | "Not this one" twice, and it asks you to pick one of three and commit. Endless rerolling is the dread talking. |
| **Overwhelmed button** | Hides everything and gives you one easy task for 5 minutes. |
| **Focus screen** | Shows only the *first step*, a Time-Timer style shrinking disc, and a rotating quote. **Just 5 minutes** mode asks "keep going?" when the 5 minutes are up. |
| **5-second capture** | Quick add (Ctrl+N) needs only a title. **Brain dump** turns a pasted list into tasks, one per line. "Add & start now" skips the list entirely. **Full task form** opens the complete editor (first step, due date, notes, energy) with what you've typed so far. |
| **Type it the way you'd say it** | "Call the bank tomorrow 2pm 15 min #money" fills in the due date and time, length and tag. Also weekdays, "tonight", "in 3 days", "4/15", "at 5", "1h 30m", "urgent" or `!!`, `#work`/`#personal`, and a `#tag` matching a project files it there. What it understood shows as chips; tap one to keep those words in the title. Offline, rule-based, no AI. |
| **Checklists** | Steps inside a task. The next unticked step is the first step on Home and the focus screen (with **Step done**). Repeating tasks come back unticked. |
| **Weekly reset** | On weekends Home offers to sort tasks that have sat untouched for a week, one at a time: Keep it, Make it smaller, Not this week, or Let it go. +20 XP. Also on the Tasks tab any day. |
| **Errand run** | With "Can go out" on, Home suggests the errands that fit your time, grouped by place, as one trip to tick off. |
| **Company while you work** | Headphones on the focus screen: background sound (brown noise, rain, fan) and an optional buddy line, like someone working at the next desk. |
| **Quick add from anywhere (Mac, Windows)** | Ctrl+Shift+Space (⌃⇧Space on a Mac) in any app brings Gumption forward with Quick add open. |
| **Break it down with AI (optional)** | In a task's editor: Claude splits the task into 3–7 small steps for the checklist. Uses your own Anthropic API key (Settings → AI helper), kept on the device. Off for Work tasks unless you turn it on; Work tasks that look like they contain patient details are never sent. |
| **Templates** | Reusable checklists and notes (Settings → Templates; **Template** in Quick add; **From a template** on Notes). One-tap examples: Start the workday, Meeting notes, Weekly reset. Save any task or note as one. `{date}` becomes today's date. |
| **XP, levels, achievements** | XP for *starting*, more for finishing, bonuses for dreaded tasks, old tasks, beating your estimate and errands. 18 achievements, ranks every 5 levels, and coins to spend in the **reward shop** (Progress tab) on treats you define, like "Fancy coffee out = 25". Streaks include 2 grace days a week and never reset to zero. |
| **Celebrations** | Confetti plus an XP breakdown card when you finish, and a small toast when you start (it never covers the screen at that moment). Intensity runs Off / Subtle / Normal / Party. |
| **Motivational quotes** | 114 bundled quotes in five categories. The category depends on the moment: dread-busting for a task you rated "Ugh", self-compassion after a skip, momentum during focus. |
| **Light and dark** | One calm look in light and dark, or matching your phone (Settings → Appearance). |
| **Repeating tasks** | Every day, weekday, week, 2 weeks or month, on a fixed schedule ("report every Friday") or counted from when you finish ("water plants a week after last time"). The next one waits in **Coming up** until its day, so finishing laundry doesn't put laundry straight back in front of you. |
| **Reminders (Android)** | A countdown in your notifications while you focus, plus a "time's up" alert even if you've switched apps. Check-in nudges ("pick one thing?") at times you choose, skipped for 90 minutes after you've started or finished something. Settings → Reminders. |
| **Undo** | **Mark done**, Archive and Delete from the task list each show an Undo bar. Undoing a done also takes back its XP and the next copy of a repeating task. |
| **Waiting on someone** | Park a task with who it's waiting on and when to check back. On the day it moves to **Check back** at the top of Tasks (and Android reminds you): back to your list, still waiting, or done. |
| **Real task lengths** | After 5 tasks timed with the focus timer, Gumption learns how long things really take you ("about 1.6× your guess") and picks tasks that truly fit your time. See Progress. |
| **Evening wrap-up** | 3 minutes at night (Android reminds you, or tap **Wrap up** on Home after 5 pm): today's wins, what's still open, and tomorrow's first thing, which then shows first on Home in the morning. |
| **Share and voice** | On Android, share text from any app to **Gumption** to make it a task. The mic in Quick add types what you say (Android, Mac, and Chrome/Safari). |
| **Notes** | A Notes tab for thoughts, call outcomes and meeting notes. Pin, search, and organize with **projects** and **tags** (chips, or type `#tag` in the text). **Make tasks** turns the lines you tick into tasks; a task's editor shows its notes and "Add a note". |
| **Projects and board** | Group tasks and notes by project. Tasks has a **List / Board** switch: To do · Doing · Waiting · Done. On a phone, tabs show one column at a time (tap or swipe); hold a card and drop it on a tab to move it, or use its ⋮ menu. Wide screens show all four columns. "Pick for me" still works across everything. |
| **Home-screen widgets (Android)** | Long-press your home screen → Widgets → Gumption. Four sizes: **start** (2×1), **square** (2×2), **card** (4×2) and **card + next up** (4×3, with two more tasks that fit right now). Each shows the current pick with **Start**; the bigger ones add **+**. They update whenever the app is open. |
| **Backup file** | Settings → **Save a backup file** puts every task, note, all your XP and your settings in one file you keep (Files, Drive, email…). Not your API key or Google sign-in, on purpose. **Restore from a backup file** adds it back in; anything newer on the device is kept, so restoring an old file never undoes work. No Google account needed. |
| **Ideas when you're stuck** | An empty first step offers three ideas for that kind of task (calls, emails, forms, bills, cleaning, errands…), and **Suggest steps** fills in a checklist, with no AI key needed. **Hold me to it** on the focus screen texts a friend that you've started (Work tasks never include the title). |
| **Guide and example tasks** | **How Gumption works** (Settings → Help, or the empty Today screen) walks through every feature with buttons to each screen. **Try with example tasks** fills the app with samples to look around; **Remove example tasks** takes away only those. |
| **Sensitive info check** (off unless turned on in Settings) | Work tasks that look like someone's personal details (a birth date, a record or account number, "pt Jane Doe") show a warning to use initials or a reference number instead. Turn it on on your own devices for clinic work. |

### Sync between devices (Phase 2)

| Feature | What it does |
|---|---|
| **Two Google accounts** | The Personal workspace syncs to your personal Google account. Work syncs to the Google account you use for work (for you, the clinic's Workspace account). Their data never mixes, and moving a task to Work scrubs its text from the Personal account. |
| **Private Drive folder** | Sync uses Drive's hidden app-data folder, which only this app can read. The app asks only for Google's non-sensitive Drive permissions, so it can't see anything else in your Drive. |
| **Works offline** | Everything saves on the device first. It syncs on start, a few seconds after you edit something, every 3 minutes while the app is open, and when you come back to the app. |
| **No conflicts** | Edits made offline on two devices merge field by field, so editing the title on your phone and the priority on your PC keeps both changes. XP is recorded as events, so points earned on each device add up instead of overwriting each other. |
| **Or iCloud, or OneDrive** | Each workspace can sync through iCloud instead (iPhone, iPad and Mac; no sign-in), or a Microsoft account's OneDrive (personal, or work or school; Android, iPhone, iPad, Mac and Windows). Settings → Sync → Connect asks which. OneDrive keeps the files in a visible **Apps/Gumption** folder that the app can't see past. |
| **Backups** | "Back up to Drive" (or "to OneDrive") saves a readable JSON copy of a workspace to your Drive (or Apps/Gumption/Backups). |
| **Guard rails** | The app warns you if the Work workspace is connected to a personal Gmail account. A sync badge shows status, and "Reconnect" appears if Google signs a device out. |

Without Google setup, the app works exactly as before, storing everything on the device.

## Install on your Android phone

Open this link on the phone (signed in to GitHub, since the repo is private):

**https://github.com/KGeary1995/ADHD-Tax/releases/download/android-latest/Gumption.apk**

(The old link ending in `Unstuck.apk` still works: it's the same file.)

Tap the downloaded file to install it. The first time, Android asks you to allow installs from Chrome or Files; Play Protect may also say it doesn't recognize the app, and **More details → Install anyway** gets past that. Every push rebuilds that same link, and new versions install over the old one without losing your tasks.

## Install on iPhone and iPad (native app, TestFlight)

The native app has everything the Android app has: timer alerts, check-ins, follow-up and wrap-up reminders, home-screen widgets (small, medium, large), **Share → Gumption**, voice, and Google sign-in that stays signed in. It installs through Apple's **TestFlight** app, not the App Store.

**One-time Apple setup (about 30 minutes, plus Apple's approval wait).**

1. **Join the Apple Developer Program** ($99/year) at [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/). Approval can take a day or two. Then open [developer.apple.com/account](https://developer.apple.com/account) → **Membership details** and copy your **Team ID**.
2. **Register the app's identifiers** at [developer.apple.com/account/resources](https://developer.apple.com/account/resources/identifiers/list):
   - **Identifiers → + → App Groups → Continue.** Description `Gumption`, identifier `group.com.adhdtax.adhdTax`.
   - **Identifiers → + → App IDs → App → Continue.** Description `Gumption`, **Explicit** Bundle ID `com.adhdtax.adhdTax`. Under Capabilities tick **App Groups**, then **Edit/Configure** and choose `group.com.adhdtax.adhdTax`. Register.
   - (The widget and share extensions' IDs are created automatically by the first build.)
3. **Create the app** in [App Store Connect](https://appstoreconnect.apple.com/apps): **+ → New App**. Platform **iOS**, Name **Gumption: Task Starter**, language English, Bundle ID `com.adhdtax.adhdTax`, SKU `gumption`, User Access **Full Access**.
4. **Create an API key** for the builds: App Store Connect → **Users and Access → Integrations → App Store Connect API → Team Keys → +**. Name `GitHub CI`, Access **Admin** (needed to create signing certificates). **Download** the `.p8` file (only possible once) and copy the **Key ID** and the **Issuer ID** shown above the list.
5. In GitHub, open this repo → **Settings → Secrets and variables → Actions → New repository secret**, and add:

   | Secret | Value |
   |---|---|
   | `APPLE_TEAM_ID` | your Team ID (step 1) |
   | `ASC_KEY_ID` | the key's Key ID |
   | `ASC_ISSUER_ID` | the Issuer ID |
   | `ASC_KEY_P8` | open the `.p8` file in a text editor and paste all of it, including the BEGIN/END lines |

6. Start a build: **Actions → CI → Run workflow**, choose **ios** under "Extra app to build", and run it (or ask Claude for an `[ios]` build). When **Build iOS app** finishes, the build shows in App Store Connect → **TestFlight** after Apple processes it (10–30 minutes).
7. **TestFlight → Internal Testing → +** (create a group, e.g. "Me"), add yourself. Install the **TestFlight** app on your iPhone/iPad, accept the invite, tap **Install**. Later builds show up there to update with one tap.

**Widgets:** long-press the home screen → **+** → Gumption. **Share:** in any app's share sheet, choose Gumption (you may need **More** the first time), edit the text, tap **Add**; the next time you open Gumption, Quick add opens with it.

### iCloud sync setup (one time, about 5 minutes)

iCloud sync (1.2) needs the app's iCloud folder registered with Apple once. Until this is done, iPhone builds that include it fail at signing.

1. Go to **developer.apple.com/account** → **Certificates, IDs & Profiles** → **Identifiers**.
2. Top right, switch the list from **App IDs** to **iCloud Containers**, then **+** → **iCloud Containers** → Continue. Description: `Gumption sync`. Identifier: `iCloud.com.adhdtax.adhdTax`. **Continue → Register**.
3. Switch the list back to **App IDs** and open **com.adhdtax.adhdTax** (the app itself, not `.Widget` or `.Share`).
4. Tick **iCloud**, choose **Include CloudKit support**, then click **Configure** (or Edit) next to it, tick `iCloud.com.adhdtax.adhdTax`, **Continue → Save**. Confirm the warning about profiles: the next build makes new ones automatically.
5. Tell Claude it's done; the next iPhone build includes iCloud sync.

### iPhone web app (no Apple account)

The web app still works on any phone: added to the home screen it opens full screen with its own icon and works offline. It has no reminders, widgets or Share, because iPhone web apps can't do those.

**One-time hosting setup (about 10 minutes, free, no credit card).** CI publishes the web app to Cloudflare Pages once it has two secrets:

1. Sign up at [dash.cloudflare.com](https://dash.cloudflare.com/sign-up).
2. **Account ID:** in the dashboard, open **Workers & Pages**. The Account ID is on the right; copy it.
3. **API token:** profile icon → **My Profile → API Tokens → Create Token → Create Custom Token**. Under Permissions choose **Account · Cloudflare Pages · Edit**, then **Continue to summary → Create Token**, and copy it.
4. In GitHub, open this repo → **Settings → Secrets and variables → Actions → New repository secret**. Add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
5. Push anything, or go to **Actions → CI → Run workflow**. When the **Publish web app (iPhone)** job finishes, its summary shows the address. **Ours is https://unstuck-4o8.pages.dev** (live since Build 39; `unstuck.pages.dev` was taken, so Cloudflare added a suffix).

**On the iPhone:** open that address in **Safari**, tap **Share → Add to Home Screen**, and from then on open Gumption from the home screen. Tasks saved in the home-screen app are separate from the Safari tab, so use the icon.

## Install on Mac

1. Download **https://github.com/KGeary1995/ADHD-Tax/releases/download/macos-latest/Gumption-macOS.zip** (signed in to GitHub). Safari unzips it.
2. Drag **Gumption** into **Applications** and open it.
3. The first time, macOS says it can't verify the developer: click **Done**, then go to **System Settings → Privacy & Security**, scroll down to "Gumption was blocked", and click **Open Anyway**. You do this once for each new version.

**Signed Mac builds (no warning).** Builds made after the Developer ID secrets are in place are signed and notarized by Apple, so they open normally and keychain "Always Allow" keeps working after updates. One-time setup with the Apple Developer account (no Xcode needed):

1. On the Mac, open **Keychain Access → Keychain Access menu → Certificate Assistant → Request a Certificate From a Certificate Authority**. Enter your email and name, choose **Saved to disk**, Continue. It saves `CertificateSigningRequest.certSigningRequest`.
2. At [developer.apple.com/account/resources/certificates/add](https://developer.apple.com/account/resources/certificates/add) choose **Developer ID Application** (G2 Sub-CA if asked), upload that file, and **Download** the certificate. Double-click it to add it to your keychain.
3. In Keychain Access → **My Certificates**, right-click **Developer ID Application: <your name> (<Team ID>)** → **Export**, save as `devid.p12` with a password you choose.
4. In Terminal: `base64 -i ~/Desktop/devid.p12 | pbcopy` (adjust the path), then add GitHub secrets `MACOS_CERT_P12` (paste) and `MACOS_CERT_PASSWORD` (the export password). Keep the .p12 in your password manager.

The Mac app is built on request, because macOS build machines cost 10x the free GitHub Actions minutes (about 100 of the 2,000 monthly minutes per build). To build a new version, go to **Actions → CI → Run workflow** and choose **mac**. Or put `[mac]` in a commit message.

## Run it

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.47+.

```bash
cd app
flutter pub get
flutter run -d chrome      # web
flutter run -d windows     # Windows desktop (on a Windows PC)
flutter run                # connected Android phone
```

Build installable versions:

```bash
flutter build apk --release                       # Android → build/app/outputs/flutter-apk/
flutter build windows --release                   # Windows → build/windows/x64/runner/Release/
flutter build web --release --no-web-resources-cdn # Web → build/web/ (self-contained, no CDN)
```

Every push runs CI, which tests the app and builds the web, Android and Windows versions. The Android build is published to the `android-latest` release, and the web app to Cloudflare Pages once it's set up (see above). The Mac app builds on request, to the `macos-latest` release. Every build is also attached to the run's **Artifacts** section.

### Set up Google sync (one time, about 20 minutes)

Sync needs your own Google Cloud sign-in keys. They're free, and the app can only see its own hidden folder in your Drive. Do this on a computer: the Google Cloud console is hard to use on a phone.

**A. Create the Google project**

1. Go to [console.cloud.google.com](https://console.cloud.google.com), sign in with your **personal** Google account, and create a project called "Gumption".
2. **APIs & Services → Library:** search for **Google Drive API** and click **Enable**.
3. Open **Google Auth Platform** (the menu item formerly called "OAuth consent screen") and click **Get started**:
   - **App name:** Gumption (if you set this up as "Unstuck", change it under **Branding**). **Support email:** yours. **Audience:** External. **Contact email:** yours. Agree and **Create**.
   - **Data Access → Add or remove scopes:** tick `.../auth/drive.appdata` and `.../auth/drive.file`, then **Update → Save**. Both are "non-sensitive", so Google doesn't need to review the app.
   - **Audience → Publish app**, so the status is **In production**. If you leave it in Testing, Google signs you out every 7 days and sync quietly stops.

**B. Create four sign-in clients** (**Google Auth Platform → Clients → Create client**)

| Application type | Fill in | Copy |
|---|---|---|
| **Web application** (used by the web app, Android *and* the iPhone app) | **Authorized JavaScript origins:** your iPhone web app address (`https://unstuck-4o8.pages.dev`) and `http://localhost:8080` | Client ID |
| **Android** | Package name `com.adhdtax.adhd_tax`, SHA-1 `E9:F6:E9:C8:17:8A:B9:27:E7:9A:28:87:EC:67:D5:04:4F:F5:1F:BA` | nothing |
| **Desktop app** (used by Mac and Windows) | Name only | Client ID **and** Client secret |
| **iOS** (the native iPhone/iPad app) | Bundle ID `com.adhdtax.adhdTax` | Client ID |

**C. Give the keys to the builds**

In GitHub, open this repo → **Settings → Secrets and variables → Actions → New repository secret**, and add:

| Secret name | Value |
|---|---|
| `GOOGLE_WEB_CLIENT_ID` | the Web application's Client ID |
| `GOOGLE_DESKTOP_CLIENT_ID` | the Desktop app's Client ID |
| `GOOGLE_DESKTOP_CLIENT_SECRET` | the Desktop app's Client secret |
| `GOOGLE_IOS_CLIENT_ID` | the iOS client's Client ID |

The next build of each app includes them. Then, in each app, go to **Settings → Accounts & sync → Connect**: your personal Google account for **Personal**, and your clinic account for **Work**.

For a build on your own computer, put the same three values in `app/google_oauth.json` (copy `app/google_oauth.example.json`; it's git-ignored) and add `--dart-define-from-file=google_oauth.json` to `flutter run` / `flutter build`.

**Clinic account:** many Google Workspace admins block apps they haven't approved. If connecting Work fails with "access blocked", ask your admin to trust the Web and Desktop client IDs under Admin console → Security → API controls. Personal sync works either way.

**Android work profile:** if your clinic account lives in the phone's work profile (apps with a briefcase badge), the regular Gumption can't see it. Install Gumption a second time inside the work profile (open the download link in the work profile's Chrome) and connect Work there; use Personal in the regular app. Then set **Settings → Show on this device** to **Work** in the work copy and **Personal** in the regular one, so each only shows (and adds to) its own side. The two copies don't share data, and each needs updating when a new build comes out.

**iPhone and web:** browsers only get one-hour Google sign-ins, so after an hour the sync badge shows **Reconnect** (one tap). The app remembers a sign-in until it expires, so reopening it within the hour doesn't ask again. Android and Mac stay signed in.

### Set up OneDrive sync (one time, about 10 minutes)

OneDrive sync needs one free app registration with Microsoft. Do this on a computer.

1. Go to **entra.microsoft.com** and sign in with your personal Microsoft account (Outlook.com, Hotmail…). If it says your account has no directory or tenant, first create a free one: sign up at **azure.microsoft.com/free** with the same account (it may ask for a card to verify you; app registrations are free), then come back.
2. **Identity → Applications → App registrations → New registration**:
   - **Name:** `Gumption`, exactly. OneDrive names the app's folder after it (**Apps/Gumption**).
   - **Supported account types:** *Accounts in any organizational directory and personal Microsoft accounts*.
   - **Redirect URI:** platform **Public client/native (mobile & desktop)**, value `http://localhost`.
   - **Register.**
3. **Authentication → Add URI** under *Mobile and desktop applications*: add `gumption://auth` (Android comes back through it). **Save.**
4. **API permissions → Add a permission → Microsoft Graph → Delegated permissions:** tick **Files.ReadWrite.AppFolder** and **offline_access**. **User.Read** is already there; keep it. **Add permissions.** Don't click "Grant admin consent" (it's for your own directory only and isn't needed).
5. **Overview:** copy the **Application (client) ID**.
6. In GitHub, add a repository secret `MICROSOFT_CLIENT_ID` with that ID (same place as the Google ones, above). It isn't a password: the app is a public client and has no secret.
7. Tell Claude it's done. The next build of each app offers **Microsoft account (OneDrive)** under Settings → Sync → Connect.

**Work or school Microsoft accounts:** many organizations only let staff approve apps from verified publishers, so connecting may say it needs an admin's approval. The admin can approve Gumption in their Entra admin center (Enterprise applications → Admin consent requests, or by its client ID). Personal accounts work either way. Verifying the publisher (a free Microsoft partner ID linked to the registration) removes the "unverified" label; worth doing before the App Store release.

**Not on the web yet:** the web app offers Google only for now.

### Keyboard shortcuts (desktop / web)

| Keys | Action |
|---|---|
| Ctrl+N | Quick add |
| Ctrl+1 … 4 | Focus / Tasks / Progress / Settings |
| Space | Pause/resume on the focus screen |

## Documentation

| Doc | For |
|---|---|
| [AGENTS.md](AGENTS.md) | Start here if you're changing the code (people or AI): commands, rules, gotchas, current status |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How it works: data model, sync, state, platforms |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | CI, release links, secrets, signing, hosting |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Symptom → cause → fix |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Why things are the way they are |
| [CHANGELOG.md](CHANGELOG.md) | What changed in each build |
| [docs/PLAN.md](docs/PLAN.md) | Original product plan and roadmap |

## Project layout

```
app/lib/
  core/            theme (light + dark tokens, fonts), shared providers
  data/            Task model, local storage
  sync/            replica (CRDT), sync engine, sync controller + badge
  google/          sign-in per platform, Drive app-data store
  features/
    picker/        pick-for-me engine (pure Dart) + dashboard
    focus/         focus screen, visual timer
    capture/       quick add, brain dump, task editor
    tasks/         task list + state
    gamification/  XP rules, levels, streaks, achievements, celebrations
    motivation/    quote service + rotator
    reminders/     focus timer notifications, check-in nudges
    safety/        sensitive info check (phi_guard.dart)
    settings/      appearance, reminders, sync, celebration intensity
app/test/          129 unit, widget, phone-layout and multi-device sync tests
docs/PLAN.md       full product plan and roadmap
app/tool/          check.sh (CI checks), make_icons.py (app icons), screenshots/ (web screenshots)
```

The decision logic (`picker_engine.dart`, `xp_rules.dart`, `achievements.dart`, `phi_guard.dart`, `quote_service.dart`) is pure Dart with no Flutter imports, so it's fast to test and reusable.

## Roadmap

1. ~~**Phase 1: offline MVP**~~ ✅
2. ~~**Phase 2: Google sign-in + Drive sync**~~ ✅ (needs your OAuth setup, above). ~~iCloud~~ ✅ and Microsoft OneDrive (built; needs the setup above) as alternatives.
3. **Phase 3: Google Calendar.** Free time detected automatically ("47 min until Staff Huddle"). Plan My Day drops suggested tasks into a dedicated "Gumption" calendar, with two-way updates and "leave in 15 min" alerts.
4. **Phase 4: Monday.com-style views.** Board, table, timeline, calendar, projects, command palette. (Repeating tasks are already done.)
5. ~~**Phase 5: ADHD extras.**~~ Learned estimate correction, errand runs, home-screen widget, desktop hotkey, reward shop, body doubling, daily wrap-up and weekly reset are all in.
6. **Phase 6: optional AI (Claude).** ~~"Break this down"~~ is in (your own API key, off for Work by default). Still open: smarter capture and a Plan-my-day explanation.

## Before using it for clinic work

- **No PHI in tasks.** Use initials or ticket numbers. Turn on **Settings → Sensitive info check** on each device you use for clinic work (it's off by default since 1.1): it catches common slips but is not a compliance control.
- Work tasks sync only to the **work** Google Workspace account you connect, and never to a server we run. Your clinic's Workspace admin may need to approve the app's OAuth client (Admin console → Security → API controls).
- Check with your compliance officer before relying on it for anything patient-adjacent.
