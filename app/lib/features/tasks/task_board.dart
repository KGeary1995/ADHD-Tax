import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../focus/focus_route.dart';
import '../notes/notes_controller.dart';
import '../notes/project_widgets.dart';
import 'task_actions.dart';
import 'tasks_controller.dart';
import 'waiting_sheet.dart';

/// A board column. Inbox counts as To do; archived tasks aren't shown.
enum BoardColumn {
  todo('To do'),
  doing('Doing'),
  waiting('Waiting'),
  done('Done');

  const BoardColumn(this.label);
  final String label;

  static BoardColumn? of(Task t) => switch (t.status) {
    TaskStatus.inbox || TaskStatus.todo => todo,
    TaskStatus.doing => doing,
    TaskStatus.waiting => waiting,
    TaskStatus.done => done,
    TaskStatus.archived => null,
  };
}

/// Moves a task to a column the way the rest of the app would: Done
/// earns XP (with Undo), Waiting asks who it's waiting on.
void moveTask(BuildContext context, WidgetRef ref, Task t, BoardColumn to) {
  if (BoardColumn.of(t) == to) return;
  final tasks = ref.read(tasksProvider.notifier);
  switch (to) {
    case BoardColumn.todo:
      tasks.reopen(t.id);
    case BoardColumn.doing:
      if (t.status == TaskStatus.done) tasks.reopen(t.id);
      tasks.markStarted(t.id);
    case BoardColumn.waiting:
      showWaitingSheet(context, t);
    case BoardColumn.done:
      markDoneWithUndo(context, ref, t);
  }
}

/// Kanban view of [tasks]: drag a card (long-press on a phone) to another
/// column, or use its menu. On a phone the columns scroll sideways.
class TaskBoard extends ConsumerWidget {
  const TaskBoard({super.key, required this.tasks, this.showProject = true});
  final List<Task> tasks;
  final bool showProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider)();
    final byColumn = {for (final c in BoardColumn.values) c: <Task>[]};
    for (final t in tasks) {
      final c = BoardColumn.of(t);
      if (c == null) continue;
      // Done stays short: the last two weeks.
      if (c == BoardColumn.done &&
          now.difference(t.completedAt ?? t.updatedAt).inDays > 14) {
        continue;
      }
      byColumn[c]!.add(t);
    }
    byColumn[BoardColumn.done]!.sort(
      (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
        a.completedAt ?? a.updatedAt,
      ),
    );
    for (final c in [
      BoardColumn.todo,
      BoardColumn.doing,
      BoardColumn.waiting,
    ]) {
      byColumn[c]!.sort((a, b) {
        final p = a.priority.index.compareTo(b.priority.index);
        return p != 0 ? p : a.createdAt.compareTo(b.createdAt);
      });
    }

    return LayoutBuilder(
      builder: (context, box) {
        const gap = 12.0;
        // A phone can't show four columns: one at a time, under tabs.
        if (box.maxWidth < 4 * 220 + 3 * gap) {
          return _TabbedBoard(byColumn: byColumn, showProject: showProject);
        }
        final width = (box.maxWidth - 3 * gap) / 4;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, c) in BoardColumn.values.indexed) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: width,
                child: _Column(
                  column: c,
                  tasks: byColumn[c]!,
                  showProject: showProject,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The board on a phone: column tabs with counts, one column at full
/// width. Tap a tab or swipe sideways to switch; drop a held card on a tab
/// to move it there.
class _TabbedBoard extends ConsumerStatefulWidget {
  const _TabbedBoard({required this.byColumn, required this.showProject});
  final Map<BoardColumn, List<Task>> byColumn;
  final bool showProject;

  @override
  ConsumerState<_TabbedBoard> createState() => _TabbedBoardState();
}

class _TabbedBoardState extends ConsumerState<_TabbedBoard> {
  var _shown = BoardColumn.todo;

  void _step(int by) {
    final i = (_shown.index + by).clamp(0, BoardColumn.values.length - 1);
    setState(() => _shown = BoardColumn.values[i]);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final tasks = widget.byColumn[_shown]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One row, evenly split, so all four always fit.
        Row(
          children: [
            for (final (i, c) in BoardColumn.values.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _ColumnTab(
                  column: c,
                  count: widget.byColumn[c]!.length,
                  selected: c == _shown,
                  onTap: () => setState(() => _shown = c),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Hold a card and drop it on a tab to move it.',
          style: TextStyle(fontSize: 12, color: s.faint),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 250) _step(v < 0 ? 1 : -1);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'Nothing in ${_shown.label}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: s.muted),
                  ),
                ),
              for (final t in tasks)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _DraggableCard(
                    task: t,
                    showProject: widget.showProject,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A column tab that also takes dropped cards.
class _ColumnTab extends ConsumerWidget {
  const _ColumnTab({
    required this.column,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final BoardColumn column;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => BoardColumn.of(d.data) != column,
      onAcceptWithDetails: (d) => moveTask(context, ref, d.data, column),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final on = selected || hovering;
        final fg = on ? s.background : s.text2;
        return Semantics(
          selected: selected,
          button: true,
          label: '${column.label}, $count',
          excludeSemantics: true,
          child: Material(
            color: hovering ? s.primary : (selected ? s.onSurface : null),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: on ? BorderSide.none : BorderSide(color: s.outline),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        column.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$count', style: s.mono(13, color: fg)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Column extends ConsumerWidget {
  const _Column({
    required this.column,
    required this.tasks,
    required this.showProject,
  });
  final BoardColumn column;
  final List<Task> tasks;
  final bool showProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => BoardColumn.of(d.data) != column,
      onAcceptWithDetails: (d) => moveTask(context, ref, d.data, column),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Semantics(
          label: '${column.label} column, ${tasks.length} tasks',
          container: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            decoration: BoxDecoration(
              color: hovering ? s.selected : s.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hovering ? s.primary : s.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: s.onSurface,
                          ),
                        ),
                      ),
                      Text('${tasks.length}', style: s.mono(13)),
                    ],
                  ),
                ),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      hovering ? 'Drop here' : 'Nothing here',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: s.faint),
                    ),
                  ),
                for (final t in tasks)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _DraggableCard(task: t, showProject: showProject),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({required this.task, required this.showProject});
  final Task task;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final card = _Card(task: task, showProject: showProject);
    return LayoutBuilder(
      builder: (context, box) => LongPressDraggable<Task>(
        data: task,
        // A short hold, so it doesn't fight with scrolling.
        delay: const Duration(milliseconds: 250),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: box.maxWidth,
            child: Opacity(opacity: 0.92, child: card),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.task, required this.showProject});
  final Task task;
  final bool showProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final now = ref.read(clockProvider)();
    final here = BoardColumn.of(task);
    final isDone = here == BoardColumn.done;
    final Project? project = showProject && task.projectId.isNotEmpty
        ? ref.watch(
            projectsProvider.select(
              (ps) => ps.where((p) => p.id == task.projectId).firstOrNull,
            ),
          )
        : null;
    return Material(
      color: s.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: s.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/task/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: isDone ? s.muted : s.onSurface,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: s.muted,
                      ),
                    ),
                    if (!isDone) ...[
                      const SizedBox(height: 4),
                      TaskMeta(task: task, now: now),
                    ],
                    if (project != null) ...[
                      const SizedBox(height: 6),
                      ProjectLabel(project),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Move or start',
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert_rounded, size: 20, color: s.faint),
                onSelected: (v) {
                  if (v == 'start') {
                    openFocus(context, task.id, minutes: task.estimateMin);
                  } else {
                    moveTask(context, ref, task, BoardColumn.values.byName(v));
                  }
                },
                itemBuilder: (_) => [
                  if (!isDone)
                    const PopupMenuItem(
                      value: 'start',
                      child: Text('Start now'),
                    ),
                  for (final c in BoardColumn.values)
                    if (c != here)
                      PopupMenuItem(
                        value: c.name,
                        child: Text('Move to ${c.label}'),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
