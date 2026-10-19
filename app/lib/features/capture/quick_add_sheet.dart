import 'package:flutter/material.dart';

import '../settings/device_workspaces.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../focus/focus_route.dart';
import '../notes/notes_controller.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../picker/picker_controller.dart';
import '../safety/phi_warning.dart';
import '../tasks/tasks_controller.dart';
import 'quick_parse.dart';
import '../../data/models/template.dart';
import '../templates/templates_controller.dart';
import '../templates/templates_screen.dart';
import 'voice_input.dart';

/// Five-second capture. Only the title is required.
Future<void> showQuickAdd(
  BuildContext context, {
  bool brainDump = false,
  String initialTitle = '',
  String initialNotes = '',
  String projectId = '',
}) async {
  final startNow = await showModalBottomSheet<Task>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => QuickAddSheet(
      brainDump: brainDump,
      initialTitle: initialTitle,
      initialNotes: initialNotes,
      projectId: projectId,
    ),
  );
  if (startNow != null && context.mounted) {
    openFocus(context, startNow.id, minutes: startNow.estimateMin);
  }
}

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.brainDump = false,
    this.initialTitle = '',
    this.initialNotes = '',
    this.projectId = '',
  });
  final bool brainDump;

  /// Opened while Tasks shows one project: new tasks go into it.
  final String projectId;

  /// Prefilled, e.g. from text shared from another app.
  final String initialTitle;
  final String initialNotes;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late String _notes = widget.initialNotes;
  late bool _brainDump = widget.brainDump;
  int _estimate = 15;
  Priority _priority = Priority.p3;
  bool _leave = false;
  int _ugh = 0;
  late Workspace _workspace;
  Project? _project;

  // Typed extras ("tomorrow 2pm 15 min") fill these in unless the user
  // picked a value by hand or tapped the chip away.
  final _ignored = <String>{};
  bool _estimateTouched = false;
  bool _priorityTouched = false;
  bool _workspaceTouched = false;

  @override
  void initState() {
    super.initState();
    final ws = ref.read(pickerInputsProvider).workspaces;
    final device = ref.read(deviceWorkspacesProvider);
    _workspace = device.single
        ? device.primary
        : ws.length == 1
        ? ws.first
        : Workspace.personal;
    _project = ref.read(projectsProvider.notifier).byId(widget.projectId);
    if (_project != null) _workspace = _project!.workspace;
    _title.addListener(() {
      if (_title.text.trim().isEmpty) _ignored.clear();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty;

  bool get _single => ref.read(deviceWorkspacesProvider).single;

  QuickParse _parse(String text, {Set<String> ignore = const {}}) =>
      parseQuickAdd(
        text,
        ref.read(clockProvider)(),
        // One workspace on this device: "#work" is just a word.
        ignore: {...ignore, if (_single) qkWorkspace},
      );

  /// What will be saved: the sheet's choices merged with what was typed.
  _Resolved _resolve(QuickParse p) {
    final ws = _workspaceTouched || p.workspace == null
        ? _workspace
        : p.workspace!;
    var project = _project?.workspace == ws ? _project : null;
    final tags = <String>[];
    for (final tag in p.tags) {
      // A #tag naming a project files the task there.
      final match = project == null
          ? ref
                .read(projectsProvider.notifier)
                .inWorkspace(ws)
                .where((pr) => normalizeTag(pr.name) == tag)
                .firstOrNull
          : null;
      if (match != null) {
        project = match;
      } else {
        tags.add(tag);
      }
    }
    return _Resolved(
      title: p.title,
      workspace: ws,
      project: project,
      estimate: _estimateTouched || p.estimateMin == null
          ? _estimate
          : p.estimateMin!,
      priority: _priorityTouched || p.priority == null
          ? _priority
          : p.priority!,
      dueAt: p.dueAt,
      tags: tags,
    );
  }

  void _save({bool start = false}) {
    if (!_canSave) return;
    final tasks = ref.read(tasksProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (_brainDump) {
      // Each line can carry its own "tomorrow", "15 min", "#tag".
      final created = [
        for (final line in _title.text.split('\n'))
          if (line.trim().isNotEmpty)
            switch (_resolve(_parse(line))) {
              final r => tasks.create(
                title: r.title,
                workspace: r.workspace,
                projectId: r.project?.id ?? '',
                estimateMin: r.estimate,
                priority: r.priority,
                dueAt: r.dueAt,
                tags: r.tags.join(','),
              ),
            },
      ];
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Captured ${created.length} tasks. Your head is lighter now.',
          ),
        ),
      );
      return;
    }
    final r = _resolve(_parse(_title.text, ignore: _ignored));
    final t = tasks.create(
      title: r.title,
      estimateMin: r.estimate,
      priority: r.priority,
      requiresLeavingHouse: _leave,
      ugh: _ugh,
      workspace: r.workspace,
      notes: _notes,
      projectId: r.project?.id ?? '',
      dueAt: r.dueAt,
      tags: r.tags.join(','),
    );
    Navigator.pop(context, start ? t : null);
  }

  /// Adds a task from a template, checklist and all.
  Future<void> _fromTemplate() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final t = await pickTemplate(context, ref, TemplateKind.task);
    if (t == null || !mounted) return;
    final task = ref.read(templatesProvider.notifier).createTask(t);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('Added: ${task.title}')));
  }

  /// Carries what's been entered so far into the full editor.
  void _openFullForm() {
    final now = ref.read(clockProvider)();
    final r = _resolve(_parse(_title.text, ignore: _ignored));
    final draft = Task(
      id: '',
      title: r.title,
      estimateMin: r.estimate,
      priority: r.priority,
      requiresLeavingHouse: _leave,
      ugh: _ugh,
      workspace: r.workspace,
      notes: _notes,
      projectId: r.project?.id ?? '',
      dueAt: r.dueAt,
      tags: r.tags.join(','),
      createdAt: now,
      updatedAt: now,
    );
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/task/new', extra: draft);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final parsed = _brainDump || !_canSave
        ? null
        : _parse(_title.text, ignore: _ignored);
    final r = parsed == null ? null : _resolve(parsed);
    final estimate = r?.estimate ?? _estimate;
    final priority = r?.priority ?? _priority;
    final workspace = r?.workspace ?? _workspace;
    final project = r == null ? _project : r.project;
    final side = narrow ? 18.0 : 22.0;
    // Sits on top of the keyboard when it's open, above the system
    // navigation bar when it isn't.
    final bottom = MediaQuery.viewInsetsOf(context).bottom > 0
        ? MediaQuery.viewInsetsOf(context).bottom
        : MediaQuery.viewPaddingOf(context).bottom;

    Widget section(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [FieldLabel(label), child],
      ),
    );

    final link = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(
        fontFamily: Fonts.ui,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(side, 0, side, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        _brainDump ? 'Brain dump' : 'Add a task',
                        style: s.display(26),
                      ),
                      Wrap(
                        children: [
                          TextButton(
                            style: link,
                            onPressed: () =>
                                setState(() => _brainDump = !_brainDump),
                            child: Text(_brainDump ? 'One task' : 'Brain dump'),
                          ),
                          if (!_brainDump)
                            TextButton(
                              style: link,
                              onPressed: _fromTemplate,
                              child: const Text('Template'),
                            ),
                          if (!_brainDump)
                            Tooltip(
                              message:
                                  'First step, due date, notes, energy and '
                                  'more',
                              child: TextButton(
                                style: link,
                                onPressed: _openFullForm,
                                child: const Text('Full form'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _title,
                    autofocus: true,
                    minLines: _brainDump ? 5 : 1,
                    maxLines: _brainDump ? 12 : 1,
                    style: TextStyle(fontSize: 17, color: s.onSurface),
                    textInputAction: _brainDump
                        ? TextInputAction.newline
                        : TextInputAction.done,
                    onSubmitted: _brainDump ? null : (_) => _save(),
                    decoration: InputDecoration(
                      hintText: _brainDump
                          ? 'Everything in your head, one per line.\nDon\'t sort it. Just get it out.'
                          : 'What needs doing?',
                      suffixIcon: VoiceButton(
                        controller: _title,
                        newLine: _brainDump,
                      ),
                    ),
                  ),
                  if (_notes.isNotEmpty && !_brainDump)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.notes_rounded, size: 16, color: s.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Note: $_notes',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: s.muted),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove note',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: () => setState(() => _notes = ''),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  if (parsed != null && parsed.understoodAnything)
                    _Understood(
                      parsed: parsed,
                      resolved: r!,
                      onIgnore: (key) => setState(() => _ignored.add(key)),
                    ),
                  if (_brainDump)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Lines can include things like "tomorrow", '
                        '"15 min" or "#tag".',
                        style: TextStyle(fontSize: 13, color: s.muted),
                      ),
                    ),
                  PhiWarning(
                    text: '${_title.text}\n$_notes',
                    workspace: workspace,
                  ),
                  if (!_brainDump) ...[
                    section(
                      'How long?',
                      ChoiceGroup(
                        values: estimatePresets,
                        selected: estimate,
                        mono: true,
                        labelOf: shortMinutes,
                        onSelected: (m) => setState(() {
                          _estimate = m;
                          _estimateTouched = true;
                        }),
                      ),
                    ),
                    section(
                      'Priority',
                      ChoiceGroup(
                        values: Priority.values,
                        selected: priority,
                        labelOf: (p) => p.label,
                        onSelected: (p) => setState(() {
                          _priority = p;
                          _priorityTouched = true;
                        }),
                      ),
                    ),
                    section(
                      'How much do you dread it?',
                      ChoiceGroup(
                        values: [for (var i = 0; i < ughLabels.length; i++) i],
                        selected: _ugh,
                        labelOf: (i) => ughLabels[i],
                        onSelected: (i) => setState(() => _ugh = i),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  // Where it goes and whether it's an errand: two yes/no
                  // facts, kept apart from the dread scale above.
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (!ref.watch(deviceWorkspacesProvider).single)
                        SizedBox(
                          width: 220,
                          child: Segmented<Workspace>(
                            values: Workspace.values,
                            selected: workspace,
                            inset: s.isDark,
                            labelOf: (w) => w.label,
                            onSelected: (w) => setState(() {
                              _workspace = w;
                              _workspaceTouched = true;
                              if (_project?.workspace != w) _project = null;
                            }),
                          ),
                        ),
                      if (project case final p?)
                        Pill(
                          label: p.name,
                          icon: Icons.folder_outlined,
                          selected: true,
                          onTap: () => setState(() {
                            if (_project == p) {
                              _project = null;
                            } else {
                              // Came from a #tag: leave the #tag in the title.
                              _ignored.add(qkTag(normalizeTag(p.name)));
                            }
                          }),
                        ),
                      if (!_brainDump)
                        Pill(
                          label: 'Leave the house',
                          icon: Icons.directions_car_outlined,
                          selected: _leave,
                          onTap: () => setState(() => _leave = !_leave),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Pinned below the scrolling fields so the buttons stay visible
          // however long the form gets.
          Padding(
            padding: EdgeInsets.fromLTRB(side, 12, side, 16),
            child: Row(
              children: [
                if (!_brainDump) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _canSave ? () => _save(start: true) : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      child: const Text('Add & start'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    child: Text(_brainDump ? 'Capture all' : 'Add'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Resolved {
  const _Resolved({
    required this.title,
    required this.workspace,
    required this.project,
    required this.estimate,
    required this.priority,
    required this.dueAt,
    required this.tags,
  });
  final String title;
  final Workspace workspace;
  final Project? project;
  final int estimate;
  final Priority priority;
  final DateTime? dueAt;
  final List<String> tags;
}

/// What was picked up from the typed text, as chips. Tapping one leaves
/// those words in the title instead.
class _Understood extends StatelessWidget {
  const _Understood({
    required this.parsed,
    required this.resolved,
    required this.onIgnore,
  });
  final QuickParse parsed;
  final _Resolved resolved;
  final ValueChanged<String> onIgnore;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final project = resolved.project;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in parsed.bits)
                Pill(
                  label:
                      project != null &&
                          b.key == qkTag(normalizeTag(project.name))
                      ? project.name
                      : b.label,
                  icon: switch (b.key) {
                    qkDue => Icons.event_outlined,
                    qkLength => Icons.timer_outlined,
                    qkPriority => Icons.flag_outlined,
                    qkWorkspace => Icons.work_outline_rounded,
                    _
                        when project != null &&
                            b.key == qkTag(normalizeTag(project.name)) =>
                      Icons.folder_outlined,
                    _ => Icons.tag_rounded,
                  },
                  selected: true,
                  onTap: () => onIgnore(b.key),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Saving as "${parsed.title}". Tap a chip to keep it as words.',
            style: TextStyle(fontSize: 12.5, color: s.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}
