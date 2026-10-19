import 'dart:async';

import '../settings/device_workspaces.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../widgets/ui.dart';
import '../capture/voice_input.dart';
import '../safety/phi_warning.dart';
import '../tasks/tasks_controller.dart';
import 'notes_controller.dart';
import 'project_widgets.dart';

/// A note, saved as you type. `noteId == 'new'` starts one; it's only
/// stored once something has been written.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.noteId,
    this.workspace = Workspace.personal,
    this.projectId = '',
    this.taskId = '',
    this.tag,
  });

  final String noteId;

  /// Starting values for a new note.
  final Workspace workspace;
  final String projectId;
  final String taskId;
  final String? tag;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late Note _note;
  late bool _stored;
  late final TextEditingController _title;
  late final TextEditingController _body;
  Timer? _debounce;
  var _deleted = false;

  // Held directly: the last save runs in dispose(), where ref can't be used.
  late final NotesController _notes = ref.read(notesProvider.notifier);

  @override
  void initState() {
    super.initState();
    final existing = _notes.byId(widget.noteId);
    _stored = existing != null;
    final now = ref.read(clockProvider)();
    _note =
        existing ??
        Note(
          id: '',
          workspace: widget.workspace,
          projectId: widget.projectId,
          taskId: widget.taskId,
          tags: [?widget.tag],
          createdAt: now,
          updatedAt: now,
        );
    _title = TextEditingController(text: _note.title)..addListener(_changed);
    _body = TextEditingController(text: _note.body)..addListener(_changed);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _save();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  /// Writes the note if anything changed. A new note isn't stored until
  /// it has words in it, so opening and closing leaves nothing behind.
  void _save() {
    if (_deleted) return;
    final next = _note.copyWith(title: _title.text, body: _body.text);
    final notes = _notes;
    if (!_stored) {
      if (next.isEmpty) return;
      _note = notes.create(
        workspace: next.workspace,
        title: next.title,
        body: next.body,
        projectId: next.projectId,
        taskId: next.taskId,
      );
      if (next.tags.isNotEmpty || next.pinned) {
        notes.save(_note.copyWith(tags: next.tags, pinned: next.pinned));
      }
      _stored = true;
      return;
    }
    final current = notes.byId(_note.id);
    final changed =
        current == null ||
        current.title != next.title ||
        current.body != next.body ||
        current.workspace != next.workspace ||
        current.projectId != next.projectId ||
        current.taskId != next.taskId ||
        current.pinned != next.pinned ||
        current.tags.join(',') != next.tags.join(',');
    if (changed) notes.save(next);
    _note = next;
  }

  void _update(Note Function(Note) f) {
    setState(() => _note = f(_note));
    _save();
  }

  Future<void> _delete() async {
    final notes = _notes;
    final messenger = ScaffoldMessenger.of(context);
    final before = _stored ? notes.byId(_note.id) : null;
    _deleted = true;
    if (before != null) notes.delete(before.id);
    if (mounted) context.pop();
    if (before != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted: ${before.heading}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => notes.restore(before),
          ),
        ),
      );
    }
  }

  Future<void> _makeTasks() async {
    _save();
    final lines = taskLinesOf(_body.text);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a line or two first.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<List<String>>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MakeTasksSheet(lines: lines),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final made = _notes.makeTasks(_note, picked);
    final project = ref.read(projectsProvider.notifier).byId(_note.projectId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Made ${made.length} ${made.length == 1 ? 'task' : 'tasks'}'
          '${project == null ? '' : ' in ${project.name}'}.',
        ),
      ),
    );
  }

  Future<void> _organize() => showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => StatefulBuilder(
      builder: (context, setSheet) => _OrganizeSheet(
        note: _note,
        onChanged: (n) {
          _update((_) => n);
          setSheet(() {});
        },
        current: () => _note,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final project = ref.watch(
      projectsProvider.select(
        (ps) => ps.where((p) => p.id == _note.projectId).firstOrNull,
      ),
    );
    final task = _note.taskId.isEmpty
        ? null
        : ref.watch(
            tasksProvider.select(
              (ts) => ts.where((t) => t.id == _note.taskId).firstOrNull,
            ),
          );
    final tags = _note.copyWith(title: _title.text, body: _body.text).allTags;

    return Scaffold(
      appBar: AppBar(
        actions: [
          VoiceButton(controller: _body, newLine: true),
          IconButton(
            tooltip: _note.pinned ? 'Unpin' : 'Pin',
            isSelected: _note.pinned,
            selectedIcon: Icon(Icons.push_pin_rounded, color: s.primary),
            icon: const Icon(Icons.push_pin_outlined),
            onPressed: () => _update((n) => n.copyWith(pinned: !n.pinned)),
          ),
          IconButton(
            tooltip: 'Make tasks',
            icon: const Icon(Icons.checklist_rounded),
            onPressed: _makeTasks,
          ),
          PopupMenuButton<String>(
            useRootNavigator: true,
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'organize') _organize();
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'organize', child: Text('Project & tags')),
              PopupMenuItem(value: 'delete', child: Text('Delete note')),
            ],
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            TextField(
              controller: _title,
              autofocus: !_stored && widget.taskId.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              style: s.display(26),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            // Where it lives, at a glance; tap to change.
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _organize,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _note.workspace.label,
                      style: s.mono(12, color: s.muted),
                    ),
                    if (project != null)
                      ProjectLabel(project)
                    else
                      Text(
                        'No project',
                        style: TextStyle(fontSize: 13, color: s.faint),
                      ),
                    for (final t in tags)
                      Text(
                        '#$t',
                        style: TextStyle(fontSize: 13, color: s.primary),
                      ),
                    Text(
                      tags.isEmpty ? '+ Tags' : 'Edit',
                      style: TextStyle(
                        fontSize: 13,
                        color: s.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (task != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Panel(
                  radius: 14,
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  onTap: () => context.push('/task/${task.id}'),
                  child: Row(
                    children: [
                      Icon(Icons.task_alt_rounded, size: 18, color: s.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'For: ${task.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: s.text2),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Unlink from task',
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: s.muted,
                        ),
                        onPressed: () => _update((n) => n.copyWith(taskId: '')),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              autofocus: !_stored && widget.taskId.isNotEmpty,
              minLines: 10,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 16, height: 1.5, color: s.onSurface),
              decoration: InputDecoration(
                hintText:
                    'Write anything. One idea per line makes "Make tasks" '
                    'easy. Add #tags as you go.',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            PhiWarning(
              text: '${_title.text}\n${_body.text}',
              workspace: _note.workspace,
            ),
          ],
        ),
      ),
    );
  }
}

/// Workspace, project and tags for a note.
class _OrganizeSheet extends ConsumerStatefulWidget {
  const _OrganizeSheet({
    required this.note,
    required this.onChanged,
    required this.current,
  });
  final Note note;
  final ValueChanged<Note> onChanged;
  final Note Function() current;

  @override
  ConsumerState<_OrganizeSheet> createState() => _OrganizeSheetState();
}

class _OrganizeSheetState extends ConsumerState<_OrganizeSheet> {
  final _tag = TextEditingController();

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  void _addTags(String text) {
    final n = widget.current();
    final added = parseTags(text).where((t) => !n.tags.contains(t));
    if (added.isNotEmpty) {
      widget.onChanged(n.copyWith(tags: [...n.tags, ...added]));
    }
    _tag.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final n = widget.current();
    final hashtags = {...hashtagsIn(n.title), ...hashtagsIn(n.body)};
    final suggestions = {
      for (final other in ref.watch(notesProvider))
        if (other.workspace == n.workspace) ...other.allTags,
    }.where((t) => !n.allTags.contains(t)).toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Organize', style: s.display(26)),
            const SizedBox(height: 16),
            if (!ref.watch(deviceWorkspacesProvider).single) ...[
              const FieldLabel('Workspace'),
              ChoiceGroup(
                values: Workspace.values,
                selected: n.workspace,
                labelOf: (w) => w.label,
                // A project belongs to one workspace.
                onSelected: (w) => widget.onChanged(
                  n.copyWith(
                    workspace: w,
                    projectId: w == n.workspace ? n.projectId : '',
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            const FieldLabel('Project'),
            ProjectPicker(
              workspace: n.workspace,
              selected: n.projectId,
              onSelected: (id) => widget.onChanged(n.copyWith(projectId: id)),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Tags'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in n.tags)
                  InputChip(
                    label: Text('#$t'),
                    onDeleted: () => widget.onChanged(
                      n.copyWith(tags: [...n.tags]..remove(t)),
                    ),
                    deleteButtonTooltipMessage: 'Remove #$t',
                  ),
                for (final t in hashtags.where((t) => !n.tags.contains(t)))
                  Chip(label: Text('#$t')),
              ],
            ),
            if (hashtags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Tags without an × come from #words in the note.',
                  style: TextStyle(fontSize: 12, color: s.muted),
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _tag,
              textInputAction: TextInputAction.done,
              onSubmitted: _addTags,
              decoration: InputDecoration(
                hintText: 'Add a tag, e.g. billing',
                prefixText: '#',
                suffixIcon: IconButton(
                  tooltip: 'Add tag',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _addTags(_tag.text),
                ),
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in suggestions.take(12))
                    Pill(
                      label: '#$t',
                      icon: Icons.add_rounded,
                      selected: false,
                      onTap: () => _addTags(t),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pick which lines of a note become tasks.
class _MakeTasksSheet extends StatefulWidget {
  const _MakeTasksSheet({required this.lines});
  final List<String> lines;

  @override
  State<_MakeTasksSheet> createState() => _MakeTasksSheetState();
}

class _MakeTasksSheetState extends State<_MakeTasksSheet> {
  late final _picked = <int>{};

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final n = _picked.length;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Make tasks', style: s.display(26)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Tick the lines that are things to do.',
              style: TextStyle(color: s.muted),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (i, line) in widget.lines.indexed)
                  CheckboxListTile(
                    value: _picked.contains(i),
                    title: Text(line),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(
                      () => v == true ? _picked.add(i) : _picked.remove(i),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: n == 0
                  ? null
                  : () => Navigator.pop(context, [
                      for (final i in _picked.toList()..sort()) widget.lines[i],
                    ]),
              child: Text(
                n == 0 ? 'Make tasks' : 'Make $n ${n == 1 ? 'task' : 'tasks'}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
