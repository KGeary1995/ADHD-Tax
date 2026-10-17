# ADHD Tax

**Pick one task. Start it. Level up.**

A task app built for ADHD brains that struggle to *start*. Most to-do apps help you organize. This one makes the decision for you, shrinks the first step until it's easy, and rewards you the moment you begin, not only when you finish.

Runs on Android, Windows, macOS and the web from one Flutter codebase. The full product plan and roadmap are in [docs/PLAN.md](docs/PLAN.md).

## What works today (Phase 1)

| Feature | What it does |
|---|---|
| **Pick for me** | Tell it how much time you have, whether you can leave the house, your energy, and Personal/Work. It returns **one** task with a reason ("Due in 19 hours · Critical priority"). |
| **Smart scoring** | Priority, deadline urgency (hard deadlines ramp sooner), staleness (avoided tasks resurface), how well the task fills your window, energy match, "eat the frog" boost for dreaded tasks in the morning, and a skip penalty that wears off within a day. |
| **Reroll limit** | "Not this one" twice, and it asks you to pick one of three and commit. Endless rerolling is the dread talking. |
| **Overwhelmed button** | Hides everything and gives you one easy task for 5 minutes. |
| **Focus screen** | Shows only the *first step*, a Time-Timer style shrinking disc, and a rotating quote. **Just 5 minutes** mode asks "keep going?" when the 5 minutes are up. |
| **5-second capture** | Quick add (Ctrl+N) needs only a title. **Brain dump** turns a pasted list into tasks, one per line. "Add & start now" skips the list entirely. |
| **XP, levels, achievements** | XP for *starting*, more for finishing, bonuses for dreaded tasks, old tasks, beating your estimate and errands. 18 achievements, ranks every 5 levels, and coins for the reward shop that's coming. Streaks include 2 grace days a week and never reset to zero. |
| **Celebrations** | Confetti plus an XP breakdown card when you finish, and a small toast when you start (it never covers the screen at that moment). Intensity runs Off / Subtle / Normal / Party. |
| **Motivational quotes** | 114 bundled quotes in five categories. The category depends on the moment: dread-busting for a task you rated "Ugh", self-compassion after a skip, momentum during focus. |
| **9 themes** | Professional (Slate, Graphite, Clinic Calm), futuristic (Neon Grid, Holo Glass, Mission Control, Terminal), and accessibility (Low-Stim, High Contrast). |
| **Patient-info guard** | Work tasks that look like PHI (DOB, MRN, "pt Jane Doe") show a warning to use initials or a ticket number instead. |

Data is stored locally on each device for now. Google Drive sync and Google Calendar planning are Phases 2 and 3.

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

Every push runs CI, which tests the app and builds the web, Android and Windows versions. You can download the builds from the run's **Artifacts** section on GitHub.

### Keyboard shortcuts (desktop / web)

| Keys | Action |
|---|---|
| Ctrl+N | Quick add |
| Ctrl+1 … 4 | Focus / Tasks / Progress / Settings |
| Space | Pause/resume on the focus screen |

## Project layout

```
app/lib/
  core/            theme engine (9 themes), shared providers
  data/            Task model, storage seam (local now, Drive sync next)
  features/
    picker/        pick-for-me engine (pure Dart) + dashboard
    focus/         focus screen, visual timer
    capture/       quick add, brain dump, task editor
    tasks/         task list + state
    gamification/  XP rules, levels, streaks, achievements, celebrations
    motivation/    quote service + rotator
    safety/        PHI guard
    settings/      themes, celebration intensity, preferences
app/test/          52 unit + widget tests
docs/PLAN.md       full product plan and roadmap
```

The decision logic (`picker_engine.dart`, `xp_rules.dart`, `achievements.dart`, `phi_guard.dart`, `quote_service.dart`) is pure Dart with no Flutter imports, so it's fast to test and reusable.

## Roadmap

1. ~~**Phase 1: offline MVP**~~ ✅
2. **Phase 2: Google sign-in + Drive sync.** Personal and Work workspaces each sync to their own Google account via the Drive app-data folder. Each device writes its own change log, so devices never write the same file and nothing conflicts.
3. **Phase 3: Google Calendar.** Free time detected automatically ("47 min until Staff Huddle"). Plan My Day drops suggested tasks into a dedicated "ADHD Tax" calendar, with two-way updates and "leave in 15 min" alerts.
4. **Phase 4: Monday.com-style views.** Board, table, timeline, calendar, projects, recurring tasks, command palette.
5. **Phase 5: ADHD extras.** Learned estimate correction, errand batching, Android home-screen widget, desktop global hotkey, reward shop, body doubling, daily shutdown.
6. **Phase 6: optional AI (Claude).** "Break this down" and natural-language capture, using your own API key. Off by default in Work.

## Before using it for clinic work

- **No PHI in tasks.** Use initials or ticket numbers. The PHI guard catches common slips but is not a compliance control.
- When Drive sync arrives, Work tasks will sync only to the **work** Google Workspace account. Your clinic's Workspace admin may need to approve the app's OAuth client (Admin console → Security → API controls).
- Check with your compliance officer before relying on it for anything patient-adjacent.
