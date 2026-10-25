import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/ph.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../focus/focus_route.dart';
import '../notes/notes_controller.dart';
import 'checklist_editor.dart';
import 'tasks_controller.dart';

/// The task shown in the Mac/iPad detail pane. Null: the first open one.
class SelectedTask extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final selectedTaskProvider = NotifierProvider<SelectedTask, String?>(
  SelectedTask.new,
);

/// Mac and iPad: the selected task beside the list, so reading it, ticking
/// a step or starting it doesn't take opening the editor. Edit opens the
/// full editor for everything else.
class TaskDetailPane extends ConsumerWidget {
  const TaskDetailPane({super.key, required this.task});
  final Task? task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final t = task;
    if (t == null) {
      return Center(
        child: Text(
          'Pick a task to see it here.',
          style: s.caption(color: s.ink2),
        ),
      );
    }
    final now = ref.read(clockProvider)();
    final project = ref
        .watch(projectsProvider)
        .where((p) => p.id == t.projectId)
        .firstOrNull;
    final notes = ref
        .watch(notesProvider)
        .where((n) => n.taskId == t.id)
        .toList();
    final steps = t.steps;
    final open = t.isOpen;

    String day(DateTime d) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[d.weekday - 1]}, ${formatDate(d)}';
    }

    final details = <(IconData, String, String)>[
      (
        Ph.timer,
        'Length',
        '${formatMinutes(t.estimateMin)}${t.chunkable ? '\nIn chunks' : ''}',
      ),
      (Ph.flag, 'Priority', t.priority.label),
      (
        Ph.calendarBlank,
        'Due',
        t.dueAt == null
            ? 'None'
            : '${day(t.dueAt!)}${t.hardDeadline ? '\nhard' : ''}',
      ),
      (Ph.smileyMeh, 'Dread', ughLabels[t.ugh]),
      (Ph.batteryHigh, 'Energy', t.energy.label),
      (
        Ph.repeat,
        'Repeats',
        t.repeat == Repeat.none ? "Doesn't repeat" : t.repeat.label,
      ),
    ];

    return ListView(
      key: ValueKey('detail-${t.id}'),
      padding: EdgeInsets.fromLTRB(32, 40, 32, navClearance(context)),
      children: [
        Row(
          children: [
            WsDot(s.workspaceColor(t.workspace == Workspace.work)),
            const SizedBox(width: Gap.s4),
            Expanded(
              child: Text(
                [t.workspace.label, ?project?.name].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: s.caption(color: s.ink2),
              ),
            ),
            if (open) ...[
              OutlineButton(
                label: '5 min',
                height: 42,
                fontSize: 15,
                onPressed: () =>
                    openFocus(context, t.id, minutes: 5, justFive: true),
              ),
              const SizedBox(width: Gap.s4),
              PrimaryButton(
                label: 'Start',
                height: 42,
                fontSize: 15,
                expand: false,
                onPressed: () =>
                    openFocus(context, t.id, minutes: t.estimateMin),
              ),
            ],
          ],
        ),
        const SizedBox(height: Gap.s7),
        Text(t.title, style: s.display(30)),
        if (t.dueAt != null) ...[
          const SizedBox(height: Gap.s2),
          Text(
            'Due ${formatDue(t.dueAt!, now)}',
            style: s.caption(color: s.accentText, weight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: Gap.s8),
        if (steps.isNotEmpty) ...[
          const FieldLabel('Steps'),
          for (final (i, item) in steps.indexed)
            ChecklistRow(
              item: item,
              onToggle: () =>
                  ref.read(tasksProvider.notifier).toggleStep(t.id, i),
            ),
        ] else if (t.firstStep.trim().isNotEmpty) ...[
          const FieldLabel('First 2-minute step'),
          Text(t.firstStep, style: s.body()),
        ],
        if (t.notes.trim().isNotEmpty) ...[
          const SizedBox(height: Gap.s8),
          const FieldLabel('Notes'),
          Text(
            t.notes,
            style: TextStyle(fontSize: 15, height: 1.5, color: s.ink2),
          ),
        ],
        const SizedBox(height: Gap.s8),
        LayoutBuilder(
          builder: (context, c) {
            final half = (c.maxWidth - Gap.s7) / 2;
            return Wrap(
              spacing: Gap.s7,
              children: [
                for (final (icon, label, value) in details)
                  SizedBox(
                    width: half,
                    child: _DetailCell(icon: icon, label: label, value: value),
                  ),
              ],
            );
          },
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: Gap.s8),
          const FieldLabel('Linked notes'),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.s4),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                onTap: () => context.push('/note/${n.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: s.body(weight: FontWeight.w700),
                    ),
                    if (n.preview.isNotEmpty)
                      Text(
                        n.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: s.caption(color: s.ink2),
                      ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: Gap.s8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlineButton(
            label: 'Edit task',
            icon: Ph.pencilSimple,
            height: 44,
            fontSize: 15,
            quiet: true,
            onPressed: () => context.push('/task/${t.id}'),
          ),
        ),
      ],
    );
  }
}

/// One detail: icon and label, then the value centred in a 96px column so
/// a two-line value ("1 hour / In chunks") stays tidy.
class _DetailCell extends StatelessWidget {
  const _DetailCell({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: s.ink3),
          const SizedBox(width: Gap.s4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: s.ink2),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: s.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
