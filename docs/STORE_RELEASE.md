# Getting Unstuck into Google Play and the App Store

The plan for moving from sideloaded/TestFlight builds to public store listings. Written 2026-10-22. Store rules change; re-check anything marked *verify* when you get to it.

**Who does what.** Anything that needs your identity, money, a legal agreement or a click in a store console is yours. Code, CI, store graphics, listing copy and draft answers to every form are Claude's. Steps are tagged **[you]** or **[Claude]**.

## Decisions to make first

| Decision | Recommendation | Why |
|---|---|---|
| Seller: individual or company | **Individual** to start | Free and fast. Your legal name shows as the seller. You can migrate to a company later on Apple; on Google you'd need a new account (apps can be transferred). |
| Price | **Free** to start | Paid apps add tax forms, banking, refunds and support load. In-app purchase or a paid tier can come later. |
| Store name | **"Unstuck: One Task Focus"** or similar | Plain "Unstuck" is likely taken on the App Store (names are unique there). The app's home-screen name stays "Unstuck" either way. |
| Positioning | **Productivity app "built for ADHD brains"**, no medical claims | Words like *treats*, *therapy* or *symptoms* trigger health-app review on both stores. Describe what it does (picks a task, focus timer), not what it cures. |
| Web address | Keep **unstuck-4o8.pages.dev** for now; optionally buy a domain (~$12/yr) | Both stores and Google's sign-in screen need a privacy policy and support URL. A real domain looks more trustworthy and makes Google's brand verification simpler. |
| Support email | **A dedicated address** (e.g. a new Gmail) | It's shown publicly on both listings. |

## Phase 0: shared preparation (both stores)

1. **[Claude] Privacy policy and support pages** at `/privacy` and `/support` on the web app's address. Honest and specific: no server and no analytics; data lives on the device and, if you turn on sync, in the user's own Google Drive app folder; the optional AI helper sends a task's title and notes to Anthropic using the user's own key; the mic is used only while the button is on. **[you]** supply the contact email and review the wording.
2. **[you] Publish and brand-verify the Google sign-in screen.** Google Cloud Console → Google Auth Platform:
   - Audience: confirm **In production**.
   - Branding: app name, logo (Claude provides a 120×120), home page, privacy policy link, authorized domain, then **submit for verification**.
   - Takes a few days. Until then, store users see "Google hasn't verified this app" when connecting sync. The scopes are non-sensitive, so no security review is needed (*verify* when submitting).
3. **[Claude] Store graphics:**
   - phone screenshots at each store's sizes, in light mode with the example tasks;
   - iPad screenshots;
   - the Play feature graphic (1024×500);
   - the 512×512 Play icon.
4. **[Claude] Listing copy:** title, subtitle/short description, full description, keywords and release notes, for both stores. **[you]** edit to taste.

## Phase 1: Google Play (start first: it has a 14-day test clock)

1. **[you] Create a Play Console developer account** at play.google.com/console:
   - Personal account, $25 one time.
   - Google verifies your identity (government ID) and phone number, and new accounts must also verify an Android device with the Play Console app. Allow a few days.
2. **[Claude] Store build:**
   - CI also builds an **Android App Bundle (.aab)**, signed with a new private **upload key** kept in GitHub secrets. The committed `sideload.jks` stays for the sideload APK; it isn't used for Play.
   - **[you]** add the two secrets Claude gives you.
3. **[you] Create the app in Play Console:**
   - Name, default language, App (not game), Free.
   - Upload the first .aab to **Internal testing**.
   - Keep **Play App Signing** on (the default): Google holds the final signing key.
4. **[you] Fix Google sign-in for the Play build.** Play re-signs the app with Google's key, so the existing Android sign-in client won't match it.
   - Copy the **App signing key certificate SHA-1** from Play Console → Test and release → App integrity.
   - Create another **Android** OAuth client in Google Cloud: package `com.adhdtax.adhd_tax` with that SHA-1.
   - Skipping this makes "Connect" fail with `DEVELOPER_ERROR` on Play installs only (docs/TROUBLESHOOTING.md).
5. **[you, with Claude's drafts] App content forms**, under Policy → App content:
   - Privacy policy URL.
   - App access: all features available without an account.
   - Ads: none.
   - Content rating questionnaire: expect *Everyone*.
   - Target audience: 18+, which keeps it out of the stricter Families rules.
   - News and government: no.
   - **Health apps declaration:** productivity, not a medical app.
   - **Data safety:** Claude drafts it. When in doubt declare more, not less; under-declaring is what gets apps pulled.
6. **Exact alarms.** The app holds `USE_EXACT_ALARM` so "time's up" fires on time. Play allows it only when timing is core to the app.
   - **[you]** declare it as a focus timer.
   - If Google refuses, **[Claude]** switches to `SCHEDULE_EXACT_ALARM`, which asks the user once, falling back to slightly-late alerts if they decline.
7. **[you] Closed test with 12+ testers for 14 days in a row.** This is required for personal accounts before production (*verify* the current numbers).
   - Recruit 15–20 people with Android phones; some never install. Work friends and family are fine.
   - Testers join through an opt-in link, then install from Play.
   - The 14 days only count while at least 12 are opted in.
8. **[you] Apply for production.** Play Console asks a few questions about the test: who tested, what feedback came in, and what changed. Claude helps write the answers. Approval usually takes a few days.
9. **[you] Release to production**, ideally as a staged rollout (for example 20% first, then 100%).

**Your own phones:** the Play version and the sideloaded version are signed differently, so one can't update the other. Before switching, either connect sync or **Save a backup file**, then uninstall the sideloaded app and install from Play. Do the same in the work profile.

## Phase 2: Apple App Store (can run in parallel)

1. **[you] Join the Apple Developer Program** as an individual: $99/yr, Apple ID with two-factor sign-in, approval in 1–2 days.
2. **[you] One-time Apple setup:** README → *Install on iPhone and iPad*, steps 2–5. That covers the identifiers, the App Group, the App Store Connect app record, the API key and four GitHub secrets.
3. **[you] iPhone sign-in client for Google sync:**
   - Google Cloud → Clients → Create → **iOS**, bundle id `com.adhdtax.adhdTax`.
   - Add the client id as the `GOOGLE_IOS_CLIENT_ID` secret.
4. **[Claude] TestFlight build:** an `[ios]` push builds, signs and uploads it.
   - **[you]** install via TestFlight and try everything on a real iPhone, especially widgets, Share, notifications and Google sync, none of which has run on a device yet.
   - Friends can join as external testers through a public link. That needs a short Beta App Review, about a day.
5. **[you, with Claude's drafts] App Store listing** in App Store Connect:
   - Name (30 characters), subtitle (30), keywords (100), description and promotional text.
   - Support URL and privacy policy URL.
   - Screenshots: 6.9-inch iPhone, plus 13-inch iPad because the app runs on iPad (*verify* sizes).
   - Age rating: expect 4+.
   - Encryption is already declared exempt (`ITSAppUsesNonExemptEncryption` = false).
6. **[you, with Claude's drafts] App Privacy questionnaire.** The developer receives no data, but sync stores the user's tasks in their own Google account, and the AI helper sends task text to Anthropic. Claude drafts the answers with the reasoning. The same rule applies as on Google: declare more when unsure.
7. **[you] Review notes for Apple:**
   - The app needs no account.
   - Google sign-in is optional and used only to store the user's data in their own Drive.
   - The AI helper needs the user's own key and can be skipped in review.
8. **[you] Submit for review.** It usually takes 1–2 days. Likely questions and Claude's prepared answers:
   - why Google sign-in appears without Sign in with Apple: there's no account, only access to the user's Drive;
   - what the microphone is for;
   - any health wording.

## Costs and timeline

| Item | Cost |
|---|---|
| Google Play developer account | $25 once |
| Apple Developer Program | $99 a year |
| Own domain (optional) | about $12 a year |

| Week | What happens |
|---|---|
| 1 | Decisions; both developer accounts applied for; Claude builds the privacy/support pages, store build signing and graphics |
| 1–2 | Play internal test; Google sign-in fixed for the Play build; app content forms; TestFlight on your iPhone |
| 2–4 | Play closed test runs its 14 days; App Store listing finished and submitted |
| 4–5 | Play production approval and release; App Store live |

## After launch

- Updates keep coming from CI. For each release, **[you]** click *Promote/Release* in Play Console and *Submit* in App Store Connect, unless automatic upload is set up later.
- Watch the support email and store reviews. Ratings from the first users matter most.
- Keep the sideload APK link for yourself, or retire it once you're on the Play version.
- The Mac app stays a direct download. The Mac App Store would need the same Apple account plus app sandbox review; that's a separate decision.
