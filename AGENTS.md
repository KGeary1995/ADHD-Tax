# AGENTS.md — start here

Orientation for any AI coding session (Claude Code, Codex, Cursor, …) or human picking up this repo cold. It is kept current: **if you change behavior, build, CI or deployment, update this file and the relevant `docs/` page in the same commit.**

## What this is

**Gumption** (store name *Gumption: Task Starter*; formerly *Unstuck*, originally *ADHD Tax*; the repo and internal ids keep the old names) is a task-initiation app for an ADHD user who struggles to *start* tasks. It picks one task for you (based on time available, energy, whether you can leave the house), shrinks it to a first step, runs a visual focus timer, and rewards starting with XP. Personal and Work tasks are kept apart and each syncs to its own account: Google Drive, iCloud or Microsoft OneDrive.

- **One Flutter codebase** in `app/` → Android (APK, sideloaded), iPhone/iPad (native, TestFlight), Mac, Windows, web. The web build is also the no-account iPhone option.
- **No backend server.** Data lives on each device and syncs through the user's own storage: a hidden Google Drive app-data folder, an iCloud Drive container, or OneDrive's app folder (Apps/Gumption).
- **Naming:** the user-visible name is **Gumption** (since 2026-10-22). Internal identifiers keep the old names **on purpose**: the Android applicationId `com.adhdtax.adhd_tax`, the Mac bundle id `com.adhdtax.adhdTax`, the Dart package `adhd_tax`, the repo `KGeary1995/ADHD-Tax`, the web token key `adhdtax.googleToken.*`, and the repeat-copy id seed `adhd-tax:repeat:` (pinned by a test). From the Unstuck era: the `unstuck/android` method channel, the `unstuck://` URL scheme, the backup file `kind` `unstuck-backup` (old backups must still restore), the iOS target folders `UnstuckWidget`/`UnstuckShare`, the Cloudflare project `unstuck` (the web address), and a copy of the APK published as `Unstuck.apk` so old links work. Changing them installs a separate, empty app, breaks Google Sign-In's Android client, or duplicates repeating tasks across devices. See docs/DECISIONS.md.
- **Owner context:** the user works in ophthalmology clinic operations. Work tasks must never contain patient information (PHI). See "Rules" below.

## Status (keep this section current)

| Area | State | Verified on a real device? |
|---|---|---|
| Phase 1: offline app (picker, focus, XP, themes, quotes) | Done | Android: yes (Build 9+) |
| Redesign: one look, light + dark, bundled fonts, floating nav | Replaced by 1.1 (below) | — |
| **1.1 "Night sky" redesign** (docs/design/handoff-1.1.md): Night/Dawn tokens, Sora + Manrope, Phosphor icons, divider-tab nav, Today as one task, Started screen, orbit/blocks timer, celebration cards, every screen restyled; new app icon (iOS dark/tinted, Android adaptive + monochrome); widgets restyled and follow the phone's appearance; Mac/iPad Tasks list + detail pane; new store screenshots | Done; merged to `main` 2026-10-25 (PR #7). Android and web on Build 112+; **iPhone 1.1.0 (113) uploaded to TestFlight** for testing. Not submitted to the App Store: that waits until Apple approves 1.0 | Not yet on a device (tests, and web screenshots against the handoff at 390×844, 360×640, 1440×900 and 1194×834). CI compiled the Android widgets and adaptive icon (Build 112) and the iPhone widget and dark/tinted icon set (Build 113) |
| Phase 2: Google sign-in + Drive sync | Code done; Google Cloud keys (web, Android, desktop clients) added as secrets 2026-10-19; iOS client added 2026-10-22 | **Yes (Android, 2026-10-19):** Personal connected in the personal profile; Work connected from a second install in the Android **work profile** (the personal-profile app can't see work-profile accounts). **2026-10-22:** sync survives an app update since the silent sign-in retry (Build 77). **2026-10-23:** Google sign-in works in the iPhone build (TestFlight Build 103, run on the owner's Mac). **Two-device sync passes (2026-10-23):** a task added on the Mac (TestFlight iPhone build) appeared on Android, and marking it done on Android showed on the Mac. **2026-10-24, real iPhone (Build 108):** Personal syncs; Work hung on "Waiting for Google sign-in…" because `google_sign_in` on iOS holds one account. **Fixed and verified (real iPhone, Build 110, 2026-10-24):** browser sign-in per workspace; Personal (personal Gmail) and Work (clinic Workspace account) both connect and sync on the same iPhone |
| Phone layout fixes, full task form, back button | Done | Android: reported working |
| Repeating tasks, Mark done + Undo, Android reminders | Done | **Partly (Build 91):** Mark done + Undo and the focus timer's "Time's up" alert (screen off) pass; repeating tasks not yet tested |
| Waiting-on follow-ups, real task lengths, evening wrap-up, voice capture | Done | **Partly (Build 91):** wrap-up and voice capture pass; waiting-on and real task lengths not yet tested on a device |
| Android home-screen widget, Share → Gumption | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed (card widget Start and +, Share from Chrome opens one copy of the app) |
| iPhone/iPad native app (notifications, widgets, Share, voice) | Done; `[ios]` pushes (or Run workflow → `ios`) sign it and upload to TestFlight. **1.0.0 (103) submitted for App Store review 2026-10-23** (manual release after approval) | **Partly (Build 103, 2026-10-23):** uploaded to TestFlight and the owner ran it on an Apple-silicon Mac ("Designed for iPad"); it opens and works. Not yet on a real iPhone (the owner has none; a friend's test is recommended before App Store review). Widgets, Share and notifications are untested |
| iPhone web app (home-screen) | Done; Cloudflare secrets added 2026-10-18, published by `web-publish` on every push to **https://unstuck-4o8.pages.dev** (Build 39+). Being trialled with iPhone-using friends to decide on the native app | No (Chromium emulation only) |
| Backup file (Settings → Save / Restore) | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed (save to Downloads, restore the same file) |
| Mac app | Builds on `[mac]` pushes (or Run workflow → `mac`), signed with Developer ID and notarized by Apple, published to `macos-latest` | **Yes**: opens and works after "Open Anyway" (Build 21, ad-hoc signed). Build 103 (2026-10-23), the first notarized build, opens with no Gatekeeper warning on the owner's Mac |
| Notes (tags, #hashtags, Make tasks, task-linked notes), projects, Tasks board view, "Show on this device" (Personal / Work / Both) | Done | Not yet (tests and web screenshots) |
| `[[links]]` in notes, Related on tasks, "Your sky" constellation on Progress | Done | Not yet (tests and web screenshots) |
| Checklists in tasks, reward shop, typed extras in Quick add ("tomorrow 2pm 15 min #tag"), templates, task tags | Done | Not yet (tests and web screenshots) |
| Weekly reset, errand runs, focus company (sounds + buddy), Mac/Windows Quick add hotkey, AI "Break it down" (own Anthropic key) | Done | **Partly (Build 91):** errand run passes on Android. Weekly reset, focus company, the desktop hotkey and AI breakdown not yet tested on a device |
| Phone declutter: Tasks filters in one sheet and short rows, Quick add "More options", quieter Today | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed |
| Desktop layout: Notes/Settings sidebars, Tasks list + detail pane (1.1), desktop Today / Progress / editor / wrap-up, pop-ups and Quick add as windows | Done | Not yet (tests and 1440×900 web screenshots; the owner's Mac screenshots predate it) |
| In-app guide ("How Gumption works") and example tasks | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed (guide and Go to buttons; example tasks not tested) |
| Built-in first-step ideas and Suggest steps (no AI key), "Hold me to it" share from the focus screen | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed (idea chips, Suggest steps, Hold me to it share sheet) |
| **Sync services: iCloud** (1.2): per-workspace choice of iCloud (iPhone/iPad) or Google | Done; merged to `main` 2026-10-25 (PR #9) after the owner added the iCloud container to the App ID. **Microsoft OneDrive** next; Samsung isn't possible (docs/DECISIONS.md) | **Yes (TestFlight build 117, 2026-10-25):** the owner reports it "works great" |
| **Sync services: Microsoft OneDrive** (1.2): third choice in the Connect chooser (Android, iPhone/iPad, Mac, Windows; web added 2026-10-25, PR #12, with the SPA redirect URI in Entra), personal and work or school accounts | Done; merged to `main` 2026-10-25 (PR #11). The owner's Entra app registration and the `MICROSOFT_CLIENT_ID` secret are in place | **Yes (2026-10-25, Build 127):** the owner connected a personal Microsoft account and synced on Android and on the TestFlight iPhone build; the web app works too (PR #12). Work or school accounts not yet tried |
| Settings from any tab (phone): a gear at the top right of Today, Tasks, Notes and Progress; tab bar stays on Settings; back returns to the tab it came from | Done; merged 2026-10-25 (PR #10) | Not yet (tests and web screenshots at 360 and 390 wide) |
| **Code audits** (three rounds): sync durability and checkpoints, stale editors and Undo, dates across clock changes (PR #14, #15); device-id clones after a phone restore, write-only-what-changed, Reconnect account check, outside links vs a running focus session, quick-add times and dates, monthly repeats on the 31st, CI secret scoping (third round, PR #16) | All three merged and shipped: #14 Build 135; #15 Builds 136/137; #16 (2026-10-27) Android/web 140, iPhone 139 (TestFlight), Mac 141 | Not yet on a device. The third round's web security headers (`app/web/_headers`) start with the CSP in report-only mode; see docs/DEPLOYMENT.md → Web headers |
| Phase 3+ (Calendar, table/timeline views) | Not started | — see docs/PLAN.md |

Last updated: 2026-10-27 (PR #16, a third audit's fixes, merged: Android/web Build 140, iPhone 139 on TestFlight, Mac 141, signed and notarized; not yet tried on a device. CI's pinned v4 actions log Node 20 deprecation warnings; moving them to newer majors and re-pinning is open).

## Toolchain

| Tool | Version | Notes |
|---|---|---|
| Flutter / Dart | **3.47.7** / 3.13.5 | Pinned in `.github/workflows/ci.yml` (`FLUTTER_VERSION`). In Claude Code cloud sessions Flutter is at `/opt/flutter/bin` and not on PATH; `app/tool/check.sh` handles that. It warns about running as root; ignore it. On the owner's Windows PC, Flutter lives in WSL Ubuntu (`~/flutter`); see "Local setup on Windows" below. |
| Java | 17 (Temurin) | Android builds |
| Node | 22 | Cloudflare deploy (`wrangler@4.145.0`) and the screenshot tool |
| Python 3 + Pillow, numpy | any recent | Only for `app/tool/make_icons.py` (Pillow, numpy), `app/tool/make_sounds.py` (numpy), `app/tool/make_phosphor.py` and `app/tool/screenshots/store_frames.py` (Pillow) |
| Xcode | CI's `macos-latest` | Mac and iOS builds happen in CI; no Mac needed locally |
| Ruby + `xcodeproj` gem | any | Only for `app/tool/ios/add_extensions.rb` (adds the iOS widget/share targets) |

## Commands (run from `app/`)

```bash
./tool/check.sh                      # format check + analyze + all tests: exactly what CI runs. Run before every push.
flutter pub get
TZ=America/Los_Angeles flutter test  # 357 tests, ~70 s; CI uses this zone so date code meets a clock change
flutter test test/widget/reminders_undo_test.dart   # one file
dart format lib test                 # CI fails on unformatted code
flutter run -d chrome                # quickest way to see the app
flutter build web --release --no-web-resources-cdn   # self-contained web build (no CDN; needed behind proxies)
flutter build apk --release --no-shrink              # --no-shrink is REQUIRED (see Gotchas)
python3 tool/make_icons.py           # redraw every app icon (web, iPhone incl. dark/tinted, Mac, Android adaptive, Windows, Play)
python3 tool/make_phosphor.py        # regenerate lib/core/theme/ph.dart (Phosphor icon constants; add names to its NAMES list)
python3 tool/make_sounds.py          # regenerate the focus-screen background sounds (numpy)
```

### Local setup on Windows (the owner's PC)

`check.sh` is bash, and the tests must run in a time zone with clock changes, which Windows' `TZ` can't do. So Flutter runs in **WSL Ubuntu**, matching CI's Linux runner:

1. Once: `wsl -u root apt-get install -y unzip xz-utils rsync git`, then in WSL `git clone --depth 1 -b 3.47.7 https://github.com/flutter/flutter.git ~/flutter`. The first `~/flutter/bin/flutter --version` downloads the Dart SDK.
2. Keep the Windows clone on **LF line endings** (`git config core.autocrlf false`, then `git rm -q --cached -r . && git reset -q --hard` once). With CRLF, `check.sh` fails with `env: 'bash
'` and `dart format` flags every file.
3. Run the checks on a copy inside WSL, which is much faster than `/mnt/c`: `rsync -a --delete --exclude .git --exclude .dart_tool --exclude build /mnt/c/Users/<you>/ADHD-Tax/ ~/gumption/ && cd ~/gumption/app && ./tool/check.sh`. Format in place on the Windows side with `cd /mnt/c/.../ADHD-Tax/app && ~/flutter/bin/dart format lib test`.
4. From Git Bash, call `wsl.exe` with `MSYS_NO_PATHCONV=1` (otherwise `/mnt/...` paths get rewritten to `C:/Program Files/Git/mnt/...`), and put anything with `$HOME` or `$PATH` in a script file: an inline `bash -c '...'` gets Windows' PATH (with spaces and parentheses) expanded into it.

There's no Android SDK, Xcode or browser here either: native code is compiled only by CI, and screenshots need Chromium (`app/tool/screenshots/shoot.mjs`).

Seeing UI changes without a phone: `app/tool/screenshots/shoot.mjs` (Playwright) screenshots the web build with demo data at any size, including fake iPhone insets (`--iphone`, `--top 62`). Usage is in the file header. Store screenshots: shoot raw screens, then `python3 tool/screenshots/store_frames.py raw/ out/` adds the captions and phone/iPad frames (steps in its header).

The approved design is the 1.1 handoff: `docs/design/handoff-1.1.md` (tokens, motion, components, screen list). Its HTML prototype and 68 reference screenshots came as two zips from the owner and aren't in the repo; ask for them if a screen's exact look is in doubt.

Google sync in a local build needs `app/google_oauth.json` (git-ignored; copy `google_oauth.example.json`) and `--dart-define-from-file=google_oauth.json`. Without it the app runs normally with sync switched off.

## Repo map

```
AGENTS.md / CLAUDE.md   this guide (CLAUDE.md imports it)
README.md               owner-facing: features, install links, setup steps
CHANGELOG.md            what changed in each build, newest first
docs/ARCHITECTURE.md    how the code works: data model, sync/CRDT, state, platforms
docs/DEPLOYMENT.md      CI/CD, releases, secrets, Google/Cloudflare setup, signing keys
docs/TROUBLESHOOTING.md symptom → cause → fix, from real incidents
docs/DECISIONS.md       why things are the way they are (read before "simplifying")
docs/design/handoff-1.1.md  the approved 1.1 design spec: tokens, type, motion, components, screens
docs/PHONE_TEST.md      15-minute checklist the owner runs on an Android phone after a build
docs/store/LISTING.md   store listing copy and draft answers to the Play/App Store forms
docs/STORE_RELEASE.md   plan for Google Play and App Store release: who does what, forms, gotchas
docs/PLAN.md            original product plan and roadmap (partly superseded; see its banner)
.github/workflows/ci.yml  test → Android / Windows / web publish / Mac
app/lib/                the app (feature-first; pure-Dart logic has no Flutter imports)
app/test/               unit, widget, phone-layout and multi-device sync tests
app/tool/               check.sh, make_icons.py, screenshots/
app/web/                index.html, manifest, offline.js (service worker), flutter_bootstrap.js
app/android/app/        build.gradle.kts, manifest, proguard rules, sideload.jks (signing key, committed on purpose)
```

## How a change ships

1. `main` is the stable copy (PR #1 merged 2026-10-22; PR #7, the iPhone sync fix and the 1.1 redesign, 2026-10-25; PR #8, wording for everyone, PR #9, iCloud sync, PR #10, Settings from any tab, and PR #11, OneDrive sync, and PR #12, OneDrive on the web, PR #13, store screenshots, and PR #14, fixes from a code audit, 2026-10-25; PR #15, a second audit's fixes, 2026-10-26; PR #16, a third audit's fixes, 2026-10-27). Work on a feature branch made from the latest `main` and open a new PR into `main` for each batch; the owner decides when to merge. A merged PR is finished: follow-up work goes on a fresh branch from `main`, never on top of the merged history.
2. `./tool/check.sh` must pass.
3. Push. CI runs once per commit (push only; docs-only commits, i.e. `*.md` and `docs/`, skip CI entirely): `test` (format, analyze, test, web build), then in parallel:
   - **Android**: builds the APK and replaces the `android-latest` release asset. The phone download link never changes.
   - **Run workflow** (`workflow_dispatch`) asks which extra app to build (`ios` by default, `mac`, `ios+mac`, `play`, `windows` or `all`); "on `workflow_dispatch`" below means "when chosen there".
   - **Windows**: only on `workflow_dispatch` or **commit messages containing `[windows]`**; builds an artifact (not published as a release).
   - **web-publish**: deploys to Cloudflare Pages if the Cloudflare secrets exist (otherwise it posts a notice).
   - **macOS**: only on `workflow_dispatch` or **commit messages containing `[mac]`** (pushes to `main` don't build it) (macOS runners cost 10× minutes). Publishes to the `macos-latest` release.
   - **iOS**: only on `workflow_dispatch` or **commit messages containing `[ios]`**. Compiles without Apple secrets; with them, uploads to TestFlight.
   - **Play bundle**: only on `workflow_dispatch` or **commit messages containing `[play]`**. Builds the signed `.aab` (needs the upload-key secrets) and publishes it to the `play-latest` release for the owner to upload to Play Console.
4. Tell the owner: "reinstall from the same link". The build number is the CI run number.

Details, secrets and failure modes: docs/DEPLOYMENT.md.

## Rules

- **No PHI anywhere**: no patient names, dates of birth or MRNs in code, tests, fixtures, docs, commit messages or screenshots. Demo data uses generic tasks. The in-app Sensitive info check (`features/safety/phi_guard.dart`, off unless turned on) is a warning, not a control.
- **Written for everyone.** The owner works in a clinic, but the app is for anyone: no medical, clinic or insurance wording in user-facing text, examples, templates, store screenshots or the web pages (docs/DECISIONS.md, 2026-10-25). Keep the dry, kind voice of the quotes and asides; never shaming.
- **New synced collections or fields:** JSON scalars only (a list or map field compares by identity and gets re-stamped on every save; see `Note.tags`).
- **Keep the sync data model backward compatible.** Devices run different builds. New `Task` fields must have defaults in `Task.fromJson`; never rename or reuse a field. Never rewrite or delete XP events: revoke one by tombstoning it (`ProgressController.revoke`).
- **Pure logic stays pure Dart** (no Flutter imports): `picker_engine.dart`, `recurrence.dart`, `nudge_plan.dart`, `xp_rules.dart`, `achievements.dart`, `progress_event.dart`, `phi_guard.dart`, `quote_service.dart`, `hlc.dart`, `replica.dart`, `sync_engine.dart`, `estimate_calibration.dart`, `backup_file.dart`, `note.dart`, `checklist.dart`, `reward.dart`, `template.dart`, `quick_parse.dart`, `weekly_reset.dart`, `errand_run.dart`, `breakdown.dart` (HTTP through an injected `http.Client`), `first_steps.dart`, `links.dart`, `onedrive_store.dart` and `microsoft_auth.dart` (HTTP through injected clients; the browser and keychain are injected too). Test them with plain unit tests.
- **Phone first.** Every screen must work at 360×800 with 1.3× text (`test/widget/narrow_layout_test.dart` enforces this for the capture screens). Prefer wrapping `ChoiceGroup` pills over `SegmentedButton`.
- **One look.** Colors, fonts and type styles come from `core/theme/app_themes.dart` (`context.spec`: the handoff's tokens `bg`, `raised`, `ink`/`ink2`/`ink3`, `line`/`line2`, `star`/`starDeep`/`accentText`, `personal`/`work`…, and `display()`, `body()`, `caption()`, `overline()`…; `Gap.s1`–`s9` and `Radii`) and shared pieces from `widgets/ui.dart` (`PrimaryButton`, `OutlineButton`, `Pill`, `WorkspaceOption`, `OptionRow`, `SheetTitle`, `ConfirmDialog`, `topBar`, `StarCheck`, `SkyBackground`, `Panel`, `Group`/`GroupRow`/`SwitchRow`…). Icons are Phosphor via `Ph.*` (`core/theme/ph.dart`), not `Icons.*`. Don't hard-code colors in screens, and check both Night and Dawn. The approved design is docs/design/handoff-1.1.md.
- **No shame mechanics** (product principle): no red overdue walls, streaks never reset to zero, celebrations respect the Off/Subtle/Normal/Party setting, and starting earns XP.
- **Spend Actions minutes like money (the owner pays for overage).** Every push to a code path builds test + Android + web; `[mac]` adds ~100 billed minutes, `[ios]` about the same, `[windows]` ~20.
  - Run `./tool/check.sh` and look at screenshots locally *before* pushing, so CI is a confirmation, not a debugger.
  - **Batch:** finish the owner's whole request, then push once. Several small code pushes in a row are several full builds (cancel-in-progress only saves part of each).
  - **`[mac]` only when the owner wants a Mac build now**, once per batch, on the last push. Never for layout iterations; check those with web screenshots. `[ios]`/`[windows]` only when asked.
  - Docs-only changes (`*.md`, `docs/`) don't build; keep them in their own commits when possible.
  - Re-run a failed job at most once, and only for a runner/infra failure.
- Commit messages explain *why*. Update `CHANGELOG.md` for anything the owner will notice.

## Gotchas that have already bitten (details in docs/TROUBLESHOOTING.md)

- `shared_preferences_android` and `path_provider_android` are **pinned** in `dependency_overrides`; newer versions crash release builds at startup (Pigeon JNI). Don't remove the pins.
- Android release builds must use `--no-shrink`. R8 strips plugin code that's only called from Dart.
- Impeller is disabled in `AndroidManifest.xml` (black screen on some GPUs).
- `MainActivity` is `singleTask` with Flutter deep linking off: shares and widget taps arrive over the `unstuck/android` channel (`features/outside/`). With the template's `singleTop` + empty `taskAffinity`, a share from another app would start a second copy of the app in that app's task.
- There's no Android SDK or Xcode in cloud sessions: Kotlin, Swift, resource and Xcode-project changes are only compiled by CI (Android job; iOS job on `[ios]`). Read them twice before pushing. Change the iOS targets through `tool/ios/add_extensions.rb`, not by hand.
- iOS: the widget and share extension share data with the app through the App Group `group.com.adhdtax.adhdTax`; all three entitlements files must list it.
- iOS iCloud sync: `Runner.entitlements` lists the iCloud container `iCloud.com.adhdtax.adhdTax`. If the App ID doesn't have it (Developer portal → Identifiers), the iOS job fails at signing. Native code lives in `AppDelegate.swift` (`ICloudBridge`) so no Xcode project edit was needed.
- OneDrive sign-in on Android comes back through `gumption://auth`: an intent filter on `MainActivity` (AndroidManifest.xml) and the `auth` request in `MainActivity.requestFrom`. The Entra registration must list both `http://localhost` and `gumption://auth` as *Mobile and desktop* redirect URIs, and must be named **Gumption** (OneDrive names the folder after it). Changing the app registration's name later renames nothing already created.
- `main.dart` wraps startup in `runZonedGuarded` and shows `StartupErrorApp` instead of a black screen. Keep it: it's how the owner reports crashes (screenshot + "Copy details").
- `app/web/about/` (the home page Google's branding check reads; the canvas-drawn app at `/` has no crawlable text), `app/web/privacy/`, `app/web/support/` and `app/web/terms/` are plain HTML pages published with the web app; Google's sign-in screen, both store listings and Settings → Help (`core/links.dart`) link to them, and the stores' Data safety / App Privacy answers (docs/store/LISTING.md) must stay true to them. Change all of these together when what the app does with data changes.
- The web build uses a **custom `web/flutter_bootstrap.js`** without Flutter's service worker, which would unregister `offline.js` and reload the page in a loop.
- Flutter web ignores iPhone safe areas and rewrites the viewport tag. `core/safe_area/` fixes both; don't remove `WebSafeArea` from `app.dart`.
- **The build tags match anywhere in the commit message**, including a sentence like "no [ios] build needed" (2026-10-24: that wording started an unwanted ~100-minute iPhone build). When a commit shouldn't trigger a build, don't write the tag at all; say "no iPhone build" instead.
- CI uses `cancel-in-progress`: a new push cancels the running build for the branch, including its Mac job. A `[mac]` push followed quickly by one without `[mac]` leaves the Mac app on the old build, so put `[mac]` on the **last** push of a series.
- **Actions minutes run out** (2026-10-22: every job, even Linux, "failed" in 2–3 s with no runner and no logs). The private repo gets 2,000 minutes a month; macOS counts 10×, Windows 2×. CI now runs once per commit, skips docs-only commits, and builds Windows/Mac/iOS only on request. Batch `[mac]` builds. If jobs fail instantly with no runner, check github.com/settings/billing before debugging.
- **Never delete and recreate the rolling releases** (`android-latest`, `macos-latest`, `play-latest`). Build 100 deleted `android-latest` and then got HTTP 403 creating it again, leaving the owner with no download. The likely cause: GitHub refuses the build token creating a tag at a commit whose `.github/workflows` file differs from the default branch's. The publish steps now `gh release upload --clobber` into the existing release and only create one (anchored on the default branch) if it's missing. The same cause probably explains an earlier 403 on a `workflow_dispatch` run.
- **Calendar days, not 24 hours:** step dates with `DateTime(y, m, d + n)`, never `.add(Duration(days: n))` on a local midnight, which lands on the wrong date across a clock change (quick add's "in 2 weeks" and streaks both broke). Tests run in Los Angeles time (CI and `check.sh`) so this shows up; passing in UTC proves nothing.
- **Editors save what changed, onto the latest record** (`TasksController.saveEdits`, `TemplatesController.saveEdits`, the note editor's `_base`), and **Undo reverts only what its action changed** (`TasksController.revert`). Writing the whole copy taken when the screen opened (or before the tap) undoes anything done meanwhile, in the list or synced in from another device.
- **Anything that sorts tasks by the time watches `pickerTickProvider`** (the picks, errand run, Tasks' Coming up, Today's check-back). Reading `clockProvider` alone in a build method goes stale: nothing rebuilds when a snooze or check-back time passes.
- **Sync checkpoints only what's on disk.** `sync.v1.<ws>` (files already read) is saved only when the workspace isn't in `ReplicaSet.unsaved`, and an upload owed is stored in it (`SyncState.uploadOwed`). See docs/ARCHITECTURE.md → sync round.
- Home changes after 5 pm (the "Wrap up" link). A layout that fits in the afternoon overflowed in the evening and only failed tests run after 5 pm; `narrow_layout_test` now pins the clock to 9 pm. Pin `clockProvider` in any test whose layout depends on the time.
- **Menus and sheets on tab screens need `useRootNavigator: true`** (`PopupMenuButton`, `showModalBottomSheet`). The tabs live in go_router's nested shell navigator, so without it they open *under* the floating nav bar and bottom items (e.g. Delete) can't be tapped. `test/flutter_test_config.dart` makes tests fail on any tap that wouldn't hit its target.
- The focus screen ticks every second and the buddy dot animates forever, so `pumpAndSettle()` there can hang: pump fixed durations instead (`frames()` in `reset_errands_company_ai_test.dart`). Override `ambientPlayerProvider`, `aiKeyStoreProvider` and `httpClientProvider` in tests; the real ones need native plugins or the network.
- `pumpApp()` defaults to 1400×1000, a desktop size: Tasks shows the filter pills, the list and a detail pane (tapping a row selects it; the editor opens from **Edit task** or a double tap), Notes shows the sidebar (no filter pills), Settings shows one section at a time (tap its `SideItem` first), Today / Progress / the editor / wrap-up are desktop layouts, and Quick add and every `showAppSheet` pop-up is a `Dialog`, not a `BottomSheet`. Pass a phone `size` to test the phone layout. On a phone, Tasks' workspace/project/List-Board choices are in a sheet (tap the square with tooltip 'Show tasks', then **Done**), Quick add hides Priority/dread/Leave the house until **More options**, and Home shows the check-back as a badge (tooltip "Check back on N waiting task(s)") instead of a banner.
- **Start shows the Started screen for 2.6 s** before Focus (1.2 s with Reduce Motion; none when celebrations are Off). Tests that tap anything on Focus must get past it first: `pastStarted(tester)` from `app_flow_test.dart`. `FieldLabel` and overlines render in capitals, so tests find `'STEP 1 OF 3'`, not `'Step 1 of 3'`.
- `IconData` can't be extended in this Flutter, so the `phosphor_flutter` package doesn't compile: the Phosphor fonts are vendored in `assets/fonts/` and `tool/make_phosphor.py` writes `Ph` constants from the package's codepoint table in the pub cache. If the cache lacks it: `dart pub cache add phosphor_flutter --version 2.1.0`.
- **Saves write only the fields that changed** (`putChanged` in `sync/replicas_controller.dart`, used by tasks, notes, projects, templates and rewards). A field this build reads with a fallback (an enum value from a newer build, like a new kind of repeat) is left as stored instead of being stamped with this build's default and overwriting the newer value everywhere. Don't go back to `r.put(coll, id, wholeRecord, now)` for an update.
- **Device id clones are detected and fixed** (`Replica.lacksOwnWritesIn`, `SyncOutcome.cloned`, `ReplicasController.changeDeviceId`). A phone restored from a backup of another (Android Auto Backup, iCloud backup, Migration Assistant) carries the same `device.id`. Its first sync round reads its "own" cloud file, finds writes stamped with its id that it never made, and takes a new id: new sync file, old one read like any other device's. A device whose storage was rolled back looks identical and does the same (harmless). `syncOnce` also drops a remembered `ownFileId` whose file name no longer matches the device id.
- **Reconnect never moves a workspace to another account silently.** `SyncController.connect()` returns the new email instead of syncing when it differs from the stored one; the UI asks, then calls `confirmAccountSwitch()` or `cancelAccountSwitch()` (`accounts_panel.dart` `_reconnect`). Android's account picker ignores the email hint, so this is reachable.
- **Opening a screen from outside goes through `openFromOutside`** (`app.dart`): notifications, the Android widget and share/route intents. It only accepts known routes, doesn't open a second focus session for the same task, swaps one task's session for another's with `pushReplacement`, and pushes full-screen pages (`/wrapup`, `/add`). A tab route **replaces** the stack, because go_router can't push the tab shell over a page (its navigator key is single: "!keyReservation.contains(key)"). A focus session closed that way, or any other way without Done/Stop, records its time in `dispose` (`_bankPartial`, deferred a microtask).
- **Things on Home that change with the time of day watch `dayPartProvider`** (`picker_controller.dart`): the 5 pm "Wrap up" link, the desktop "Monday evening" header. `OutsideBootstrap` invalidates it at noon, 5 pm, 10 pm and midnight (`nextDayPart`) and on resume. Timers live in that widget, not in providers: a provider timer outlives `pumpApp`'s widget tree and fails tests with "A Timer is still pending".
- **Start and finish XP come once per task per day** (`ProgressController._recordedOn`). Finishing again (done, reopened, done) or starting again returns a celebration with an empty award and writes no event; `foldEvents` already counted one finish per task per day, so XP shown and then taken back can't happen.
- **CI secrets go only into the `env:` of the step that uses them**, and jobs test for a secret with a flag (`HAS_ASC_KEY: ${{ secrets.ASC_KEY_ID != '' }}`). Third-party actions are pinned to commit SHAs (`# v4` comments say which tag); the workflow is `permissions: contents: read` by default. To update a pin: `gh api repos/<owner>/<action>/commits/<tag> -q .sha`.
- Widget tests: `pumpApp()` in `test/widget/app_flow_test.dart` builds the full app with in-memory storage and accepts provider `overrides`. Use `FakeReminders` (`reminders_undo_test.dart`) for notification behavior. Snackbars need `pumpAndSettle()` before tapping their action.
