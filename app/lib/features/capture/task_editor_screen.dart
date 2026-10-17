import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/task_chips.dart';
import '../safety/phi_warning.dart';
import '../tasks/tasks_controller.dart';

/// Full task editor. `taskId == 'new'` creates a task.
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.taskId,
    this.focusFirstStep = false,
  });

  final String taskId;

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

  @override
  void initState() {
    super.initState();
    final existing = ref.read(tasksProvider.notifier).byId(widget.taskId);
    _isNew = existing == null;
    final now = ref.read(clockProvider)();
    _task = existing ?? Task(id: '', title: '', createdAt: now, updatedAt: now);
    _title = TextEditingController(text: _task.title)
      ..addListener(() => setState(() {}));
    _firstStep = TextEditingController(text: _task.firstStep)
      ..addListener(() => setState(() {}));
    _notes = TextEditingController(text: _task.notes)
      ..addListener(() => setState(() {}));
    _location = TextEditingController(text: _task.location);
    _estimate = TextEditingController(text: '${_task.estimateMin}');
  }

  @override
  void dispose() {
    for (final c in [_title, _firstStep, _notes, _location, _estimate]) {
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
    if (ok == true) {
      ref.read(tasksProvider.notifier).delete(_task.id);
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

  @override
  Widget build(BuildContext context) {
    final s = context.spec;

    Widget field(String label, Widget child, {String? help}) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          child,
          if (help != null) ...[
            const SizedBox(height: 4),
            Text(help, style: TextStyle(color: s.muted, fontSize: 12)),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
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
                    SegmentedButton<Workspace>(
                      showSelectedIcon: false,
                      segments: [
                        for (final w in Workspace.values)
                          ButtonSegment(value: w, label: Text(w.label)),
                      ],
                      selected: {_task.workspace},
                      onSelectionChanged: (v) => setState(
                        () => _task = _task.copyWith(workspace: v.first),
                      ),
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
                          ChoiceChip(
                            label: Text(formatMinutes(m)),
                            selected: int.tryParse(_estimate.text) == m,
                            onSelected: (_) =>
                                setState(() => _estimate.text = '$m'),
                          ),
                        SizedBox(
                          width: 110,
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
                    SegmentedButton<Priority>(
                      showSelectedIcon: false,
                      segments: [
                        for (final p in Priority.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {_task.priority},
                      onSelectionChanged: (v) => setState(
                        () => _task = _task.copyWith(priority: v.first),
                      ),
                    ),
                  ),
                  field(
                    'How much do you not want to do this?',
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (var i = 0; i < ughLabels.length; i++)
                          ButtonSegment(value: i, label: Text(ughLabels[i])),
                      ],
                      selected: {_task.ugh},
                      onSelectionChanged: (v) =>
                          setState(() => _task = _task.copyWith(ugh: v.first)),
                    ),
                    help: 'Dreaded tasks earn bonus XP and get suggested when your energy is up.',
                  ),
                  field(
                    'Energy it takes',
                    SegmentedButton<Energy>(
                      showSelectedIcon: false,
                      segments: [
                        for (final e in Energy.values)
                          ButtonSegment(value: e, label: Text(e.label)),
                      ],
                      selected: {_task.energy},
                      onSelectionChanged: (v) => setState(
                        () => _task = _task.copyWith(energy: v.first),
                      ),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due date'),
                    subtitle: Text(
                      _task.dueAt == null
                          ? 'None'
                          : MaterialLocalizations.of(context)
                                .formatFullDate(_task.dueAt!),
                    ),
                    trailing: Wrap(
                      children: [
                        if (_task.dueAt != null)
                          IconButton(
                            tooltip: 'Clear',
                            onPressed: () => setState(
                              () => _task = _task.copyWith(dueAt: null),
                            ),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Pick date',
                          onPressed: _pickDue,
                          icon: const Icon(Icons.event_outlined),
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
                  if (!_isNew)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Status'),
                      trailing: DropdownButton<TaskStatus>(
                        value: _task.status,
                        underline: const SizedBox.shrink(),
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
                ],
              ),
            ),
          ],
        ),
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
