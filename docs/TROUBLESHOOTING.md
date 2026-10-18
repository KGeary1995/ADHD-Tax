# Troubleshooting

Symptom → cause → fix. Every entry here happened on this project; add new ones as they come up (date + build).

## Installing and launching

| Symptom | Cause | Fix |
|---|---|---|
| APK download reaches 100% then "download failed" (Android) | Opened in an in-app browser (e.g. the GitHub or Claude app's web view), which can't hand the file to the installer | Open the link in **Chrome**, or long-press → Open in browser. |
| "App not installed" when updating on Android | APK signed with a different key than the installed one | Only CI builds (signed with `sideload.jks`) install over each other. A locally built debug APK needs an uninstall first, which loses local-only data. |
| **Black screen** on Android launch (Builds ≤ 6) | An exception before the first frame (release builds show nothing) | Fixed in Build 8: `runZonedGuarded` + `StartupErrorApp` show the error instead. If you ever see black again, it's below Dart (engine/GPU); Impeller is already disabled. |
| Startup error screen: `PlatformException … NoSuchMethodError … SharedPreferencesApiRegistrar.getAll` | `shared_preferences_android` ≥ 2.5 / `path_provider_android` ≥ 2.3 use Pigeon JNI, which breaks in release builds | Pinned to 2.4.28 / 2.2.23 in `dependency_overrides` (Build 9). Keep the pins and keep `--no-shrink`. Re-test on a real phone before removing them. |
| Mac: *"Unstuck" Not Opened — Apple could not verify…* | Ad-hoc signed app, not notarized | **Done** → System Settings → Privacy & Security → **Open Anyway**. Or `xattr -dr com.apple.quarantine "/Applications/Unstuck.app"`. Repeat for each new download. |
| Two apps on the Mac after the rename ("ADHD Tax" and "Unstuck") | The Mac app file name changed with the rename | Delete **ADHD Tax** from Applications. Both use the same bundle id, so tasks are kept. |
| Android still says "ADHD Tax" under the icon right after updating | Launcher label cache | It updates after a moment; restarting the launcher or phone forces it. |
| iPhone home-screen app starts empty | Data is per address, and home-screen installs are separate from Safari tabs | Always open the same `*.pages.dev` address from the home-screen icon. With sync on, connecting restores everything. |

## Reminders (Android)

| Symptom | Cause | Fix |
|---|---|---|
| No timer alert or nudges at all | Notification permission denied | Settings → Reminders shows **Allow notifications**; otherwise Android Settings → Apps → Unstuck → Notifications. |
| Alerts late or missing | Manufacturer battery optimization (Samsung, Xiaomi, OnePlus…) | Android Settings → Apps → Unstuck → Battery → **Unrestricted**. |
| Nudges stopped after weeks without opening the app | Only 14 days are planned ahead, re-planned on each launch | Open the app; it re-plans. |
| Swiped the app away mid-focus and the session is gone | The session lives in memory; only the alert is OS-scheduled | Known limitation. |

## Sync

| Symptom | Cause | Fix |
|---|---|---|
| Settings says "Google sync isn't set up in this build" | Build made without client ids | Add the `GOOGLE_*` secrets (docs/DEPLOYMENT.md), then rebuild (push; `[mac]` for Mac). |
| Work account: "access blocked" | Clinic Google Workspace blocks unapproved third-party apps | Admin trusts the client ids (Admin console → Security → API controls). Personal still works. |
| Signed out about every 7 days | Google Auth Platform audience still in **Testing** | Publish the app (In production). |
| Web/iPhone shows **Reconnect** hourly | Browsers only get ~1 h tokens without a server | Expected; one tap. Token persists across reopenings within the hour. |
| Android sign-in fails with `DEVELOPER_ERROR` / "Developer console is not set up correctly" | No Android OAuth client for package `com.adhdtax.adhd_tax` + SHA-1 `E9:F6:…:1F:BA`, or the web client id missing (`serverClientId`) | Create both clients in the same Google project. |
| Web sign-in: "Error 400: origin_mismatch" or console "The given origin is not allowed for the given client ID" | The site's address isn't in the web client's Authorized JavaScript origins | Add the exact origin (scheme + host, no path). |
| Same task appears twice after offline edits | Shouldn't happen: ids are uuids and repeat copies use deterministic ids | Capture both devices' "Back up to Drive" JSON and inspect the `tasks` records' clocks. |

## CI

| Symptom | Cause | Fix |
|---|---|---|
| `test` job fails at `dart format` | Unformatted code | `cd app && dart format lib test`, or run `./tool/check.sh` before pushing. |
| Release step: `HTTP 403: Resource not accessible by integration` | Seen when the run was a `workflow_dispatch` started through the GitHub API (via the Claude GitHub App). Push-triggered runs publish fine. | Trigger the Mac build with a `[mac]` commit, or have the owner press **Run workflow** in GitHub. |
| Android publish skipped after a manual run | (Fixed) Older workflow only published on `push` | The current workflow publishes on any non-PR event. |
| A push run shows "cancelled" | A newer push on the same branch superseded it (concurrency) | Expected; the newest run publishes. |
| macOS job skipped | Not a `[mac]` commit, not `main`, not dispatch | Intended (10× minutes). |
| `web-publish` succeeds but nothing deployed | Cloudflare secrets missing; the job only posts a notice | Add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. |

## Web build quirks

| Symptom | Cause | Fix |
|---|---|---|
| Page reloads itself on every load / offline mode never sticks | Flutter's default bootstrap registers its deprecated service worker, which unregisters all workers and reloads | Keep the custom `web/flutter_bootstrap.js` (no `serviceWorkerSettings`). |
| Bottom bar under the iPhone home indicator | Flutter web ignores safe areas and drops `viewport-fit=cover` | `WebSafeArea` (`core/safe_area/`) must stay in `app.dart`. Test with `shoot.mjs … --iphone`. |
| Web build fails to load fonts/CanvasKit behind a proxy | Default build pulls CanvasKit from gstatic | Build with `--no-web-resources-cdn`. |

## Working in a Claude Code cloud session

| Symptom | Fix |
|---|---|
| `flutter: command not found` | `export PATH=/opt/flutter/bin:$PATH` in the same command, or use `app/tool/check.sh`. |
| "Woah! You appear to be trying to run flutter as root" | Harmless. |
| Playwright can't reach the local server or the internet | Launch Chromium with `--proxy-server=$HTTPS_PROXY` (shoot.mjs does) and serve on `127.0.0.1`. |
| Web screenshots show a locale error | Use `locale: 'en-US'` in the browser context (shoot.mjs does). |
| Phone-layout tests fail only in the evening | Home adds a "Wrap up" link after 5 pm. Pin `clockProvider` in layout tests (`narrow_layout_test` uses 9 pm). |
| `rm` of temp files refused by a safety check | Write temp files to the session scratchpad instead and don't delete them. |
