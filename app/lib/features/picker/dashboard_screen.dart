import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../settings/device_workspaces.dart';
import '../settings/settings_button.dart';

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
import '../capture/first_steps.dart';
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
import '../../core/theme/ph.dart';

/// Home: one task, right now. Not a card: the task sits on the sky, with
/// Start under it and three quiet ways out.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(pickResultProvider);
    final suggestion = result.suggestion;
    // Tap to skip ahead. Dread-busting when the pick is one you rated
    // "Ugh" or worse.
    final quoteContext = (suggestion?.task.ugh ?? 0) >= 2
        ? QuoteContext.dreadTask
        : QuoteContext.dashboard;

    Widget pick({required bool compact, bool large = false}) =>
        AnimatedSwitcher(
          duration: Duration(milliseconds: context.reduceMotion ? 0 : 250),
          child: KeyedSubtree(
            key: ValueKey(suggestion?.task.id ?? result.noPickReason?.name),
            child: suggestion != null
                ? _Pick(suggestion: suggestion, compact: compact, large: large)
                : _NothingPanel(reason: result.noPickReason!),
          ),
        );

    return LayoutBuilder(
      builder: (context, c) {
        final bottom = MediaQuery.paddingOf(context).bottom;
        // A computer: the task in the main column, the situation and
        // everything around it in a column on the right.
        if (c.maxWidth >= 1000) {
          return ContentWidth(
            maxWidth: 1200,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(44, 36, 36, bottom + 28),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _DesktopHeader(),
                              const Spacer(),
                              pick(compact: false, large: true),
                              const Spacer(),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: QuoteRotator(
                                  context: quoteContext,
                                  footnote: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        const SizedBox(width: 320, child: _RightNowPanel()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        // A small phone, or big text: fewer reminder lines, and the quiet
        // actions in one row.
        final compact =
            c.maxWidth < 380 ||
            c.maxHeight < 700 ||
            MediaQuery.textScalerOf(context).scale(10) > 12;
        return ContentWidth(
          maxWidth: 560,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Gap.s8,
                    6,
                    Gap.s8,
                    bottom + Gap.s6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: _SituationButton(compact: compact)),
                          const SizedBox(width: Gap.s4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SyncAlert(),
                              // With the gear beside it, the streak only
                              // fits on a big phone; Progress always has it.
                              LevelPill(compact: compact || c.maxWidth < 420),
                              const SettingsButton(quiet: true),
                            ],
                          ),
                        ],
                      ),
                      _Reminders(compact: compact),
                      // Free space splits evenly above the task and above
                      // the footer.
                      const Spacer(),
                      SizedBox(height: compact ? Gap.s7 : Gap.s9),
                      pick(compact: compact),
                      const Spacer(),
                      SizedBox(height: compact ? Gap.s4 : Gap.s8),
                      if (!compact) _Footer(quoteContext: quoteContext),
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

/// "30 min · Staying in ⌄": what the picker knows about right now. Opens
/// the Right now sheet.
class _SituationButton extends ConsumerWidget {
  const _SituationButton({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final i = ref.watch(pickerInputsProvider);
    final single = ref.watch(deviceWorkspacesProvider).single;
    final parts = [
      i.availableMin >= 120 ? '2h+' : formatMinutes(i.availableMin),
      if (!compact) i.willingToLeave ? 'Can go out' : 'Staying in',
      if (!compact && i.energy != null) '${i.energy!.label} energy',
      if (!compact && i.workspaces.length == 1 && !single)
        '${i.workspaces.first.label} only',
    ];
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(color: s.line2, width: 2),
    );
    return Semantics(
      button: true,
      label:
          'Right now: ${[i.availableMin >= 120 ? '2h+' : formatMinutes(i.availableMin), i.willingToLeave ? 'Can go out' : 'Staying in'].join(', ')}. Change',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => showSituationSheet(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          for (final (n, p) in parts.indexed) ...[
                            if (n > 0)
                              TextSpan(
                                text: ' · ',
                                style: TextStyle(color: s.ink3),
                              ),
                            TextSpan(text: p),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: s.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(Ph.caretDown, size: 13, color: s.ink3),
                ],
              ),
            ),
          ),
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
      padding: sheetPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('Right now'),
          const SizedBox(height: Gap.s7),
          const SituationControls(),
          const SizedBox(height: Gap.s8),
          PrimaryButton(
            label: 'Pick for me',
            height: 58,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  ),
);

/// The picker's inputs as controls: in the sheet on a phone, always on
/// screen on a computer. Every change re-picks straight away.
class SituationControls extends ConsumerWidget {
  const SituationControls({super.key, this.gap = Gap.s7});
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
        const OptionLabel('How much time do you have?'),
        Wrap(
          spacing: Gap.s4,
          runSpacing: Gap.s4,
          children: [
            for (final m in timeOptions)
              _TimePill(
                label: m >= 120 ? '2h+' : shortMinutes(m),
                selected: i.availableMin == m,
                onTap: () => ctl.setTime(m),
              ),
          ],
        ),
        space,
        const OptionLabel('Can you leave the house?'),
        OptionRow(
          children: [
            for (final out in [false, true])
              OptionButton(
                label: out ? 'Can go out' : 'Staying in',
                icon: out ? Ph.carSimple : Ph.houseSimple,
                height: 48,
                selected: i.willingToLeave == out,
                onTap: () => ctl.setWillingToLeave(out),
              ),
          ],
        ),
        space,
        const OptionLabel('Energy', note: 'optional'),
        OptionRow(
          children: [
            for (final e in Energy.values)
              OptionButton(
                label: e.label,
                selected: i.energy == e,
                onTap: () => ctl.setEnergy(i.energy == e ? null : e),
              ),
          ],
        ),
        if (!single) ...[
          space,
          const OptionLabel('Which tasks?'),
          OptionRow(
            children: [
              for (final w in const [null, Workspace.personal, Workspace.work])
                OptionButton(
                  label: w?.label ?? 'Both',
                  dot: switch (w) {
                    null => null,
                    Workspace.personal => s.personal,
                    Workspace.work => s.work,
                  },
                  selected: ws == w,
                  onTap: () => ctl.setWorkspaces(w == null ? both : {w}),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A time option: Sora numbers, 44 tall.
class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(color: selected ? s.star : s.line2, width: 2),
    );
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? s.star : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: s.button(15, selected ? s.onStar : s.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lines under the header: errand run, check back, weekly reset,
/// examples. On a small phone just the check-back count, with Wrap up and
/// Overwhelmed? beside it.
class _Reminders extends ConsumerWidget {
  const _Reminders({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    ref.watch(pickerTickProvider); // a check-back date arriving
    final now = ref.read(clockProvider)();
    final waiting = ref
        .watch(tasksProvider)
        .where((t) => followUpDue(t, now))
        .toList();
    final out = ref.watch(pickerInputsProvider.select((i) => i.willingToLeave));
    final run = out ? ref.watch(errandRunProvider) : null;
    final stale = staleTasks(ref.watch(tasksProvider), now).length;
    final resetIsDue = resetDue(
      staleCount: stale,
      lastReset: ref.watch(lastResetProvider),
      now: now,
    );
    final examples = ref.watch(examplesShowingProvider);

    final rows = <Widget>[
      if (run != null)
        _ReminderRow(
          icon: Ph.carSimple,
          text:
              'Errand run: ${run.summary}, about ${formatMinutes(run.minutes)}',
          onTap: () => context.push('/errands'),
        ),
      if (compact)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Gap.s4,
          children: [
            if (waiting.isNotEmpty)
              Tooltip(
                message:
                    'Check back on ${waiting.length} waiting '
                    '${waiting.length == 1 ? 'task' : 'tasks'}',
                child: _ReminderRow(
                  icon: Ph.bellSimpleRinging,
                  text: '${waiting.length} new',
                  onTap: () => context.go('/tasks'),
                  shrink: true,
                ),
              ),
            const _WrapAndOverwhelmed(),
          ],
        )
      else ...[
        if (waiting.isNotEmpty)
          _ReminderRow(
            icon: Ph.bellSimpleRinging,
            text: waiting.length == 1
                ? 'Check back: ${waiting.single.waitingOn.isEmpty ? waiting.single.title : 'any news on ${_lowerFirst(waiting.single.waitingOn)}'}?'
                : 'Check back on ${waiting.length} waiting tasks',
            onTap: () => context.go('/tasks'),
          ),
        if (resetIsDue)
          _ReminderRow(
            icon: Ph.broom,
            text:
                'Weekly reset: $stale ${stale == 1 ? 'task' : 'tasks'} to '
                'sort, about ${_resetTime(stale)}',
            onTap: () => context.push('/reset'),
          ),
        if (examples)
          _ReminderRow(
            icon: Ph.flask,
            text: 'These are example tasks. How Gumption works',
            onTap: () => context.push('/guide'),
          ),
      ],
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(bottom: Gap.s6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

String _resetTime(int stale) {
  final min = (stale / 2).ceil().clamp(1, 15);
  return min == 1 ? 'a minute' : '$min minutes';
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.text,
    required this.onTap,
    this.shrink = false,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  /// As wide as its text (beside other things in a row).
  final bool shrink;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final label = Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: s.ink2,
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: shrink ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(icon, size: 17, color: s.accentText),
              const SizedBox(width: Gap.s4),
              if (shrink) label else Expanded(child: label),
              const SizedBox(width: Gap.s4),
              Icon(Ph.caretRight, size: 14, color: s.ink2),
            ],
          ),
        ),
      ),
    );
  }
}

/// "☾ Wrap up   Overwhelmed?": quiet links. Wrap up shows after 5 pm.
class _WrapAndOverwhelmed extends ConsumerWidget {
  const _WrapAndOverwhelmed({this.stacked = false});

  /// One above the other, right-aligned: beside the quote at the foot of
  /// Today, so the evening's second link doesn't squeeze the quote.
  final bool stacked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    ref.watch(dayPartProvider); // "Wrap up" appears at 5 pm
    final now = ref.read(clockProvider)();
    Widget link(String text, IconData? icon, VoidCallback onTap) => InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: s.ink2),
                const SizedBox(width: Gap.s2),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: s.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final links = [
      if (now.hour >= 17)
        link('Wrap up', Ph.moon, () => context.push('/wrapup')),
      link('Overwhelmed?', null, () => overwhelm(context, ref)),
    ];
    return stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: links,
          )
        : Wrap(spacing: 10, children: links);
  }
}

/// The quote and the quiet links, above a hairline at the foot of Today.
class _Footer extends StatelessWidget {
  const _Footer({required this.quoteContext});
  final QuoteContext quoteContext;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: Gap.s4),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.spec.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: QuoteRotator(context: quoteContext, footnote: true)),
        const SizedBox(width: Gap.s4),
        const _WrapAndOverwhelmed(stacked: true),
      ],
    ),
  );
}

/// The picked task: meta line, title, due, step dots, the step, Start and
/// 5 min, then Not this one / Smaller / Later.
class _Pick extends ConsumerWidget {
  const _Pick({
    required this.suggestion,
    required this.compact,
    this.large = false,
  });
  final Suggestion suggestion;
  final bool compact;

  /// On a computer: bigger type.
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final t = suggestion.task;
    final now = ref.read(clockProvider)();
    final time = suggestion.isChunk
        ? '${suggestion.plannedMin} of ${t.estimateMin} min'
        : formatMinutes(suggestion.plannedMin);
    final steps = t.steps;
    final current = steps.indexWhere((i) => !i.done);
    final step = t.nextStep;
    final due = t.dueAt == null
        ? null
        : 'Due ${_dueText(t.dueAt!, now)}${t.hardDeadline ? '' : ''}';
    final titleSize = large ? 56.0 : (compact ? 26.0 : 34.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            WsDot(s.workspaceColor(t.workspace == Workspace.work)),
            const SizedBox(width: Gap.s4),
            Flexible(
              child: Text(
                '${t.workspace.label} · $time',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: s.ink2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.s5),
        Text(t.title, style: s.display(titleSize)),
        if (due != null) ...[
          const SizedBox(height: Gap.s1),
          Text(
            due,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: s.accentText,
            ),
          ),
        ] else if (suggestion.reasonLine.isNotEmpty) ...[
          const SizedBox(height: Gap.s1),
          Text(suggestion.reasonLine, style: s.caption(color: s.ink2)),
        ],
        if (step.isNotEmpty) ...[
          SizedBox(height: compact ? 16 : 22),
          if (steps.length > 1)
            _StepDots(count: steps.length, current: current)
          else
            Text('First step', style: s.caption()),
          const SizedBox(height: Gap.s4),
          Text(step, style: s.step(compact ? 17 : (large ? 22 : 19))),
        ],
        SizedBox(height: compact ? 18 : 28),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Start',
                icon: Ph.starFourFill,
                height: 64,
                fontSize: 20,
                onPressed: () =>
                    openFocus(context, t.id, minutes: suggestion.plannedMin),
              ),
            ),
            const SizedBox(width: Gap.s5),
            SizedBox(
              width: 100,
              child: Tooltip(
                message: 'Just 5 minutes',
                child: OutlineButton(
                  label: '5 min',
                  height: 64,
                  onPressed: () =>
                      openFocus(context, t.id, minutes: 5, justFive: true),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? Gap.s3 : 12),
        // On a small phone Wrap up and Overwhelmed? sit in the top row
        // (_Reminders), not here too.
        _QuietActions(task: t, compact: compact),
      ],
    );
  }
}

/// "tomorrow, 3:27 pm" / "today, 5 pm" / "Oct 27".
String _dueText(DateTime d, DateTime now) {
  final day = formatDueDay(d, now);
  final hasTime = d.hour != 0 || d.minute != 0;
  if ((day == 'today' || day == 'tomorrow') && hasTime) {
    return '$day, ${formatClock(d)}';
  }
  return day;
}

/// ● ○ ○ ○ Step 2 of 4: done steps filled, this one outlined in star.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final shown = math.min(count, 8);
    return Row(
      children: [
        for (var i = 0; i < shown; i++) ...[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < current ? s.star : Colors.transparent,
              border: Border.all(
                color: i <= current ? s.star : s.ink3,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 7),
        ],
        const SizedBox(width: Gap.s1),
        Text('Step ${current + 1} of $count', style: s.caption()),
      ],
    );
  }
}

/// Not this one / Smaller / Later: an icon over a label, or side by side
/// on a small phone.
class _QuietActions extends ConsumerWidget {
  const _QuietActions({required this.task, required this.compact});
  final Task task;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final actions = [
      (
        Ph.shuffle,
        compact ? 'Not this' : 'Not this one',
        () => notThisOne(context, ref, task),
      ),
      (Ph.arrowsInLineVertical, 'Smaller', () => showSmaller(context, task)),
      (Ph.moonStars, 'Later', () => _snooze(context, ref, task)),
    ];
    return Row(
      children: [
        for (final (icon, label, onTap) in actions)
          Expanded(
            child: Semantics(
              button: true,
              label: label == 'Not this' ? 'Not this one' : label,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: compact ? 4 : 10),
                    child: Flex(
                      direction: compact ? Axis.horizontal : Axis.vertical,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: compact ? 17 : 20, color: s.ink2),
                        SizedBox(width: 5, height: Gap.s2),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: s.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Passes on [task]. After two in a row, asks you to pick one of three.
void notThisOne(BuildContext context, WidgetRef ref, Task task) {
  final ctl = ref.read(pickerInputsProvider.notifier);
  ctl.reject(task.id);
  if (ref.read(pickerInputsProvider).shouldCommit) showCommit(context, ref);
}

/// "Pick one of these three": after too many rerolls, choose and it's
/// decided. The sheet reads providers itself: the widget that opened it is
/// gone by then, replaced by the next pick.
Future<void> showCommit(BuildContext context, WidgetRef ref) {
  final choices = ref.read(commitChoicesProvider);
  return showAppSheet<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) => SafeArea(
        child: SingleChildScrollView(
          padding: sheetPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(
                'Pick one of these three',
                subtitle:
                    "Rerolling feels productive, but it's the dread talking. "
                    "Any of these is a good start.",
              ),
              const SizedBox(height: Gap.s6),
              for (final c in choices) ...[
                SheetChoice(
                  icon: Ph.starFour,
                  title: c.task.title,
                  subtitle: [
                    c.isChunk
                        ? '${c.plannedMin} of ${c.task.estimateMin} min'
                        : formatMinutes(c.plannedMin),
                    c.task.workspace.label,
                  ].join(' · '),
                  onTap: () {
                    ref.read(pickerInputsProvider.notifier).choose(c.task.id);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: Gap.s4),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// "Make it smaller": write a smaller next step, or take an idea. On a
/// task with a checklist the new step goes in before the current one.
Future<void> showSmaller(BuildContext context, Task task) => showAppSheet<void>(
  context: context,
  builder: (ctx) => _SmallerSheet(task: task),
);

class _SmallerSheet extends ConsumerStatefulWidget {
  const _SmallerSheet({required this.task});
  final Task task;

  @override
  ConsumerState<_SmallerSheet> createState() => _SmallerSheetState();
}

class _SmallerSheetState extends ConsumerState<_SmallerSheet> {
  late final _text = TextEditingController(text: widget.task.nextStep);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _use(String step) {
    final text = step.trim();
    // The task as it is now; deleted or hidden meanwhile, the sheet saves
    // nothing (saving its old copy would bring the task back).
    final t = ref
        .read(tasksProvider)
        .where((x) => x.id == widget.task.id)
        .firstOrNull;
    if (t == null || text.isEmpty || text == t.nextStep) {
      Navigator.pop(context);
      return;
    }
    final items = t.steps;
    final current = items.indexWhere((i) => !i.done);
    final Task updated;
    if (items.isEmpty) {
      updated = t.copyWith(firstStep: text);
    } else {
      final at = current < 0 ? items.length : current;
      items.insert(at, ChecklistItem(text));
      updated = t.copyWith(checklist: encodeChecklist(items));
    }
    ref.read(tasksProvider.notifier).saveEdits(t, updated);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Smaller. Much better.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final ideas = stepIdeasFor(widget.task.title).firstSteps;
    return SafeArea(
      child: SingleChildScrollView(
        padding: sheetPadding.add(
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle(
              'Make it smaller',
              subtitle: 'So small it feels a bit silly.',
            ),
            const SizedBox(height: Gap.s6),
            TextField(
              controller: _text,
              textInputAction: TextInputAction.done,
              onSubmitted: _use,
              style: TextStyle(fontSize: 17, color: s.ink),
              decoration: InputDecoration(
                hintText: 'The very first thing to do',
                fillColor: Colors.transparent,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  borderSide: BorderSide(color: s.star, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: Gap.s6),
            for (final idea in ideas) ...[
              SheetChoice(
                icon: Ph.sparkle,
                title: idea,
                caret: false,
                onTap: () => _use(idea),
              ),
              const SizedBox(height: Gap.s4),
            ],
            const SizedBox(height: Gap.s4),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/task/${widget.task.id}?focusFirstStep=1');
                  },
                  child: const Text('Edit all the steps'),
                ),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: PrimaryButton(
                    label: 'Use this',
                    height: 48,
                    fontSize: 15,
                    onPressed: () => _use(_text.text),
                  ),
                ),
              ],
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
    SnackBar(content: Text('"${t.title}" comes back in 3 hours.')),
  );
}

/// "Saturday evening" and the level, over the task on a computer.
class _DesktopHeader extends ConsumerWidget {
  const _DesktopHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    ref.watch(dayPartProvider); // "morning" turns into "afternoon"…
    final now = ref.read(clockProvider)();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final part = now.hour < 12
        ? 'morning'
        : now.hour < 17
        ? 'afternoon'
        : now.hour < 22
        ? 'evening'
        : 'night';
    return Row(
      children: [
        Text(
          '${days[now.weekday - 1]} $part',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: s.ink2,
          ),
        ),
        const SizedBox(width: Gap.s4),
        const SyncAlert(),
        const Spacer(),
        const LevelPill(),
      ],
    );
  }
}

/// The right-hand column on a computer: Right now, what's waiting, and
/// how today is going.
class _RightNowPanel extends ConsumerWidget {
  const _RightNowPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final p = ref.watch(progressProvider);
    final now = ref.read(clockProvider)();
    final xpToday = p.xpOn(now);
    final streak = streakWithGrace(p.activeDays, now);
    final stats = [
      ('${p.startedOn(now)}', 'Started today'),
      ('$xpToday', 'XP today'),
      // No streak right now: show every day that counted, never a zero
      // (no shame mechanics).
      streak > 0
          ? ('$streak', 'Day streak')
          : ('${p.activeDays.length}', 'Days active'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Right now', style: s.display(20)),
        const SizedBox(height: Gap.s7),
        const SituationControls(gap: Gap.s7),
        const SizedBox(height: Gap.s7),
        Divider(color: s.line2, height: 2, thickness: 2),
        const _Reminders(compact: false),
        const Spacer(),
        Row(
          children: [
            for (final (value, label) in stats)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: s.stat()),
                    const SizedBox(height: Gap.s2),
                    Text(label, style: s.caption(color: s.ink2)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.s7),
        const Align(
          alignment: Alignment.centerLeft,
          child: _WrapAndOverwhelmed(),
        ),
      ],
    );
  }
}

/// "Okay. Breathe.": everything else hidden; one tiny step and five
/// minutes.
Future<void> overwhelm(BuildContext context, WidgetRef ref) async {
  final tiny = ref.read(tinySuggestionProvider);
  final s = context.spec;
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Okay. Breathe.', style: s.display(30)),
              const SizedBox(height: Gap.s3),
              Text(
                tiny == null
                    ? "Nothing's on your list yet. Write down the one thing "
                          "that's bugging you most. That's the whole task."
                    : 'Everything else is hidden. Just this, for five '
                          'minutes:',
                style: TextStyle(fontSize: 16, height: 1.45, color: s.ink2),
              ),
              if (tiny != null) ...[
                const SizedBox(height: Gap.s7),
                Panel(
                  color: Colors.transparent,
                  borderColor: s.line2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tiny.task.startLine, style: s.display(22)),
                      if (tiny.task.startLine != tiny.task.title) ...[
                        const SizedBox(height: Gap.s3),
                        Text(
                          tiny.task.title,
                          style: TextStyle(fontSize: 14, color: s.ink3),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Gap.s6),
                Text(
                  "When the timer ends you can stop. That's a win.",
                  style: TextStyle(fontSize: 15, height: 1.45, color: s.ink2),
                ),
              ],
              const SizedBox(height: Gap.s8),
              Wrap(
                spacing: Gap.s5,
                runSpacing: Gap.s5,
                verticalDirection: VerticalDirection.up,
                children: [
                  SizedBox(
                    width: 120,
                    child: OutlineButton(
                      label: 'Not now',
                      quiet: true,
                      fontSize: 16,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: PrimaryButton(
                      label: tiny == null ? 'Write it down' : 'Start 5 minutes',
                      fontSize: 16,
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (tiny == null) {
                          showQuickAdd(context);
                        } else {
                          openFocus(
                            context,
                            tiny.task.id,
                            minutes: 5,
                            justFive: true,
                            panic: true,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NothingPanel extends ConsumerWidget {
  const _NothingPanel({required this.reason});
  final NoPickReason reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final ctl = ref.read(pickerInputsProvider.notifier);
    final inputs = ref.watch(pickerInputsProvider);

    Widget buttons(
      String primary,
      VoidCallback onPrimary, [
      String? secondary,
      VoidCallback? onSecondary,
    ]) => Wrap(
      spacing: Gap.s5,
      runSpacing: Gap.s5,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 150),
          child: IntrinsicWidth(
            child: PrimaryButton(
              label: primary,
              height: 60,
              fontSize: 18,
              onPressed: onPrimary,
            ),
          ),
        ),
        if (secondary != null)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150),
            child: IntrinsicWidth(
              child: OutlineButton(
                label: secondary,
                height: 60,
                onPressed: onSecondary,
              ),
            ),
          ),
      ],
    );

    final (String title, String body, List<Widget> actions) = switch (reason) {
      NoPickReason.noOpenTasks => (
        'Your sky is clear.',
        "Get what's on your mind out of your head. I'll pick the first one.",
        [
          buttons(
            'Add a task',
            () => showQuickAdd(context),
            'Brain dump',
            () => showQuickAdd(context, brainDump: true),
          ),
          const SizedBox(height: Gap.s4),
          Wrap(
            spacing: Gap.s4,
            children: [
              // New here: see it full first, or read how it works.
              const ExamplesButton(link: true),
              TextButton(
                onPressed: () => context.push('/guide'),
                child: const Text('How Gumption works'),
              ),
            ],
          ),
        ],
      ),
      NoPickReason.allNeedLeaving => (
        'Everything left needs you out of the house.',
        'Up for an errand run?',
        [buttons('I can go out', () => ctl.setWillingToLeave(true))],
      ),
      NoPickReason.allLater => (
        "Everything's parked for later.",
        "It comes back on its own when it's time. Add something, or take "
            'the break.',
        [
          buttons(
            'Quick add',
            () => showQuickAdd(context),
            "See what's coming",
            () => context.go('/tasks'),
          ),
        ],
      ),
      NoPickReason.allExcluded => (
        "You've passed on everything.",
        "That's okay. Let's look again with fresh eyes.",
        [buttons('Show me again', ctl.resetRejections)],
      ),
      NoPickReason.nothingFitsTime => (
        'Nothing fits ${formatMinutes(inputs.availableMin)}.',
        'Try a bigger window, or mark long tasks as "can do in chunks".',
        [
          if (inputs.availableMin < timeOptions.last)
            buttons(
              'A bit more time',
              () => ctl.setTime(
                timeOptions.firstWhere((m) => m > inputs.availableMin),
              ),
              '5 minutes on something',
              () => overwhelm(context, ref),
            )
          else
            buttons('5 minutes on something', () => overwhelm(context, ref)),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(bottom: Gap.s8),
          child: CustomPaint(painter: _DashedCircle(s.star)),
        ),
        Text(title, style: s.display(34)),
        const SizedBox(height: Gap.s1),
        Text(body, style: TextStyle(fontSize: 17, height: 1.45, color: s.ink2)),
        const SizedBox(height: 28),
        ...actions,
      ],
    );
  }
}

/// A small dashed ring: a star still to come.
class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = size.width / 2 - 1;
    const n = 8;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: r),
        i * 2 * math.pi / n,
        math.pi / n,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}
