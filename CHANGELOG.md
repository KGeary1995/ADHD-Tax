# Changelog

What changed in each build, newest first. Build number = CI run number (= Android `versionCode`). Update this with every change the owner would notice.

## Build 144 (iPhone) / 145 (Android, web) — 2026-10-27: iPhone widget taps and shares, web security policy on
- **iPhone widget taps** now open screens the same careful way Android's do: tapping Start for the task already running opens nothing new, and another task's Start replaces the running one instead of stacking a second session.
- **iPhone Share → Gumption** can't lose a share made at the same moment the app was opening another one.
- **Web app:** the site's security policy now blocks anything it doesn't expect (before, it only reported). Emoji and other scripts still load their fonts.
- Not yet tried on a phone; covered by tests (359). The iPhone changes are compiled only by the iPhone build.

## Build 140 (Android, web) / 139 (iPhone) / 141 (Mac) — 2026-10-27: fixes from a third code audit
- **A new phone restored from your old one's backup syncs properly.** It used to share the old phone's sync identity, so the two overwrote each other's copy in the cloud and each missed the other's changes. The restored phone now notices and takes its own identity on its first sync. A second sync file appearing in your account is expected.
- **Reconnect asks before moving a workspace to a different account.** If the account picker hands back another account (Android's often does), you're asked "Switch Work to …?" instead of having every Work task uploaded there.
- **Older and newer versions can share an account safely.** A device on an older build no longer overwrites things only a newer build understands when you edit a task, note, project, template or reward.
- **Less data used:** after the app restarts it no longer uploads your whole copy on every sync until you edit something.
- **An edit isn't lost when another device moved the task** to the other workspace at the same time: it lands on the moved task, and nothing is left behind in the old account.
- **One damaged sync file no longer stops a workspace syncing**, and a phone with its date set far ahead can't freeze everyone's clocks.
- **Repeating tasks:** "monthly on the 31st" goes Jan 31, Feb 28, **Mar 31** (it used to stay on the 28th). A weekly task with no due date no longer drifts after you tap Start or Later.
- **Quick add reads times better:** "pizza tonight at 8" is 8 pm, "gym tomorrow evening at 7" is 7 pm, "call mom at 5:30" is 5:30 pm like "at 5". "Look at 3 houses" and "Buy 1/2 gallon milk" stay titles. "Feb 30" and "4/31" aren't taken as dates, "Feb 29" means the next one, and "this weekend" on a Sunday means today.
- **Today says "Everything's parked for later"** when every task is snoozed or waiting for its next repeat, instead of suggesting a bigger time window.
- **The focus screen:** if time runs out while the Stop question or a sheet is open, **Finished** now leaves the screen (it used to leave you on a frozen timer). Tapping the widget's Start for the task already running opens nothing new. A session closed by opening a notification still counts its minutes. A "Time's up" alert can't arrive after you've already tapped Done, and it hides the task name on the lock screen when your phone hides sensitive content.
- **Celebrations:** Undo and then finishing another task no longer swallows the second celebration. Finishing or starting the same task twice in a day doesn't award XP again (it used to show XP that the total then took back). Confetti respects Reduce Motion.
- **No more "0 day streak":** Progress shows the days you were active instead.
- **Wrap-up** doesn't keep a task you've finished since as tomorrow's first thing. **Wrap up** appears at 5 pm without reopening Today.
- **Restoring settings from a backup** onto a new phone still asks for notification permission, so reminders arrive.
- **Sensitive info check** (if on) catches more slips: "3/14/2012", "3/14/85", "1985-03-14", "Mrs. O'Brien", "Mr Smith", "patient SMITH", "123 45 6789".
- **Web app:** updates reach phones on slow connections, a page never mixes old and new files, and the site can't be framed by other sites.
- Builds are now safer: signing keys are visible only to the steps that use them.
- Not yet tried on a phone; covered by tests (357).

## Build 137 (Android, web) / 136 (iPhone, Mac) — 2026-10-26: fixes from a second code audit
- **Sync can't lose a download after a failed save.** If this device couldn't save what it downloaded (storage full, say), it no longer marks those files as read, so after a restart it fetches them again. What one file brought is also kept and shown when a later file fails to download.
- **An upload still owed survives a restart:** changes merged from another device but not yet uploaded (offline halfway through) go up on the next sync after reopening the app.
- **A device restored from an old phone backup** (the phone's own, not Gumption's backup file) picks up its newer copy in the cloud instead of overwriting it.
- **Updating from a very early build** keeps the old tasks in place until they're saved in the new format.
- **Templates:** saving a template you had open keeps changes synced in meanwhile (its checklist, say), as tasks and notes already did.
- **Undo is gentler:** Undo after Done, Archive or a weekly-reset choice puts back only what that tap changed, so an edit made in the seconds before (here or on another device) stays.
- **An old link doesn't restart a finished task.** Opening Focus for a task already done (an old widget button, a notification) says "This one's already done." with **Start it again**, instead of quietly reopening it and giving start XP.
- **The home-screen widget's Just 5 minutes** now ends like Today's: *Keep going* or *Stop here, that counts*.
- **Lists keep up with the clock:** the Tasks list moves a snoozed task out of Coming up when its time comes, Today shows a check-back when its date arrives, and the errand run takes in an errand whose snooze ended, all without reopening the app.
- **"Back up to Drive" / "to OneDrive" saves a full backup** of that workspace (notes, projects, templates and rewards too, not just tasks and XP) in the same format as Save a backup file, so **Restore from a backup file** takes it. It holds only that workspace, since it lives in that workspace's account.
- **Date pickers open on any date:** a task due years ago (or far ahead) no longer stops the date picker opening.
- **Wrap-up counts all of a busy day's XP**, not just the last 30 entries.
- **Two devices finishing the same task offline** count it once (same day). Finishing a task again on another day still counts.
- **Removing your AI key while the app is starting** keeps it removed, and **Disconnect from Microsoft** while a sign-in was being renewed no longer saves that sign-in again.
- **The mic button** in a second note or task stops showing "Stop listening" when dictation ends.
- **Web app:** the first visit now saves the app for offline use, so the very next launch opens without a connection (before, it took a second visit).
- Not yet tried on a phone; covered by tests (328).

## Build 135 / iPhone 135 — 2026-10-25: fixes from a code audit
- **Sync keeps what it downloads** even when the upload after it fails (offline halfway through): tasks from your other devices show at once and are saved, and the next round uploads them. Before, they could stay invisible.
- **A warning if this device can't save** (storage full, say): a strip at the top says so and the app keeps retrying, instead of looking saved when it isn't.
- **An editor left open no longer undoes newer changes.** Saving a task saves only what you changed in the editor, so a task marked done in the list or on another device meanwhile stays done. Closing a note you didn't type in leaves it alone, so a note deleted on another device doesn't come back.
- **Disconnect stays disconnected**, even if a sync was halfway through.
- **Undo after finishing a repeating task** only removes the next copy if that tap made it, never one that was already there (and maybe edited).
- **Focus minutes count once:** stopping a task after 10 minutes and finishing it later in 5 now adds 15 to Progress, not 25.
- **A snoozed task comes back on time**: Today looks again when a snooze ends, at midnight, and when you return to the app.
- **Dates across a clock change:** "in 2 weeks" typed before the clocks go back no longer lands a day early, and a streak no longer breaks when the clocks change. Same fix for "tomorrow" labels, the Progress sky and repeating tasks' lead time.
- **Hidden workspace stays hidden:** on a device set to show only Personal (or only Work), Progress shows the other side's history as "Started: a Work task", without titles. XP still counts in full.
- Web app: the saved offline copy is used when the server has an error (not only when there's no network), and disconnecting Google also forgets the sign-in saved in the browser.
- Not yet tried on a phone; covered by tests (308, now run in a time zone with clock changes).

## Next build — 2026-10-25 (web): OneDrive in the web app
- **OneDrive works in the web app too:** Settings → Sync → Connect → Microsoft account opens Microsoft's sign-in in a small window (allow pop-ups if the browser asks). Microsoft keeps a browser signed in for 24 hours; after that the row shows **Reconnect**.
- Fixed: with only OneDrive available, the note under the Sync rows talked about Google Drive.
- Tested by the owner in the web app with a personal Microsoft account.

## Build 127 / iPhone 127 — 2026-10-25: Microsoft OneDrive sync
- **Sync with a Microsoft account:** Settings → Sync → Connect now also offers **Microsoft account (OneDrive)**, for a personal account (Outlook.com, Hotmail) or one from work or school. Works on Android, iPhone, iPad, Mac and Windows; not in the web app yet. Mix as you like: Personal on iCloud, Work on Microsoft 365, and so on.
- The files go in **Apps/Gumption** in that OneDrive (visible there; please leave them be). "Back up to OneDrive" saves a readable copy in Apps/Gumption/Backups.
- A Work workspace on an Outlook.com or Hotmail address gets the same "looks like a personal account" note as Gmail.
- Tested on Android and iPhone with a personal Microsoft account.

## Next build — 2026-10-25 (Android, web): Settings from any tab
- **Settings is one tap from every tab:** a gear at the top right of Today, Tasks, Notes and Progress (before, only Progress had it). The tab bar stays on Settings, and its back arrow (or Android's back) returns to the tab you opened it from.
- On phones narrower than a large iPhone, Today's level pill shows just the level so the gear fits; your streak is on Progress.
- Fixed: on small phones, Today showed **Wrap up · Overwhelmed?** twice.

## iPhone 117 — 2026-10-25: iCloud sync (iPhone and iPad)
- **Sync with iCloud:** on iPhone and iPad, Settings → Sync → Connect now asks where each workspace should sync: **iCloud** (no sign-in, uses the Apple ID the device is signed in to; iPhone, iPad and Mac only) or a **Google account** (any device). You can mix: Personal on iCloud, Work on Google. Existing Google connections carry on unchanged.
- If the device switches to a different Apple ID, sync stops and asks you to reconnect rather than mixing the two.
- Needs a one-time switch in the Apple Developer account before an iPhone build (README → iCloud sync setup). Done 2026-10-25; the owner reports it working.

## Next build — 2026-10-25 (Android, web)
- **For everyone, not just clinics:** the app no longer talks about patients, clinics or insurance. Sync asks for "the Google account you use for work", typing hints say things like "Call the bank tomorrow 2pm", and the example templates are **Start the workday**, **Meeting notes** and **Weekly reset**. The privacy policy and terms say "sensitive personal information" instead of "patient information".
- **Sensitive info check** (was "Patient-info guard"): same warning, neutral wording, and **off for new installs**. Your devices keep it on if it was on; check Settings → Look and feel on each one you use for clinic work. The AI helper still never sends a Work task that looks like it holds someone's personal details.
- **The dry wit is back:** a quote under the focus timer again, Today shows funny ones more often and in brighter text, the Finished card has a one-liner ("Another one bites the dust."), two rerolls get "Rerolling feels productive, but it's the dread talking.", and 12 new lines ("Reorganising the list is not doing the list.").
- New App Store screenshots with everyday and office examples (a quarterly report, a launch date, an expense sign-off).

## Build 112 / iPhone 113 — 2026-10-25 (bcf59aa): 1.1 "Night sky" (Android, web, iPhone TestFlight)
- **A whole new look**, from the design you commissioned. Gold stars on a deep night sky (**Night**), or on warm cream (**Dawn**); it follows the phone unless you pick one in Settings → Appearance. New fonts and icons throughout.
- **Today shows one task and its next step**, with a big Start and 5 min, and three quiet choices: Not this one, Smaller, Later. **Smaller** lets you shrink the step on the spot; **Later** brings the task back in 3 hours. "Right now" (time, staying in or going out, energy, which tasks) is one button at the top.
- **Starting lights a star:** pressing Start shows a short "A new star." moment (tap to skip; off if Celebrations are Off), then the focus timer.
- **Focus timer:** a star travels round an orbit, or pick one block per minute in Settings → Focus timer. Pause, +5 and Done; the checklist sits at the bottom.
- **Celebrations are cards:** Finished, then Level up, then any achievement, each with one button.
- **Tasks, notes, the editor, Progress, Settings, Wrap up, the guide:** all restyled. The task editor's details (length, priority, due date…) are rows that each open a small sheet. Settings now opens from the gear on Progress.
- **On a Mac or an iPad in landscape, Tasks shows the selected task beside the list:** tick its steps, Start it or open it to edit, without leaving the list. The filters are pills above the list.
- **New app icon:** a gold star on night blue. On iPhone it has dark and tinted versions; on Android it's an adaptive icon and works with themed icons.
- **Home-screen widgets** match the new look and follow your phone's light or dark setting. The 4×2 widget shows the step you're on, the next one, Start, 5 min, Add a task and your streak.
- Fixed: in the task editor, adding the first checklist step no longer makes the page jump.

## Build 112 — 2026-10-25 (bcf59aa): iPhone sync fixes (Android, web; iPhone 113)
- **iPhone: Personal and Work can both sync now.** Signing in to Work used to hang on "Waiting for Google sign-in…", and could make Personal sync through the Work account. iPhone now signs in to each one separately in a Safari sheet, like the Mac app does. **After updating, tap Reconnect on Personal once.**
- **Sync never writes into the wrong Google account:** if a device finds a different account signed in than the one a workspace syncs with, it stops and asks you to reconnect instead of syncing.
- **Cancel** next to "Waiting for Google sign-in…", and a sign-in that's left open gives up after 5 minutes instead of spinning forever.
- **Reconnect shows straight away** on iPhone, Mac and the web when there's no saved sign-in, instead of after a minute and a half of "Reconnecting to Google…". Android still retries quietly, because its sign-in can lag just after an update.

## Build 107 — 2026-10-23 (dd313b1) (Android, web; iPhone Build 108)
- **Link notes to tasks and to each other:** type `[[` in a note (or tap the new link button at the top) and pick a task or note from the bar above the keyboard. Links show in green, and a **Links** list under the note opens each one. A link to something that doesn't exist yet offers **Make task**. A note with a title also lists the notes that link to it.
- **Related, on every task:** the notes that link to it, and unfinished tasks that share a #tag or its project. Tasks with no connections look the same as before.
- **Your sky, on Progress:** every task you start becomes a star, and each week's days in a row join into a constellation. Missed days just leave a gap.
- **Privacy policy and Support pages** are online at unstuck-4o8.pages.dev/privacy and /support, and linked from **Settings → Help**. The app stores and Google's sign-in screen need them. A short **Terms of use** page (/terms) and an **About** page (/about) sit beside them.

## Build 91 — 2026-10-22 (d3ddd5d) (Android, web)
- **A calmer phone layout:**
  - **Tasks:** the four rows of filters are now one button ("Everything", or e.g. "Work · Car") that opens a sheet with Personal/Work, projects and List/Board. Each task shows only when it's due and how long it takes; priority, tags and the rest are in the task.
  - **Quick add:** just the task, how long, and Personal/Work. Priority, dread and "Leave the house" are under **More options**, which stays open if you leave it open. Typing "urgent" or "tomorrow 2pm" still fills them in.
  - **Today:** the card's top line is short ("30 min · due tomorrow"), "check back" is a small badge next to your situation instead of its own row, and today's done/XP counts moved off Home (they're on Progress).
  - Computers are unchanged.
- **New headline on Today:** "Don't decide. Just start." replaces "One thing. Right now." (also at the top of the guide).

## Build 90 — 2026-10-22 (4ad3af5) (Android, web)
- **The app is now called Gumption** ("Gumption: Task Starter" in the app stores, when it gets there). "Unstuck" turned out to be taken by several ADHD apps. Only the name changed: it updates over your current install, and your tasks, XP and Google sync carry on. The download link is now `…/android-latest/Gumption.apk`; the old `Unstuck.apk` link still works. On an iPhone home screen the old name stays until you remove the icon and add it again from Safari. The Mac app changes name with the next Mac build; delete the old Unstuck app then.

## Build 89 — 2026-10-22 (3abe8f0) (Android, web, Mac)
- **Ideas for a first step:** when a task has no first step yet, its editor offers three ideas for that kind of task. "Call the dentist" gets "Find the number and put it on screen"; a form gets "Fill in just your name and the date". Tap one to use it. Built in: no AI, works offline, nothing leaves your phone.
- **Suggest steps:** without an AI key, the checklist's button now fills in a sensible breakdown for the kind of task instead of asking for a key. With a key it still asks Claude.
- **Hold me to it:** the people button on the focus screen sends a friend "I'm starting … now, for 25 min. Check on me when the time is up?" through whichever app you pick. Work tasks only say "a work task", so their title never leaves the app.

## Build 81 — 2026-10-22 (4be7c2c) (Mac)
- **Fewer keychain password prompts on Mac:** the app was saving your Google sign-in to the Mac keychain every time its hourly access pass renewed, and each save could make macOS ask for your password again. It now only saves when something that matters changes. Choose **Always Allow** on the prompts you do get; see the note about updates below.

## Build 77 — 2026-10-21 (52025bd) (Android, web, Mac)
- **How Unstuck works**, inside the app: a guide to every feature, with "your first five minutes" and a **Go to…** button on each part that takes you to the real screen. Find it on an empty Today screen, or in Settings → Help.
- **Try with example tasks:** fills the app with sample tasks (an errand run, a checklist, something you're waiting on, a repeating task) and two notes, so a new user can look around before adding their own. **Remove example tasks** (Today's banner, the guide, or Settings → Help) takes away only those; anything you added stays.
- **Google sync after an update (Android):** after installing a new build, the first quiet sign-in to Google can fail for a moment, and the app used to ask you to reconnect right away. It now retries by itself for about a minute (showing "Reconnecting to Google…") and only asks if it still can't get in.

## Build 73 — 2026-10-21 (c10d388) (Mac, web, Android)
- **Pop-ups are windows on a computer:** Waiting on, focus Company, Celebrations, Quote speed, the template picker, a note's Make tasks / Organize, and New project for… now open as a centered window instead of sliding up from the bottom of the screen. Phones keep the sheets.
- **Settings on a computer** is a list of sections on the left (Look and feel, This device, Reminders, Sync, Shortcuts and templates, AI helper, Backup, Data) with the open one on the right, like Mac System Settings.
- **Task editor on a computer:** in the right-hand column, labels sit beside their choices instead of above them, so it's much shorter.
- **Wrap up on a computer:** today is a summary strip across the top, with what you finished, and tomorrow's candidates sit side by side with **Done for today** under them.

## Build 71 — 2026-10-21 (27e405a) (Mac, web, Android)
- **Today, redone for a computer:** the time / can-go-out / energy / Personal-Work choices sit in a **Right now** panel on the right and re-pick as you click, with no pencil or sheet to open. The task card is bigger and shows the whole checklist and why it was picked. A **Today** panel shows done, XP and streak with the Overwhelmed button, and the quote sits along the bottom so the page fills the window. Phones are unchanged.

## Build 69 — 2026-10-21 (f33203b) (Mac, web, Android)
- **Every page uses a computer screen now**, not just Tasks and Notes. On a wide window: **Today** keeps the one task front and center with check-backs, errand runs, the quote and today's count in a column on the right; **Progress** puts level, stats and achievements (two columns of them) on the left and the reward shop, real task lengths and recent XP on the right; **Settings** is two columns of groups; the **task editor** has what the task is (name, first step, checklist, notes) on the left and how and when (workspace, project, length, priority, due date, repeats) on the right; **Wrap up** has today on the left and tomorrow's pick on the right. The focus timer and the note editor stay a single centered column on purpose. Phones are unchanged.

## Build 67 — 2026-10-21 (eacbd5e) (Mac, web, Android)
- **Desktop layout** (Mac, Windows, wide browser windows): Tasks and Notes now have a filter sidebar on the left (Show, Projects with counts, Tags, Weekly reset, Brain dump, templates) and use the width of the window, instead of a phone-width column with rows of pills. Notes show two or three side by side. The List / Board switch moves next to the title. Phones are unchanged.
- **Backup files now include your settings** (look, celebrations, reminders, quotes, List/Board, focus sounds, the desktop shortcut). Restoring asks "Also restore its settings" (ticked by default). Left out on purpose: "Show on this device" (so a work-profile copy doesn't flip to Personal), "Use AI on Work tasks" (needs its confirmation again), and your API key and Google sign-in, since backup files get emailed and left in Drive. Older backup files still restore as before.
- **Quick add** opens as a centered window on a computer, and the box now shows an example ("Call insurance tomorrow 2pm 15 min #billing") plus a hint that you can type when, how long and #tags straight in.

## Build 61 — 2026-10-21 (fc6533e) (Android, Mac, web)
- **Weekly reset**: on weekends Home offers "Weekly reset: N tasks to sort". It shows each task that has sat untouched for a week, one at a time: **Keep it**, **Make it smaller**, **Not this week** (hidden 7 days) or **Let it go** (archived), with **Back** if you tap the wrong one. +20 XP when you finish. Also on the Tasks tab any day ("Weekly reset · N").
- **Errand run**: when Home is set to "Can go out", it suggests a run of errands that fit your time, grouped by place ("Errand run: Pharmacy + Post office · 45m", with 10 min travel per stop). Tap it for the list and tick each one off as you go.
- **Company while you work** (headphones on the focus screen): background sound (Brown noise, Rain or Fan, mixed with your own music rather than stopping it) and an optional **buddy**, a quiet line under the timer like someone at the next desk ("Your buddy · Answering emails"). Pausing the timer pauses the sound. Remembered for next time.
- **Quick add from anywhere (Mac and Windows)**: press **Ctrl+Shift+Space** (⌃⇧Space on a Mac) in any app and Unstuck comes forward with Quick add open. Settings → Reuse to turn it off.
- **Break it down with AI** (optional): in a task's editor, under Checklist. Claude turns the task into 3–7 small steps you can edit before saving. Needs your own Anthropic API key (Settings → AI helper; it stays on the device and costs a fraction of a cent per task). Off for Work tasks unless you turn it on, and a Work task that looks like it has patient details is never sent.

## Build 59 — 2026-10-19 (96cdaf7) (Android, Mac, web)
- **Type it the way you'd say it**: in Quick add, "Call insurance tomorrow 2pm 15 min #billing" fills in the due date and time, the length and the tag, and saves the title as "Call insurance". What it picked up shows as chips under the box; tap one to keep those words in the title instead. It also understands weekdays ("by friday"), "tonight", "next week", "in 3 days", dates like "4/15" or "Nov 3", "at 5", "noon", "1h 30m", "urgent", `!!` (High), `#work` / `#personal`, and a `#tag` that matches a project's name files the task into that project. Works offline, in Brain dump too (one line each). No AI involved.
- **Checklists inside a task**: break a task into steps in its editor (paste a list to add several at once). The next unticked step becomes the first step everywhere: Home shows "Step 2 of 4: …" and the focus screen has a **Step done** button plus the whole checklist to tick. A repeating task's next copy comes back unticked.
- **Reward shop** (Progress tab): spend the coins you earn on treats you choose, e.g. Fancy coffee out = 25. Tap **Redeem** (with Undo). A 15-minute task started and finished earns about 2 coins. Spending never touches XP, level or streak.
- **Templates**: reusable checklists and notes (Settings → Templates, or **Template** in Quick add, **From a template** on Notes). Starts with examples you can add with one tap: Opening checklist, Huddle notes, Weekly reset. Save any task or note as a template from its editor. `{date}` in a template's title becomes today's date ("Huddle Oct 19").
- **Tags on tasks**: tasks can now carry `#tags` too (editor → Tags, or type them in Quick add). They show on the task's line.
- Fixed: on Progress with large text, the "XP · to next level" line could run off a narrow screen.

## Build 57 — 2026-10-19 (8459fda) (Android, Mac, web)
- Fixed: menus and pop-up sheets on the main tabs opened *behind* the floating bottom bar, so items at the bottom of a menu, like **Delete** on a task low on the screen, couldn't be tapped. They now always open on top.
- **Swipe to delete or finish**: swipe a task left to delete it, right to mark it done; swipe a note left to delete it. Each shows Undo. The board card menu (⋮) has **Delete** too.

## Build 55 — 2026-10-19 (3d11ea3) (Android, web)
- **Show on this device**: Settings → **Personal / Work / Both**. Set the work-profile copy to **Work** and your regular copy to **Personal**: each then shows, picks and adds only its own side, and the Personal/Work switches disappear. Nothing is deleted; Settings says how many items from the other side are hidden.
- **Board on a phone**: no more sideways scrolling. Four tabs with counts (To do · Doing · Waiting · Done) show one column at full width; tap a tab or swipe across the cards to switch. To move a card, hold it and drop it on a tab (or use its ⋮ menu). Wide screens still show all four columns.

## Build 47 — 2026-10-19 (da10a1c) (Android, Mac, web)
- **Notes** (new tab): jot anything, pin what matters, search everything. Organize with **projects** and **tags**: add tags as chips or just type `#billing` in the text. Filter by Personal/Work, project or tag.
- **Make tasks from a note**: tick the lines that are things to do and they become tasks in the same project.
- **Notes on a task**: open a task → "Add a note" for call outcomes and where you left off; the note shows a "For:" link back.
- **Projects**: group tasks (and notes) by project. Tasks shows project pills; with one open, **+** adds straight into it. Rename or delete from the ⋯ next to it (deleting keeps the tasks).
- **Board view**: Tasks → **Board** shows To do · Doing · Waiting · Done columns. Hold a card and drag it, or use its ⋮ menu. Done still earns XP with Undo; Waiting asks who you're waiting on. Your choice of List or Board is remembered.
- Sync now refreshes every device's copy after it receives changes, so something deleted or moved to Work no longer lingers in the Personal account's copy from another device.

## Build 45 — 2026-10-19 (eebf108) (Android, Mac, web)
- **Google sync is switched on**: the Google keys are now in the builds. Settings → Sync → Connect your personal Google account for Personal (and your clinic account for Work, if your IT allows it).

## Build 43 — 2026-10-18 (1ac5a2a) (Android, Mac, web)
- **Backup file**: Settings → **Save a backup file** saves every task and all your XP to one file (on a phone it opens the share sheet: Save to Files, Drive, email). **Restore from a backup file** brings it back on a new or wiped device; anything newer on the device is kept. Settings shows when you last saved one.
- Fixed: after 5 pm on a narrow phone with large text, the "Wrap up · Overwhelmed?" line on Home ran off the screen. The links now drop to their own line.

## Build 39 — 2026-10-18 (18ededd) (web)
- **iPhone web app is live** at **https://unstuck-4o8.pages.dev**: open it in Safari → Share → Add to Home Screen. Free, no account; tasks stay on that phone. No reminders, widget or Share (iPhone web apps can't do those).

## Next build — 2026-10-18 (iPhone/iPad)
- **Native iPhone and iPad app** (via TestFlight once the Apple Developer account is set up): reminders, widgets in three sizes, Share → Unstuck, voice, and Google sign-in that stays signed in. Setup steps in the README.

## Build 33 — 2026-10-18 (1f2d7f2) (Android)
- **Widget sizes**: besides the 4×2 card, pick **Unstuck start** (2×1: the task and a Start button), **Unstuck square** (2×2) or **Unstuck card + next up** (4×3: two more tasks that fit right now, each one tap to start). All can be resized.

## Build 31 — 2026-10-18 (dfb4094) — follow-ups, wrap-up, widget (Android, Mac)
- **Waiting on someone**: say who it's waiting on and when to check back. On the day it jumps to **Check back** at the top of Tasks (Home shows a reminder line, Android notifies): back to your list, still waiting, or done.
- **Real task lengths**: after 5 tasks timed with the focus timer, Unstuck learns how long things really take you and picks tasks that truly fit your time. Progress shows "Tasks take you about 1.6× your guess".
- **Evening wrap-up** (8:30 PM reminder on Android, or **Wrap up** on Home after 5 pm): today's wins, what's still open, and tomorrow's first thing, which shows first on Home the next morning. Settings → Reminders to change the time or turn it off.
- **Share → Unstuck** (Android): share text from any app; the first line becomes the task, the rest its note.
- **Voice**: tap the mic in Quick add and say the task (Android, Mac, Chrome/Safari). Android and Mac ask for microphone permission the first time.
- **Home-screen widget** (Android): the current pick with Start, and + to add.

## Build 29 — 2026-10-18 (ab500f5) (Android, Mac)
- The rotating quote is back on Home, between the task and the bottom bar. Tap it for the next one; it switches to dread-busting quotes when the pick is one you rated "Ugh" or worse.

## Build 27 — 2026-10-18 (dafab77) — new look (Android, Mac)
- Redesigned from scratch: one calm look in **light and dark** (Settings → Appearance: Light / Dark / Match phone). Your old theme choice carries over as light or dark.
- Home: "One thing. Right now.", your situation on one line (tap to change), the task as a big teal card with **Start** and **5 min**, then **Not this one / Smaller / Later**.
- Floating bottom bar with the **+** button to add a task (replaces "Quick add").
- Tasks: tap the circle to mark done; due dates in amber.
- Focus: a ring timer, Pause / +5 / Done.
- Settings: grouped Reminders, Sync and Feel sections. Progress: level card and stats.
- New bundled fonts (Bricolage Grotesque, Geist, Geist Mono).

## Build 25 — 2026-10-18 (3819fb9) — renamed to **Unstuck** (Android, Mac)
- New name everywhere you see it (formerly ADHD Tax). Tasks, XP and settings carry over: the internal ids didn't change.
- New icon: a tangle straightening into an arrow.
- Downloads are now `Unstuck.apk` and `Unstuck-macOS.zip`. The release pages (`android-latest`, `macos-latest`) are the same.
- Mac: after installing **Unstuck**, delete the old **ADHD Tax** app.

## 2026-10-18 — Docs for AI sessions
- `AGENTS.md` / `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/DEPLOYMENT.md`, `docs/TROUBLESHOOTING.md`, `docs/DECISIONS.md`, this changelog.
- `app/tool/check.sh` (the CI checks in one command) and `app/tool/screenshots/` (Playwright screenshots of the web build).

## Build 21 — 2026-10-18 (595756a) — Android, Mac
- Google sign-in keys are read from repository secrets in every build (sync stays off until they're added).
- Web/iPhone: Google sign-in remembered for its one-hour lifetime.
- First published Mac build (`macos-latest` release).

## Build 19 — 2026-10-18 (0217ca2) — Android
- iPhone support: installable home-screen web app with safe-area handling and offline copy (publishes once Cloudflare is set up).
- New app icon on every platform.
- CI: manual runs and pushes no longer cancel each other.

## Build 14 — 2026-10-18 (2deab8f) — Android
- Repeating tasks (daily, weekdays, weekly, every 2 weeks, monthly; fixed schedule or from when finished) with a **Coming up** section.
- **Mark done** from the task list; Undo for Done, Archive, Delete (also takes back XP).
- Android: focus countdown in notifications, "time's up" alert in the background, check-in nudges (Settings → Reminders).

## Build 12 — 2026-10-17 (ecc2cfc) — Android
- Quick add: headers for every option group, "Need to leave the house" as its own switch, buttons pinned above the keyboard, **Full task form** button.
- Task editor and dashboard fit 360dp phones at larger text sizes.
- Android back goes to Home instead of closing the app.

## Build 9 — 2026-10-17 (418168f) — Android
- Fixed the startup crash (shared_preferences Pigeon JNI). First build confirmed working on the owner's phone.

## Build 8 — 2026-10-17 (1295524) — Android
- Startup errors are shown on screen instead of a black screen. Impeller disabled.

## Build 6 — 2026-10-17 (503fed0) — Android
- First build on the fixed `android-latest` download link.

## Phase 2 — 2026-10-17 (6f623a9)
- Google sign-in per workspace and Drive sync (CRDT), backup to Drive, sync badge.

## Phase 1 — 2026-10-17 (1723c8f)
- Offline app: Pick for me, focus timer, Just 5 minutes, Overwhelmed, quick add / brain dump, XP and levels, 18 achievements, celebrations, 114 quotes, 9 themes, PHI guard.
