# Deployment

Everything about getting builds onto devices: CI, release links, secrets, signing, hosting and the Google setup. The owner-facing install steps live in `README.md`; this page is the operator's view.

## Where each platform's build lands

| Platform | Built by | Delivered via | Link |
|---|---|---|---|
| Android | CI `android` job, every push | GitHub release **`android-latest`** (asset replaced each build) | `https://github.com/KGeary1995/ADHD-Tax/releases/download/android-latest/Gumption.apk` (the same file is also published as `Unstuck.apk`, so links from before the rename keep working) |
| Mac | CI `macos` job, on `[mac]` commits or Run workflow | GitHub release **`macos-latest`** | `https://github.com/KGeary1995/ADHD-Tax/releases/download/macos-latest/Gumption-macOS.zip` |
| iPhone / iPad (native) | CI `ios` job, on `[ios]` commits or Run workflow | App Store Connect → **TestFlight** (needs the Apple secrets; until then the job only compiles) | TestFlight app on the device |
| Web (and iPhone without an Apple account) | CI `test` job builds; `web-publish` deploys | Cloudflare Pages project `unstuck` (or repo variable `CLOUDFLARE_PROJECT`) | **`https://unstuck-4o8.pages.dev`** (project created by Build 39; the suffix is Cloudflare's because `unstuck` was taken) |
| Google Play bundle | CI `play` job, on Run workflow or a `[play]` commit | GitHub release **`play-latest`** (pre-release), then uploaded by hand in Play Console | `…/releases/download/play-latest/Gumption-play.aab` |
| Windows | CI `windows` job, on Run workflow or a `[windows]` commit | Run artifact `unstuck-windows` only (no release yet) | Actions → run → Artifacts |

The repo is **private**, so release downloads need a signed-in GitHub session.

## CI workflow (`.github/workflows/ci.yml`)

Triggers: `push` (except docs-only commits) and `workflow_dispatch` (Run workflow), which asks which extra app to build: `ios` (default), `mac`, `ios+mac`, `play`, `windows` or `all`; no `pull_request`, so each commit builds once. Pushes to `main` build like any branch: test, Android and web only (they used to add Mac and iOS, ~200 minutes per merge; dropped 2026-10-22). Concurrency group = `ci-<event>-<ref>` with cancel-in-progress, so a newer push cancels an older push run on the same branch, but manual runs and pushes don't cancel each other.

| Job | Runs on | Does | Publishes |
|---|---|---|---|
| `test` | ubuntu | `pub get` → `dart format --set-exit-if-changed` → `flutter analyze` → `flutter test` → web build | artifact `unstuck-web` |
| `android` | ubuntu, after `test` | `flutter build apk --release --no-shrink --build-number=<run_number>` | `android-latest` release, except on `pull_request` |
| `play` | ubuntu, after `test`; dispatch or `[play]` in the commit message | Decodes the upload keystore from secrets, `UPLOAD_KEYSTORE=… flutter build appbundle --release --no-shrink --build-number=<run_number>` (`build.gradle.kts` signs with the upload key when that variable is set). Fails with a message if the secrets are missing | `play-latest` release |
| `windows` | windows, after `test` | `flutter build windows --release` | artifact only |
| `web-publish` | ubuntu, after `test`, push or dispatch | `wrangler pages project create` (first time) + `pages deploy --branch=main` | Cloudflare Pages; skipped with a notice if secrets are missing |
| `macos` | macos-latest, after `test`; dispatch or `[mac]` in the commit message | `flutter build macos --release` → `ditto` zip | `macos-latest` release |
| `ios` | macos-latest, after `test`; dispatch or `[ios]` in the commit message | Adds Google's reversed client id as a URL scheme. Without Apple secrets: `flutter build ios --no-codesign` (compile check). With them: `flutter build ios --config-only`, then `xcodebuild archive` and `-exportArchive` with `ios/ExportOptions.plist` (`destination: upload`), signing automatically through the API key (`-allowProvisioningUpdates`) | TestFlight |

Every build job first writes `app/google_oauth.json` from secrets and builds with `--dart-define-from-file=google_oauth.json`. Missing secrets produce empty values, which means sync is off.

**Version numbers:** the CI run number is the build number. On Android it's the `versionCode`, so each APK installs over the previous one and keeps local data, as long as it's signed with the same key.

**Actions minutes:** the repo is private, so GitHub's free plan gives 2,000 minutes a month. Linux runs count 1×, Windows 2× and macOS 10×. A normal push run now uses roughly 12 billed minutes (test + Android; docs-only commits run nothing); a Windows build adds about 20 and a Mac build about 100. They ran out on 2026-10-22 after 18 Mac builds plus every commit running twice (push and pull_request); both are fixed. When the minutes are gone, every job fails within seconds with no runner and no logs.

## Secrets and variables (repo → Settings → Secrets and variables → Actions)

| Name | Kind | Used by | Where to get it |
|---|---|---|---|
| `GOOGLE_WEB_CLIENT_ID` | secret | all builds | Google Auth Platform → Clients → Web application |
| `GOOGLE_DESKTOP_CLIENT_ID` | secret | all builds (used by Mac/Windows) | Clients → Desktop app |
| `GOOGLE_DESKTOP_CLIENT_SECRET` | secret | all builds (used by Mac/Windows) | Clients → Desktop app |
| `GOOGLE_IOS_CLIENT_ID` | secret | all builds (used by iOS) | Clients → iOS, bundle id `com.adhdtax.adhdTax` |
| `APPLE_TEAM_ID` | secret | `ios` | developer.apple.com → Membership details |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | secret | `ios` | App Store Connect → Users and Access → Integrations → Team Keys, **Admin** access; `ASC_KEY_P8` is the whole `.p8` file |
| `CLOUDFLARE_API_TOKEN` | secret | `web-publish` | Cloudflare → My Profile → API Tokens → custom token, permission *Account · Cloudflare Pages · Edit* |
| `CLOUDFLARE_ACCOUNT_ID` | secret | `web-publish` | Cloudflare → Workers & Pages (right sidebar) |
| `CLOUDFLARE_PROJECT` | variable (optional) | `web-publish` | Defaults to `unstuck` |
| `UPLOAD_KEYSTORE_BASE64`, `UPLOAD_STORE_PASSWORD`, `UPLOAD_KEY_ALIAS`, `UPLOAD_KEY_PASSWORD` | secret | `play` | The Play upload key, generated 2026-10-22 and sent to the owner as a file (never committed). Alias `upload`, PKCS12, store and key password the same. SHA-1 `1D:05:72:5F:78:9E:F9:29:CA:9C:4A:08:B2:89:99:7F:01:04:37:4F` |

The Google client ids and the desktop "secret" end up inside the shipped apps. That's normal for installed and browser apps (Google documents installed-app secrets as non-confidential). They're kept as secrets only to keep them out of the repo history.

**Status as of 2026-10-18:** none of these secrets exist yet, so builds have sync off, the iPhone web app isn't published, and the iOS job only compiles.

## Android signing

- Key: `app/android/app/sideload.jks`, **committed on purpose**. Every CI build must be signed with the same key, or Android refuses to install updates over the old app, and Google Sign-In's Android client is registered against this key's SHA-1.
- Store/key password `adhdtax-sideload`, alias `sideload` (in `build.gradle.kts`).
- SHA-1: `E9:F6:E9:C8:17:8A:B9:27:E7:9A:28:87:EC:67:D5:04:4F:F5:1F:BA`.
- Google Play builds don't use it: the `play` job signs with the **upload key** from secrets, and Google re-signs with its own app signing key (Play App Signing). So the Play app and the sideloaded app can't update each other, and the Play app needs its own Android OAuth client registered with the **app signing** SHA-1 from Play Console → App integrity (docs/STORE_RELEASE.md).
- Release flags that matter: `--no-shrink` (R8 broke plugins), Impeller disabled in the manifest, core-library desugaring enabled (flutter_local_notifications).

## iOS distribution (TestFlight)

- Bundle ids: app `com.adhdtax.adhdTax`, widget `…​.Widget`, share extension `…​.Share`; App Group `group.com.adhdtax.adhdTax` (entitlements in `ios/Runner`, `ios/UnstuckWidget`, `ios/UnstuckShare`). The owner registers the app's App ID and the App Group once (README → Install on iPhone and iPad); automatic signing creates the extension IDs, the distribution certificate and the profiles.
- The extension targets were added with `app/tool/ios/add_extensions.rb` (Ruby `xcodeproj` gem). Re-run it rather than hand-editing `project.pbxproj` if the targets ever go missing.
- Build numbers are the CI run number, so every upload is newer than the last, which TestFlight requires.
- Internal testers (the owner) get builds without Apple review. External testers or the App Store would need review, a privacy policy and screenshots.
- `ITSAppUsesNonExemptEncryption = false` in Info.plist skips the export-compliance question on every upload.

## Mac distribution

- CI builds a universal app, signed ad hoc (`CODE_SIGN_IDENTITY = "-"`), with no Apple Developer account. Gatekeeper blocks the first launch: **System Settings → Privacy & Security → Open Anyway**, or `xattr -dr com.apple.quarantine "/Applications/Gumption.app"`.
- Sandbox entitlements (`macos/Runner/*.entitlements`) include `network.client` (Drive) and `network.server` (the loopback OAuth redirect).
- Data lives in the app's sandbox container (bundle id `com.adhdtax.adhdTax`) and survives updates.
- Proper signing and notarization would need the $99/year Apple Developer Program; that would also enable TestFlight for a native iPhone app.

## iPhone / web hosting (Cloudflare Pages)

- `web-publish` always deploys with `--branch=main` to a project whose production branch is `main`, so the address never changes. This matters: **an iPhone home-screen app's data belongs to its address**, so changing the URL starts it empty.
- The first deploy creates the project. If `unstuck.pages.dev` is taken, Cloudflare picks a suffixed name, shown in the job summary. Ours got `unstuck-4o8.pages.dev`. Add that address to the Google web client's JavaScript origins. Never delete or rename the Pages project: everyone's home-screen data belongs to that address.
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
npx wrangler@4.145.0 pages deploy build/web --project-name=unstuck --branch=main
```
