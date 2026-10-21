import 'package:flutter/material.dart';

import '../settings/device_workspaces.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../capture/quick_add_sheet.dart';
import '../focus/focus_route.dart';
import '../notes/notes_controller.dart';
import '../notes/project_widgets.dart';
import 'task_actions.dart';
import 'task_board.dart';
import 'tasks_controller.dart';
import 'weekly_reset.dart';
import 'waiting_sheet.dart';

final _workspaceFilterProvider = NotifierProvider<_WorkspaceFilter, Workspace?>(
  _WorkspaceFilter.new,
);

class _WorkspaceFilter extends Notifier<Workspace?> {
  @override
  Workspace? build() {
    ref.watch(deviceWorkspacesProvider); // reset when that changes
    return null;
  }

  void set(Workspace? w) => state = w;
}

/// The project Tasks is showing, or null for all. Quick add files new tasks
/// into it.
final taskProjectFilterProvider = NotifierProvider<TaskProjectFilter, String?>(
  TaskProjectFilter.new,
);

class TaskProjectFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

enum TaskView { list, board }

const _viewKey = 'tasks.view';

/// List or board; remembered on this device.
final taskViewProvider = NotifierProvider<TaskViewController, TaskView>(
  TaskViewController.new,
);

class TaskViewController extends Notifier<TaskView> {
  @override
  TaskView build() => ref.read(keyValueStoreProvider).read(_viewKey) == 'board'
      ? TaskView.board
      : TaskView.list;

  void set(TaskView v) {
    ref.read(keyValueStoreProvider).write(_viewKey, v.name);
    state = v;
  }
}

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final device = ref.watch(deviceWorkspacesProvider);
    final filter = ref.watch(_workspaceFilterProvider);
    final view = ref.watch(taskViewProvider);
    final projects = ref
        .watch(projectsProvider)
        .where((p) => filter == null || p.workspace == filter)
        .toList();
    final projectId = ref.watch(taskProjectFilterProvider);
    final project = projects.where((p) => p.id == projectId).firstOrNull;
    final all = ref
        .watch(tasksProvider)
        .where((t) => filter == null || t.workspace == filter)
        .where((t) => project == null || t.projectId == project.id)
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
    final waitingAll = all.where((t) => t.status == TaskStatus.waiting);
    final checkBack = waitingAll.where((t) => followUpDue(t, now)).toList()
      ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));
    final waiting = waitingAll.where((t) => !followUpDue(t, now)).toList();
    final done = all.where((t) => t.status == TaskStatus.done).toList()
      ..sort(
        (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
          a.completedAt ?? a.updatedAt,
        ),
      );

    final totalMin = [...doing, ...next].fold(0, (a, t) => a + t.estimateMin);

    final stale = staleTasks(ref.watch(tasksProvider), now);
    final viewSwitch = Segmented<TaskView>(
      values: TaskView.values,
      selected: view,
      inset: s.isDark,
      labelOf: (v) => v == TaskView.list ? 'List' : 'Board',
      onSelected: ref.read(taskViewProvider.notifier).set,
    );

    return SidebarLayout(
      maxWidth: view == TaskView.board ? 1680 : 1240,
      narrowMaxWidth: view == TaskView.board ? 1400 : 640,
      sidebar: _TaskSidebar(
        filter: filter,
        projects: projects,
        selected: project,
        stale: stale.length,
      ),
      builder: (context, wide) => ListView(
        padding: EdgeInsets.fromLTRB(
          wide ? 12 : 22,
          wide ? 40 : 24,
          22,
          navClearance(context),
        ),
        children: [
          PageHeader(
            project?.name ?? 'Tasks',
            subtitle:
                '${doing.length + next.length} open · about '
                '${shortMinutes(totalMin)}',
            // Wide: the filters are in the sidebar, so the view switch and
            // the project's menu sit up here.
            trailing: wide
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?(project == null
                          ? null
                          : _ProjectMenu(project: project)),
                      const SizedBox(width: 8),
                      SizedBox(width: 200, child: viewSwitch),
                    ],
                  )
                : OutlinedButton(
                    onPressed: () => showQuickAdd(context, brainDump: true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(
                        fontFamily: Fonts.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Brain dump'),
                  ),
          ),
          const SizedBox(height: 20),
          if (!wide) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // A one-workspace device has nothing to choose between.
                for (final w in [
                  if (!device.single) ...[null, ...Workspace.values],
                ])
                  Pill(
                    label: w?.label ?? 'Everything',
                    selected: filter == w,
                    solid: true,
                    onTap: () {
                      ref.read(_workspaceFilterProvider.notifier).set(w);
                      if (w != null &&
                          project != null &&
                          project.workspace != w) {
                        ref.read(taskProjectFilterProvider.notifier).set(null);
                      }
                    },
                  ),
                if (stale.isNotEmpty)
                  Pill(
                    label: 'Weekly reset · ${stale.length}',
                    icon: Icons.cleaning_services_outlined,
                    selected: false,
                    onTap: () => context.push('/reset'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _ProjectBar(
              projects: projects,
              selected: project,
              workspace: device.single ? device.primary : filter,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 220, child: viewSwitch),
            ),
            const SizedBox(height: 22),
          ],
          if (view == TaskView.board && all.isNotEmpty)
            TaskBoard(tasks: all, showProject: project == null)
          else ...[
            if (all.isEmpty)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nothing here yet.', style: s.display(24)),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => showQuickAdd(context),
                      child: const Text('Add a task'),
                    ),
                  ],
                ),
              ),
            if (checkBack.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle('Check back', count: checkBack.length),
                    for (final t in checkBack) _CheckBackRow(task: t),
                  ],
                ),
              ),
            _Section(title: 'In progress', tasks: doing),
            _Section(title: 'Up next', tasks: next),
            _Section(title: 'Waiting on someone', tasks: waiting),
            _Section(title: 'Coming up', tasks: comingUp, quiet: true),
            if (done.isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: s.muted,
                  collapsedIconColor: s.muted,
                  title: SectionTitle('Done', count: done.length),
                  children: [for (final t in done.take(50)) _TaskTile(task: t)],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// "+ Project": asks which workspace when none is chosen, then names it
/// and opens it.
Future<void> _addProject(
  BuildContext context,
  WidgetRef ref,
  Workspace? workspace,
) async {
  final ws =
      workspace ??
      await showModalBottomSheet<Workspace>(
        useRootNavigator: true,
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('New project for…')),
              for (final w in Workspace.values)
                ListTile(
                  title: Text(w.label),
                  onTap: () => Navigator.pop(ctx, w),
                ),
            ],
          ),
        ),
      );
  if (ws == null || !context.mounted) return;
  final p = await showNewProjectDialog(context, ref, ws);
  if (p != null) ref.read(taskProjectFilterProvider.notifier).set(p.id);
}

/// Rename / delete for the project being shown.
class _ProjectMenu extends ConsumerWidget {
  const _ProjectMenu({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    useRootNavigator: true,
    tooltip: 'Project options',
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (v) async {
      if (v == 'rename') await showRenameProjectDialog(context, ref, project);
      if (v == 'delete' &&
          context.mounted &&
          await confirmDeleteProject(context, ref, project)) {
        ref.read(taskProjectFilterProvider.notifier).set(null);
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'rename', child: Text('Rename project')),
      PopupMenuItem(value: 'delete', child: Text('Delete project')),
    ],
  );
}

/// Phone: project filter pills, "+ Project", and the open one's menu.
class _ProjectBar extends ConsumerWidget {
  const _ProjectBar({
    required this.projects,
    required this.selected,
    required this.workspace,
  });
  final List<Project> projects;
  final Project? selected;
  final Workspace? workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = ref.read(taskProjectFilterProvider.notifier).set;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (projects.isNotEmpty)
          Pill(
            label: 'All projects',
            selected: selected == null,
            onTap: () => set(null),
          ),
        for (final p in projects)
          Pill(
            label: p.name,
            icon: Icons.circle,
            iconColor: context.spec.projectColor(p.color),
            selected: selected?.id == p.id,
            onTap: () => set(selected?.id == p.id ? null : p.id),
          ),
        Pill(
          label: projects.isEmpty ? 'New project' : 'Project',
          icon: Icons.add_rounded,
          selected: false,
          onTap: () => _addProject(context, ref, workspace),
        ),
        if (selected case final p?) _ProjectMenu(project: p),
      ],
    );
  }
}

/// Desktop: the same filters as a sidebar, with counts.
class _TaskSidebar extends ConsumerWidget {
  const _TaskSidebar({
    required this.filter,
    required this.projects,
    required this.selected,
    required this.stale,
  });
  final Workspace? filter;
  final List<Project> projects;
  final Project? selected;
  final int stale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final device = ref.watch(deviceWorkspacesProvider);
    final open = ref.watch(tasksProvider).where((t) => t.isOpen).toList();
    int count(bool Function(Task) f) => open.where(f).length;
    final setProject = ref.read(taskProjectFilterProvider.notifier).set;
    void setWs(Workspace? w) {
      ref.read(_workspaceFilterProvider.notifier).set(w);
      if (w != null && selected != null && selected!.workspace != w) {
        setProject(null);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!device.single)
          SideSection(
            label: 'Show',
            children: [
              SideItem(
                label: 'Everything',
                icon: Icons.all_inclusive_rounded,
                count: count((_) => true),
                selected: filter == null,
                onTap: () => setWs(null),
              ),
              for (final w in Workspace.values)
                SideItem(
                  label: w.label,
                  icon: w == Workspace.work
                      ? Icons.work_outline_rounded
                      : Icons.home_outlined,
                  count: count((t) => t.workspace == w),
                  selected: filter == w,
                  onTap: () => setWs(w),
                ),
            ],
          ),
        SideSection(
          label: 'Projects',
          children: [
            SideItem(
              label: 'All projects',
              icon: Icons.folder_open_outlined,
              count: count((t) => filter == null || t.workspace == filter),
              selected: selected == null,
              onTap: () => setProject(null),
            ),
            for (final p in projects)
              SideItem(
                label: p.name,
                dot: s.projectColor(p.color),
                count: count((t) => t.projectId == p.id),
                selected: selected?.id == p.id,
                onTap: () => setProject(selected?.id == p.id ? null : p.id),
              ),
            SideItem(
              label: 'New project',
              icon: Icons.add_rounded,
              onTap: () => _addProject(
                context,
                ref,
                device.single ? device.primary : filter,
              ),
            ),
          ],
        ),
        SideSection(
          label: 'Tidy up',
          children: [
            SideItem(
              label: 'Weekly reset',
              icon: Icons.cleaning_services_outlined,
              count: stale,
              onTap: () => context.push('/reset'),
            ),
            SideItem(
              label: 'Brain dump',
              icon: Icons.bolt_outlined,
              onTap: () => showQuickAdd(context, brainDump: true),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.tasks,
    this.quiet = false,
  });
  final String title;
  final List<Task> tasks;

  /// Not actionable yet: dimmed.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title, count: tasks.length),
          for (final (i, t) in tasks.indexed)
            Opacity(
              opacity: quiet ? 0.75 : 1,
              child: _TaskTile(task: t, last: i == tasks.length - 1),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, this.last = false});
  final Task task;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final ctl = ref.read(tasksProvider.notifier);
    final isDone = task.status == TaskStatus.done;
    final now = ref.read(clockProvider)();
    final days = now.difference(task.createdAt).inDays;
    final projectName = task.projectId.isEmpty
        ? null
        : ref.watch(
            projectsProvider.select(
              (ps) => ps.where((p) => p.id == task.projectId).firstOrNull?.name,
            ),
          );
    final extras = [
      ?projectName,
      if (task.isOpen && days >= 7) 'sitting for $days days',
    ];

    return SwipeActions(
      key: ValueKey('task-${task.id}'),
      onDelete: () => deleteWithUndo(context, ref, task),
      onDone: isDone ? null : () => markDoneWithUndo(context, ref, task),
      child: InkWell(
        onTap: () => context.push('/task/${task.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: last ? null : Border(bottom: BorderSide(color: s.hairline)),
          ),
          child: Row(
            children: [
              _DoneCircle(
                done: isDone,
                label: task.title,
                onTap: isDone
                    ? () => ctl.reopen(task.id)
                    : () => markDoneWithUndo(context, ref, task),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: isDone ? s.muted : s.onSurface,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: s.muted,
                      ),
                    ),
                    if (!isDone) ...[
                      const SizedBox(height: 4),
                      TaskMeta(
                        task: task,
                        now: now,
                        extra: extras.isEmpty ? null : extras.join(' · '),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                useRootNavigator: true,
                tooltip: 'More',
                icon: Icon(Icons.more_horiz_rounded, color: s.faint),
                onSelected: (v) {
                  switch (v) {
                    case 'start':
                      openFocus(context, task.id, minutes: task.estimateMin);
                    case 'edit':
                      context.push('/task/${task.id}');
                    case 'five':
                      openFocus(context, task.id, minutes: 5, justFive: true);
                    case 'waiting':
                      showWaitingSheet(context, task);
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
                  if (!isDone) ...[
                    const PopupMenuItem(
                      value: 'start',
                      child: Text('Start now'),
                    ),
                    const PopupMenuItem(
                      value: 'five',
                      child: Text('Just 5 minutes'),
                    ),
                    const PopupMenuItem(
                      value: 'done',
                      child: Text('Mark done'),
                    ),
                  ],
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (!isDone && task.status != TaskStatus.waiting)
                    const PopupMenuItem(
                      value: 'waiting',
                      child: Text('Waiting on someone'),
                    ),
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
          ),
        ),
      ),
    );
  }
}

/// Round tick on the left of a task row.
class _DoneCircle extends StatelessWidget {
  const _DoneCircle({
    required this.done,
    required this.label,
    required this.onTap,
  });
  final bool done;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return IconButton(
      tooltip: done ? 'Not done yet' : 'Mark done',
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? s.accent : null,
          border: done
              ? null
              : Border.all(
                  color: s.isDark ? const Color(0xFF3A4548) : s.faint,
                  width: 2,
                ),
        ),
        child: done
            ? Icon(Icons.check_rounded, size: 16, color: s.onAccent)
            : null,
      ),
    );
  }
}

/// A waiting task whose check-back date has come: one tap to resolve it.
class _CheckBackRow extends ConsumerWidget {
  const _CheckBackRow({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final ctl = ref.read(tasksProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Panel(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        onTap: () => context.push('/task/${task.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.waitingOn.isEmpty
                  ? 'Any news? Time to check back.'
                  : 'Waiting on ${task.waitingOn}. Any news?',
              style: TextStyle(fontSize: 13, color: s.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(
                  label: 'Back to my list',
                  selected: false,
                  onTap: () => ctl.reopen(task.id),
                ),
                Pill(
                  label: 'Still waiting',
                  selected: false,
                  onTap: () => showWaitingSheet(context, task),
                ),
                Pill(
                  label: 'Done',
                  selected: false,
                  onTap: () => markDoneWithUndo(context, ref, task),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
