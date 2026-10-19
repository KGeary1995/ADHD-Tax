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
    final xpToday = progress.recent
        .where((r) => _sameDay(r.at, now))
        .fold(0, (a, r) => a + r.amount);
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

    const gap = SizedBox(height: 28);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                MaterialLocalizations.of(context).formatMediumDate(now),
                style: s.mono(13),
              ),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 560,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            22,
            4,
            22,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Text('Wrap up the day', style: s.display(36)),
            gap,
            const SectionTitle('Today'),
            const SizedBox(height: 6),
            Text(
              done.isEmpty
                  ? started > 0
                        ? 'You started $started. Starting counts.'
                        : 'A quiet day. That counts too.'
                  : '${done.length} done · $xpToday XP',
              style: s.display(26, weight: FontWeight.w600),
            ),
            for (final t in done.take(6))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, size: 18, color: s.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.title,
                        style: TextStyle(fontSize: 15, color: s.text2),
                      ),
                    ),
                  ],
                ),
              ),
            if (done.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 28),
                child: Text(
                  '+${done.length - 6} more',
                  style: TextStyle(color: s.muted),
                ),
              ),
            if (inProgress.isNotEmpty) ...[
              gap,
              SectionTitle('Still in progress', count: inProgress.length),
              for (final t in inProgress)
                Container(
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
                ),
            ],
            gap,
            const SectionTitle("Tomorrow's first thing"),
            const SizedBox(height: 4),
            Text(
              'Choose it now, and tomorrow starts with the decision already '
              'made. It shows first on Home in the morning.',
              style: TextStyle(fontSize: 14, color: s.muted, height: 1.4),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _finish,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              child: const Text('Done for today'),
            ),
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
        radius: 18,
        color: selected ? s.accent : null,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: selected ? s.onAccent : s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (selected)
                    Text(
                      taskFacts(task).join(' · '),
                      style: TextStyle(fontSize: 13, color: s.onAccentMuted),
                    )
                  else
                    TaskMeta(task: task),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? s.onAccent : s.faint,
            ),
          ],
        ),
      ),
    );
  }
}
