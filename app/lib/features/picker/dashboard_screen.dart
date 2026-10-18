import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../sync/sync_badge.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../capture/quick_add_sheet.dart';
import '../focus/focus_route.dart';
import '../gamification/level_badge.dart';
import '../gamification/progress_controller.dart';
import '../motivation/quote_rotator.dart';
import '../motivation/quote_service.dart';
import '../tasks/tasks_controller.dart';
import '../tasks/waiting_sheet.dart';
import 'picker_controller.dart';
import 'picker_engine.dart';

/// Home: one task, right now.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final inputs = ref.watch(pickerInputsProvider);
    final result = ref.watch(pickResultProvider);
    final choices = inputs.shouldCommit
        ? ref.watch(commitChoicesProvider)
        : const <Suggestion>[];
    final suggestion = choices.isEmpty ? result.suggestion : null;

    final Widget main;
    if (choices.isNotEmpty) {
      main = _CommitPanel(choices: choices);
    } else if (suggestion != null) {
      main = _TaskCard(suggestion: suggestion);
    } else {
      main = _NothingPanel(reason: result.noPickReason!);
    }

    return ContentWidth(
      maxWidth: 560,
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                20,
                14,
                MediaQuery.paddingOf(context).bottom + 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Wordmark(),
                        SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SyncAlert(),
                                SizedBox(width: 4),
                                Flexible(child: LevelPill()),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: 'One thing. ',
                          children: [
                            TextSpan(
                              text: 'Right now.',
                              style: TextStyle(color: s.primary),
                            ),
                          ],
                        ),
                        style: s.display(31),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: _SituationBar(),
                  ),
                  const _CheckBackBanner(),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: Duration(
                      milliseconds: context.reduceMotion ? 0 : 250,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(
                        suggestion?.task.id ??
                            (choices.isNotEmpty
                                ? 'commit'
                                : result.noPickReason?.name),
                      ),
                      child: main,
                    ),
                  ),
                  if (suggestion != null) ...[
                    const SizedBox(height: 10),
                    _Tiles(task: suggestion.task),
                  ],
                  const SizedBox(height: 24),
                  const Spacer(),
                  // Tap to skip ahead. Dread-busting when the pick is one
                  // you rated "Ugh" or worse.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: QuoteRotator(
                      context: (suggestion?.task.ugh ?? 0) >= 2
                          ? QuoteContext.dreadTask
                          : QuoteContext.dashboard,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _TodayLine(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SituationBar extends ConsumerWidget {
  const _SituationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final i = ref.watch(pickerInputsProvider);
    final parts = [
      i.availableMin >= 120 ? '2h+' : formatMinutes(i.availableMin),
      i.willingToLeave ? 'Can go out' : 'At home',
      if (i.energy != null) '${i.energy!.label} energy',
      if (i.workspaces.length == 1) '${i.workspaces.first.label} only',
    ];
    return Semantics(
      button: true,
      label: 'Your situation: ${parts.join(', ')}. Change',
      excludeSemantics: true,
      child: Panel(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: () => showSituationSheet(context),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final (n, p) in parts.indexed) ...[
                      if (n > 0)
                        TextSpan(
                          text: '  /  ',
                          style: TextStyle(color: s.faint),
                        ),
                      TextSpan(text: p),
                    ],
                  ],
                ),
                style: TextStyle(fontSize: 15, color: s.text2),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.edit_outlined, size: 17, color: s.muted),
          ],
        ),
      ),
    );
  }
}

/// Time, place, energy and workspace: what the picker needs to know.
Future<void> showSituationSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final s = ctx.spec;
          final i = ref.watch(pickerInputsProvider);
          final ctl = ref.read(pickerInputsProvider.notifier);
          const gap = SizedBox(height: 18);
          final both = {Workspace.personal, Workspace.work};
          final ws = i.workspaces.length == 2 ? null : i.workspaces.first;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your situation', style: s.display(26)),
                  gap,
                  const FieldLabel('How much time do you have?'),
                  ChoiceGroup<int>(
                    values: timeOptions,
                    selected: i.availableMin,
                    mono: true,
                    labelOf: (m) => m >= 120 ? '2h+' : shortMinutes(m),
                    onSelected: ctl.setTime,
                  ),
                  gap,
                  const FieldLabel('Can you leave the house?'),
                  Segmented<bool>(
                    values: const [false, true],
                    selected: i.willingToLeave,
                    inset: s.isDark,
                    labelOf: (v) => v ? 'Can go out' : 'Staying in',
                    onSelected: ctl.setWillingToLeave,
                  ),
                  gap,
                  const FieldLabel('Energy right now (optional)'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in Energy.values)
                        Pill(
                          label: e.label,
                          selected: i.energy == e,
                          onTap: () => ctl.setEnergy(i.energy == e ? null : e),
                        ),
                    ],
                  ),
                  gap,
                  const FieldLabel('Which tasks?'),
                  Segmented<Workspace?>(
                    values: const [null, Workspace.personal, Workspace.work],
                    selected: ws,
                    inset: s.isDark,
                    labelOf: (w) => w?.label ?? 'Both',
                    onSelected: (w) =>
                        ctl.setWorkspaces(w == null ? both : {w}),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.suggestion});
  final Suggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final t = suggestion.task;
    final now = DateTime.now();
    final time = suggestion.isChunk
        ? '${suggestion.plannedMin} of ${t.estimateMin} min'
        : suggestion.plannedMin != t.estimateMin
        ? '~${suggestion.plannedMin} min'
        : formatMinutes(t.estimateMin);
    final meta = [
      time,
      if (t.dueAt != null) 'due ${formatDue(t.dueAt!, now)}',
    ].join(' · ');
    final hasFirstStep = t.firstStep.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: s.accent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.workspace.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: s.onAccentMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  meta,
                  textAlign: TextAlign.right,
                  style: s.mono(
                    14,
                    color: s.onAccentMuted,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(t.title, style: s.display(32, color: s.onAccent)),
          const SizedBox(height: 10),
          Text.rich(
            hasFirstStep
                ? TextSpan(
                    children: [
                      const TextSpan(
                        text: 'First: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: t.firstStep.trim()),
                    ],
                  )
                : TextSpan(text: suggestion.reasonLine),
            style: TextStyle(
              fontSize: hasFirstStep ? 17 : 15,
              height: 1.4,
              color: s.onAccentMuted,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      openFocus(context, t.id, minutes: suggestion.plannedMin),
                  style: FilledButton.styleFrom(
                    backgroundColor: s.ink,
                    foregroundColor: s.onInk,
                    minimumSize: const Size(0, 58),
                    textStyle: const TextStyle(
                      fontFamily: Fonts.ui,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: Icon(Icons.play_arrow_rounded, color: s.accent),
                  label: const Text('Start'),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Just 5 minutes',
                child: OutlinedButton(
                  onPressed: () =>
                      openFocus(context, t.id, minutes: 5, justFive: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: s.ink,
                    side: BorderSide(color: s.ink, width: 2),
                    minimumSize: const Size(98, 58),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('5 min'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Not this one / Smaller / Later, under the task card.
class _Tiles extends ConsumerWidget {
  const _Tiles({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = [
      (
        Icons.shuffle_rounded,
        'Not this one',
        () => ref.read(pickerInputsProvider.notifier).reject(task.id),
      ),
      (
        Icons.compress_rounded,
        'Smaller',
        () => context.push('/task/${task.id}?focusFirstStep=1'),
      ),
      (Icons.schedule_rounded, 'Later', () => _snooze(context, ref, task)),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (icon, label, onTap)) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _Tile(icon: icon, label: label, onTap: onTap),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Panel(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: s.text2),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: s.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _snooze(BuildContext context, WidgetRef ref, Task t) {
  ref.read(tasksProvider.notifier).snooze(t.id, const Duration(hours: 3));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('"${t.title}" will come back in 3 hours.')),
  );
}

/// "2 done today · 40 XP today · Overwhelmed?"
class _TodayLine extends ConsumerWidget {
  const _TodayLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final p = ref.watch(progressProvider);
    final now = ref.read(clockProvider)();
    final done = p.completedOn(now);
    final xpToday = p.recent
        .where(
          (r) =>
              r.at.year == now.year &&
              r.at.month == now.month &&
              r.at.day == now.day,
        )
        .fold(0, (a, r) => a + r.amount);
    final style = s.mono(12, color: s.isDark ? const Color(0xFF7C8885) : null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 18,
              runSpacing: 4,
              children: [
                Text('$done done today', style: style),
                Text('$xpToday XP today', style: style),
              ],
            ),
          ),
          if (now.hour >= 17) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/wrapup'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                child: Text(
                  'Wrap up',
                  style: style.copyWith(
                    color: s.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: s.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => overwhelm(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Text(
                'Overwhelmed?',
                style: style.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: style.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hide everything except one tiny step and a 5-minute timer.
Future<void> overwhelm(BuildContext context, WidgetRef ref) async {
  final tiny = ref.read(tinySuggestionProvider);
  final s = context.spec;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Okay. Breathe.'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tiny == null
              ? [
                  Text(
                    "Nothing's on your list yet. Write down the one thing "
                    "that's bugging you most. That's the whole task.",
                    style: TextStyle(color: s.text2, height: 1.4),
                  ),
                ]
              : [
                  Text(
                    'Everything else is hidden. Just this, for 5 minutes:',
                    style: TextStyle(color: s.text2, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(tiny.task.startLine, style: s.display(22)),
                  const SizedBox(height: 10),
                  Text(
                    "When the timer ends you can stop. That's a win.",
                    style: TextStyle(color: s.muted),
                  ),
                ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Not now'),
        ),
        if (tiny == null)
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              showQuickAdd(context);
            },
            child: const Text('Write it down'),
          )
        else
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openFocus(
                context,
                tiny.task.id,
                minutes: 5,
                justFive: true,
                panic: true,
              );
            },
            child: const Text('Start 5 minutes'),
          ),
      ],
    ),
  );
}

class _CommitPanel extends ConsumerWidget {
  const _CommitPanel({required this.choices});
  final List<Suggestion> choices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    return Panel(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pick one of these and commit.', style: s.display(26)),
          const SizedBox(height: 8),
          Text(
            "Rerolling feels productive, but it's the dread talking. "
            'Any of these is a good choice.',
            style: TextStyle(color: s.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          const QuoteRotator(context: QuoteContext.afterSkip),
          const SizedBox(height: 8),
          for (final (i, c) in choices.indexed)
            InkWell(
              onTap: () {
                ref.read(pickerInputsProvider.notifier).resetRejections();
                openFocus(context, c.task.id, minutes: c.plannedMin);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: s.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: s.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TaskMeta(
                            task: c.task,
                            plannedMin: c.isChunk ? c.plannedMin : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: s.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: s.onAccent,
                        semanticLabel: 'Start',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NothingPanel extends ConsumerWidget {
  const _NothingPanel({required this.reason});
  final NoPickReason reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final ctl = ref.read(pickerInputsProvider.notifier);
    final inputs = ref.watch(pickerInputsProvider);

    final (String title, String body, List<Widget> actions) = switch (reason) {
      NoPickReason.noOpenTasks => (
        'Your list is empty.',
        'Get everything out of your head, then let Unstuck choose.',
        [
          FilledButton(
            onPressed: () => showQuickAdd(context),
            child: const Text('Add a task'),
          ),
          OutlinedButton(
            onPressed: () => showQuickAdd(context, brainDump: true),
            child: const Text('Brain dump'),
          ),
        ],
      ),
      NoPickReason.allNeedLeaving => (
        'Everything left needs you out of the house.',
        'Up for an errand run?',
        [
          FilledButton(
            onPressed: () => ctl.setWillingToLeave(true),
            child: const Text('I can go out'),
          ),
        ],
      ),
      NoPickReason.allExcluded => (
        "You've passed on everything.",
        "That's okay. Let's look again with fresh eyes.",
        [
          FilledButton(
            onPressed: ctl.resetRejections,
            child: const Text('Show me again'),
          ),
        ],
      ),
      NoPickReason.nothingFitsTime => (
        'Nothing fits ${formatMinutes(inputs.availableMin)}.',
        'Try a bigger window, or mark long tasks as "can do in chunks".',
        [
          if (inputs.availableMin < timeOptions.last)
            FilledButton(
              onPressed: () => ctl.setTime(
                timeOptions.firstWhere((m) => m > inputs.availableMin),
              ),
              child: const Text('A bit more time'),
            ),
          OutlinedButton(
            onPressed: () => overwhelm(context, ref),
            child: const Text('5 minutes on something'),
          ),
        ],
      ),
    };

    return Panel(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: s.display(28)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: s.muted, height: 1.4)),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

/// "Check back on 2 waiting tasks": shown only when a follow-up is due.
class _CheckBackBanner extends ConsumerWidget {
  const _CheckBackBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final now = ref.read(clockProvider)();
    final due = ref
        .watch(tasksProvider)
        .where((t) => followUpDue(t, now))
        .toList();
    if (due.isEmpty) return const SizedBox.shrink();
    final text = due.length == 1
        ? 'Check back: ${due.single.waitingOn.isEmpty ? due.single.title : due.single.waitingOn}'
        : 'Check back on ${due.length} waiting tasks';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Panel(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: () => context.go('/tasks'),
        child: Row(
          children: [
            Icon(Icons.mark_email_unread_outlined, size: 18, color: s.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: s.text2),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: s.faint),
          ],
        ),
      ),
    );
  }
}
