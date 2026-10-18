# Unstuck

*Formerly "ADHD Tax". The GitHub repo keeps its old name.*

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
| **XP, levels, achievements** | XP for *starting*, more for finishing, bonuses for dreaded tasks, old tasks, beating your estimate and errands. 18 achievements, ranks every 5 levels, and coins for the reward shop that's coming. Streaks include 2 grace days a week and never reset to zero. |
| **Celebrations** | Confetti plus an XP breakdown card when you finish, and a small toast when you start (it never covers the screen at that moment). Intensity runs Off / Subtle / Normal / Party. |
| **Motivational quotes** | 114 bundled quotes in five categories. The category depends on the moment: dread-busting for a task you rated "Ugh", self-compassion after a skip, momentum during focus. |
| **Light and dark** | One calm look in light and dark, or matching your phone (Settings → Appearance). |
| **Repeating tasks** | Every day, weekday, week, 2 weeks or month, on a fixed schedule ("report every Friday") or counted from when you finish ("water plants a week after last time"). The next one waits in **Coming up** until its day, so finishing laundry doesn't put laundry straight back in front of you. |
| **Reminders (Android)** | A countdown in your notifications while you focus, plus a "time's up" alert even if you've switched apps. Check-in nudges ("pick one thing?") at times you choose, skipped for 90 minutes after you've started or finished something. Settings → Reminders. |
| **Undo** | **Mark done**, Archive and Delete from the task list each show an Undo bar. Undoing a done also takes back its XP and the next copy of a repeating task. |
| **Patient-info guard** | Work tasks that look like PHI (DOB, MRN, "pt Jane Doe") show a warning to use initials or a ticket number instead. |

### Sync between devices (Phase 2)

| Feature | What it does |
|---|---|
| **Two Google accounts** | The Personal workspace syncs to your personal Google account. Work syncs to your clinic's Google Workspace account. Their data never mixes, and moving a task to Work scrubs its text from the Personal account. |
| **Private Drive folder** | Sync uses Drive's hidden app-data folder, which only this app can read. The app asks only for Google's non-sensitive Drive permissions, so it can't see anything else in your Drive. |
| **Works offline** | Everything saves on the device first. It syncs on start, a few seconds after you edit something, every 3 minutes while the app is open, and when you come back to the app. |
| **No conflicts** | Edits made offline on two devices merge field by field, so editing the title on your phone and the priority on your PC keeps both changes. XP is recorded as events, so points earned on each device add up instead of overwriting each other. |
| **Backups** | "Back up to Drive" saves a readable JSON copy of a workspace to your Drive. |
| **Guard rails** | The app warns you if the Work workspace is connected to a personal Gmail account. A sync badge shows status, and "Reconnect" appears if Google signs a device out. |

Without Google setup, the app works exactly as before, storing everything on the device.

## Install on your Android phone

Open this link on the phone (signed in to GitHub, since the repo is private):

**https://github.com/KGeary1995/ADHD-Tax/releases/download/android-latest/Unstuck.apk**

Tap the downloaded file to install it. The first time, Android asks you to allow installs from Chrome or Files; Play Protect may also say it doesn't recognize the app, and **More details → Install anyway** gets past that. Every push rebuilds that same link, and new versions install over the old one without losing your tasks.

## Install on iPhone

The iPhone version is the web app, added to the home screen. It opens full screen with its own icon and works offline. Timer alerts and check-in nudges are Android-only, because iPhone web apps can't schedule notifications; the focus timer still runs on screen.

**One-time hosting setup (about 10 minutes, free, no credit card).** CI publishes the web app to Cloudflare Pages once it has two secrets:

1. Sign up at [dash.cloudflare.com](https://dash.cloudflare.com/sign-up).
2. **Account ID:** in the dashboard, open **Workers & Pages**. The Account ID is on the right; copy it.
3. **API token:** profile icon → **My Profile → API Tokens → Create Token → Create Custom Token**. Under Permissions choose **Account · Cloudflare Pages · Edit**, then **Continue to summary → Create Token**, and copy it.
4. In GitHub, open this repo → **Settings → Secrets and variables → Actions → New repository secret**. Add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
5. Push anything, or go to **Actions → CI → Run workflow**. When the **Publish web app (iPhone)** job finishes, its summary shows the address, normally **https://unstuck.pages.dev**.

**On the iPhone:** open that address in **Safari**, tap **Share → Add to Home Screen**, and from then on open Unstuck from the home screen. Tasks saved in the home-screen app are separate from the Safari tab, so use the icon.

## Install on Mac

1. Download **https://github.com/KGeary1995/ADHD-Tax/releases/download/macos-latest/Unstuck-macOS.zip** (signed in to GitHub). Safari unzips it.
2. Drag **Unstuck** into **Applications** and open it.
3. The first time, macOS says it can't verify the developer: click **Done**, then go to **System Settings → Privacy & Security**, scroll down to "Unstuck was blocked", and click **Open Anyway**. You do this once for each new version.

The Mac app is built on request, because macOS build machines cost 10x the free GitHub Actions minutes (about 100 of the 2,000 monthly minutes per build). To build a new version, go to **Actions → CI → Run workflow**. Merges to `main` also build one.

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

1. Go to [console.cloud.google.com](https://console.cloud.google.com), sign in with your **personal** Google account, and create a project called "Unstuck".
2. **APIs & Services → Library:** search for **Google Drive API** and click **Enable**.
3. Open **Google Auth Platform** (the menu item formerly called "OAuth consent screen") and click **Get started**:
   - **App name:** Unstuck. **Support email:** yours. **Audience:** External. **Contact email:** yours. Agree and **Create**.
   - **Data Access → Add or remove scopes:** tick `.../auth/drive.appdata` and `.../auth/drive.file`, then **Update → Save**. Both are "non-sensitive", so Google doesn't need to review the app.
   - **Audience → Publish app**, so the status is **In production**. If you leave it in Testing, Google signs you out every 7 days and sync quietly stops.

**B. Create three sign-in clients** (**Google Auth Platform → Clients → Create client**)

| Application type | Fill in | Copy |
|---|---|---|
| **Web application** (used by iPhone, web *and* Android) | **Authorized JavaScript origins:** your iPhone web app address (e.g. `https://unstuck.pages.dev`) and `http://localhost:8080` | Client ID |
| **Android** | Package name `com.adhdtax.adhd_tax`, SHA-1 `E9:F6:E9:C8:17:8A:B9:27:E7:9A:28:87:EC:67:D5:04:4F:F5:1F:BA` | nothing |
| **Desktop app** (used by Mac and Windows) | Name only | Client ID **and** Client secret |

**C. Give the keys to the builds**

In GitHub, open this repo → **Settings → Secrets and variables → Actions → New repository secret**, and add:

| Secret name | Value |
|---|---|
| `GOOGLE_WEB_CLIENT_ID` | the Web application's Client ID |
| `GOOGLE_DESKTOP_CLIENT_ID` | the Desktop app's Client ID |
| `GOOGLE_DESKTOP_CLIENT_SECRET` | the Desktop app's Client secret |

The next build of each app includes them. Then, in each app, go to **Settings → Accounts & sync → Connect**: your personal Google account for **Personal**, and your clinic account for **Work**.

For a build on your own computer, put the same three values in `app/google_oauth.json` (copy `app/google_oauth.example.json`; it's git-ignored) and add `--dart-define-from-file=google_oauth.json` to `flutter run` / `flutter build`.

**Clinic account:** many Google Workspace admins block apps they haven't approved. If connecting Work fails with "access blocked", ask your admin to trust the Web and Desktop client IDs under Admin console → Security → API controls. Personal sync works either way.

**iPhone and web:** browsers only get one-hour Google sign-ins, so after an hour the sync badge shows **Reconnect** (one tap). The app remembers a sign-in until it expires, so reopening it within the hour doesn't ask again. Android and Mac stay signed in.

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
    safety/        PHI guard
    settings/      appearance, reminders, sync, celebration intensity
app/test/          129 unit, widget, phone-layout and multi-device sync tests
docs/PLAN.md       full product plan and roadmap
app/tool/          check.sh (CI checks), make_icons.py (app icons), screenshots/ (web screenshots)
```

The decision logic (`picker_engine.dart`, `xp_rules.dart`, `achievements.dart`, `phi_guard.dart`, `quote_service.dart`) is pure Dart with no Flutter imports, so it's fast to test and reusable.

## Roadmap

1. ~~**Phase 1: offline MVP**~~ ✅
2. ~~**Phase 2: Google sign-in + Drive sync**~~ ✅ (needs your OAuth setup, above)
3. **Phase 3: Google Calendar.** Free time detected automatically ("47 min until Staff Huddle"). Plan My Day drops suggested tasks into a dedicated "Unstuck" calendar, with two-way updates and "leave in 15 min" alerts.
4. **Phase 4: Monday.com-style views.** Board, table, timeline, calendar, projects, command palette. (Repeating tasks are already done.)
5. **Phase 5: ADHD extras.** Learned estimate correction, errand batching, Android home-screen widget, desktop global hotkey, reward shop, body doubling, daily shutdown.
6. **Phase 6: optional AI (Claude).** "Break this down" and natural-language capture, using your own API key. Off by default in Work.

## Before using it for clinic work

- **No PHI in tasks.** Use initials or ticket numbers. The PHI guard catches common slips but is not a compliance control.
- Work tasks sync only to the **work** Google Workspace account you connect, and never to a server we run. Your clinic's Workspace admin may need to approve the app's OAuth client (Admin console → Security → API controls).
- Check with your compliance officer before relying on it for anything patient-adjacent.
