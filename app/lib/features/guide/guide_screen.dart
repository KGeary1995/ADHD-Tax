import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import '../capture/quick_add_sheet.dart';
import 'examples.dart';
import '../../core/theme/ph.dart';

/// Example tasks: try the app full, then clear them with one tap.
class ExamplesButton extends ConsumerWidget {
  const ExamplesButton({super.key, this.filled = false, this.link = false});
  final bool filled;

  /// A plain gold text link (Today's first run).
  final bool link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showing = ref.watch(examplesShowingProvider);
    final ctl = ref.read(examplesProvider.notifier);
    void onTap() {
      final messenger = ScaffoldMessenger.of(context);
      if (showing) {
        ctl.remove();
        messenger.showSnackBar(
          const SnackBar(content: Text('Example tasks removed.')),
        );
      } else {
        ctl.add();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Added example tasks. Remove them any time from here or '
              'Settings → Help.',
            ),
          ),
        );
      }
    }

    final label = Text(
      showing ? 'Remove example tasks' : 'Try with example tasks',
    );
    if (link) return TextButton(onPressed: onTap, child: label);
    return filled && !showing
        ? FilledButton(onPressed: onTap, child: label)
        : OutlinedButton(onPressed: onTap, child: label);
  }
}

/// How Gumption works: what each part does, with a way to go and see it.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    void go(String path) => context.go(path);
    void push(String path) => context.push(path);

    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final desktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);

    final sections = <_Section>[
      _Section(
        Ph.target,
        'Today: one task, picked for you',
        'Gumption chooses one task from the time you have, whether you can go '
            'out, your energy, and how urgent, important, old and dreaded '
            'each task is.',
        [
          '**5 min** starts a five-minute session. When it ends, it asks '
              'whether to keep going.',
          '**Not this one** picks another. After two, it asks you to commit '
              'to one of three.',
          '**Smaller** opens the first step so you can make it tiny. '
              '**Later** hides the task for three hours.',
          '**Overwhelmed?** hides everything but one easy task and a '
              'five-minute timer.',
          'Tap the bar with your time and place ("30 min / At home") to '
              'change them.',
        ],
        'Go to Today',
        () => go('/'),
      ),
      _Section(
        Ph.plusBold,
        'Adding tasks in five seconds',
        'Only a title is needed. Type extra details right into it and they '
            'fill themselves in.',
        [
          '"Call the bank **tomorrow 2pm 15 min #money**" sets the due '
              'time, length and tag.',
          'It understands friday, tonight, in 3 days, 4/15, at 5, 1h 30m, '
              'urgent and !!.',
          '**Add & start** adds it and starts the timer straight away.',
          '**Brain dump** turns a pasted list into tasks, one per line.',
          'The microphone lets you say the task instead of typing it.',
        ],
        'Try Quick add',
        () => showQuickAdd(context),
      ),
      _Section(
        Ph.timer,
        'The focus timer',
        'After you tap Start you see only the next step and a ring that '
            'shrinks as time passes.',
        [
          'With a checklist, **Step done** moves you to the next step.',
          '**+5** adds five minutes. Pause whenever you need to.',
          'The headphones add background sound (brown noise, rain, fan) and '
              'an optional "buddy" line, like someone at the next desk.',
          'After five timed tasks Gumption learns how long things really take '
              'you, and picks tasks that truly fit.',
        ],
        'Start something',
        () => go('/'),
      ),
      _Section(
        Ph.listBullets,
        'Tasks, projects and the board',
        'Every task lives in the Tasks tab, as a list or a board.',
        [
          'Swipe right to mark done, left to delete. Each one can be undone.',
          '**Waiting on someone?** Park the task with when to check back. '
              'On that day it moves to **Check back**.',
          '**Repeating tasks** wait in **Coming up** until their day.',
          '**Projects** group tasks and notes together.',
          'Tap a task to edit it: a **first 2-minute step**, a **checklist**, '
              'how much you dread it, due date, repeats and notes.',
        ],
        'Go to Tasks',
        () => go('/tasks'),
      ),
      _Section(
        Ph.note,
        'Notes',
        'Thoughts, call outcomes and meeting notes, next to your tasks.',
        [
          'Type **#tags** anywhere in a note, then filter by them.',
          '**Make tasks** turns the lines you tick into tasks.',
          'Each task has its own notes: open it and tap **Add a note**.',
        ],
        'Go to Notes',
        () => go('/notes'),
      ),
      _Section(
        Ph.chartBar,
        'Progress and rewards',
        'You earn XP for starting, more for finishing, and bonuses for '
            'dreaded and long-ignored tasks.',
        [
          'Streaks allow two grace days a week and never reset to zero.',
          'Spend coins in the **reward shop** on treats you choose.',
          'Too much confetti? Settings → Look and feel → Celebrations.',
        ],
        'Go to Progress',
        () => go('/progress'),
      ),
      _Section(
        Ph.repeat,
        'Weekly reset, errand runs and wrap-up',
        'Today offers these at the right moments.',
        [
          '**Weekly reset** (weekends): decide about each task that has sat '
              'for a week. Keep it, make it smaller, not this week, or let it '
              'go.',
          '**Errand run**: when you can go out, errands that fit your time, '
              'grouped by place.',
          '**Wrap up** (after 5 pm): what you did, and tomorrow\'s first '
              'thing chosen tonight.',
        ],
        'Open the weekly reset',
        () => push('/reset'),
      ),
      _Section(
        Ph.slidersHorizontal,
        'Settings, sync and backups',
        'Personal and Work stay apart. Each can sync to its own Google '
            'account, or neither.',
        [
          '**Sync**: a hidden folder in your own Google Drive that only '
              'Gumption can open.',
          '**Backup file**: everything in one file you keep, to restore on '
              'any device.',
          if (android)
            '**Reminders**: a countdown while you focus, a "time\'s up" '
                'alert, and gentle check-ins.',
          '**Sensitive info check** (off unless you turn it on) warns when '
              "a Work task looks like it holds someone's personal details.",
        ],
        'Go to Settings',
        () => go('/settings'),
      ),
      if (android)
        _Section(
          Ph.squaresFour,
          'Outside the app',
          'Gumption can help without being open.',
          [
            '**Widgets**: long-press your home screen → Widgets → Gumption. '
                'They show the current pick with Start.',
            '**Share** text from any app to Gumption to turn it into a task.',
          ],
          null,
          null,
        ),
      if (desktop)
        _Section(
          Ph.keyboard,
          'Keyboard shortcuts',
          'Faster on a computer.',
          [
            '**Ctrl+Shift+Space** (⌃⇧Space on a Mac) opens Quick add from '
                'any app.',
            '**Ctrl+N** Quick add · **Ctrl+1…4** switch tabs · **Space** '
                'pauses the timer.',
          ],
          null,
          null,
        ),
    ];

    return Scaffold(
      appBar: topBar(context, close: true, overline: 'HOW GUMPTION WORKS'),
      body: ContentWidth(
        maxWidth: 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 22,
            8,
            narrow ? 16 : 22,
            MediaQuery.paddingOf(context).bottom + 40,
          ),
          children: [
            Text.rich(
              TextSpan(
                text: "Don't decide. ",
                children: [
                  TextSpan(
                    text: 'Just start.',
                    style: TextStyle(color: s.primary),
                  ),
                ],
              ),
              style: s.display(narrow ? 30 : 36),
            ),
            const SizedBox(height: 10),
            Text(
              "Gumption is for when the hard part isn't remembering a task but "
              'starting it. It picks one task for you, shrinks it to a first '
              'step, and rewards you the moment you begin.',
              style: TextStyle(fontSize: 16, height: 1.5, color: s.text2),
            ),
            const SizedBox(height: 20),
            Panel(
              radius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your first five minutes', style: s.display(22)),
                  const SizedBox(height: 12),
                  for (final (i, step) in const [
                    'Add three things on your mind. Tap + and type a title, '
                        'or use Brain dump for a whole list.',
                    'On Today, set how much time you have and whether you '
                        'can go out.',
                    'Look at the one task it picked. Not right? Tap Not this '
                        'one.',
                    'Tap Start, or 5 min if even that feels like a lot. '
                        'Starting earns XP.',
                    'Tap Done when you finish, then peek at Progress.',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Radii.sm),
                              border: Border.all(color: s.star, width: 2),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: s.button(13, s.accentText),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.45,
                                color: s.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Want to look around first? Fill the app with example '
                    'tasks and notes, then remove them with one tap. Your '
                    'own tasks are never touched.',
                    style: TextStyle(fontSize: 14, height: 1.4, color: s.muted),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ExamplesButton(filled: true),
                  ),
                ],
              ),
            ),
            for (final sec in sections) _SectionView(sec),
          ],
        ),
      ),
    );
  }
}

class _Section {
  const _Section(
    this.icon,
    this.title,
    this.about,
    this.points,
    this.action,
    this.onAction,
  );
  final IconData icon;
  final String title;
  final String about;

  /// Bullet points; **bold** marks the name of a button or place.
  final List<String> points;
  final String? action;
  final VoidCallback? onAction;
}

class _SectionView extends StatelessWidget {
  const _SectionView(this.sec);
  final _Section sec;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final base = TextStyle(fontSize: 15, height: 1.45, color: s.text2);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sec.icon, color: s.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(sec.title, style: s.display(21))),
            ],
          ),
          const SizedBox(height: 8),
          Text(sec.about, style: base.copyWith(color: s.onSurface)),
          const SizedBox(height: 8),
          for (final p in sec.points)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: s.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(_bold(p, s.onSurface), style: base),
                  ),
                ],
              ),
            ),
          if (sec.action != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: sec.onAction,
              icon: const Icon(Ph.arrowRight, size: 18),
              label: Text(sec.action!),
            ),
          ],
        ],
      ),
    );
  }
}

/// "a **b** c" → b in semibold.
TextSpan _bold(String text, Color strong) {
  final parts = text.split('**');
  return TextSpan(
    children: [
      for (final (i, part) in parts.indexed)
        TextSpan(
          text: part,
          style: i.isOdd
              ? TextStyle(fontWeight: FontWeight.w600, color: strong)
              : null,
        ),
    ],
  );
}
