import 'package:flutter/material.dart';

import '../settings/device_workspaces.dart';

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
import '../gamification/xp_rules.dart';
import '../guide/examples.dart';
import '../guide/guide_screen.dart';
import '../motivation/quote_rotator.dart';
import '../motivation/quote_service.dart';
import '../tasks/tasks_controller.dart';
import '../tasks/waiting_sheet.dart';
import '../tasks/weekly_reset.dart';
import '../tasks/weekly_reset_screen.dart';
import 'errand_run_screen.dart';
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

    Widget mainPanel({bool large = false}) {
      if (choices.isNotEmpty) return _CommitPanel(choices: choices);
      if (suggestion != null) {
        return _TaskCard(suggestion: suggestion, large: large);
      }
      return _NothingPanel(reason: result.noPickReason!);
    }

    const header = Padding(
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
    );
    Widget headline(double size) => Padding(
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
          style: s.display(size),
          maxLines: 1,
        ),
      ),
    );
    Widget card({bool large = false}) => AnimatedSwitcher(
      duration: Duration(milliseconds: context.reduceMotion ? 0 : 250),
      child: KeyedSubtree(
        key: ValueKey(
          suggestion?.task.id ??
              (choices.isNotEmpty ? 'commit' : result.noPickReason?.name),
        ),
        child: mainPanel(large: large),
      ),
    );
    // Tap to skip ahead. Dread-busting when the pick is one you rated
    // "Ugh" or worse.
    final quoteContext = (suggestion?.task.ugh ?? 0) >= 2
        ? QuoteContext.dreadTask
        : QuoteContext.dashboard;
    final quote = QuoteRotator(context: quoteContext);

    return LayoutBuilder(
      builder: (context, c) {
        // A computer: the one task stays front and center; everything
        // around it moves to a column on the right instead of stacking
        // above it.
        if (c.maxWidth >= 1000) {
          return ContentWidth(
            maxWidth: 1240,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      28,
                      28,
                      28,
                      MediaQuery.paddingOf(context).bottom + 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 30),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    headline(48),
                                    const SizedBox(height: 26),
                                    card(large: true),
                                    if (suggestion != null) ...[
                                      const SizedBox(height: 12),
                                      _Tiles(task: suggestion.task),
                                    ],
                                    const SizedBox(height: 32),
                                    const Spacer(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: QuoteRotator(
                                        context: quoteContext,
                                        large: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              // Tune the pick without opening a sheet, see
                              // what's waiting, and how today is going.
                              SizedBox(
                                width: 360,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Same inset as the banners below.
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Panel(
                                        radius: 22,
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          18,
                                          20,
                                          20,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Right now',
                                              style: s.display(22),
                                            ),
                                            const SizedBox(height: 12),
                                            const SituationControls(gap: 14),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // The banners carry their own top gap.
                                    const _CheckBackBanner(),
                                    const _ErrandRunBanner(),
                                    const _ResetBanner(),
                                    const _ExamplesBanner(),
                                    const SizedBox(height: 14),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: _TodayPanel(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                      header,
                      const SizedBox(height: 26),
                      headline(31),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: _SituationBar(),
                      ),
                      const _CheckBackBanner(),
                      const _ErrandRunBanner(),
                      const _ResetBanner(),
                      const _ExamplesBanner(),
                      const SizedBox(height: 20),
                      card(),
                      if (suggestion != null) ...[
                        const SizedBox(height: 10),
                        _Tiles(task: suggestion.task),
                      ],
                      const SizedBox(height: 24),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: quote,
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
      },
    );
  }
}

class _SituationBar extends ConsumerWidget {
  const _SituationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final i = ref.watch(pickerInputsProvider);
    final single = ref.watch(deviceWorkspacesProvider).single;
    final parts = [
      i.availableMin >= 120 ? '2h+' : formatMinutes(i.availableMin),
      i.willingToLeave ? 'Can go out' : 'At home',
      if (i.energy != null) '${i.energy!.label} energy',
      if (i.workspaces.length == 1 && !single)
        '${i.workspaces.first.label} only',
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
Future<void> showSituationSheet(BuildContext context) => showAppSheet<void>(
  context: context,
  builder: (ctx) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your situation', style: ctx.spec.display(26)),
          const SizedBox(height: 18),
          const SituationControls(),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  ),
);

/// The picker's inputs as controls: in the sheet on a phone, always on
/// screen on a computer. Every change re-picks straight away.
class SituationControls extends ConsumerWidget {
  const SituationControls({super.key, this.gap = 18});
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final i = ref.watch(pickerInputsProvider);
    final ctl = ref.read(pickerInputsProvider.notifier);
    final space = SizedBox(height: gap);
    final both = {Workspace.personal, Workspace.work};
    final ws = i.workspaces.length == 2 ? null : i.workspaces.first;
    final single = ref.watch(deviceWorkspacesProvider).single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('How much time do you have?'),
        ChoiceGroup<int>(
          values: timeOptions,
          selected: i.availableMin,
          mono: true,
          labelOf: (m) => m >= 120 ? '2h+' : shortMinutes(m),
          onSelected: ctl.setTime,
        ),
        space,
        const FieldLabel('Can you leave the house?'),
        Segmented<bool>(
          values: const [false, true],
          selected: i.willingToLeave,
          inset: s.isDark,
          labelOf: (v) => v ? 'Can go out' : 'Staying in',
          onSelected: ctl.setWillingToLeave,
        ),
        space,
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
        if (!single) ...[
          space,
          const FieldLabel('Which tasks?'),
          Segmented<Workspace?>(
            values: const [null, Workspace.personal, Workspace.work],
            selected: ws,
            inset: s.isDark,
            labelOf: (w) => w?.label ?? 'Both',
            onSelected: (w) => ctl.setWorkspaces(w == null ? both : {w}),
          ),
        ],
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.suggestion, this.large = false});
  final Suggestion suggestion;

  /// On a computer: bigger type, and room for the whole checklist and why
  /// it was picked.
  final bool large;

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
    final hasFirstStep = t.nextStep.isNotEmpty;
    final steps = t.steps;

    final buttonHeight = large ? 64.0 : 58.0;

    return Container(
      padding: large
          ? const EdgeInsets.fromLTRB(32, 30, 32, 30)
          : const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: s.accent,
        borderRadius: BorderRadius.circular(large ? 34 : 30),
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
          Text(t.title, style: s.display(large ? 44 : 32, color: s.onAccent)),
          const SizedBox(height: 10),
          Text.rich(
            hasFirstStep
                ? TextSpan(
                    children: [
                      TextSpan(
                        text: steps.isEmpty
                            ? 'First: '
                            : 'Step ${steps.indexWhere((i) => !i.done) + 1} '
                                  'of ${steps.length}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: t.nextStep),
                    ],
                  )
                : TextSpan(text: suggestion.reasonLine),
            style: TextStyle(
              fontSize: hasFirstStep ? (large ? 19 : 17) : (large ? 17 : 15),
              height: 1.4,
              color: s.onAccentMuted,
            ),
          ),
          if (large && steps.length > 1) ...[
            const SizedBox(height: 16),
            for (final step in steps.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      step.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: s.onAccentMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step.text,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          color: s.onAccentMuted,
                          decoration: step.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (steps.length > 6)
              Text(
                '+${steps.length - 6} more',
                style: TextStyle(fontSize: 14, color: s.onAccentMuted),
              ),
          ],
          if (large && hasFirstStep && suggestion.reasonLine.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Why this one: ${suggestion.reasonLine}',
              style: TextStyle(fontSize: 14, color: s.onAccentMuted),
            ),
          ],
          SizedBox(height: large ? 28 : 22),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      openFocus(context, t.id, minutes: suggestion.plannedMin),
                  style: FilledButton.styleFrom(
                    backgroundColor: s.ink,
                    foregroundColor: s.onInk,
                    minimumSize: Size(0, buttonHeight),
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
                    minimumSize: Size(98, buttonHeight),
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

/// Today's numbers on a computer, with the way out when it's too much.
class _TodayPanel extends ConsumerWidget {
  const _TodayPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final p = ref.watch(progressProvider);
    final now = ref.read(clockProvider)();
    final xpToday = p.recent
        .where(
          (r) =>
              r.at.year == now.year &&
              r.at.month == now.month &&
              r.at.day == now.day,
        )
        .fold(0, (a, r) => a + r.amount);
    final streak = streakWithGrace(p.activeDays, now);
    final stats = [
      ('${p.completedOn(now)}', 'done'),
      ('$xpToday', 'XP'),
      ('$streak', streak == 1 ? 'day streak' : 'days streak'),
    ];
    return Panel(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Today'),
          Row(
            children: [
              for (final (value, label) in stats)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: s.display(30, weight: FontWeight.w600),
                      ),
                      Text(
                        label,
                        style: TextStyle(fontSize: 13, color: s.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            children: [
              if (now.hour >= 17)
                TextButton.icon(
                  onPressed: () => context.push('/wrapup'),
                  icon: const Icon(Icons.nights_stay_outlined, size: 18),
                  label: const Text('Wrap up'),
                ),
              TextButton.icon(
                onPressed: () => overwhelm(context, ref),
                style: TextButton.styleFrom(foregroundColor: s.text2),
                icon: const Icon(Icons.spa_outlined, size: 18),
                label: const Text('Overwhelmed?'),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
    Widget link(String text, Color? color, VoidCallback onTap) => InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Text(
          text,
          style: style.copyWith(
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color ?? style.color,
          ),
        ),
      ),
    );
    // Stats left, links right; on a narrow phone with large text the links
    // drop to their own line instead of overflowing.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              Text('$done done today', style: style),
              Text('$xpToday XP today', style: style),
            ],
          ),
          Wrap(
            spacing: 10,
            children: [
              if (now.hour >= 17)
                link('Wrap up', s.primary, () => context.push('/wrapup')),
              link('Overwhelmed?', null, () => overwhelm(context, ref)),
            ],
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
        'Get everything out of your head, then let Gumption choose.',
        [
          FilledButton(
            onPressed: () => showQuickAdd(context),
            child: const Text('Add a task'),
          ),
          OutlinedButton(
            onPressed: () => showQuickAdd(context, brainDump: true),
            child: const Text('Brain dump'),
          ),
          // New here: see it full first, or read how it works.
          const ExamplesButton(),
          TextButton(
            onPressed: () => context.push('/guide'),
            child: const Text('How Gumption works'),
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
    return _Banner(
      icon: Icons.mark_email_unread_outlined,
      color: s.warning,
      text: due.length == 1
          ? 'Check back: ${due.single.waitingOn.isEmpty ? due.single.title : due.single.waitingOn}'
          : 'Check back on ${due.length} waiting tasks',
      onTap: () => context.go('/tasks'),
    );
  }
}

/// "Errand run: Pharmacy + Post office · 45m" when you can go out.
class _ErrandRunBanner extends ConsumerWidget {
  const _ErrandRunBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final out = ref.watch(pickerInputsProvider.select((i) => i.willingToLeave));
    final run = out ? ref.watch(errandRunProvider) : null;
    if (run == null) return const SizedBox.shrink();
    return _Banner(
      icon: Icons.directions_car_outlined,
      color: context.spec.primary,
      text: 'Errand run: ${run.summary} · ${shortMinutes(run.minutes)}',
      onTap: () => context.push('/errands'),
    );
  }
}

/// The weekly reset, offered on weekends (see `resetDue`).
class _ResetBanner extends ConsumerWidget {
  const _ResetBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider)();
    final stale = staleTasks(ref.watch(tasksProvider), now).length;
    final due = resetDue(
      staleCount: stale,
      lastReset: ref.watch(lastResetProvider),
      now: now,
    );
    if (!due) return const SizedBox.shrink();
    return _Banner(
      icon: Icons.cleaning_services_outlined,
      color: context.spec.primary,
      text:
          'Weekly reset: $stale ${stale == 1 ? 'task' : 'tasks'} to sort · '
          'about ${(stale / 2).ceil().clamp(1, 15)} min',
      onTap: () => context.push('/reset'),
    );
  }
}

/// While the example tasks are showing: a reminder they can go.
class _ExamplesBanner extends ConsumerWidget {
  const _ExamplesBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(examplesShowingProvider)) return const SizedBox.shrink();
    return _Banner(
      icon: Icons.science_outlined,
      color: context.spec.primary,
      text: 'These are example tasks · How Gumption works',
      onTap: () => context.push('/guide'),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Panel(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
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
