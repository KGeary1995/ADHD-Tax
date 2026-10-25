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
import 'task_detail_pane.dart';
import 'tasks_controller.dart';
import 'waiting_sheet.dart';
import '../../core/theme/ph.dart';

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

    final viewSwitch = Segmented<TaskView>(
      values: TaskView.values,
      selected: view,
      inset: s.isDark,
      labelOf: (v) => v == TaskView.list ? 'List' : 'Board',
      onSelected: ref.read(taskViewProvider.notifier).set,
    );

    final filterLabel = [
      if (!device.single) filter?.label ?? 'Everything',
      ?project?.name,
      if (view == TaskView.board) 'Board',
    ].join(' · ');

    // Mac and iPad, list view: the selected task shows in a pane beside
    // the list (the first open one until you pick another).
    final selectedId = ref.watch(selectedTaskProvider);
    final selected =
        all.where((t) => t.id == selectedId).firstOrNull ??
        [...doing, ...next, ...checkBack, ...waiting, ...comingUp].firstOrNull;

    Widget list(bool wide, {bool pane = false}) => ListView(
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : 22,
        wide ? 40 : 24,
        wide ? 32 : 22,
        navClearance(context),
      ),
      children: [
        PageHeader(
          project?.name ?? 'Tasks',
          subtitle:
              '${doing.length + next.length} open · about '
              '${shortMinutes(totalMin)}',
          // Wide: the filters show as pills below, so the board's view
          // switch and the project's menu sit up here.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wide && project != null) ...[
                _ProjectMenu(project: project),
                const SizedBox(width: Gap.s4),
              ],
              if (wide && view == TaskView.board) ...[
                SizedBox(width: 200, child: viewSwitch),
                const SizedBox(width: Gap.s4),
              ],
              SquareIconButton(
                icon: Ph.lightning,
                tooltip: 'Brain dump',
                onPressed: () => showQuickAdd(context, brainDump: true),
              ),
              const SizedBox(width: Gap.s4),
              SquareIconButton(
                icon: Ph.funnelSimple,
                tooltip: 'Show tasks',
                selected: filter != null || project != null,
                onPressed: () => _showFilterSheet(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.s7),
        // Wide: All · Personal · Work and Projects as pills, as in the
        // design's Mac/iPad Tasks.
        if (wide) ...[
          Wrap(
            spacing: Gap.s3,
            runSpacing: Gap.s3,
            children: [
              if (!device.single) ...[
                Pill(
                  label: 'All',
                  dot: s.star,
                  selected: filter == null,
                  solid: filter == null,
                  onTap: () =>
                      ref.read(_workspaceFilterProvider.notifier).set(null),
                ),
                for (final w in Workspace.values)
                  Pill(
                    label: w.label,
                    dot: s.workspaceColor(w == Workspace.work),
                    selected: filter == w,
                    solid: filter == w,
                    onTap: () =>
                        ref.read(_workspaceFilterProvider.notifier).set(w),
                  ),
              ],
              Pill(
                label: project?.name ?? 'Projects',
                dot: project == null ? null : s.projectColor(project.color),
                selected: project != null,
                solid: project != null,
                onTap: () => _showFilterSheet(context),
              ),
            ],
          ),
          const SizedBox(height: Gap.s7),
        ],
        // Phone: the workspace, project and list/board choices live in a
        // sheet behind the filter button. What's chosen shows here.
        if (!wide &&
            filterLabel.isNotEmpty &&
            (filter != null || project != null)) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(
                label: filterLabel,
                icon: Ph.funnelSimple,
                selected: true,
                solid: true,
                onTap: () => _showFilterSheet(context),
              ),
              if (project case final p?) _ProjectMenu(project: p),
            ],
          ),
          const SizedBox(height: Gap.s7),
        ],
        if (view == TaskView.board && all.isNotEmpty)
          TaskBoard(tasks: all, showProject: project == null)
        else ...[
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nothing here yet.', style: s.display(24)),
                  const SizedBox(height: Gap.s6),
                  SizedBox(
                    width: 180,
                    child: PrimaryButton(
                      label: 'Add a task',
                      onPressed: () => showQuickAdd(context),
                    ),
                  ),
                ],
              ),
            ),
          if (checkBack.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final t in checkBack) _CheckBackRow(task: t)],
              ),
            ),
          for (final (title, tasks, quiet) in [
            ('In progress', doing, false),
            ('Up next', next, false),
            ('Waiting on someone', waiting, false),
            ('Coming up', comingUp, true),
          ])
            _Section(
              title: title,
              tasks: tasks,
              quiet: quiet,
              compact: !wide || pane,
              selectedId: pane ? selected?.id : null,
              onSelect: pane
                  ? (t) => ref.read(selectedTaskProvider.notifier).set(t.id)
                  : null,
            ),
          if (done.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: s.ink3,
                collapsedIconColor: s.ink3,
                title: SectionTitle('Done', count: done.length),
                children: [for (final t in done.take(50)) _TaskTile(task: t)],
              ),
            ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        // Lower than other screens' sidebar breakpoint, so an iPad in
        // landscape (about 970 beside the app's sidebar) gets the pane.
        if (c.maxWidth < 880) {
          return ContentWidth(
            maxWidth: view == TaskView.board ? 1400 : 640,
            child: list(false),
          );
        }
        if (view == TaskView.board) {
          return ContentWidth(maxWidth: 1680, child: list(true));
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: (c.maxWidth * 0.5).clamp(420.0, 600.0),
              child: list(true, pane: true),
            ),
            VerticalDivider(width: 1, thickness: 1, color: s.line),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: TaskDetailPane(task: selected),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Phone: Show / Project / View in one sheet. Every choice applies
/// straight away; Done just closes it.
Future<void> _showFilterSheet(BuildContext context) => showAppSheet<void>(
  context: context,
  builder: (ctx) => SafeArea(
    child: SingleChildScrollView(
      padding: sheetPadding,
      child: Consumer(
        builder: (ctx, ref, _) {
          final device = ref.watch(deviceWorkspacesProvider);
          final filter = ref.watch(_workspaceFilterProvider);
          final projects = ref
              .watch(projectsProvider)
              .where((p) => filter == null || p.workspace == filter)
              .toList();
          final projectId = ref.watch(taskProjectFilterProvider);
          final project = projects.where((p) => p.id == projectId).firstOrNull;
          final view = ref.watch(taskViewProvider);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('Show tasks'),
              const SizedBox(height: Gap.s7),
              // A one-workspace device has nothing to choose between.
              if (!device.single) ...[
                const OptionLabel('Which side'),
                OptionRow(
                  children: [
                    for (final w in [null, ...Workspace.values])
                      OptionButton(
                        label: w?.label ?? 'Everything',
                        selected: filter == w,
                        onTap: () {
                          ref.read(_workspaceFilterProvider.notifier).set(w);
                          if (w != null &&
                              project != null &&
                              project.workspace != w) {
                            ref
                                .read(taskProjectFilterProvider.notifier)
                                .set(null);
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: Gap.s7),
              ],
              const OptionLabel('Project'),
              _ProjectBar(
                projects: projects,
                selected: project,
                workspace: device.single ? device.primary : filter,
              ),
              const SizedBox(height: Gap.s7),
              const OptionLabel('View'),
              OptionRow(
                children: [
                  for (final v in TaskView.values)
                    OptionButton(
                      label: v == TaskView.list ? 'List' : 'Board',
                      icon: v == TaskView.list ? Ph.listBullets : Ph.kanban,
                      selected: view == v,
                      onTap: () => ref.read(taskViewProvider.notifier).set(v),
                    ),
                ],
              ),
              const SizedBox(height: Gap.s8),
              PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
            ],
          );
        },
      ),
    ),
  ),
);

/// "+ Project": asks which workspace when none is chosen, then names it
/// and opens it.
Future<void> _addProject(
  BuildContext context,
  WidgetRef ref,
  Workspace? workspace,
) async {
  final ws =
      workspace ??
      await showAppSheet<Workspace>(
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
    icon: const Icon(Ph.dotsThree),
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
            dot: context.spec.projectColor(p.color),
            selected: selected?.id == p.id,
            onTap: () => set(selected?.id == p.id ? null : p.id),
          ),
        _DashedPill(
          label: projects.isEmpty ? '+ New project' : '+ Project',
          onTap: () => _addProject(context, ref, workspace),
        ),
        if (selected case final p?) _ProjectMenu(project: p),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.tasks,
    this.quiet = false,
    this.compact = false,
    this.selectedId,
    this.onSelect,
  });
  final String title;
  final List<Task> tasks;
  final bool compact;

  /// Mac/iPad pane layout: tapping a row selects it instead of opening
  /// the editor, and the selected row is raised.
  final String? selectedId;
  final void Function(Task)? onSelect;

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
              child: _TaskTile(
                task: t,
                last: i == tasks.length - 1,
                compact: compact,
                selected: selectedId == t.id,
                onSelect: onSelect,
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    this.last = false,
    this.compact = false,
    this.selected = false,
    this.onSelect,
  });
  final Task task;
  final bool last;
  final bool compact;
  final bool selected;
  final void Function(Task)? onSelect;

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
        borderRadius: onSelect == null ? null : BorderRadius.circular(Radii.md),
        onTap: onSelect == null
            ? () => context.push('/task/${task.id}')
            : () => onSelect!(task),
        onDoubleTap: onSelect == null
            ? null
            : () => context.push('/task/${task.id}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: onSelect == null ? 0 : 10,
          ),
          decoration: selected
              ? BoxDecoration(
                  color: s.raised,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: s.line2, width: 2),
                )
              : BoxDecoration(
                  border: last
                      ? null
                      : Border(bottom: BorderSide(color: s.line)),
                ),
          child: Row(
            children: [
              Transform.translate(
                offset: const Offset(-9, 0),
                child: StarCheck(
                  done: isDone,
                  label: isDone ? 'Not done yet' : 'Mark done',
                  onTap: isDone
                      ? () => ctl.reopen(task.id)
                      : () => markDoneWithUndo(context, ref, task),
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(-4, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: isDone ? s.ink3 : s.ink,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: s.ink3,
                        ),
                      ),
                      const SizedBox(height: Gap.s1),
                      TaskMeta(
                        task: task,
                        now: now,
                        compact: compact,
                        extra: extras.isEmpty ? null : extras.join(' · '),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: Icon(Ph.dotsThree, size: 20, color: s.ink3),
                onPressed: () => showTaskMenu(context, ref, task),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ⋯ menu on a task: a sheet of actions, Delete last and in red.
Future<void> showTaskMenu(BuildContext context, WidgetRef ref, Task task) {
  final ctl = ref.read(tasksProvider.notifier);
  final isDone = task.status == TaskStatus.done;
  final items = <(String, IconData, VoidCallback, bool)>[
    if (!isDone) ...[
      (
        'Start now',
        Ph.starFour,
        () => openFocus(context, task.id, minutes: task.estimateMin),
        false,
      ),
      (
        'Just 5 minutes',
        Ph.timer,
        () => openFocus(context, task.id, minutes: 5, justFive: true),
        false,
      ),
      (
        'Mark done',
        Ph.check,
        () => markDoneWithUndo(context, ref, task),
        false,
      ),
    ],
    ('Edit', Ph.pencilSimple, () => context.push('/task/${task.id}'), false),
    if (!isDone && task.status != TaskStatus.waiting)
      (
        'Waiting on someone',
        Ph.hourglassMedium,
        () => showWaitingSheet(context, task),
        false,
      ),
    if (isDone || task.status == TaskStatus.waiting)
      (
        'Move back to to-do',
        Ph.arrowCounterClockwise,
        () => ctl.reopen(task.id),
        false,
      ),
    ('Archive', Ph.archive, () => archiveWithUndo(context, ref, task), false),
    ('Delete', Ph.trash, () => deleteWithUndo(context, ref, task), true),
  ];
  return showAppSheet<void>(
    context: context,
    builder: (ctx) {
      final s = ctx.spec;
      return SafeArea(
        child: SingleChildScrollView(
          padding: sheetPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: s.display(17),
              ),
              const SizedBox(height: Gap.s4),
              for (final (label, icon, onTap, danger) in items)
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    onTap();
                  },
                  child: SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: danger ? s.danger : s.ink),
                        const SizedBox(width: Gap.s6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: danger ? s.danger : s.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// "+ Project": a dashed outline, for making something new.
class _DashedPill extends StatelessWidget {
  const _DashedPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorder(s.line2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: s.ink2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(Radii.md),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
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
      padding: const EdgeInsets.only(bottom: Gap.s4),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        onTap: () => context.push('/task/${task.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ph.bellSimpleRinging, size: 14, color: s.accentText),
                const SizedBox(width: Gap.s3),
                Text('CHECK BACK', style: s.overline(color: s.accentText)),
              ],
            ),
            const SizedBox(height: Gap.s4),
            Text(task.title, style: s.body(weight: FontWeight.w700)),
            const SizedBox(height: Gap.s1),
            Text(
              task.waitingOn.isEmpty
                  ? 'Any news? Time to check back.'
                  : 'Waiting on ${_lower(task.waitingOn)}. Any news?',
              style: s.caption(color: s.ink2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(
                  label: 'Back to list',
                  selected: true,
                  solid: true,
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

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
