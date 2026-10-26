import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../capture/quick_add_sheet.dart';
import '../gamification/progress_controller.dart';
import '../picker/picker_controller.dart';
import '../picker/picker_engine.dart';
import '../settings/settings_controller.dart';
import '../tasks/task_actions.dart';
import '../tasks/tasks_controller.dart';
import '../../core/theme/ph.dart';

bool _sameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

/// Three minutes at the end of the day: what got done, what's still open,
/// and tomorrow's first thing, so the morning starts with the decision
/// already made.
class WrapUpScreen extends ConsumerStatefulWidget {
  const WrapUpScreen({super.key});

  @override
  ConsumerState<WrapUpScreen> createState() => _WrapUpScreenState();
}

class _WrapUpScreenState extends ConsumerState<WrapUpScreen> {
  String? _pick;
  final _firstStep = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    final now = ref.read(clockProvider)();
    // Reopened later the same evening: keep what was chosen.
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _pick = s.pinnedFor(tomorrow);
  }

  @override
  void dispose() {
    _firstStep.dispose();
    super.dispose();
  }

  void _choose(Task t) => setState(() {
    _pick = _pick == t.id ? null : t.id;
    _firstStep.text = '';
  });

  void _finish() {
    final now = ref.read(clockProvider)();
    final tasks = ref.read(tasksProvider.notifier);
    final chosen = _pick == null ? null : tasks.byId(_pick!);
    final step = _firstStep.text.trim();
    if (chosen != null && step.isNotEmpty && chosen.nextStep.isEmpty) {
      tasks.save(chosen.copyWith(firstStep: step));
    }
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.pinForTomorrow(chosen?.id, now));
    final messenger = ScaffoldMessenger.of(context);
    context.canPop() ? context.pop() : context.go('/');
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          chosen == null
              ? 'Done for today. Rest up.'
              : 'Done for today. Tomorrow starts with "${chosen.title}".',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final now = ref.read(clockProvider)();
    final all = ref.watch(tasksProvider);
    final progress = ref.watch(progressProvider);
    final done = all
        .where(
          (t) => t.status == TaskStatus.done && _sameDay(t.completedAt, now),
        )
        .toList();
    final started = all.where((t) => _sameDay(t.startedAt, now)).length;
    final xpToday = progress.xpOn(now);
    final inProgress = all.where((t) => t.status == TaskStatus.doing).toList();

    // Tomorrow morning, with plenty of time and no place restrictions:
    // the best few candidates to start the day with.
    final morning = DateTime(now.year, now.month, now.day + 1, 9);
    final candidates = pickerEngine
        .rank(
          all,
          PickerContext(
            availableMin: 120,
            willingToLeave: true,
            now: morning,
            calibration: ref.watch(calibrationProvider),
          ),
        )
        .take(4)
        .map((x) => x.task)
        .toList();
    final pinned = _pick == null
        ? null
        : all.where((t) => t.id == _pick && t.isOpen).firstOrNull;
    if (pinned != null && !candidates.contains(pinned)) {
      candidates.insert(0, pinned);
    }

    Widget inProgressItem(Task t) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: s.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                label: 'Done',
                selected: false,
                onTap: () => markDoneWithUndo(context, ref, t),
              ),
              Pill(
                label: 'Keep for tomorrow',
                selected: _pick == t.id,
                onTap: () => _choose(t),
              ),
              Pill(
                label: 'Back to the list',
                selected: false,
                onTap: () => ref
                    .read(tasksProvider.notifier)
                    .setStatus(t.id, TaskStatus.todo),
              ),
            ],
          ),
        ],
      ),
    );

    const gap = SizedBox(height: 28);
    const words = [
      'No',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
    ];
    String count(int n) => n < words.length ? words[n] : '$n';
    // Tonight in stars: one for each start.
    final headline = started > 0
        ? '${count(started)} ${started == 1 ? 'star' : 'stars'} tonight.'
        : done.isNotEmpty
        ? '${count(done.length)} done today.'
        : 'A quiet day.';
    final line = started > 0
        ? 'You started $started ${started == 1 ? 'thing' : 'things'} and '
              'finished ${done.length}. That counts.'
        : done.isNotEmpty
        ? '$xpToday XP. That counts.'
        : 'That counts too.';
    final today = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, size) in [14.0, 10.0, 12.0].indexed)
            if (i < math.max(1, math.min(3, started)))
              Padding(
                padding: EdgeInsets.only(right: 6, top: i == 1 ? 6 : 0),
                child: StarMark(size: size),
              ),
        ],
      ),
      const SizedBox(height: Gap.s5),
      Text(headline, style: s.display(32)),
      const SizedBox(height: Gap.s1),
      Text(line, style: TextStyle(fontSize: 16, color: s.ink2, height: 1.4)),
      if (inProgress.isNotEmpty) ...[
        gap,
        SectionTitle('Still in progress', count: inProgress.length),
        for (final t in inProgress) inProgressItem(t),
      ],
    ];
    final tomorrow = <Widget>[
      Text("Tomorrow's first thing", style: s.display(17)),
      const SizedBox(height: Gap.s1),
      Text(
        'Decide now and the morning starts already decided. It shows '
        'first on Today.',
        style: TextStyle(fontSize: 14, color: s.ink2, height: 1.4),
      ),
      const SizedBox(height: Gap.s6),
      if (candidates.isEmpty)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nothing on your list yet.',
                style: TextStyle(color: s.text2),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => showQuickAdd(context),
                child: const Text('Add something for tomorrow'),
              ),
            ],
          ),
        ),
      for (final t in candidates)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _Candidate(
            task: t,
            selected: _pick == t.id,
            onTap: () => _choose(t),
          ),
        ),
      if (pinned != null && pinned.nextStep.isEmpty) ...[
        const SizedBox(height: 16),
        const FieldLabel('First 2-minute step (optional)'),
        TextField(
          controller: _firstStep,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. "Open the doc and read the first line"',
          ),
        ),
      ],
      const SizedBox(height: Gap.s8),
      PrimaryButton(label: 'Done for today', height: 60, onPressed: _finish),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    // On a computer: today as a summary strip, tomorrow's pick as the
    // main thing, its candidates side by side.
    List<Widget> wideBody() => [
      Panel(
        radius: 22,
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: today.take(3).toList(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in done.take(10))
                    _DoneChip(t.title, check: true),
                  if (done.length > 10) _DoneChip('+${done.length - 10} more'),
                ],
              ),
            ),
          ],
        ),
      ),
      if (inProgress.isNotEmpty) ...[
        gap,
        SectionTitle('Still in progress', count: inProgress.length),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 32,
            children: [
              for (final t in inProgress)
                SizedBox(
                  width: (c.maxWidth - 32) / 2,
                  child: inProgressItem(t),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 36),
      const SectionTitle("Tomorrow's first thing"),
      const SizedBox(height: 4),
      Text(
        'Choose it now, and tomorrow starts with the decision already '
        'made. It shows first on Home in the morning.',
        style: TextStyle(fontSize: 14, color: s.muted, height: 1.4),
      ),
      const SizedBox(height: 12),
      if (candidates.isEmpty)
        tomorrow.firstWhere((w) => w is Panel)
      else
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final t in candidates)
                SizedBox(
                  width: (c.maxWidth - 12) / 2,
                  child: _Candidate(
                    task: t,
                    selected: _pick == t.id,
                    onTap: () => _choose(t),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: pinned != null && pinned.nextStep.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('First 2-minute step (optional)'),
                      TextField(
                        controller: _firstStep,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. "Open the doc and read the first line"',
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 300,
            child: PrimaryButton(
              label: 'Done for today',
              height: 60,
              onPressed: _finish,
            ),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Ph.x),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                MaterialLocalizations.of(context).formatMediumDate(now),
                style: s.caption(),
              ),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: wide ? 1120 : 560,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            22,
            4,
            22,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            if (wide) ...wideBody() else ...[...today, gap, ...tomorrow],
          ],
        ),
      ),
    );
  }
}

class _Candidate extends StatelessWidget {
  const _Candidate({
    required this.task,
    required this.selected,
    required this.onTap,
  });
  final Task task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Semantics(
      selected: selected,
      button: true,
      child: Panel(
        color: selected ? s.starSoft : Colors.transparent,
        borderColor: selected ? s.star : s.line2,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: s.body(weight: FontWeight.w700)),
                  const SizedBox(height: Gap.s1),
                  TaskMeta(task: task, compact: true),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? s.star : Colors.transparent,
                border: Border.all(color: selected ? s.star : s.ink3, width: 2),
              ),
              child: selected
                  ? Icon(Ph.checkBold, size: 13, color: s.onStar)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A finished task's name in the Today strip: a label, not a button.
class _DoneChip extends StatelessWidget {
  const _DoneChip(this.text, {this.check = false});
  final String text;
  final bool check;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: s.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (check) ...[
            Icon(Ph.checkBold, size: 16, color: s.primary),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: s.text2),
            ),
          ),
        ],
      ),
    );
  }
}
