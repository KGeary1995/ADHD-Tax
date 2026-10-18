import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/task_chips.dart';
import '../capture/quick_add_sheet.dart';
import '../focus/focus_route.dart';
import 'task_actions.dart';
import 'tasks_controller.dart';

final _workspaceFilterProvider = NotifierProvider<_WorkspaceFilter, Workspace?>(
  _WorkspaceFilter.new,
);

class _WorkspaceFilter extends Notifier<Workspace?> {
  @override
  Workspace? build() => null;
  void set(Workspace? w) => state = w;
}

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final filter = ref.watch(_workspaceFilterProvider);
    final all = ref
        .watch(tasksProvider)
        .where((t) => filter == null || t.workspace == filter)
        .toList();

    int byUrgency(Task a, Task b) {
      final p = a.priority.index.compareTo(b.priority.index);
      if (p != 0) return p;
      final ad = a.dueAt, bd = b.dueAt;
      if (ad != null && bd != null) return ad.compareTo(bd);
      if (ad != null) return -1;
      if (bd != null) return 1;
      return a.createdAt.compareTo(b.createdAt);
    }

    final doing = all.where((t) => t.status == TaskStatus.doing).toList()
      ..sort(byUrgency);
    final now = ref.read(clockProvider)();
    bool later(Task t) =>
        t.scheduledStart != null && t.scheduledStart!.isAfter(now);
    final open = all.where(
      (t) => t.status == TaskStatus.todo || t.status == TaskStatus.inbox,
    );
    final next = open.where((t) => !later(t)).toList()..sort(byUrgency);
    // Snoozed, and the next copy of repeating tasks: out of the way until
    // their day.
    final comingUp = open.where(later).toList()
      ..sort((a, b) => a.scheduledStart!.compareTo(b.scheduledStart!));
    final waiting = all.where((t) => t.status == TaskStatus.waiting).toList();
    final done = all.where((t) => t.status == TaskStatus.done).toList()
      ..sort(
        (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
          a.completedAt ?? a.updatedAt,
        ),
      );

    final totalMin = [...doing, ...next].fold(0, (a, t) => a + t.estimateMin);

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All tasks',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: s.onSurface,
                      ),
                    ),
                    Text(
                      '${doing.length + next.length} open · about ${formatMinutes(totalMin)} of work',
                      style: TextStyle(color: s.muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => showQuickAdd(context, brainDump: true),
                icon: const Icon(Icons.psychology_alt_outlined),
                label: const Text('Brain dump'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Everything'),
                selected: filter == null,
                onSelected: (_) =>
                    ref.read(_workspaceFilterProvider.notifier).set(null),
              ),
              for (final w in Workspace.values)
                ChoiceChip(
                  label: Text(w.label),
                  selected: filter == w,
                  onSelected: (_) =>
                      ref.read(_workspaceFilterProvider.notifier).set(w),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (all.isEmpty)
            Panel(
              child: Column(
                children: [
                  Text(
                    'Nothing here yet.',
                    style: TextStyle(fontSize: 18, color: s.onSurface),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => showQuickAdd(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add a task'),
                  ),
                ],
              ),
            ),
          _Section(title: 'In progress', tasks: doing),
          _Section(title: 'Up next', tasks: next),
          _Section(title: 'Waiting on someone', tasks: waiting),
          _Section(title: 'Coming up', tasks: comingUp),
          if (done.isNotEmpty)
            Panel(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                title: Text(
                  'Done (${done.length})',
                  style: TextStyle(
                    color: s.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  for (final t in done.take(50))
                    _TaskTile(task: t, inPanel: false),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tasks});
  final String title;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('$title · ${tasks.length}'),
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TaskTile(task: t),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, this.inPanel = true});
  final Task task;
  final bool inPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final ctl = ref.read(tasksProvider.notifier);
    final isDone = task.status == TaskStatus.done;

    final body = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDone ? s.muted : s.onSurface,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              if (task.firstStep.isNotEmpty && !isDone) ...[
                const SizedBox(height: 2),
                Text(
                  '→ ${task.firstStep}',
                  style: TextStyle(color: s.muted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              TaskChips(task: task),
            ],
          ),
        ),
        if (!isDone)
          IconButton(
            tooltip: 'Start',
            onPressed: () =>
                openFocus(context, task.id, minutes: task.estimateMin),
            icon: Icon(Icons.play_circle_outline, color: s.primary, size: 30),
          ),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (v) {
            switch (v) {
              case 'edit':
                context.push('/task/${task.id}');
              case 'five':
                openFocus(context, task.id, minutes: 5, justFive: true);
              case 'waiting':
                ctl.setStatus(task.id, TaskStatus.waiting);
              case 'todo':
                ctl.reopen(task.id);
              case 'done':
                markDoneWithUndo(context, ref, task);
              case 'archive':
                archiveWithUndo(context, ref, task);
              case 'delete':
                deleteWithUndo(context, ref, task);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (!isDone) ...[
              const PopupMenuItem(value: 'done', child: Text('Mark done')),
              const PopupMenuItem(value: 'five', child: Text('Just 5 minutes')),
              if (task.status != TaskStatus.waiting)
                const PopupMenuItem(
                  value: 'waiting',
                  child: Text('Waiting on someone'),
                ),
            ],
            if (isDone || task.status == TaskStatus.waiting)
              const PopupMenuItem(
                value: 'todo',
                child: Text('Move back to to-do'),
              ),
            const PopupMenuItem(value: 'archive', child: Text('Archive')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    );

    if (!inPanel) {
      return ListTile(
        onTap: () => context.push('/task/${task.id}'),
        title: body,
      );
    }
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      onTap: () => context.push('/task/${task.id}'),
      child: body,
    );
  }
}
