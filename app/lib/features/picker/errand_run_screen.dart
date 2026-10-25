import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../tasks/task_actions.dart';
import '../tasks/tasks_controller.dart';
import 'errand_run.dart';
import 'picker_controller.dart';

/// The best errand run for the time and workspaces set on Home. Home only
/// suggests it when "Can go out" is on; the screen shows it either way.
final errandRunProvider = Provider<ErrandRun?>((ref) {
  final inputs = ref.watch(pickerInputsProvider);
  return planErrandRun(
    ref.watch(tasksProvider),
    availableMin: inputs.availableMin,
    workspaces: inputs.workspaces,
    now: ref.read(clockProvider)(),
  );
});

/// One trip, all the errands: grouped by place, ticked off as you go.
class ErrandRunScreen extends ConsumerStatefulWidget {
  const ErrandRunScreen({super.key});

  @override
  ConsumerState<ErrandRunScreen> createState() => _ErrandRunScreenState();
}

class _ErrandRunScreenState extends ConsumerState<ErrandRunScreen> {
  // Fixed when the screen opens, so finishing one doesn't pull in others.
  late final ErrandRun? _run = ref.read(errandRunProvider);

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final run = _run;
    final current = {for (final t in ref.watch(tasksProvider)) t.id: t};
    final narrow = MediaQuery.sizeOf(context).width < 420;

    if (run == null) {
      return Scaffold(
        appBar: topBar(context, close: true, overline: 'ERRAND RUN'),
        body: const Center(child: Text('No errands to batch right now.')),
      );
    }
    final left = run.tasks.where((t) => current[t.id]?.isOpen ?? false);
    final allDone = left.isEmpty;

    return Scaffold(
      appBar: topBar(context, close: true, overline: 'ERRAND RUN'),
      body: ContentWidth(
        maxWidth: 560,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 22,
            8,
            narrow ? 16 : 22,
            40,
          ),
          children: [
            Text(run.summary, style: s.display(28)),
            const SizedBox(height: 6),
            Text(
              '${run.tasks.length} errands · ${run.stops.length} '
              '${run.stops.length == 1 ? 'stop' : 'stops'} · about '
              '${shortMinutes(run.minutes)} with travel',
              style: s.mono(13),
            ),
            const SizedBox(height: 18),
            for (final (i, stop) in run.stops.indexed) ...[
              FieldLabel(
                '${i + 1}. ${stop.place.isEmpty ? 'Anywhere on the way' : stop.place}',
              ),
              Panel(
                radius: 18,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final t in stop.tasks)
                      _ErrandRow(task: current[t.id] ?? t),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (allDone)
              Panel(
                color: s.accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'All done. Head home.',
                      style: s.display(24, color: s.onAccent),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: s.ink,
                        foregroundColor: s.onInk,
                      ),
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Tick each one off as you go. Each earns XP, and three in '
                'a day unlocks Errand Runner.',
                style: TextStyle(color: s.muted, fontSize: 13, height: 1.4),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrandRow extends ConsumerWidget {
  const _ErrandRow({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final done = !task.isOpen;
    return InkWell(
      onTap: done ? null : () => markDoneWithUndo(context, ref, task),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
        child: Row(
          children: [
            Checkbox(
              value: done,
              onChanged: done
                  ? null
                  : (_) => markDoneWithUndo(context, ref, task),
            ),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  color: done ? s.muted : s.onSurface,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(shortMinutes(task.estimateMin), style: s.mono(12)),
          ],
        ),
      ),
    );
  }
}
