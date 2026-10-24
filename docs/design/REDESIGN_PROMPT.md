# Gumption 1.1 redesign: Claude Design prompt

Prepared 2026-10-24. The owner said the app "feels cheaply made by AI and clunky" and wants the first App Store update (1.1) to look first-class. 1.0 (Build 103) ships as it is; this redesign is for 1.1.

Decisions the owner made for this brief:
- Claude Design proposes **3 distinct directions**; the owner picks one (or a mix), then the full set gets designed.
- **Everything is open**: colors, fonts, nav, icon. Only the name Gumption stays.
- **Own brand look**, not imitation iOS. Respect iPhone gestures and safe areas, but Android, iPad and Mac get the same design.
- **One direction may try a mascot**; decide after seeing it.
- Scope: core loop, progress and rewards, every other screen, app icon and App Store screenshots.

## How to use it

1. Open Claude Design (claude.ai) and start a new design. The previous exploration is at https://claude.ai/artifact/558G1Ms1eMZAsD1UHHwFfB if you want it side by side, but start fresh so it isn't anchored on the current look.
2. Attach the six images in `docs/design/current/`:
   - `1-core-loop-light.png`: Today, Quick add, Focus, Tasks (light)
   - `2-core-loop-dark.png`: the same four in dark
   - `3-progress-notes-settings.png`: Progress (top and Your sky), Notes, task editor, Settings
   - `4-secondary-flows.png`: first run, evening wrap-up, weekly reset, guide, board view
   - `5-mac-today.png`: Today on a Mac at 1440×900
   - `6-app-icon.png`: current 1024 px icon
3. Paste everything in **Round 1 prompt** below as one message.
4. After you pick a direction, send **Round 2 prompt**. When the screens are final, send **Handoff prompt**, and give the resulting canvas link to a Claude Code session to build it.

Screenshots come from the web build with demo data (`app/tool/screenshots/shoot.mjs`, 390×844, iPhone inset); they match what the phone shows. To refresh them after a change, see "Refreshing the screenshots" at the end.

---

## Round 1 prompt

> I'm redesigning **Gumption**, an iPhone app (also Android, iPad, Mac) that helps people with ADHD **start** tasks. It's going to the App Store now, and the first update needs to look like a premium, crafted app. Right now it looks like a generic AI-generated template. Attached are screenshots of every main screen as it is today, plus the current icon.
>
> ### What the app does
> People with ADHD usually know what they need to do; the hard part is starting. Gumption:
> 1. **Picks one task for you.** You say how much time you have, whether you can leave the house, and (optionally) your energy. It picks the one task to do now and shows only that.
> 2. **Shrinks it to a first step.** Each task has a 2-minute first step or a checklist; Today shows the next unticked step ("Step 2 of 4: List the five calls we get most").
> 3. **Gets you going.** "Start" opens a focus timer; "5 min" starts a no-pressure five-minute version. If the pick is wrong: "Not this one", "Smaller" (break it down), or "Later".
> 4. **Rewards starting, not just finishing.** Starting earns XP and coins. Levels, streaks with grace days (they never reset to zero), a reward shop you stock yourself ("Fancy coffee out: 25 coins"), and **Your sky**: every start becomes a star and each week forms its own constellation.
> 5. Keeps **Personal** and **Work** tasks separate (each syncs to a different Google account).
>
> Who it's for: adults with ADHD, many of whom use it for work as well as home. The owner works in healthcare operations. The tone is warm, a bit wry, never guilt-inducing. Users open it when they feel stuck, so the screen must feel calm and obvious in one glance.
>
> ### What's wrong with the current design (be specific about fixing these)
> - **Boxes everywhere.** Today stacks five rounded containers around the task (situation bar, check-back badge, weekly-reset row, the task card, three action tiles). Settings and the task editor are big grey slabs with fields inside. Cards inside cards, everything the same radius.
> - **No hierarchy.** "Not this one / Smaller / Later" are three equal tiles; chips and pills are everywhere at the same weight. Only the mint card stands out.
> - **Too much text.** Helper sentences under inputs ("Type when, how long, #tags…", "With a checklist, the next unticked step is shown instead"), explanations in Settings, a quote on almost every screen.
> - **Template look.** A flat mint slab with a black pill button, a monospace font for metadata ("LV 6 · 13 DAYS", "30 min · due tomorrow") that reads like a developer tool, one minty teal used for everything (card, chips, ring, add button, links).
> - **Generic icons.** Stock Material icons; the bottom bar is five unlabeled icons (a sliders icon for Settings, bars for Progress) plus a + button.
> - **Chip walls.** Notes shows three rows of chips (workspace, template, projects, tags) before the first note. Quick add has two text links, a helper line, five length pills, a Personal/Work switch, "More options" and two buttons.
> - **Forms look like forms.** The task editor is a stack of labelled fields.
> - **No moments.** Starting a task, the single most important action, looks like any other button. The focus timer is a plain thick ring. Finishing feels the same as saving.
> - **Clunky details.** Awkward line wraps ("about 1 / min"), inconsistent button shapes on one row, the Mac layout is the phone layout stretched with a column of chips beside it.
>
> Worth keeping as ideas (restyle freely): the one-task pick, Start + "5 min", "Not this one / Smaller / Later", "Step 2 of 4", **Your sky** (the most distinctive thing in the app; build on it), the no-shame tone, the dry humour in copy ("This task won't do itself. I checked.").
>
> ### Constraints
> - **Built in Flutter, one codebase.** Design tokens must map to code: a named color palette for light and dark, a type scale, spacing, radii, elevation, motion durations. Avoid effects that are slow on mid-range Android (heavy background blur everywhere, large animated shadows). Blur is fine in one or two places.
> - **Fonts must be free to bundle** in the app on every platform (SIL Open Font License or Apache, e.g. from Google Fonts). Not SF Pro, not paid fonts. Icons from an open-licensed set (e.g. Phosphor, Lucide, Tabler) or custom; no emoji as icons.
> - **Phone first:** every screen must work at 360×800 with text at 130% size. Big tap targets (44 pt minimum). Respect the iPhone home indicator and Dynamic Island.
> - **Light and dark** versions of everything, both first-class. Contrast at least WCAG AA for text.
> - **Motion respects Reduce Motion.** Celebrations have a user setting: Off / Subtle / Normal / Party.
> - **No shame mechanics:** no red overdue walls, no broken-streak messages, no guilt copy. Due dates are gentle heads-ups.
> - **Personal vs Work must stay visible when adding a task** (filing a work task into the personal account is the mistake to prevent).
> - **Sample content only:** use generic tasks like the ones in the screenshots. Never patient names or medical details.
> - Own brand look on every platform (not imitation iOS), but follow iPhone conventions where users expect them: swipe back, sheets that drag down, the home indicator.
>
> ### Round 1: three directions
> Propose **three clearly different directions**. For each, give it a name and one sentence of intent, then show:
> - **Today** (a task picked), **Focus timer** (running), **Tasks list**, **Progress** (with Your sky), and the **"you started" moment** (what happens right after tapping Start).
> - Light and dark of Today, side by side.
> - The palette (light and dark), the font pairing, the icon style, the bottom navigation, and one **app icon concept** at 1024 px and at home-screen size.
>
> Directions I'd like to see (push each one further than feels safe; adjust if you have a stronger idea):
> - **A. Quiet confidence.** Editorial and typographic. Almost no containers: hierarchy comes from type size, weight and space. One strong accent used sparingly. Grown-up enough to use at work. Think Things 3, Apple Journal, a well-set magazine page.
> - **B. Night sky.** Build the whole identity on Your sky: every start is a star. Deep, rich darks with a warm star-light accent (and a light mode that still feels like dawn, not an afterthought). The focus timer as an orbit or a star filling with light; celebrations as stars igniting; the icon is a star or spark. Calm, slightly magical.
> - **C. Companion.** Warm and playful with a small character (a spark or ember, suggest a name) that reacts when you start, finish, get stuck or come back after days away, never sulking or guilt-tripping. Soft, tactile buttons, rounded type, friendly colour. Think Finch, Duolingo's polish, Tiimo.
>
> Across all three:
> - **One obvious next action per screen.** On Today the task and Start should be ~80% of the visual weight; everything else recedes or moves one tap away.
> - **Fewer words.** Cut helper text; let layout and icons explain. Keep the humour in one place per screen at most.
> - **Containers only where they group something.** No card-in-card, no chip walls.
> - **Numbers look designed** (timer, XP, streak), not like terminal output.
> - Designed details: real empty states, pressed states, the transition into Focus.
>
> Please don't: add features that don't exist, use purple-to-blue gradients or glassmorphism as decoration, put everything in rounded cards, use lorem ipsum, or copy the current mint-and-black look.
>
> ### Screens in the app (for later rounds; don't drop functions)
> - **Today:** situation (time available 10m–2h+, staying in / can go out, energy low/medium/high, Personal/Work/Both); the picked task (workspace, length, due, title, next step or first step); Start; 5 min; Not this one; Smaller; Later; level + streak indicator; a "check back" badge for tasks waiting on someone; a weekly-reset nudge; after 5 pm a "Wrap up" link; "Overwhelmed?" (a calmer, single-smallest-thing mode); an optional motivational quote.
> - **First run / empty Today:** Add a task, Brain dump (many at once), Try with example tasks, How Gumption works.
> - **Focus:** step title and task, Step done, countdown, pause, +5 min, Done, checklist (expandable), focus company (background sounds and a "buddy" presence dot), Time's up state, "Hold me to it" (share what you're starting with a friend).
> - **Quick add (sheet):** one text box that understands "tomorrow 2pm 15 min #tag urgent"; voice input; length; Personal/Work (always visible); More options (priority, dread level, needs leaving the house); Add, Add & start; links to Brain dump, Template, Full form.
> - **Tasks:** open count and total time; filter (workspace, project, list or board view); Brain dump; Weekly reset; sections "Check back" (Back to my list / Still waiting / Done), "Up next", "Waiting on someone"; rows show title, due, length, who it's waiting on; mark done with Undo. Board view: To do / Doing / Waiting / Done.
> - **Task editor:** title, first 2-minute step, checklist with Suggest steps (and optional AI Break it down), notes, workspace, project, tags, length, priority, due date and hard deadline, dread, energy, needs leaving the house and where, repeat, reminders, waiting on + follow-up date, related notes; save as template; delete.
> - **Progress:** level and XP to next level, tasks started, finished, focused time, streak (with "2 grace days a week"), dreaded ones done, coins; Your sky; reward shop; achievements; "how long things really take" (estimate vs actual).
> - **Notes:** search, Personal/Work filter, projects, #tags, pinned, note cards, note editor with [[links]] to tasks and notes, Make tasks from a note, templates.
> - **Settings:** appearance (Light/Dark/Match phone), show on this device (Both/Personal/Work), Google sync for each workspace, reminders, celebrations level, quotes, health-info warning for Work tasks, AI key, backup save/restore, help and privacy links.
> - **Evening wrap-up** (what you did today, choose tomorrow's first thing), **Weekly reset** (one stale task at a time: Keep it / Make it smaller / Not this week / Let it go), **Errand run** (batch out-of-house tasks), **In-app guide**, **Templates**.
> - **Celebrations:** started (XP), finished, level up, achievement unlocked, reward bought.
> - **Home-screen widgets** (small and medium: today's pick with Start, and quick add), **Mac/iPad** layout (sidebar + content, not a stretched phone).
> - **App Store:** the icon (with iOS dark and tinted variants) and five 6.3" iPhone screenshot frames (1206×2622) with short headline captions.

---

## Round 2 prompt (after picking a direction)

> Let's go with **[direction, plus anything to borrow from the others]**. Now design the full set in that direction, light and dark, at iPhone size (390×844), using the "Screens in the app" list from my first message: every screen and state, including empty states, the Quick add sheet with More options open, the focus Time's up state, all five celebrations, the widgets, and the Mac/iPad Today and Tasks layouts. Then the final app icon (light, dark and tinted) and the five App Store screenshot frames with captions. Check each phone screen at 360×800 with 130% text and show one example of that.

## Handoff prompt (when the screens are final)

> Prepare this for a developer building it in Flutter. Give me, on one page:
> 1. **Color tokens** for light and dark, by role (background, surface, text primary/secondary/muted, accent, on-accent, hairline, warning, project colors…) with hex values.
> 2. **Type scale:** font families (with their Google Fonts names and weights), and for each style its size, weight, line height and letter spacing.
> 3. **Spacing, radii, elevation and motion:** the scales, plus durations and curves for the key transitions (into Focus, sheet open, celebrations) and what changes under Reduce Motion.
> 4. **Components:** buttons (primary, secondary, quiet; pressed and disabled), the task row, the Today task, pills/segmented controls, sheets, the bottom navigation, inputs, toasts, with sizes and states.
> 5. **Icons:** the set used and the icon for each nav item and action.
> 6. The app icon as a 1024×1024 PNG with no transparency, and notes for the dark and tinted variants.

---

## Refreshing the screenshots

From `app/` (cloud sessions: Flutter at `/opt/flutter/bin`; if `shoot.mjs` can't find Chromium, launch with `executablePath: '/opt/pw-browsers/chromium'`):

```bash
flutter build web --release --no-web-resources-cdn
(cd build/web && python3 -m http.server 8765 --bind 127.0.0.1) &
node tool/screenshots/shoot.mjs out/ light-01-today / 390 844 --iphone --appearance light
```

The contact sheets were made by tiling 390×844 (@2x) shots of `/`, `/add`, `/focus/1`, `/tasks`, `/progress` (and `--scroll 700`), `/notes`, `/task/1`, `/settings`, `/` with `--empty`, `/wrapup`, `/reset`, `/guide` and `/tasks --board`, with labels, using Pillow.
