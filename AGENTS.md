# AGENTS.md — start here

Orientation for any AI coding session (Claude Code, Codex, Cursor, …) or human picking up this repo cold. It is kept current: **if you change behavior, build, CI or deployment, update this file and the relevant `docs/` page in the same commit.**

## What this is

**Gumption** (store name *Gumption: Task Starter*; formerly *Unstuck*, originally *ADHD Tax*; the repo and internal ids keep the old names) is a task-initiation app for an ADHD user who struggles to *start* tasks. It picks one task for you (based on time available, energy, whether you can leave the house), shrinks it to a first step, runs a visual focus timer, and rewards starting with XP. Personal and Work tasks are kept apart and each syncs to its own Google account through Drive.

- **One Flutter codebase** in `app/` → Android (APK, sideloaded), iPhone/iPad (native, TestFlight), Mac, Windows, web. The web build is also the no-account iPhone option.
- **No backend server.** Data lives on each device and syncs through a hidden Google Drive app-data folder per Google account.
- **Naming:** the user-visible name is **Gumption** (since 2026-10-22). Internal identifiers keep the old names **on purpose**: the Android applicationId `com.adhdtax.adhd_tax`, the Mac bundle id `com.adhdtax.adhdTax`, the Dart package `adhd_tax`, the repo `KGeary1995/ADHD-Tax`, the web token key `adhdtax.googleToken.*`, and the repeat-copy id seed `adhd-tax:repeat:` (pinned by a test). From the Unstuck era: the `unstuck/android` method channel, the `unstuck://` URL scheme, the backup file `kind` `unstuck-backup` (old backups must still restore), the iOS target folders `UnstuckWidget`/`UnstuckShare`, the Cloudflare project `unstuck` (the web address), and a copy of the APK published as `Unstuck.apk` so old links work. Changing them installs a separate, empty app, breaks Google Sign-In's Android client, or duplicates repeating tasks across devices. See docs/DECISIONS.md.
- **Owner context:** the user works in ophthalmology clinic operations. Work tasks must never contain patient information (PHI). See "Rules" below.

## Status (keep this section current)

| Area | State | Verified on a real device? |
|---|---|---|
| Phase 1: offline app (picker, focus, XP, themes, quotes) | Done | Android: yes (Build 9+) |
| Redesign: one look, light + dark, bundled fonts, floating nav | Done | Not yet (web screenshots only) |
| Phase 2: Google sign-in + Drive sync | Code done; Google Cloud keys (web, Android, desktop clients) added as secrets 2026-10-19; no iOS client yet | **Yes (Android, 2026-10-19):** Personal connected in the personal profile; Work connected from a second install in the Android **work profile** (the personal-profile app can't see work-profile accounts). **2026-10-22:** sync survives an app update since the silent sign-in retry (Build 77). Two-device sync not yet reported |
| Phone layout fixes, full task form, back button | Done | Android: reported working |
| Repeating tasks, Mark done + Undo, Android reminders | Done | **Partly (Build 91):** Mark done + Undo and the focus timer's "Time's up" alert (screen off) pass; repeating tasks not yet tested |
| Waiting-on follow-ups, real task lengths, evening wrap-up, voice capture | Done | **Partly (Build 91):** wrap-up and voice capture pass; waiting-on and real task lengths not yet tested on a device |
| Android home-screen widget, Share → Gumption | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed (card widget Start and +, Share from Chrome opens one copy of the app) |
| iPhone/iPad native app (notifications, widgets, Share, voice) | Code done; CI compiles it on `[ios]` pushes; TestFlight upload needs the Apple secrets | **No.** Compiles in CI (Build 35). On hold: the owner will join the Apple Developer Program once iPhone-using friends confirm they want it |
| iPhone web app (home-screen) | Done; Cloudflare secrets added 2026-10-18, published by `web-publish` on every push to **https://unstuck-4o8.pages.dev** (Build 39+). Being trialled with iPhone-using friends to decide on the native app | No (Chromium emulation only) |
| Backup file (Settings → Save / Restore) | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed (save to Downloads, restore the same file) |
| Mac app | Builds and publishes on `[mac]` pushes | **Yes**: opens and works after "Open Anyway" (Build 21, still named ADHD Tax) |
| Notes (tags, #hashtags, Make tasks, task-linked notes), projects, Tasks board view, "Show on this device" (Personal / Work / Both) | Done | Not yet (tests and web screenshots) |
| Checklists in tasks, reward shop, typed extras in Quick add ("tomorrow 2pm 15 min #tag"), templates, task tags | Done | Not yet (tests and web screenshots) |
| Weekly reset, errand runs, focus company (sounds + buddy), Mac/Windows Quick add hotkey, AI "Break it down" (own Anthropic key) | Done | **Partly (Build 91):** errand run passes on Android. Weekly reset, focus company, the desktop hotkey and AI breakdown not yet tested on a device |
| Phone declutter: Tasks filters in one sheet and short rows, Quick add "More options", quieter Today | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed |
| Desktop layout: Tasks/Notes/Settings sidebars, desktop Today / Progress / editor / wrap-up, pop-ups and Quick add as windows | Done | Not yet (tests and 1440×900 web screenshots; the owner's Mac screenshots predate it) |
| In-app guide ("How Gumption works") and example tasks | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed (guide and Go to buttons; example tasks not tested) |
| Built-in first-step ideas and Suggest steps (no AI key), "Hold me to it" share from the focus screen | Done | **Yes (Android, Build 91, 2026-10-22):** docs/PHONE_TEST.md all passed (idea chips, Suggest steps, Hold me to it share sheet) |
| Phase 3+ (Calendar, table/timeline views) | Not started | — see docs/PLAN.md |

Last updated: 2026-10-22 (Build 91 passed the phone test in docs/PHONE_TEST.md).

## Toolchain

| Tool | Version | Notes |
|---|---|---|
| Flutter / Dart | **3.47.7** / 3.13.5 | Pinned in `.github/workflows/ci.yml` (`FLUTTER_VERSION`). In Claude Code cloud sessions Flutter is at `/opt/flutter/bin` and not on PATH; `app/tool/check.sh` handles that. It warns about running as root; ignore it. |
| Java | 17 (Temurin) | Android builds |
| Node | 22 | Cloudflare deploy (`wrangler@4.145.0`) and the screenshot tool |
| Python 3 + Pillow, numpy | any recent | Only for `app/tool/make_icons.py` (Pillow) and `app/tool/make_sounds.py` (numpy) |
| Xcode | CI's `macos-latest` | Mac and iOS builds happen in CI; no Mac needed locally |
| Ruby + `xcodeproj` gem | any | Only for `app/tool/ios/add_extensions.rb` (adds the iOS widget/share targets) |

## Commands (run from `app/`)

```bash
./tool/check.sh                      # format check + analyze + all tests: exactly what CI runs. Run before every push.
flutter pub get
flutter test                         # 232 tests, ~60 s
flutter test test/widget/reminders_undo_test.dart   # one file
dart format lib test                 # CI fails on unformatted code
flutter run -d chrome                # quickest way to see the app
flutter build web --release --no-web-resources-cdn   # self-contained web build (no CDN; needed behind proxies)
flutter build apk --release --no-shrink              # --no-shrink is REQUIRED (see Gotchas)
python3 tool/make_icons.py           # redraw every app icon (web, iPhone, Mac, Android)
python3 tool/make_sounds.py          # regenerate the focus-screen background sounds (numpy)
```

Seeing UI changes without a phone: `app/tool/screenshots/shoot.mjs` (Playwright) screenshots the web build with demo data at any size, including a fake iPhone home-indicator inset. Usage is in the file header.

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

1. Work on the session's feature branch; keep PR #1 (`claude/eloquent-feynman-mhvav7` → `main`) or its successor updated.
2. `./tool/check.sh` must pass.
3. Push. CI runs once per commit (push only; docs-only commits, i.e. `*.md` and `docs/`, skip CI entirely): `test` (format, analyze, test, web build), then in parallel:
   - **Android**: builds the APK and replaces the `android-latest` release asset. The phone download link never changes.
   - **Windows**: only on `workflow_dispatch` or **commit messages containing `[windows]`**; builds an artifact (not published as a release).
   - **web-publish**: deploys to Cloudflare Pages if the Cloudflare secrets exist (otherwise it posts a notice).
   - **macOS**: only on `workflow_dispatch`, pushes to `main`, or **commit messages containing `[mac]`** (macOS runners cost 10× minutes). Publishes to the `macos-latest` release.
   - **iOS**: only on `workflow_dispatch`, pushes to `main`, or **commit messages containing `[ios]`**. Compiles without Apple secrets; with them, uploads to TestFlight.
   - **Play bundle**: only on `workflow_dispatch` or **commit messages containing `[play]`**. Builds the signed `.aab` (needs the upload-key secrets) and publishes it to the `play-latest` release for the owner to upload to Play Console.
4. Tell the owner: "reinstall from the same link". The build number is the CI run number.

Details, secrets and failure modes: docs/DEPLOYMENT.md.

## Rules

- **No PHI anywhere**: no patient names, dates of birth or MRNs in code, tests, fixtures, docs, commit messages or screenshots. Demo data uses generic tasks. The in-app PHI guard (`features/safety/phi_guard.dart`) is a warning, not a control.
- **New synced collections or fields:** JSON scalars only (a list or map field compares by identity and gets re-stamped on every save; see `Note.tags`).
- **Keep the sync data model backward compatible.** Devices run different builds. New `Task` fields must have defaults in `Task.fromJson`; never rename or reuse a field. Never rewrite or delete XP events: revoke one by tombstoning it (`ProgressController.revoke`).
- **Pure logic stays pure Dart** (no Flutter imports): `picker_engine.dart`, `recurrence.dart`, `nudge_plan.dart`, `xp_rules.dart`, `achievements.dart`, `progress_event.dart`, `phi_guard.dart`, `quote_service.dart`, `hlc.dart`, `replica.dart`, `sync_engine.dart`, `estimate_calibration.dart`, `backup_file.dart`, `note.dart`, `checklist.dart`, `reward.dart`, `template.dart`, `quick_parse.dart`, `weekly_reset.dart`, `errand_run.dart`, `breakdown.dart` (HTTP through an injected `http.Client`), `first_steps.dart`. Test them with plain unit tests.
- **Phone first.** Every screen must work at 360×800 with 1.3× text (`test/widget/narrow_layout_test.dart` enforces this for the capture screens). Prefer wrapping `ChoiceGroup` pills over `SegmentedButton`.
- **One look.** Colors, fonts and type styles come from `core/theme/app_themes.dart` (`context.spec`: `display()`, `mono()`, `accent`, `primary`…) and shared pieces from `widgets/ui.dart` (`Panel`, `Group`/`GroupRow`/`SwitchRow`, `Pill`, `ChoiceGroup`, `Segmented`, `PageHeader`). Don't hard-code colors in screens, and check both light and dark. The approved design is the Claude Design canvas linked in docs/DECISIONS.md.
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
- `main.dart` wraps startup in `runZonedGuarded` and shows `StartupErrorApp` instead of a black screen. Keep it: it's how the owner reports crashes (screenshot + "Copy details").
- `app/web/privacy/`, `app/web/support/` and `app/web/terms/` are plain HTML pages published with the web app; Google's sign-in screen, both store listings and Settings → Help (`core/links.dart`) link to them, and the stores' Data safety / App Privacy answers (docs/store/LISTING.md) must stay true to them. Change all of these together when what the app does with data changes.
- The web build uses a **custom `web/flutter_bootstrap.js`** without Flutter's service worker, which would unregister `offline.js` and reload the page in a loop.
- Flutter web ignores iPhone safe areas and rewrites the viewport tag. `core/safe_area/` fixes both; don't remove `WebSafeArea` from `app.dart`.
- CI uses `cancel-in-progress`: a new push cancels the running build for the branch, including its Mac job. A `[mac]` push followed quickly by one without `[mac]` leaves the Mac app on the old build, so put `[mac]` on the **last** push of a series.
- **Actions minutes run out** (2026-10-22: every job, even Linux, "failed" in 2–3 s with no runner and no logs). The private repo gets 2,000 minutes a month; macOS counts 10×, Windows 2×. CI now runs once per commit, skips docs-only commits, and builds Windows/Mac/iOS only on request. Batch `[mac]` builds. If jobs fail instantly with no runner, check github.com/settings/billing before debugging.
- Starting `workflow_dispatch` through the GitHub API gave HTTP 403 on release creation; push-triggered runs publish fine. Use a `[mac]` commit to get a Mac build.
- Home changes after 5 pm (the "Wrap up" link). A layout that fits in the afternoon overflowed in the evening and only failed tests run after 5 pm; `narrow_layout_test` now pins the clock to 9 pm. Pin `clockProvider` in any test whose layout depends on the time.
- **Menus and sheets on tab screens need `useRootNavigator: true`** (`PopupMenuButton`, `showModalBottomSheet`). The tabs live in go_router's nested shell navigator, so without it they open *under* the floating nav bar and bottom items (e.g. Delete) can't be tapped. `test/flutter_test_config.dart` makes tests fail on any tap that wouldn't hit its target.
- The focus screen ticks every second and the buddy dot animates forever, so `pumpAndSettle()` there can hang: pump fixed durations instead (`frames()` in `reset_errands_company_ai_test.dart`). Override `ambientPlayerProvider`, `aiKeyStoreProvider` and `httpClientProvider` in tests; the real ones need native plugins or the network.
- `pumpApp()` defaults to 1400×1000, a desktop size: Tasks and Notes show the sidebar (no filter pills), Settings shows one section at a time (tap its `SideItem` first), Today / Progress / the editor / wrap-up are desktop layouts, and Quick add and every `showAppSheet` pop-up is a `Dialog`, not a `BottomSheet`. Pass a phone `size` to test the phone layout. On a phone, Tasks' workspace/project/List-Board choices are in a sheet (tap the `Icons.filter_list_rounded` pill, then **Done**), Quick add hides Priority/dread/Leave the house until **More options**, and Home shows the check-back as a badge (tooltip "Check back on N waiting task(s)") instead of a banner.
- Widget tests: `pumpApp()` in `test/widget/app_flow_test.dart` builds the full app with in-memory storage and accepts provider `overrides`. Use `FakeReminders` (`reminders_undo_test.dart`) for notification behavior. Snackbars need `pumpAndSettle()` before tapping their action.
