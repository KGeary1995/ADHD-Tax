import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../notes/notes_controller.dart';
import '../notes/notes_screen.dart';
import '../notes/project_widgets.dart';
import '../safety/phi_warning.dart';
import '../tasks/task_actions.dart';
import '../tasks/tasks_controller.dart';

/// Full task editor. `taskId == 'new'` creates a task.
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.taskId,
    this.focusFirstStep = false,
    this.draft,
  });

  final String taskId;

  /// Starting values for a new task, e.g. what was typed into Quick add.
  final Task? draft;

  /// Opened from "Make it smaller": jump straight to the first-step field.
  final bool focusFirstStep;

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  late Task _task;
  late final bool _isNew;
  late final TextEditingController _title;
  late final TextEditingController _firstStep;
  late final TextEditingController _notes;
  late final TextEditingController _location;
  late final TextEditingController _estimate;
  late final TextEditingController _waitingOn;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(tasksProvider.notifier).byId(widget.taskId);
    _isNew = existing == null;
    final now = ref.read(clockProvider)();
    _task =
        existing ??
        widget.draft ??
        Task(id: '', title: '', createdAt: now, updatedAt: now);
    _title = TextEditingController(text: _task.title)
      ..addListener(() => setState(() {}));
    _firstStep = TextEditingController(text: _task.firstStep)
      ..addListener(() => setState(() {}));
    _notes = TextEditingController(text: _task.notes)
      ..addListener(() => setState(() {}));
    _location = TextEditingController(text: _task.location);
    _estimate = TextEditingController(text: '${_task.estimateMin}');
    _waitingOn = TextEditingController(text: _task.waitingOn);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _firstStep,
      _notes,
      _location,
      _estimate,
      _waitingOn,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final tasks = ref.read(tasksProvider.notifier);
    final estimate =
        int.tryParse(_estimate.text)?.clamp(1, 24 * 60) ?? _task.estimateMin;
    final t = _task.copyWith(
      title: _title.text.trim(),
      firstStep: _firstStep.text.trim(),
      notes: _notes.text,
      location: _location.text.trim(),
      estimateMin: estimate,
      waitingOn: _waitingOn.text.trim(),
    );
    tasks.save(t);
    _close();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/tasks');

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this task?'),
        content: const Text(
          'If it just doesn\'t matter anymore, that\'s a valid outcome.',
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
    if (ok == true && mounted) {
      // The saved version, not unsaved edits, is what Undo brings back.
      final saved = ref.read(tasksProvider.notifier).byId(_task.id);
      if (saved != null) deleteWithUndo(context, ref, saved);
      _close();
    }
  }

  Future<void> _pickDue() async {
    final now = ref.read(clockProvider)();
    final d = await showDatePicker(
      context: context,
      initialDate: _task.dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (d != null) {
      // End of day: "due Tuesday" means by Tuesday evening.
      setState(
        () =>
            _task = _task.copyWith(dueAt: DateTime(d.year, d.month, d.day, 17)),
      );
    }
  }

  Future<void> _pickFollowUp() async {
    final now = ref.read(clockProvider)();
    final d = await showDatePicker(
      context: context,
      initialDate: _task.followUpAt ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(
        () => _task = _task.copyWith(
          followUpAt: DateTime(d.year, d.month, d.day, 9),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final narrow = MediaQuery.sizeOf(context).width < 420;

    Widget field(String label, Widget child, {String? help}) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          child,
          if (help != null) ...[
            const SizedBox(height: 4),
            Text(
              help,
              style: TextStyle(color: s.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New task' : 'Edit task'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _title.text.trim().isEmpty ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 12 : 20,
            8,
            narrow ? 12 : 20,
            48,
          ),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field(
                    'Task',
                    TextField(
                      controller: _title,
                      autofocus: _isNew,
                      decoration: const InputDecoration(
                        hintText: 'What needs doing?',
                      ),
                    ),
                  ),
                  field(
                    'First 2-minute step',
                    TextField(
                      controller: _firstStep,
                      autofocus: widget.focusFirstStep,
                      decoration: const InputDecoration(
                        hintText: 'e.g. "Open the portal and log in"',
                      ),
                    ),
                    help:
                        'Make it so small it feels silly. This is what the '
                        'focus screen shows instead of the whole task.',
                  ),
                  field(
                    'Notes',
                    TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Links, details, context',
                      ),
                    ),
                  ),
                  PhiWarning(
                    text: '${_title.text}\n${_firstStep.text}\n${_notes.text}',
                    workspace: _task.workspace,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field(
                    'Workspace',
                    ChoiceGroup(
                      values: Workspace.values,
                      selected: _task.workspace,
                      labelOf: (w) => w.label,
                      // Projects belong to one workspace.
                      onSelected: (w) => setState(
                        () => _task = _task.copyWith(
                          workspace: w,
                          projectId: w == _task.workspace
                              ? _task.projectId
                              : '',
                        ),
                      ),
                    ),
                  ),
                  field(
                    'Project',
                    ProjectPicker(
                      workspace: _task.workspace,
                      selected: _task.projectId,
                      onSelected: (id) =>
                          setState(() => _task = _task.copyWith(projectId: id)),
                    ),
                  ),
                  field(
                    'Estimate',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final m in estimatePresets)
                          Pill(
                            label: shortMinutes(m),
                            mono: true,
                            selected: int.tryParse(_estimate.text) == m,
                            onTap: () => setState(() => _estimate.text = '$m'),
                          ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _estimate,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              suffixText: 'min',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Can be done in chunks'),
                    subtitle: const Text(
                      'Lets "Pick for me" offer a slice of it when you have less time.',
                    ),
                    value: _task.chunkable,
                    onChanged: (v) =>
                        setState(() => _task = _task.copyWith(chunkable: v)),
                  ),
                  const SizedBox(height: 8),
                  field(
                    'Priority',
                    ChoiceGroup(
                      values: Priority.values,
                      selected: _task.priority,
                      labelOf: (p) => p.label,
                      onSelected: (p) =>
                          setState(() => _task = _task.copyWith(priority: p)),
                    ),
                  ),
                  field(
                    'How much do you dread it?',
                    ChoiceGroup(
                      values: [for (var i = 0; i < ughLabels.length; i++) i],
                      selected: _task.ugh,
                      labelOf: (i) => ughLabels[i],
                      onSelected: (i) =>
                          setState(() => _task = _task.copyWith(ugh: i)),
                    ),
                    help: 'Dreaded tasks earn bonus XP and get suggested when your energy is up.',
                  ),
                  field(
                    'Energy it takes',
                    ChoiceGroup(
                      values: Energy.values,
                      selected: _task.energy,
                      labelOf: (e) => e.label,
                      onSelected: (e) =>
                          setState(() => _task = _task.copyWith(energy: e)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Need to leave the house'),
                    value: _task.requiresLeavingHouse,
                    onChanged: (v) => setState(
                      () => _task = _task.copyWith(requiresLeavingHouse: v),
                    ),
                  ),
                  if (_task.requiresLeavingHouse)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _location,
                        decoration: const InputDecoration(
                          hintText: 'Where? (Pharmacy, Post office…)',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  field(
                    'Due date',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDue,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _task.dueAt == null
                                ? 'Pick a date'
                                : MaterialLocalizations.of(context)
                                      .formatMediumDate(_task.dueAt!),
                          ),
                        ),
                        if (_task.dueAt != null)
                          TextButton(
                            onPressed: () => setState(
                              () => _task = _task.copyWith(dueAt: null),
                            ),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                  if (_task.dueAt != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hard deadline'),
                      subtitle: const Text(
                        'Real consequences if missed. Ramps up sooner.',
                      ),
                      value: _task.hardDeadline,
                      onChanged: (v) => setState(
                        () => _task = _task.copyWith(hardDeadline: v),
                      ),
                    ),
                  const SizedBox(height: 8),
                  field(
                    'Repeats',
                    DropdownButtonFormField<Repeat>(
                      initialValue: _task.repeat,
                      isExpanded: true,
                      items: [
                        for (final r in Repeat.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _task = _task.copyWith(repeat: v));
                        }
                      },
                    ),
                    help: _task.repeat == Repeat.none
                        ? null
                        : 'When you finish it, the next one is added '
                              'automatically.',
                  ),
                  if (_task.repeat != Repeat.none)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Count from when I finish it'),
                      subtitle: Text(
                        _task.repeatFromDone
                            ? 'Like watering plants: the next one is a full '
                                  'period after you actually did it.'
                            : 'Keeps a fixed schedule, like a report due '
                                  'every Friday.',
                      ),
                      value: _task.repeatFromDone,
                      onChanged: (v) => setState(
                        () => _task = _task.copyWith(repeatFromDone: v),
                      ),
                    ),
                  if (!_isNew) ...[
                    const SizedBox(height: 8),
                    field(
                      'Status',
                      DropdownButtonFormField<TaskStatus>(
                        initialValue: _task.status,
                        isExpanded: true,
                        items: [
                          for (final st in TaskStatus.values)
                            DropdownMenuItem(
                              value: st,
                              child: Text(statusLabel(st)),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _task = _task.copyWith(status: v));
                          }
                        },
                      ),
                    ),
                    if (_task.status == TaskStatus.waiting) ...[
                      field(
                        'Waiting on',
                        TextField(
                          controller: _waitingOn,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Insurance callback, IT ticket',
                          ),
                        ),
                      ),
                      field(
                        'Check back',
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickFollowUp,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                _task.followUpAt == null
                                    ? 'Pick a date'
                                    : MaterialLocalizations.of(context)
                                          .formatMediumDate(_task.followUpAt!),
                              ),
                            ),
                            if (_task.followUpAt != null)
                              TextButton(
                                onPressed: () => setState(
                                  () =>
                                      _task = _task.copyWith(followUpAt: null),
                                ),
                                child: const Text('No reminder'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 16),
              _TaskNotes(task: _task),
            ],
          ],
        ),
      ),
    );
  }
}

/// Notes written about this task, and a button to add one.
class _TaskNotes extends ConsumerWidget {
  const _TaskNotes({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final notes = ref
        .watch(notesProvider)
        .where((n) => n.taskId == task.id)
        .toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Notes about this task'),
          if (notes.isEmpty)
            Text(
              'Call outcomes, what you tried, where you left off. They '
              'stay with the task.',
              style: TextStyle(color: s.muted, fontSize: 13, height: 1.4),
            ),
          for (final n in notes) NoteTile(note: n, showProject: false),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.push(
                Uri(
                  path: '/note/new',
                  queryParameters: {
                    'ws': task.workspace.name,
                    'task': task.id,
                    if (task.projectId.isNotEmpty) 'project': task.projectId,
                  },
                ).toString(),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a note'),
            ),
          ),
        ],
      ),
    );
  }
}

String statusLabel(TaskStatus s) => switch (s) {
  TaskStatus.inbox => 'Inbox',
  TaskStatus.todo => 'To do',
  TaskStatus.doing => 'In progress',
  TaskStatus.waiting => 'Waiting on someone',
  TaskStatus.done => 'Done',
  TaskStatus.archived => 'Archived',
};
