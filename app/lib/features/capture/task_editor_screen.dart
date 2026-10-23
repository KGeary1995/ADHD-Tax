import 'package:flutter/material.dart';

import '../settings/device_workspaces.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart' show parseTags;
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import 'first_steps.dart';
import '../ai/ai_settings.dart';
import '../ai/breakdown.dart';
import '../../data/models/links.dart';
import '../notes/note_links.dart';
import '../notes/notes_controller.dart';
import '../notes/notes_screen.dart';
import '../notes/project_widgets.dart';
import '../safety/phi_warning.dart';
import '../tasks/checklist_editor.dart';
import '../tasks/task_actions.dart';
import '../tasks/tasks_controller.dart';
import '../templates/templates_controller.dart';

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
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(tasksProvider.notifier).byId(widget.taskId);
    _isNew = existing == null;
    final now = ref.read(clockProvider)();
    _task =
        existing ??
        widget.draft ??
        Task(
          id: '',
          title: '',
          workspace: ref.read(deviceWorkspacesProvider).primary,
          createdAt: now,
          updatedAt: now,
        );
    _title = TextEditingController(text: _task.title)
      ..addListener(() => setState(() {}));
    _firstStep = TextEditingController(text: _task.firstStep)
      ..addListener(() => setState(() {}));
    _notes = TextEditingController(text: _task.notes)
      ..addListener(() => setState(() {}));
    _location = TextEditingController(text: _task.location);
    _estimate = TextEditingController(text: '${_task.estimateMin}');
    _waitingOn = TextEditingController(text: _task.waitingOn);
    _tags = TextEditingController(
      text: _task.tagList.map((t) => '#$t').join(' '),
    );
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
      _tags,
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
      tags: parseTags(_tags.text.split(RegExp(r'[\s,]+')).join(',')).join(','),
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

  bool _breakingDown = false;

  /// Asks Claude for steps and adds them to the checklist (not saved until
  /// Save, so they can be edited or dropped first).
  Future<void> _breakDown() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_title.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Give the task a name first.')),
      );
      return;
    }
    final task = _task.copyWith(title: _title.text.trim(), notes: _notes.text);
    // Without a key (or when the AI is off for this task), suggest steps
    // from the built-in ideas instead of failing.
    if (aiBlockReason(
          settings: ref.read(aiSettingsProvider),
          workspace: task.workspace,
          text: '${task.title}\n${task.notes}',
        ) !=
        null) {
      final have = {for (final st in _task.steps) st.text.toLowerCase()};
      final ideas = [
        for (final st in stepIdeasFor(task.title).checklist)
          if (!have.contains(st.toLowerCase())) st,
      ];
      setState(
        () => _task = _task.copyWith(
          checklist: encodeChecklist([
            ..._task.steps,
            for (final st in ideas) ChecklistItem(st),
          ]),
        ),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ideas.isEmpty
                ? 'Those steps are already there.'
                : 'Added ${ideas.length} suggested steps. Edit or remove '
                      'any, then Save.',
          ),
        ),
      );
      return;
    }
    setState(() => _breakingDown = true);
    try {
      final steps = await ref.read(aiSettingsProvider.notifier).breakDown(task);
      if (!mounted) return;
      setState(
        () => _task = _task.copyWith(
          checklist: encodeChecklist([
            ..._task.steps,
            for (final st in steps) ChecklistItem(st),
          ]),
        ),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Added ${steps.length} steps. Edit or remove any, then Save.',
          ),
        ),
      );
    } on BreakdownException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _breakingDown = false);
    }
  }

  /// Saves the task as it is on screen, checklist unticked, for reuse.
  void _saveAsTemplate() {
    if (_title.text.trim().isEmpty) return;
    final t = ref
        .read(templatesProvider.notifier)
        .fromTask(_task.copyWith(title: _title.text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved as a template: ${t.name}'),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () => context.push('/template/${t.id}'),
        ),
      ),
    );
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

    // On a computer: what the task is on the left, how and when on the
    // right, instead of one long narrow column.
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    // On a computer the settings-like fields put their label beside the
    // choices, so the "how" and "when" panels fit without scrolling.
    Widget row(String label, Widget child, {String? help}) => !wide
        ? field(label, child, help: help)
        : Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 128,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, right: 12),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: s.isDark ? s.text2 : s.muted,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      child,
                      if (help != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          help,
                          style: TextStyle(
                            color: s.muted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );

    final whatPanel = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field(
            'Task',
            TextField(
              controller: _title,
              autofocus: _isNew,
              decoration: const InputDecoration(hintText: 'What needs doing?'),
            ),
          ),
          field(
            'First 2-minute step',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _firstStep,
                  autofocus: widget.focusFirstStep,
                  decoration: const InputDecoration(
                    hintText: 'e.g. "Open the portal and log in"',
                  ),
                ),
                // Stuck for a first step? A few ideas for this kind of
                // task, built in (no AI, nothing leaves the device).
                ListenableBuilder(
                  listenable: Listenable.merge([_title, _firstStep]),
                  builder: (context, _) {
                    if (_firstStep.text.trim().isNotEmpty ||
                        _title.text.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final ideas = stepIdeasFor(_title.text).firstSteps;
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Ideas:',
                            style: TextStyle(fontSize: 13, color: s.muted),
                          ),
                          for (final idea in ideas)
                            Pill(
                              label: idea,
                              selected: false,
                              icon: Icons.add_rounded,
                              onTap: () => _firstStep.text = idea,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            help: _task.steps.isEmpty
                ? 'Make it so small it feels silly. This is what the '
                      'focus screen shows instead of the whole task.'
                : 'With a checklist, the next unticked step is shown '
                      'instead.',
          ),
          field(
            'Checklist',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChecklistEditor(
                  value: _task.checklist,
                  onChanged: (v) =>
                      setState(() => _task = _task.copyWith(checklist: v)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _breakingDown ? null : _breakDown,
                    icon: _breakingDown
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _breakingDown
                          ? 'Breaking it down…'
                          : ref.watch(aiSettingsProvider).hasKey
                          ? 'Break it down with AI'
                          : 'Suggest steps',
                    ),
                  ),
                ),
              ],
            ),
            help: _task.steps.isEmpty
                ? 'Optional. Break it into steps you can tick off.'
                : null,
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
            text:
                '${_title.text}\n${_firstStep.text}\n'
                '${_task.checklist}\n${_notes.text}',
            workspace: _task.workspace,
          ),
        ],
      ),
    );
    final howPanel = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!ref.watch(deviceWorkspacesProvider).single)
            row(
              'Workspace',
              ChoiceGroup(
                values: Workspace.values,
                selected: _task.workspace,
                labelOf: (w) => w.label,
                // Projects belong to one workspace.
                onSelected: (w) => setState(
                  () => _task = _task.copyWith(
                    workspace: w,
                    projectId: w == _task.workspace ? _task.projectId : '',
                  ),
                ),
              ),
            ),
          row(
            'Project',
            ProjectPicker(
              workspace: _task.workspace,
              selected: _task.projectId,
              onSelected: (id) =>
                  setState(() => _task = _task.copyWith(projectId: id)),
            ),
          ),
          row(
            'Tags',
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                hintText: '#billing #calls',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
          ),
          row(
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
          row(
            'Priority',
            ChoiceGroup(
              values: Priority.values,
              selected: _task.priority,
              labelOf: (p) => p.label,
              onSelected: (p) =>
                  setState(() => _task = _task.copyWith(priority: p)),
            ),
          ),
          row(
            'How much do you dread it?',
            ChoiceGroup(
              values: [for (var i = 0; i < ughLabels.length; i++) i],
              selected: _task.ugh,
              labelOf: (i) => ughLabels[i],
              onSelected: (i) => setState(() => _task = _task.copyWith(ugh: i)),
            ),
            help: 'Dreaded tasks earn bonus XP and get suggested when your energy is up.',
          ),
          row(
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
    );
    final whenPanel = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Need to leave the house'),
            value: _task.requiresLeavingHouse,
            onChanged: (v) =>
                setState(() => _task = _task.copyWith(requiresLeavingHouse: v)),
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
          row(
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
                    onPressed: () =>
                        setState(() => _task = _task.copyWith(dueAt: null)),
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
              onChanged: (v) =>
                  setState(() => _task = _task.copyWith(hardDeadline: v)),
            ),
          const SizedBox(height: 8),
          row(
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
              onChanged: (v) =>
                  setState(() => _task = _task.copyWith(repeatFromDone: v)),
            ),
          if (!_isNew) ...[
            const SizedBox(height: 8),
            row(
              'Status',
              DropdownButtonFormField<TaskStatus>(
                initialValue: _task.status,
                isExpanded: true,
                items: [
                  for (final st in TaskStatus.values)
                    DropdownMenuItem(value: st, child: Text(statusLabel(st))),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _task = _task.copyWith(status: v));
                  }
                },
              ),
            ),
            if (_task.status == TaskStatus.waiting) ...[
              row(
                'Waiting on',
                TextField(
                  controller: _waitingOn,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Insurance callback, IT ticket',
                  ),
                ),
              ),
              row(
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
                          () => _task = _task.copyWith(followUpAt: null),
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
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New task' : 'Edit task'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Save as template',
              onPressed: _saveAsTemplate,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
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
        maxWidth: wide ? 1180 : 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 12 : 20,
            8,
            narrow ? 12 : 20,
            48,
          ),
          children: [
            if (wide)
              ResponsiveColumns(
                sideWidth: 520,
                main: [
                  whatPanel,
                  if (!_isNew) ...[
                    const SizedBox(height: 16),
                    _TaskNotes(task: _task),
                    _Related(task: _task),
                  ],
                ],
                side: [howPanel, const SizedBox(height: 16), whenPanel],
              )
            else ...[
              whatPanel,
              const SizedBox(height: 16),
              howPanel,
              const SizedBox(height: 16),
              whenPanel,
              if (!_isNew) ...[
                const SizedBox(height: 16),
                _TaskNotes(task: _task),
                _Related(task: _task),
              ],
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

/// Notes that `[[link]]` to this task, and unfinished tasks that share a
/// tag or its project. Nothing at all when there's neither, so a task with
/// no connections stays as short as before.
class _Related extends ConsumerWidget {
  const _Related({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentions = notesLinkingTo(
      task.title,
      workspace: task.workspace,
      notes: ref.watch(notesProvider),
    ).where((n) => n.taskId != task.id).toList();
    final tasks = relatedTasks(task, ref.watch(tasksProvider));
    if (mentions.isEmpty && tasks.isEmpty) return const SizedBox.shrink();
    final project = ref
        .watch(projectsProvider)
        .where((p) => p.id == task.projectId)
        .firstOrNull;
    final mine = {for (final t in task.tagList) t.toLowerCase()};
    String why(Task t) {
      final shared = [
        for (final tag in t.tagList)
          if (mine.contains(tag.toLowerCase())) '#$tag',
      ];
      if (shared.isNotEmpty) return shared.join(' ');
      return project == null ? 'Same project' : project.name;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Related'),
            for (final n in mentions)
              LinkRow(
                icon: Icons.sticky_note_2_outlined,
                title: n.heading,
                subtitle: 'Note that links here',
                onTap: () => context.push('/note/${n.id}'),
              ),
            for (final t in tasks)
              LinkRow(
                icon: Icons.task_alt_rounded,
                title: t.title,
                subtitle: why(t),
                onTap: () => context.push('/task/${t.id}'),
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
