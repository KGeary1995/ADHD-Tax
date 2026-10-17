import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../sync/sync_badge.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/task_chips.dart';
import '../capture/quick_add_sheet.dart';
import '../focus/focus_route.dart';
import '../gamification/level_badge.dart';
import '../gamification/progress_controller.dart';
import '../motivation/quote_rotator.dart';
import '../motivation/quote_service.dart';
import '../tasks/tasks_controller.dart';
import 'picker_controller.dart';
import 'picker_engine.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final now = ref.read(clockProvider)();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final header = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(color: s.muted, fontWeight: FontWeight.w500),
              ),
              Text(
                "Let's pick one thing.",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: s.onSurface,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _overwhelm(context, ref),
          icon: const Icon(Icons.self_improvement),
          label: const Text('Overwhelmed?'),
        ),
        // Phones have no side rail to show sync status in.
        if (MediaQuery.sizeOf(context).width < 760) const SyncBadge(),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 920;
        // On phones the pick comes first; the situation collapses under it.
        final main = wide
            ? const [_SituationPanel(), SizedBox(height: 16), _SuggestionArea()]
            : const [
                _SuggestionArea(),
                SizedBox(height: 16),
                _SituationPanel(collapsible: true),
              ];
        final side = [
          const Panel(child: LevelBadge()),
          const SizedBox(height: 16),
          const Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel('Fuel'),
                QuoteRotator(context: QuoteContext.dashboard),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _TodayPanel(),
        ];
        return ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
            children: [
              header,
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: main,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: side,
                      ),
                    ),
                  ],
                )
              else ...[
                ...main,
                const SizedBox(height: 16),
                ...side,
              ],
            ],
          ),
        );
      },
    );
  }
}

Future<void> _overwhelm(BuildContext context, WidgetRef ref) async {
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
                  const Text(
                    "Nothing's on your list yet. Write down the one thing "
                    "that's bugging you most — that's the whole task.",
                  ),
                ]
              : [
                  const Text(
                    'Everything else is hidden. Just this, for 5 minutes:',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tiny.task.startLine,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
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
          FilledButton.icon(
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
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start 5 minutes'),
          ),
      ],
    ),
  );
}

class _SituationPanel extends ConsumerWidget {
  const _SituationPanel({this.collapsible = false});

  /// Phone layout: a one-line summary that expands into the controls.
  final bool collapsible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputs = ref.watch(pickerInputsProvider);
    final ctl = ref.read(pickerInputsProvider.notifier);
    final s = context.spec;

    Widget row(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionLabel(label), child],
      ),
    );

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(
          'How much time do you have?',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in timeOptions)
                ChoiceChip(
                  label: Text(m >= 120 ? '2h+' : formatMinutes(m)),
                  selected: inputs.availableMin == m,
                  onSelected: (_) => ctl.setTime(m),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 24,
          runSpacing: 4,
          children: [
            row(
              'Leave the house?',
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.home_outlined),
                    label: Text('Stay in'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.directions_car_outlined),
                    label: Text('Can go out'),
                  ),
                ],
                selected: {inputs.willingToLeave},
                onSelectionChanged: (v) => ctl.setWillingToLeave(v.first),
              ),
            ),
            row(
              'Energy right now',
              SegmentedButton<Energy>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: [
                  for (final e in Energy.values)
                    ButtonSegment(value: e, label: Text(e.label)),
                ],
                selected: {if (inputs.energy != null) inputs.energy!},
                onSelectionChanged: (v) =>
                    ctl.setEnergy(v.isEmpty ? null : v.first),
              ),
            ),
            row(
              'Workspace',
              SegmentedButton<Workspace>(
                multiSelectionEnabled: true,
                showSelectedIcon: false,
                segments: [
                  for (final w in Workspace.values)
                    ButtonSegment(value: w, label: Text(w.label)),
                ],
                selected: inputs.workspaces,
                onSelectionChanged: (v) {
                  if (v.isNotEmpty) ctl.setWorkspaces(v);
                },
              ),
            ),
          ],
        ),
      ],
    );

    if (!collapsible) return Panel(child: controls);

    final summary = [
      inputs.availableMin >= 120 ? '2h+' : formatMinutes(inputs.availableMin),
      inputs.willingToLeave ? 'can go out' : 'staying in',
      if (inputs.energy != null) '${inputs.energy!.label.toLowerCase()} energy',
      if (inputs.workspaces.length == 1) inputs.workspaces.first.label,
    ].join(' · ');
    return Panel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(Icons.tune, color: s.primary),
        title: Text(
          'Your situation',
          style: TextStyle(color: s.onSurface, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(summary, style: TextStyle(color: s.muted)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [controls],
      ),
    );
  }
}

class _SuggestionArea extends ConsumerWidget {
  const _SuggestionArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputs = ref.watch(pickerInputsProvider);
    if (inputs.shouldCommit) {
      final choices = ref.watch(commitChoicesProvider);
      if (choices.isNotEmpty) return _CommitPanel(choices: choices);
    }
    final result = ref.watch(pickResultProvider);
    final suggestion = result.suggestion;
    if (suggestion != null) return _SuggestionCard(suggestion: suggestion);
    return _NothingPanel(reason: result.noPickReason!);
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.suggestion});
  final Suggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final t = suggestion.task;
    final hasFirstStep = t.firstStep.trim().isNotEmpty;

    return Panel(
      highlight: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Your next task'),
          AnimatedSwitcher(
            duration: Duration(milliseconds: s.reduceMotion ? 0 : 300),
            child: Text(
              t.title,
              key: ValueKey(t.id),
              style: TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: s.onSurface,
                shadows: s.glow
                    ? [
                        Shadow(
                          color: s.primary.withValues(alpha: 0.6),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          if (hasFirstStep) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 18,
                  color: s.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'First step: ${t.firstStep}',
                    style: TextStyle(fontSize: 16, color: s.onSurface),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: s.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  suggestion.reasonLine,
                  style: TextStyle(color: s.muted, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TaskChips(task: t, plannedMin: suggestion.plannedMin),
          if (t.ugh >= 2) ...[
            const SizedBox(height: 16),
            const QuoteRotator(context: QuoteContext.dreadTask),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    openFocus(context, t.id, minutes: suggestion.plannedMin),
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: const Text(
                  'Start',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    openFocus(context, t.id, minutes: 5, justFive: true),
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Just 5 minutes'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () =>
                    ref.read(pickerInputsProvider.notifier).reject(t.id),
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('Not this one'),
              ),
              TextButton.icon(
                onPressed: () => context.push('/task/${t.id}?focusFirstStep=1'),
                icon: const Icon(Icons.content_cut, size: 18),
                label: const Text('Make it smaller'),
              ),
              TextButton.icon(
                onPressed: () => _snooze(context, ref, t),
                icon: const Icon(Icons.snooze, size: 18),
                label: const Text('Later today'),
              ),
            ],
          ),
        ],
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

class _CommitPanel extends ConsumerWidget {
  const _CommitPanel({required this.choices});
  final List<Suggestion> choices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    return Panel(
      highlight: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Decision time'),
          Text(
            'Pick one of these and commit.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: s.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Rerolling feels productive, but it's the dread talking. "
            "Any of these is a good choice.",
            style: TextStyle(color: s.muted),
          ),
          const SizedBox(height: 16),
          const QuoteRotator(context: QuoteContext.afterSkip),
          const SizedBox(height: 16),
          for (final c in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.all(16),
                onTap: () {
                  ref.read(pickerInputsProvider.notifier).resetRejections();
                  openFocus(context, c.task.id, minutes: c.plannedMin);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.task.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: s.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TaskChips(task: c.task, plannedMin: c.plannedMin),
                        ],
                      ),
                    ),
                    Icon(Icons.play_circle_fill, color: s.primary, size: 36),
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
        'Dump everything in your head, then let the app choose.',
        [
          FilledButton.icon(
            onPressed: () => showQuickAdd(context),
            icon: const Icon(Icons.add),
            label: const Text('Add a task'),
          ),
          OutlinedButton.icon(
            onPressed: () => showQuickAdd(context, brainDump: true),
            icon: const Icon(Icons.psychology_alt_outlined),
            label: const Text('Brain dump'),
          ),
        ],
      ),
      NoPickReason.allNeedLeaving => (
        'Everything left needs you out of the house.',
        'Up for an errand run?',
        [
          FilledButton.icon(
            onPressed: () => ctl.setWillingToLeave(true),
            icon: const Icon(Icons.directions_car_outlined),
            label: const Text('I can go out'),
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
            onPressed: () => _overwhelm(context, ref),
            child: const Text('Just 5 minutes on something'),
          ),
        ],
      ),
    };

    return Panel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: s.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: s.muted)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

class _TodayPanel extends ConsumerWidget {
  const _TodayPanel();

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
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Today'),
          Row(
            children: [
              _Metric(
                value: '$done',
                label: done == 1 ? 'task done' : 'tasks done',
              ),
              _Metric(value: '$xpToday', label: 'XP earned'),
            ],
          ),
          if (done == 0) ...[
            const SizedBox(height: 10),
            Text(
              'One start is all today needs.',
              style: TextStyle(color: s.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: s.primary,
            ),
          ),
          Text(label, style: TextStyle(color: s.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
