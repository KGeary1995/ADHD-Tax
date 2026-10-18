# Deployment

Everything about getting builds onto devices: CI, release links, secrets, signing, hosting and the Google setup. The owner-facing install steps live in `README.md`; this page is the operator's view.

## Where each platform's build lands

| Platform | Built by | Delivered via | Link |
|---|---|---|---|
| Android | CI `android` job, every push | GitHub release **`android-latest`** (asset replaced each build) | `https://github.com/KGeary1995/ADHD-Tax/releases/download/android-latest/ADHD-Tax.apk` |
| Mac | CI `macos` job, on `[mac]` commits, pushes to `main`, or Run workflow | GitHub release **`macos-latest`** | `https://github.com/KGeary1995/ADHD-Tax/releases/download/macos-latest/ADHD-Tax-macOS.zip` |
| iPhone + web | CI `test` job builds; `web-publish` deploys | Cloudflare Pages project `adhd-tax` (or repo variable `CLOUDFLARE_PROJECT`) | `https://adhd-tax.pages.dev` (the exact address is shown in the job summary) |
| Windows | CI `windows` job, every push | Run artifact `adhd-tax-windows` only (no release yet) | Actions → run → Artifacts |

The repo is **private**, so release downloads need a signed-in GitHub session.

## CI workflow (`.github/workflows/ci.yml`)

Triggers: `push`, `pull_request`, `workflow_dispatch`. Concurrency group = `ci-<event>-<ref>` with cancel-in-progress, so a newer push cancels an older push run on the same branch, but manual runs and pushes don't cancel each other.

| Job | Runs on | Does | Publishes |
|---|---|---|---|
| `test` | ubuntu | `pub get` → `dart format --set-exit-if-changed` → `flutter analyze` → `flutter test` → web build | artifact `adhd-tax-web` |
| `android` | ubuntu, after `test` | `flutter build apk --release --no-shrink --build-number=<run_number>` | `android-latest` release, except on `pull_request` |
| `windows` | windows, after `test` | `flutter build windows --release` | artifact only |
| `web-publish` | ubuntu, after `test`, push or dispatch | `wrangler pages project create` (first time) + `pages deploy --branch=main` | Cloudflare Pages; skipped with a notice if secrets are missing |
| `macos` | macos-latest, after `test`; dispatch, `main`, or `[mac]` in the commit message | `flutter build macos --release` → `ditto` zip | `macos-latest` release |

Every build job first writes `app/google_oauth.json` from secrets and builds with `--dart-define-from-file=google_oauth.json`. Missing secrets produce empty values, which means sync is off.

**Version numbers:** the CI run number is the build number. On Android it's the `versionCode`, so each APK installs over the previous one and keeps local data, as long as it's signed with the same key.

**Actions minutes:** the repo is private, so GitHub's free plan gives 2,000 minutes a month. Linux runs count 1×, Windows 2× and macOS 10×. A normal push run uses roughly 25 billed minutes (Windows counts double); a Mac build about 100.

## Secrets and variables (repo → Settings → Secrets and variables → Actions)

| Name | Kind | Used by | Where to get it |
|---|---|---|---|
| `GOOGLE_WEB_CLIENT_ID` | secret | all builds | Google Auth Platform → Clients → Web application |
| `GOOGLE_DESKTOP_CLIENT_ID` | secret | all builds (used by Mac/Windows) | Clients → Desktop app |
| `GOOGLE_DESKTOP_CLIENT_SECRET` | secret | all builds (used by Mac/Windows) | Clients → Desktop app |
| `CLOUDFLARE_API_TOKEN` | secret | `web-publish` | Cloudflare → My Profile → API Tokens → custom token, permission *Account · Cloudflare Pages · Edit* |
| `CLOUDFLARE_ACCOUNT_ID` | secret | `web-publish` | Cloudflare → Workers & Pages (right sidebar) |
| `CLOUDFLARE_PROJECT` | variable (optional) | `web-publish` | Defaults to `adhd-tax` |

The Google client ids and the desktop "secret" end up inside the shipped apps. That's normal for installed and browser apps (Google documents installed-app secrets as non-confidential). They're kept as secrets only to keep them out of the repo history.

**Status as of 2026-10-18:** none of these secrets exist yet, so builds have sync off and the iPhone web app isn't published.

## Android signing

- Key: `app/android/app/sideload.jks`, **committed on purpose**. Every CI build must be signed with the same key, or Android refuses to install updates over the old app, and Google Sign-In's Android client is registered against this key's SHA-1.
- Store/key password `adhdtax-sideload`, alias `sideload` (in `build.gradle.kts`).
- SHA-1: `E9:F6:E9:C8:17:8A:B9:27:E7:9A:28:87:EC:67:D5:04:4F:F5:1F:BA`.
- Before any public or Play Store release, move to a secret-backed key. Changing keys means users must uninstall (losing local-only data), and the Android OAuth client must be re-registered with the new SHA-1.
- Release flags that matter: `--no-shrink` (R8 broke plugins), Impeller disabled in the manifest, core-library desugaring enabled (flutter_local_notifications).

## Mac distribution

- CI builds a universal app, signed ad hoc (`CODE_SIGN_IDENTITY = "-"`), with no Apple Developer account. Gatekeeper blocks the first launch: **System Settings → Privacy & Security → Open Anyway**, or `xattr -dr com.apple.quarantine "/Applications/ADHD Tax.app"`.
- Sandbox entitlements (`macos/Runner/*.entitlements`) include `network.client` (Drive) and `network.server` (the loopback OAuth redirect).
- Data lives in the app's sandbox container (bundle id `com.adhdtax.adhdTax`) and survives updates.
- Proper signing and notarization would need the $99/year Apple Developer Program; that would also enable TestFlight for a native iPhone app.

## iPhone / web hosting (Cloudflare Pages)

- `web-publish` always deploys with `--branch=main` to a project whose production branch is `main`, so the address never changes. This matters: **an iPhone home-screen app's data belongs to its address**, so changing the URL starts it empty.
- The first deploy creates the project. If `adhd-tax.pages.dev` is taken, Cloudflare picks a suffixed name, shown in the job summary. After that, add the address to the Google web client's JavaScript origins.
- Home-screen installs keep their own storage, separate from Safari tabs.
- No push notifications: iPhone web apps can't schedule local notifications, and there's no server to send push.

## Google Cloud setup (sync)

The step-by-step for the owner is in `README.md` → *Set up Google sync*. Operator notes:

- One Google Cloud project, **External** audience, **published (In production)**. Testing mode expires refresh tokens after 7 days.
- Scopes: `drive.appdata`, `drive.file` only (non-sensitive, so no verification needed). Adding anything sensitive (e.g. Calendar for Phase 3) means Google shows an "unverified app" warning (fine for up to 100 users) or requires verification.
- Clients: **Web** (web, iPhone and Android `serverClientId`), **Android** (package + SHA-1 above, no id needed in the app), **Desktop** (Mac/Windows).
- The clinic's Google Workspace may block unapproved apps. The admin trusts the client ids under Admin console → Security → API controls.

## Doing it by hand (no CI)

```bash
cd app
flutter build apk --release --no-shrink --dart-define-from-file=google_oauth.json
flutter build macos --release --dart-define-from-file=google_oauth.json      # on a Mac
flutter build windows --release --dart-define-from-file=google_oauth.json    # on Windows
flutter build web --release --no-web-resources-cdn --dart-define-from-file=google_oauth.json
npx wrangler@4.145.0 pages deploy build/web --project-name=adhd-tax --branch=main
```
