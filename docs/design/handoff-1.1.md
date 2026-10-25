# Handoff: Gumption 1.1 — "Night sky" redesign

## Overview
Gumption is an ADHD-friendly task app. Version 1.1 redesigns every screen around one idea: **Today shows one task and one next step, and Start lights a star.** Progress is a night sky that fills with the stars you've lit. It covers Today, Quick add, Start/Focus, celebrations, Tasks, the task editor, Notes, Progress, Settings, Wrap up, the guide, home-screen widgets, Mac/iPad layouts, the app icon and App Store screenshots. Every screen has a dark theme (**Night**) and a light theme (**Dawn**). The app follows the phone's appearance setting by default.

Target codebase: `KGeary1995/ADHD-Tax`, branch `main`, Flutter, under `app/lib`.
- `features/picker/` and `app.dart`: Today
- `features/focus/` and `features/gamification/`: Focus and celebrations
- `features/tasks/`: Tasks
- `features/gamification/`: Progress / Your sky

## About the design files
The files in `design/` are **HTML design references**: prototypes that show the intended look and behaviour. They are not production code. Recreate them in the existing Flutter app using its patterns (ThemeExtension, widgets, state management). Don't port the HTML.

- `design/Gumption App.dc.html` is the source of truth for every phone screen and holds a clickable prototype. Each screen state is a named `start` value (see the screen list below). Open it in a browser. The `mode` (`dark` or `light`), `timer` (`orbit` or `blocks`) and `device` (`phone` or `small`) props switch variants.
- `design/Gumption Round 2.dc.html` is the full review canvas: all phone states, widgets, Mac/iPad, the app icon and App Store screenshots.
- `design/Gumption Handoff.dc.html` is the token and component spec sheet, which this README repeats.

## Fidelity
**High fidelity.** Colors, type, spacing, radii, copy and motion are final. Match them exactly. Copy in the screenshots is final unless it's obviously sample data (task names, dates).

## Screenshots
This handoff is split across two downloads. Merge them into one folder before you start. **Part 1** has this README, `design/` and phone screenshots 01–34. **Part 2** has phone screenshots 35–68 and `screenshots/other/`.

- `screenshots/phone/`: 68 phone states at 2× (812×1720, in a 390×844 device frame), named `NN-screen-theme.png`.
- `screenshots/other/`: `widgets.png`, `mac-ipad.png`, `app-icon.png`, `app-store.png`.

## Design tokens

### Color (Night / Dawn)
| Token | Use | Night | Dawn |
|---|---|---|---|
| bg | App background (base) | #0A0F1F | #F7F1E8 |
| bgTop | Gradient top | #17203F | #FBE2C6 |
| raised | Selected tab, inputs | #151C33 | #FFFFFF |
| sheet | Sheets, dialogs | #121930 | #FFFFFF |
| ink | Primary text | #EEF0F8 | #19203A |
| ink2 | Secondary text | #A3AAC2 | #555C77 |
| ink3 | Muted, hints | #717894 | #878B9E |
| line | 1px hairline dividers | #20283F | #E8DFD1 |
| line2 | 2px outlines | #323B58 | #D6CCBC |
| star | Accent fill: Start, active | #F4C76A | #E8A73C |
| starDeep | Pressed edge under primary buttons | #A8782A | #9A6413 |
| onStar | Text on star | #1A1406 | #1A1406 |
| accentText | Gold text (due dates, links) | #F4C76A | #8F5D0E |
| starSoft | Selected tint (16–18%) | #3A3730 | #F5E2BF |
| glow | Star glow (55% / 45% alpha) | #8C7448 | #ECC27E |
| personal | Personal workspace | #F29E7A | #D9704A |
| work | Work workspace | #8DB4FF | #3D6FD1 |
| danger | Delete only. Never used for overdue | #FF8A7A | #B8402F |
| scrim | Behind sheets (62% / 38% alpha) | #03050C | #19203A |
| project.car / training / phones | Project colours | #E879A6 / #5CC9A7 / #8DB4FF | same |

- **Backgrounds.** Night is `radial-gradient(130% 55% at 50% 0%, #17203F → #0A0F1F 62%)`. Dawn is `#FBE2C6 → #F7F1E8`. Paint the background once as a fixed layer, never inside scrolling content.
- **Night stars.** A sparse star field of 1–2 px dots, #C9D2F0 at 30–60% opacity.
- **Your sky card.** It always uses the Night gradient, even in Dawn.
- **Gold in Dawn.** Gold on cream is only a fill under dark ink. Gold text uses accentText #8F5D0E.
- **Contrast.** All text pairs pass WCAG AA.

### Type
- **Fonts.** The display face is **Sora** (300/500/600/700) and the interface face is **Manrope** (500/600/700/800). Both are on Google Fonts under the OFL.
- **Tabular figures.** Timers and stats use `FontFeature.tabularFigures()`.
- **Scaling.** Sizes are logical px and scale with the system text size. Layouts were tested at 130% on a 360×800 phone.

| Style | Spec |
|---|---|
| display (timer) | Sora 300 · 64/64 · −4% · tabular |
| levelHero | Sora 300 · 120 · −5% |
| h1 (Today task title) | Sora 600 · 34/37 · −3% |
| h1Large (celebrations) | Sora 600 · 40/42 · −3% |
| h2 (sheet titles) | Sora 600 · 24/28 · −2% |
| h3 (list headings) | Sora 600 · 17/21 |
| stat | Sora 500 · 26/26 · −3% · tabular |
| button | Sora 700 · 17 (hero Start 20) |
| step | Manrope 500 · 19/26 |
| body | Manrope 600–700 · 16/22 |
| label | Manrope 700 · 14/18 |
| caption | Manrope 500 · 13/18 |
| overline | Sora 600 · 12 · +8% · all caps (e.g. "STEP 2 OF 4") |

### Spacing
| Token | Value | Use |
|---|---|---|
| s1 | 2 | Title to its subtitle |
| s2 | 4 | Icon to label |
| s3 | 6 | Pill gaps |
| s4 | 8 | Stacked options |
| s5 | 10 | Image, sky or diagram to its caption |
| s6 | 14 | Heading to content |
| s7 | 20 | Grid row gap; between option groups inside a sheet |
| s8 | 24 | Screen side margin (22 on Tasks and Notes); space above a sheet's bottom CTA |
| s9 | 32 | Between sections |

### Radii
| Token | Value | Use |
|---|---|---|
| xs | 2 | Workspace dot |
| sm | 8 | Check box |
| md | 12 | Pills, icon buttons |
| lg | 14 | Buttons, inputs |
| xl | 24 | Dialogs |
| sheet | 28 | Sheet top corners |

### Strokes and elevation
- **Strokes.** Outlines are 2px in `line2`. Hairline dividers are 1px in `line`.
- **Shadows.** There are only two:
  - The **pressed edge** on primary buttons: `0 4px 0 starDeep`, which drops to 1px when pressed.
  - The star **glow**: `0 0 22px 4px glow`.
- **Sheets.** No shadow, just a scrim plus the `sheet` surface. Nothing uses background blur.

### Motion
| Moment | Spec | Reduce Motion |
|---|---|---|
| Tap press | 80 ms, translateY(3px), edge 4→1 px | Same |
| Sheet open | 300 ms easeOutCubic, slide 40 px + fade; scrim fades over 250 ms | Fade only, 150 ms |
| Start → Started | Star ignites over 900 ms (scale 0→1.35→1, easeOutBack). Two rings start at 200 and 550 ms and run 1.6 s, scaling 0.2→3.2. Text rises at 500 and 700 ms | Static star + text, 200 ms fade |
| Started → Focus | Hold 2.6 s, then a 500 ms crossfade. The star travels to the orbit start | Cut at 1.2 s |
| Focus orbit | The star moves along the ring every second, linear. It drops to 35% opacity while paused | Moves once a minute |
| Finished | Five stars ignite 100 ms apart, then the text lines fade in at 1.1 s | All appear at once |
| Level up | 14 bursts over 1.4 s easeOut, a 1.8 s ring, a 700 ms number pop | Number + text only |
| Toast | Rises 12 px over 250 ms, hides after 3 s | Fade |

**Celebration levels** (in Settings):
- **Off:** XP toast only.
- **Subtle:** the card without rings or bursts.
- **Normal:** as designed. This is the default.
- **Party:** adds a 2 s Your sky flyover with 40 bursts.

Reduce Motion overrides every level.

## Components
- **Buttons**
  - Heights: 64 (hero Start), 56–60 (sheet and dialog CTA), 42–44 (inline). Radius 14. Minimum target 44×44.
  - **Primary:** `star` fill, `onStar` text, `starDeep` pressed edge.
  - **Secondary:** 2px `ink` outline. Lesser actions use a 2px `line2` outline.
  - **Quiet:** an icon plus an `ink2` label.
- **Pills and segmented controls**
  - A selected pill fills with `star`. An unselected pill is a 2px `line2` outline.
  - Pills are as wide as their content, with 12 px padding each side.
  - The workspace picker is always a two-up row (Personal / Work) with a colour dot. The selected one takes its workspace colour as its border. It always shows in Quick add.
- **Filter row** (Tasks and Notes): All · Personal · Work, each with an 8 px square dot (radius 2), then Projects on Tasks or `# Tags` on Notes, where the "#" is in ink3. The row wraps and is centred.
- **Task row**
  - Minimum height 64. The check is 26 px, radius 8, inside a 44 px hit area. When done it fills with `star` and shows a four-point star glyph.
  - The title is body/16/700. The meta line is caption/13: workspace dot, then the due date (accentText, 700), then length.
  - A hairline divider sits under the row. The ⋯ button opens the row menu sheet.
- **Today pick.** Not a card. Top to bottom:
  1. Meta line (dot · workspace · length)
  2. h1 title, with the due line 2 px below it
  3. Step dots
  4. Step text
  5. Start (hero, 64 tall) and 5 min
  6. Three quiet actions: **Not this one** (`ph-shuffle`), **Smaller** (`ph-arrows-in-line-vertical`), **Later** (`ph-moon-stars`)

  Free space is split equally above the task and above the footer.
- **Sheet:** top radius 28, a 38×5 grabber, 24 padding, an h2 title with its subtitle 2 px below, 20 px between option groups, 24 px above the bottom CTA, and drag down to dismiss. On short screens a tall sheet stops below the status bar and scrolls inside.
- **Dialog:** radius 24, inset 22, used only for confirmations (stop the session, delete, time's up).
- **Nav bar**
  - 94 tall, with a 2px `line2` top rule.
  - Four divider tabs, each 54 tall with radius 0 0 12 12: Today `ph-sun-horizon`, Tasks `ph-list-bullets`, Notes `ph-note-pencil`, Progress `ph-shooting-star`.
  - The active tab is raised (`raised` fill), outlined, and uses the Fill icon weight.
  - "+" is a 54 primary square that opens Quick add.
- **Toast:** radius 14, inverse colours, 108 px from the bottom, 3 s. Undo is in the toast accent colour.

## Screens (phone, 390×844; `start` value in brackets)
**01 Today**
- `today`: one task, one step.
- `today-situation`: the "Right now" sheet with time (10m–2h+), place (Staying in / Can go out), energy and which tasks (Both / Personal / Work).
- `today-goout`: errand-run variant.
- `today-smaller`: the Smaller sheet, which breaks a step down.
- `today-commit`: after two "Not this one" taps, Gumption asks you to commit.
- `today-later`: toast "… comes back in 3 hours."
- `today-overwhelmed`: the "Okay. Breathe." card with Start 5 minutes and Not now.
- `today-empty`: first run, with Add a task and Brain dump.

**02 Quick add**
- `quick`: title field, length pills, workspace two-up.
- `quick-typed`: natural-language details are parsed into chips.
- `quick-more`: more options.
- `quick-dump`: Brain dump, one task per line.
- `quick-template`: start from a template.

**03 Starting and focus**
- `started`: celebration 1, the star ignites, then Focus follows automatically after 2.6 s.
- `focus`: orbit timer by default; `timer="blocks"` gives one block a minute.
- `focus-paused`.
- `focus-five`: Just 5 minutes.
- `focus-checklist`: step checklist. On the regular phone the timer collapses to small digits; on the small phone the checklist opens as a sheet.
- `focus-company`: body-doubling sounds.
- `focus-hold`: "Hold me to it".
- `focus-stop`: dialog.
- `focus-timesup`: dialog with Finished / +10 min / Stop for now.

Focus controls are Pause, +5 and Done (primary). The checklist bar is pinned at the bottom: "Checklist · 2 of 4".

**04 Celebrations**
- `finished` (2), `levelup` (3), `today-achievement` (4), `progress-reward` (5, reward bought with coins).

**05 Tasks**
- `tasks`: list with Check back, Pinned and Up next.
- `tasks-board`: board view.
- `tasks-filter`.
- `tasks-menu`: row menu.
- `tasks-waiting`: waiting on someone.
- `tasks-undo`: mark done with an Undo toast.
- `reset`: Weekly reset.
- `errand`: Errand run.

**06 Task editor**
- `editor`.
- `editor-more`: Details.
- `editor-new`.
- `editor-suggest`: toast "Added 5 suggested steps…".
- `editor-delete`: dialog.

**07 Notes**
- `notes`.
- `note`: editor.
- `note-make`: make tasks from note lines.
- `note-link`: link picker.

**08 Progress** (tab label "Progress", sky called "Your sky")
- `progress`: the sky, Level and streak in days, stats.
- `progress-more`: rewards and achievements.

**09 Settings and more**
- `settings`, `settings-more`, `settings-celebrations`.
- `templates`.
- `wrapup` and `wrapup-picked`: the evening Wrap up.
- `guide`: How Gumption works.

**10 Widgets** (`screenshots/other/widgets.png`)
- **Small (170×170).** Star, length, the step title (Sora 600 16), the step's first checklist line (12 px, wraps to two lines), and Start.
- **Medium (364×170).** Workspace · step x of y, the step title (Sora 600 15), the first two checklist lines, then Start + 5 min. A divided right column holds Add a task and the streak ("13 days").
- Widgets follow the phone's appearance.

**11 Mac and iPad** (`mac-ipad.png`)
- **Layout.** A 220 px sidebar (Add a task, the four tabs, Settings, "Saved on this device"), with content to its right.
- **Today.** The main column sits next to a 320 px "Right now" panel.
- **Tasks.** The list sits next to a detail pane. The detail grid is two equal columns (`minmax(0,1fr)`). Each value is centred in a 96 px column and can wrap to two lines ("1 hour / In chunks", "Sun, Oct 25 / hard").
- **Header.** "Level 6 · 13 days".

**12 App icon** (`design/icon/`)
- **Default.** A 1024² PNG with no alpha. The background is a radial from #1E2A52 at 50%/30% to #0A0F1F. The star is a four-point vector with curved sides, 52% of the canvas wide, filled #F4C76A, with a 36 px Gaussian glow at 80%.
- **iOS dark.** The same star on #000 with the glow at 60%.
- **iOS tinted.** The bare star as a greyscale #D9D9D9 shape on a transparent background.
- **Android.** An adaptive icon with the star in the 66% safe zone, plus a monochrome layer of the bare star.
- **Files.** SVG sources and PNGs for each.

**13 App Store screenshots** (`app-store.png`).

## Interactions and behaviour
- **Start** (hero, or 5 min)
  1. Started screen.
  2. After 2.6 s, Focus.
  3. The timer counts down once a second.
  4. At 0 the Time's up dialog opens.
- **Pause** freezes the timer and dims the orbit star to 35%. **+5** adds 5 minutes.
- **Done** finishes the task and shows Finished. Level up and achievements follow when earned.
- **Not this one** picks the next task. After two in a row, the commit prompt appears.
- **Smaller** opens the breakdown sheet.
- **Later** snoozes the task for 3 hours and shows a toast.
- **Right now** (the Situation sheet) filters Today's pick by time, place, energy and workspace.
- **Check-off in lists** shows a toast with Undo (3 s).
- **Toasts** are single-instance: a new toast replaces the current one.
- **Overdue never uses red.** `danger` is only for Delete.
- **Streaks** never fall back to zero. Users get 2 grace days a week.
- **Small phones (360×800 at 130% text).** Compact Focus metrics: orbit radius 82, block timer digits 52, blocks 8 tall. On Today the three quiet actions sit in one row, and Wrap up and Overwhelmed? move into the reminder row.

## State (from the prototype)
The app-level state you'll need:
- **Navigation:** the current screen and the open sheet or dialog.
- **Theme:** dark/light following the system appearance, plus the timer style (orbit or blocks).
- **Today's pick:** the pick index and the skip count.
- **Focus session:** seconds remaining, total, paused.
- **Done and undo:** per-task done flags, per-step done flags, the toast message and its undo target.
- **Right now filters:** time, place, energy, workspace.
- **Quick add draft:** text, length, workspace, more-options open.
- **Task details:** priority, dread.
- **Settings:** celebration level (Off / Subtle / Normal / Party).
- **Progress:** XP, level, streak and coins.

## Icons
**Phosphor Icons** (MIT; `phosphor_flutter`). Use Regular weight by default, Fill for the active nav tab and stars, and Bold for "+" and checks. Size 20–22 in rows and 18 inline.

| Use | Icon | Use | Icon |
|---|---|---|---|
| Start / star | ph-star-four | Wrap up | ph-moon |
| Check back | ph-bell-simple-ringing | Weekly reset | ph-broom |
| Errand run | ph-car-simple | Brain dump | ph-lightning |
| Template | ph-copy-simple | Full form | ph-arrows-out-simple |
| Filter | ph-funnel-simple | Voice | ph-microphone |
| Company | ph-headphones | Hold me to it | ph-hand-heart |
| Waiting | ph-hourglass-medium | Settings | ph-gear-six |
| Link | ph-link-simple | Pin | ph-push-pin |
| Suggest steps | ph-sparkle | Delete | ph-trash |

## Files
- `README.md`: this spec.
- `design/Gumption App.dc.html`: all phone screens and the clickable prototype. Needs `design/support.js` next to it.
- `design/Gumption Round 2.dc.html`: the review canvas, including widgets, Mac/iPad, the icon and the store screenshots.
- `design/Gumption Handoff.dc.html`: the token and component sheet.
- `screenshots/phone/*.png`: 68 phone states. `screenshots/other/*.png`: widgets, Mac/iPad, icon, store.
- `design/icon/`: production icon SVGs and 1024 px PNGs.
