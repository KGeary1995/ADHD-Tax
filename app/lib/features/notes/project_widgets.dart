import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../widgets/ui.dart';
import 'notes_controller.dart';
import '../../core/theme/ph.dart';

/// A project's colored dot.
class ProjectDot extends StatelessWidget {
  const ProjectDot(this.project, {super.key, this.size = 10});
  final Project project;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: context.spec.projectColor(project.color),
      shape: BoxShape.circle,
    ),
  );
}

/// "● Payroll" in a meta line.
class ProjectLabel extends StatelessWidget {
  const ProjectLabel(this.project, {super.key, this.color});
  final Project project;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ProjectDot(project, size: 8),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: color ?? context.spec.muted),
        ),
      ),
    ],
  );
}

/// Asks for a name and creates the project. Returns it, or null.
Future<Project?> showNewProjectDialog(
  BuildContext context,
  WidgetRef ref,
  Workspace workspace,
) async {
  final name = await _askName(context, title: 'New ${workspace.label} project');
  if (name == null) return null;
  return ref.read(projectsProvider.notifier).create(name, workspace);
}

Future<void> showRenameProjectDialog(
  BuildContext context,
  WidgetRef ref,
  Project p,
) async {
  final name = await _askName(
    context,
    title: 'Rename project',
    initial: p.name,
  );
  if (name != null) ref.read(projectsProvider.notifier).rename(p.id, name);
}

/// Confirms, then deletes. Returns true if deleted.
Future<bool> confirmDeleteProject(
  BuildContext context,
  WidgetRef ref,
  Project p,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete "${p.name}"?'),
      content: const Text(
        'Its tasks and notes stay; they just won\'t be in a project.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  ref.read(projectsProvider.notifier).delete(p.id);
  return true;
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (ctx) {
    final c = TextEditingController(text: initial);
    void done() {
      if (c.text.trim().isNotEmpty) Navigator.pop(ctx, c.text.trim());
    }

    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Payroll, Move house'),
        onSubmitted: (_) => done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: done, child: const Text('Save')),
      ],
    );
  },
);

/// Pick one project of [workspace], or none, or make a new one.
class ProjectPicker extends ConsumerWidget {
  const ProjectPicker({
    super.key,
    required this.workspace,
    required this.selected,
    required this.onSelected,
  });

  final Workspace workspace;

  /// '' for none.
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref
        .watch(projectsProvider)
        .where((p) => p.workspace == workspace)
        .toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        Pill(
          label: 'None',
          selected: selected.isEmpty,
          onTap: () => onSelected(''),
        ),
        for (final p in projects)
          Pill(
            label: p.name,
            dot: context.spec.projectColor(p.color),
            selected: selected == p.id,
            onTap: () => onSelected(p.id),
          ),
        Pill(
          label: 'New project',
          icon: Ph.plusBold,
          selected: false,
          onTap: () async {
            final p = await showNewProjectDialog(context, ref, workspace);
            if (p != null) onSelected(p.id);
          },
        ),
      ],
    );
  }
}
