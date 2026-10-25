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
import '../../core/theme/ph.dart';

/// Five-second capture. Only the title is required.
Future<void> showQuickAdd(
  BuildContext context, {
  bool brainDump = false,
  String initialTitle = '',
  String initialNotes = '',
  String projectId = '',
}) async {
  QuickAddSheet sheet({bool dialog = false}) => QuickAddSheet(
    brainDump: brainDump,
    initialTitle: initialTitle,
    initialNotes: initialNotes,
    projectId: projectId,
    dialog: dialog,
  );
  // A computer gets a centered window; a phone the bottom sheet, which
  // stays in thumb reach and above the keyboard.
  final size = MediaQuery.sizeOf(context);
  final startNow = size.width >= wideBreakpoint && size.height >= 640
      ? await showDialog<Task>(
          useRootNavigator: true,
          context: context,
          builder: (_) => Dialog(
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760),
              child: sheet(dialog: true),
            ),
          ),
        )
      : await showModalBottomSheet<Task>(
          useRootNavigator: true,
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 640),
          builder: (_) => sheet(),
        );
  if (startNow != null && context.mounted) {
    openFocus(context, startNow.id, minutes: startNow.estimateMin);
  }
}

const _moreKey = 'quickadd.more';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.brainDump = false,
    this.initialTitle = '',
    this.initialNotes = '',
    this.projectId = '',
    this.dialog = false,
  });
  final bool brainDump;

  /// Shown as a centered window (desktop) rather than a bottom sheet.
  final bool dialog;

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

  /// Phone: priority, dread and "leave the house" sit behind "More
  /// options" so capture is a title and a length. Remembered on this device.
  late bool _more =
      widget.dialog || ref.read(keyValueStoreProvider).read(_moreKey) == 'open';

  void _toggleMore() {
    setState(() => _more = !_more);
    ref.read(keyValueStoreProvider).write(_moreKey, _more ? 'open' : 'closed');
  }

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
    final side = narrow ? 20.0 : 22.0;
    final single = ref.watch(deviceWorkspacesProvider).single;
    final lines = _title.text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .length;
    // Sits on top of the keyboard when it's open, above the system
    // navigation bar when it isn't.
    final bottom = MediaQuery.viewInsetsOf(context).bottom > 0
        ? MediaQuery.viewInsetsOf(context).bottom
        : MediaQuery.viewPaddingOf(context).bottom;

    Widget iconAction(IconData icon, String tip, VoidCallback onTap) =>
        IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, size: 21, color: s.ink2),
        );

    // Where it goes stays in view, so Work tasks don't land in the personal
    // account by accident.
    final workspaces = single
        ? null
        : OptionRow(
            children: [
              for (final w in Workspace.values)
                WorkspaceOption(
                  work: w == Workspace.work,
                  label: w.label,
                  selected: workspace == w,
                  onTap: () => setState(() {
                    _workspace = w;
                    _workspaceTouched = true;
                    if (_project?.workspace != w) _project = null;
                  }),
                ),
            ],
          );

    final field = TextField(
      controller: _title,
      autofocus: true,
      minLines: _brainDump ? 5 : 1,
      maxLines: _brainDump ? 12 : 3,
      style: TextStyle(
        fontSize: _brainDump ? 16 : 17,
        height: _brainDump ? 1.75 : 1.35,
        color: s.ink,
      ),
      keyboardType: TextInputType.multiline,
      textInputAction: _brainDump
          ? TextInputAction.newline
          : TextInputAction.done,
      onSubmitted: _brainDump ? null : (_) => _save(),
      decoration: InputDecoration(
        hintText: _brainDump
            ? "Everything in your head, one per line.\nDon't sort it."
            : 'e.g. Call the bank tomorrow 2pm…',
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          borderSide: BorderSide(color: s.star, width: 2),
        ),
        suffixIcon: VoiceButton(controller: _title, newLine: _brainDump),
      ),
    );

    final moreRows = [
      _OptionLine(
        label: 'Priority',
        narrow: narrow,
        children: [
          for (final p in Priority.values)
            _SmallOption(
              label: p.label,
              selected: priority == p,
              onTap: () => setState(() {
                _priority = p;
                _priorityTouched = true;
              }),
            ),
        ],
      ),
      _OptionLine(
        label: 'Dread',
        narrow: narrow,
        children: [
          for (var i = 0; i < ughLabels.length; i++)
            _SmallOption(
              label: i == 3 ? 'Dreading' : ughLabels[i],
              selected: _ugh == i,
              onTap: () => setState(() => _ugh = i),
            ),
        ],
      ),
      // A yes/no fact of its own, kept apart from the dread scale.
      SwitchRow(
        title: 'Need to leave the house',
        leading: const Icon(Ph.carSimple),
        value: _leave,
        onChanged: (v) => setState(() => _leave = v),
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                side,
                widget.dialog ? 24 : 0,
                side,
                4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _brainDump ? 'Brain dump' : 'Add a task',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: s.display(narrow ? 22 : 24),
                        ),
                      ),
                      if (_brainDump)
                        TextButton(
                          onPressed: () => setState(() => _brainDump = false),
                          child: const Text('One task'),
                        )
                      else ...[
                        iconAction(
                          Ph.lightning,
                          'Brain dump',
                          () => setState(() => _brainDump = true),
                        ),
                        iconAction(
                          Ph.copySimple,
                          'From a template',
                          _fromTemplate,
                        ),
                        iconAction(
                          Ph.arrowsOutSimple,
                          'Full form',
                          _openFullForm,
                        ),
                      ],
                    ],
                  ),
                  if (_brainDump) ...[
                    const SizedBox(height: Gap.s1),
                    Text(
                      "Everything in your head, one per line. Don't sort it. "
                      'Lines can say "tomorrow", "15 min" or "#tag".',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: s.ink2,
                      ),
                    ),
                    const SizedBox(height: Gap.s6),
                    field,
                    if (workspaces != null) ...[
                      const SizedBox(height: 12),
                      workspaces,
                    ],
                  ] else ...[
                    if (workspaces != null) ...[
                      const SizedBox(height: 12),
                      workspaces,
                    ],
                    const SizedBox(height: 12),
                    field,
                  ],
                  if (_notes.isNotEmpty && !_brainDump)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Ph.textAlignLeft, size: 16, color: s.ink3),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Note: $_notes',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: s.caption(),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove note',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: () => setState(() => _notes = ''),
                            icon: const Icon(Ph.x),
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
                  PhiWarning(
                    text: '${_title.text}\n$_notes',
                    workspace: workspace,
                  ),
                  if (project case final p?)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Pill(
                          label: p.name,
                          icon: Ph.folderSimple,
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
                      ),
                    ),
                  if (!_brainDump) ...[
                    const SizedBox(height: Gap.s6),
                    Semantics(
                      label: 'How long?',
                      container: true,
                      child: Row(
                        children: [
                          for (final (i, m) in estimatePresets.indexed) ...[
                            if (i > 0) const SizedBox(width: Gap.s3),
                            Expanded(
                              child: _SmallOption(
                                label: shortMinutes(m),
                                selected: estimate == m,
                                sora: true,
                                height: 42,
                                onTap: () => setState(() {
                                  _estimate = m;
                                  _estimateTouched = true;
                                }),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!estimatePresets.contains(estimate))
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.s3),
                        child: Text(
                          'Length: ${formatMinutes(estimate)}',
                          style: s.caption(color: s.ink2),
                        ),
                      ),
                    if (!widget.dialog)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 40),
                            textStyle: const TextStyle(
                              fontFamily: Fonts.ui,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: _toggleMore,
                          icon: Icon(
                            _more ? Ph.caretUp : Ph.caretDown,
                            size: 16,
                          ),
                          label: Text(_more ? 'Fewer options' : 'More options'),
                        ),
                      )
                    else
                      const SizedBox(height: Gap.s6),
                    if (_more)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, w) in moreRows.indexed) ...[
                              if (i > 0) const SizedBox(height: 12),
                              w,
                            ],
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Pinned below the scrolling fields so the buttons stay visible
          // however long the form gets.
          Padding(
            padding: EdgeInsets.fromLTRB(side, 12, side, 16),
            child: _brainDump
                ? PrimaryButton(
                    label: lines > 1
                        ? 'Capture $lines tasks'
                        : lines == 1
                        ? 'Capture 1 task'
                        : 'Capture all',
                    height: 58,
                    onPressed: _canSave ? _save : null,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: OutlineButton(
                          label: 'Add & start',
                          fontSize: 16,
                          onPressed: _canSave ? () => _save(start: true) : null,
                        ),
                      ),
                      const SizedBox(width: Gap.s5),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Add',
                          fontSize: 16,
                          onPressed: _canSave ? _save : null,
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

/// A compact option: lengths, priorities, dread.
class _SmallOption extends StatelessWidget {
  const _SmallOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sora = false,
    this.height = 38,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool sora;
  final double height;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final fg = selected ? s.onStar : s.ink;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(sora ? 11 : 10),
      side: BorderSide(color: selected ? s.star : s.line2, width: 2),
    );
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? s.star : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: sora
                      ? s.button(14, fg)
                      : TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fg,
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

/// "Priority  [Critical][High][Normal][Someday]": the label beside four
/// options, or above them (two by two) on a narrow phone.
class _OptionLine extends StatelessWidget {
  const _OptionLine({
    required this.label,
    required this.children,
    required this.narrow,
  });
  final String label;
  final List<Widget> children;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: s.ink2,
      ),
    );
    final big = MediaQuery.textScalerOf(context).scale(10) > 11.5;
    if (narrow || big) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text,
          const SizedBox(height: Gap.s3),
          OptionRow(children: children.sublist(0, 2)),
          const SizedBox(height: Gap.s3),
          OptionRow(children: children.sublist(2)),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 62, child: text),
        const SizedBox(width: Gap.s5),
        Expanded(child: OptionRow(children: children)),
      ],
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
                _ParsedChip(
                  label:
                      project != null &&
                          b.key == qkTag(normalizeTag(project.name))
                      ? project.name
                      : b.label,
                  icon: switch (b.key) {
                    qkDue => Ph.calendarBlank,
                    qkLength => Ph.timer,
                    qkPriority => Ph.flag,
                    qkWorkspace => Ph.briefcase,
                    _
                        when project != null &&
                            b.key == qkTag(normalizeTag(project.name)) =>
                      Ph.folderSimple,
                    _ => Ph.hash,
                  },
                  onTap: () => onIgnore(b.key),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Saving as "${parsed.title}". Tap a chip to keep it as words.',
            style: s.caption(),
          ),
        ],
      ),
    );
  }
}

/// Something understood from the typed text: a soft gold chip.
class _ParsedChip extends StatelessWidget {
  const _ParsedChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Semantics(
      button: true,
      label: '$label. Keep as words',
      excludeSemantics: true,
      child: Material(
        color: s.starSoft,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: s.accentText),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: s.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
