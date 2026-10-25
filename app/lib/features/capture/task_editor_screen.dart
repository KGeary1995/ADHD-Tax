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
import '../../core/theme/ph.dart';

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

  /// A task with steps starts from its checklist, so the first-step field
  /// is hidden. Decided once on open: adding the first step mustn't make
  /// the section vanish under your finger.
  late final bool _showFirstStep;
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
    _showFirstStep = _task.steps.isEmpty || _task.firstStep.isNotEmpty;
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
      builder: (ctx) => ConfirmDialog(
        title: 'Delete this task?',
        body: "If it just doesn't matter anymore, that's a fine outcome.",
        confirm: 'Delete',
        danger: true,
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

  /// A detail's own sheet: a title, its controls, and Done. Changes apply
  /// to the editor straight away (still only saved with Save).
  Future<void> _detailSheet(
    String title,
    List<Widget> Function(BuildContext ctx, void Function(Task) set) body, {
    String? subtitle,
  }) => showAppSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        void set(Task t) {
          setState(() => _task = t);
          setSheet(() {});
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: sheetPadding.add(
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetTitle(title, subtitle: subtitle),
                const SizedBox(height: Gap.s7),
                ...body(ctx, set),
                const SizedBox(height: Gap.s8),
                PrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  /// Options in rows of [perRow], equal width.
  List<Widget> _options<T>(
    List<T> values,
    T selected,
    String Function(T) labelOf,
    void Function(T) onTap, {
    int perRow = 2,
  }) => [
    for (var i = 0; i < values.length; i += perRow) ...[
      if (i > 0) const SizedBox(height: Gap.s4),
      OptionRow(
        children: [
          for (final v in values.skip(i).take(perRow))
            OptionButton(
              label: labelOf(v),
              selected: v == selected,
              onTap: () => onTap(v),
            ),
          for (var k = values.skip(i).take(perRow).length; k < perRow; k++)
            const SizedBox.shrink(),
        ],
      ),
    ],
  ];

  String get _lengthText {
    final m = int.tryParse(_estimate.text) ?? _task.estimateMin;
    return '${formatMinutes(m)}${_task.chunkable ? ', can be done in chunks' : ''}';
  }

  String _dateText(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${formatDate(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final single = ref.watch(deviceWorkspacesProvider).single;
    final project = ref
        .watch(projectsProvider)
        .where((p) => p.id == _task.projectId)
        .firstOrNull;
    final canSave = _title.text.trim().isNotEmpty;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: Gap.s9, bottom: Gap.s2),
      child: Text(text.toUpperCase(), style: s.overline()),
    );

    // A field drawn as a line, not a box: the editor reads as a page.
    InputDecoration underline(String hint, {double width = 2}) =>
        InputDecoration(
          hintText: hint,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: s.line2, width: width),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: s.line2, width: width),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: s.star, width: 2),
          ),
        );

    final workspaceRow = single
        ? null
        : OptionRow(
            children: [
              for (final w in Workspace.values)
                WorkspaceOption(
                  work: w == Workspace.work,
                  label: w.label,
                  selected: _task.workspace == w,
                  // Projects belong to one workspace.
                  onTap: () => setState(
                    () => _task = _task.copyWith(
                      workspace: w,
                      projectId: w == _task.workspace ? _task.projectId : '',
                    ),
                  ),
                ),
            ],
          );

    final firstStep = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('First 2-minute step'),
        TextField(
          controller: _firstStep,
          autofocus: widget.focusFirstStep,
          style: TextStyle(fontSize: 17, color: s.ink),
          decoration: underline('So small it feels silly'),
        ),
        // Stuck for a first step? A few ideas for this kind of task, built
        // in (no AI, nothing leaves the device).
        ListenableBuilder(
          listenable: Listenable.merge([_title, _firstStep]),
          builder: (context, _) {
            if (_firstStep.text.trim().isNotEmpty ||
                _title.text.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final idea in stepIdeasFor(_title.text).firstSteps)
                    _IdeaChip(
                      label: '+ $idea',
                      onTap: () => _firstStep.text = idea,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );

    final steps = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Steps'),
        ChecklistEditor(
          value: _task.checklist,
          onChanged: (v) =>
              setState(() => _task = _task.copyWith(checklist: v)),
        ),
        const SizedBox(height: Gap.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _breakingDown ? null : _breakDown,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: s.line2, width: 2),
              foregroundColor: s.accentText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontFamily: Fonts.ui,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: _breakingDown
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Ph.sparkle, size: 16),
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
    );

    final what = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isNew) ...[
          TextField(
            controller: _title,
            autofocus: true,
            maxLines: null,
            style: s.display(24),
            decoration: InputDecoration(
              hintText: 'What needs doing?',
              hintStyle: s.display(24, color: s.ink3),
              fillColor: Colors.transparent,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.lg),
                borderSide: BorderSide(color: s.star, width: 2),
              ),
            ),
          ),
          if (workspaceRow != null) ...[
            const SizedBox(height: Gap.s5),
            workspaceRow,
          ],
        ] else ...[
          Row(
            children: [
              WsDot(s.workspaceColor(_task.workspace == Workspace.work)),
              const SizedBox(width: Gap.s4),
              Flexible(
                child: Text(
                  [_task.workspace.label, ?project?.name].join(' · '),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: s.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.s1),
          TextField(
            controller: _title,
            maxLines: null,
            style: s.display(28),
            decoration: InputDecoration(
              hintText: 'What needs doing?',
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: s.star, width: 2),
              ),
            ),
          ),
        ],
        if (_showFirstStep) firstStep,
        if (!_isNew || _task.steps.isNotEmpty) steps,
        label('Notes'),
        TextField(
          controller: _notes,
          minLines: 1,
          maxLines: 8,
          style: TextStyle(fontSize: 16, height: 1.45, color: s.ink),
          decoration: underline('Links, details, context', width: 2),
        ),
        PhiWarning(
          text:
              '${_title.text}\n${_firstStep.text}\n'
              '${_task.checklist}\n${_notes.text}',
          workspace: _task.workspace,
        ),
      ],
    );

    final dueText = _task.dueAt == null
        ? 'None'
        : '${_dateText(_task.dueAt!)}${_task.hardDeadline ? ' · hard deadline' : ''}';
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Details'),
        if (!single)
          _DetailRow(
            icon: Ph.briefcase,
            label: 'Workspace',
            value: _task.workspace.label,
            onTap: () => _detailSheet(
              'Workspace',
              (ctx, set) => [
                OptionRow(
                  children: [
                    for (final w in Workspace.values)
                      OptionButton(
                        label: w.label,
                        dot: s.workspaceColor(w == Workspace.work),
                        selected: _task.workspace == w,
                        onTap: () => set(
                          _task.copyWith(
                            workspace: w,
                            projectId: w == _task.workspace
                                ? _task.projectId
                                : '',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        _DetailRow(
          icon: Ph.folderSimple,
          label: 'Project',
          value: project?.name ?? 'None',
          onTap: () => _detailSheet(
            'Project',
            (ctx, set) => [
              Consumer(
                builder: (ctx, ref, _) => ProjectPicker(
                  workspace: _task.workspace,
                  selected: _task.projectId,
                  onSelected: (id) => set(_task.copyWith(projectId: id)),
                ),
              ),
            ],
          ),
        ),
        _DetailRow(
          icon: Ph.hash,
          label: 'Tags',
          value: _tags.text.trim().isEmpty ? 'None' : _tags.text.trim(),
          onTap: () => _detailSheet(
            'Tags',
            subtitle: 'Words to find it by, like #billing or #calls.',
            (ctx, set) => [
              TextField(
                controller: _tags,
                autofocus: true,
                onChanged: (_) => set(_task),
                decoration: const InputDecoration(
                  hintText: '#billing #calls',
                  prefixIcon: Icon(Ph.hash),
                ),
              ),
            ],
          ),
        ),
        _DetailRow(
          icon: Ph.timer,
          label: 'Length',
          value: _lengthText,
          onTap: () => _detailSheet(
            'Length',
            (ctx, set) => [
              Wrap(
                spacing: Gap.s3,
                runSpacing: Gap.s3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final m in estimatePresets)
                    Pill(
                      label: shortMinutes(m),
                      mono: true,
                      selected: int.tryParse(_estimate.text) == m,
                      onTap: () {
                        _estimate.text = '$m';
                        set(_task);
                      },
                    ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _estimate,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => set(_task),
                      decoration: const InputDecoration(
                        suffixText: 'min',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.s5),
              SwitchRow(
                title: 'Can be done in chunks',
                subtitle:
                    'Lets "Pick for me" offer a slice of it when you have '
                    'less time.',
                value: _task.chunkable,
                onChanged: (v) => set(_task.copyWith(chunkable: v)),
              ),
            ],
          ),
        ),
        _DetailRow(
          icon: Ph.flag,
          label: 'Priority',
          value: _task.priority.label,
          onTap: () => _detailSheet(
            'Priority',
            (ctx, set) => _options(
              Priority.values,
              _task.priority,
              (p) => p.label,
              (p) => set(_task.copyWith(priority: p)),
            ),
          ),
        ),
        _DetailRow(
          icon: Ph.smileyMeh,
          label: 'Dread',
          value: ughLabels[_task.ugh],
          onTap: () => _detailSheet(
            'How much do you dread it?',
            subtitle:
                'Dreaded tasks earn bonus XP and come up when your energy '
                'is up.',
            (ctx, set) => _options(
              [for (var i = 0; i < ughLabels.length; i++) i],
              _task.ugh,
              (i) => ughLabels[i],
              (i) => set(_task.copyWith(ugh: i)),
            ),
          ),
        ),
        _DetailRow(
          icon: Ph.batteryHigh,
          label: 'Energy it takes',
          value: _task.energy.label,
          onTap: () => _detailSheet(
            'Energy it takes',
            (ctx, set) => _options(
              Energy.values,
              _task.energy,
              (e) => e.label,
              (e) => set(_task.copyWith(energy: e)),
              perRow: 3,
            ),
          ),
        ),
        _DetailRow(
          icon: Ph.carSimple,
          label: 'Leave the house',
          value: !_task.requiresLeavingHouse
              ? 'No'
              : _location.text.trim().isEmpty
              ? 'Yes'
              : 'Yes: ${_location.text.trim()}',
          onTap: () => _detailSheet(
            'Leave the house',
            (ctx, set) => [
              SwitchRow(
                title: 'Need to leave the house',
                value: _task.requiresLeavingHouse,
                onChanged: (v) => set(_task.copyWith(requiresLeavingHouse: v)),
              ),
              if (_task.requiresLeavingHouse) ...[
                const SizedBox(height: Gap.s4),
                TextField(
                  controller: _location,
                  onChanged: (_) => set(_task),
                  decoration: const InputDecoration(
                    hintText: 'Where? (Pharmacy, Post office…)',
                    prefixIcon: Icon(Ph.mapPin),
                  ),
                ),
              ],
            ],
          ),
        ),
        _DetailRow(
          icon: Ph.calendarBlank,
          label: 'Due',
          value: dueText,
          onTap: () => _detailSheet(
            'Due',
            (ctx, set) => [
              Wrap(
                spacing: Gap.s4,
                runSpacing: Gap.s4,
                children: [
                  OutlineButton(
                    label: _task.dueAt == null
                        ? 'Pick a date'
                        : _dateText(_task.dueAt!),
                    icon: Ph.calendarBlank,
                    height: 48,
                    fontSize: 15,
                    onPressed: () async {
                      await _pickDue();
                      set(_task);
                    },
                  ),
                  if (_task.dueAt != null)
                    OutlineButton(
                      label: 'Clear',
                      quiet: true,
                      height: 48,
                      fontSize: 15,
                      onPressed: () => set(_task.copyWith(dueAt: null)),
                    ),
                ],
              ),
              if (_task.dueAt != null) ...[
                const SizedBox(height: Gap.s4),
                SwitchRow(
                  title: 'Hard deadline',
                  subtitle: 'Real consequences if missed. Ramps up sooner.',
                  value: _task.hardDeadline,
                  onChanged: (v) => set(_task.copyWith(hardDeadline: v)),
                ),
              ],
            ],
          ),
        ),
        _DetailRow(
          icon: Ph.repeat,
          label: 'Repeats',
          value: _task.repeat == Repeat.none
              ? "Doesn't repeat"
              : _task.repeat.label,
          onTap: () => _detailSheet(
            'Repeats',
            (ctx, set) => [
              ..._options(
                Repeat.values,
                _task.repeat,
                (r) => r == Repeat.none ? "Doesn't repeat" : r.label,
                (r) => set(_task.copyWith(repeat: r)),
              ),
              if (_task.repeat != Repeat.none) ...[
                const SizedBox(height: Gap.s5),
                SwitchRow(
                  title: 'Count from when I finish it',
                  subtitle: _task.repeatFromDone
                      ? 'Like watering plants: the next one is a full period '
                            'after you actually did it.'
                      : 'Keeps a fixed schedule, like a report due every '
                            'Friday.',
                  value: _task.repeatFromDone,
                  onChanged: (v) => set(_task.copyWith(repeatFromDone: v)),
                ),
              ],
            ],
          ),
        ),
        if (!_isNew) ...[
          _DetailRow(
            icon: Ph.hourglassMedium,
            label: 'Waiting on',
            value: _task.status != TaskStatus.waiting
                ? 'Nobody'
                : _waitingOn.text.trim().isEmpty
                ? 'Someone'
                : _waitingOn.text.trim(),
            onTap: () => _detailSheet(
              'Waiting on someone',
              (ctx, set) => [
                SwitchRow(
                  title: 'Waiting on someone',
                  value: _task.status == TaskStatus.waiting,
                  onChanged: (v) => set(
                    _task.copyWith(
                      status: v ? TaskStatus.waiting : TaskStatus.todo,
                    ),
                  ),
                ),
                if (_task.status == TaskStatus.waiting) ...[
                  const SizedBox(height: Gap.s4),
                  TextField(
                    controller: _waitingOn,
                    onChanged: (_) => set(_task),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Insurance callback, IT ticket',
                    ),
                  ),
                  const SizedBox(height: Gap.s5),
                  Wrap(
                    spacing: Gap.s4,
                    runSpacing: Gap.s4,
                    children: [
                      OutlineButton(
                        label: _task.followUpAt == null
                            ? 'Check back on…'
                            : 'Check back ${_dateText(_task.followUpAt!)}',
                        icon: Ph.calendarBlank,
                        height: 48,
                        fontSize: 15,
                        onPressed: () async {
                          await _pickFollowUp();
                          set(_task);
                        },
                      ),
                      if (_task.followUpAt != null)
                        OutlineButton(
                          label: 'No reminder',
                          quiet: true,
                          height: 48,
                          fontSize: 15,
                          onPressed: () =>
                              set(_task.copyWith(followUpAt: null)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _DetailRow(
            icon: Ph.columns,
            label: 'Status',
            value: statusLabel(_task.status),
            onTap: () => _detailSheet(
              'Status',
              (ctx, set) => _options(
                TaskStatus.values,
                _task.status,
                statusLabel,
                (st) => set(_task.copyWith(status: st)),
              ),
            ),
          ),
        ],
      ],
    );

    final linked = _isNew
        ? const <Widget>[]
        : [_TaskNotes(task: _task), _Related(task: _task)];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Ph.caretLeft),
          onPressed: _close,
        ),
        titleSpacing: 0,
        title: Text(_isNew ? 'New task' : 'Edit task'),
        shape: Border(bottom: BorderSide(color: s.line)),
        backgroundColor: s.bg,
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Save as template',
              onPressed: _saveAsTemplate,
              icon: Icon(Ph.copySimple, size: 20, color: s.ink2),
            ),
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: Icon(Ph.trash, size: 20, color: s.ink2),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 16),
            child: SizedBox(
              width: 80,
              child: PrimaryButton(
                label: 'Save',
                height: 42,
                fontSize: 15,
                onPressed: canSave ? _save : null,
              ),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: wide ? 1180 : 640,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 20 : 24,
            20,
            narrow ? 20 : 24,
            60,
          ),
          children: [
            if (wide)
              ResponsiveColumns(
                sideWidth: 460,
                gap: 48,
                main: [what, ...linked],
                side: [details],
              )
            else ...[
              what,
              details,
              ...linked,
            ],
          ],
        ),
      ),
    );
  }
}

/// One line under Details: icon, name, the value, a caret. Opens a sheet.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: s.line)),
        ),
        child: LayoutBuilder(
          builder: (context, c) => Row(
            children: [
              SizedBox(width: 22, child: Icon(icon, size: 20, color: s.ink3)),
              const SizedBox(width: Gap.s6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, color: s.ink2),
                ),
              ),
              const SizedBox(width: Gap.s4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth * 0.55),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: s.ink,
                  ),
                ),
              ),
              const SizedBox(width: Gap.s4),
              Icon(Ph.caretRight, size: 14, color: s.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+ Open whatever you need": a first-step idea.
class _IdeaChip extends StatelessWidget {
  const _IdeaChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: s.line2, width: 2),
    );
    return Material(
      color: Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: s.ink,
              ),
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(top: Gap.s9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Linked notes'),
          if (notes.isEmpty)
            Text(
              'Call outcomes, what you tried, where you left off. They '
              'stay with the task.',
              style: s.caption(color: s.ink2),
            ),
          for (final n in notes) NoteTile(note: n, showProject: false),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                side: BorderSide(color: s.line2, width: 2),
                textStyle: const TextStyle(
                  fontFamily: Fonts.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
              icon: const Icon(Ph.plusBold),
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
      padding: const EdgeInsets.only(top: Gap.s9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Related'),
          for (final n in mentions)
            LinkRow(
              icon: Ph.note,
              title: n.heading,
              subtitle: 'Note that links here',
              onTap: () => context.push('/note/${n.id}'),
            ),
          for (final t in tasks)
            LinkRow(
              icon: Ph.checkSquare,
              title: t.title,
              subtitle: why(t),
              onTap: () => context.push('/task/${t.id}'),
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
