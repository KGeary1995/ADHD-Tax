import 'dart:async';

import '../settings/device_workspaces.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/links.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../widgets/ui.dart';
import '../tasks/checklist_editor.dart';
import '../capture/voice_input.dart';
import '../safety/phi_warning.dart';
import '../tasks/tasks_controller.dart';
import '../templates/templates_controller.dart';
import 'note_links.dart';
import 'notes_controller.dart';
import 'project_widgets.dart';
import '../../core/theme/ph.dart';

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
  late final LinkTextController _body;
  final _bodyFocus = FocusNode();
  Timer? _debounce;
  var _deleted = false;

  // The last save runs in dispose(), where ref can't be used. Keep the
  // container, not the controller: the controller is replaced whenever
  // the notes provider rebuilds (a sync arriving, say) and a stale one
  // throws.
  late final ProviderContainer _container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  NotesController get _notes => _container.read(notesProvider.notifier);

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
    _body = LinkTextController(text: _note.body)..addListener(_changed);
    // The link bar shows only while the body has focus.
    _bodyFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _save();
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
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

  /// The `[[link` being typed at the cursor, if any.
  ({String query, int start})? get _openLink {
    final sel = _body.selection;
    if (!_bodyFocus.hasFocus || !sel.isValid || !sel.isCollapsed) return null;
    return openLinkAt(_body.text, sel.baseOffset);
  }

  /// Starts a link at the cursor, or wraps the selected words in one.
  void _startLink() {
    final v = _body.value;
    final start = v.selection.isValid ? v.selection.start : v.text.length;
    final end = v.selection.isValid ? v.selection.end : start;
    final words = v.text.substring(start, end).trim();
    final insert = words.isEmpty ? '[[' : '[[$words]]';
    _body.value = TextEditingValue(
      text: v.text.replaceRange(start, end, insert),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _bodyFocus.requestFocus();
  }

  void _pickLink(String name) {
    final r = completeLink(_body.text, _body.selection.baseOffset, name);
    _body.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.cursor),
    );
  }

  void _update(Note Function(Note) f) {
    setState(() => _note = f(_note));
    _save();
  }

  void _saveAsTemplate() {
    final n = _note.copyWith(title: _title.text, body: _body.text);
    if (n.isEmpty) return;
    final t = ref.read(templatesProvider.notifier).fromNote(n);
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
    final picked = await showAppSheet<List<String>>(
      context: context,
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

  Future<void> _organize() => showAppSheet<void>(
    context: context,
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

    // A small phone: Make tasks as an icon, so the bar fits.
    final narrow = MediaQuery.sizeOf(context).width < 400;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Ph.caretLeft),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          VoiceButton(controller: _body, newLine: true),
          IconButton(
            tooltip: 'Link a task or note',
            icon: Icon(Ph.linkSimple, size: 20, color: s.ink2),
            onPressed: _startLink,
          ),
          IconButton(
            tooltip: _note.pinned ? 'Unpin' : 'Pin',
            isSelected: _note.pinned,
            selectedIcon: Icon(Ph.pushPinFill, size: 20, color: s.accentText),
            icon: Icon(Ph.pushPin, size: 20, color: s.ink2),
            onPressed: () => _update((n) => n.copyWith(pinned: !n.pinned)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: 'Make tasks',
              child: narrow
                  ? IconButton(
                      onPressed: _makeTasks,
                      icon: Icon(Ph.listChecks, size: 20, color: s.ink),
                    )
                  : OutlinedButton.icon(
                      onPressed: _makeTasks,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: Fonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Ph.listChecks, size: 16),
                      label: const Text('Make tasks'),
                    ),
            ),
          ),
          PopupMenuButton<String>(
            useRootNavigator: true,
            tooltip: 'More',
            icon: Icon(Ph.dotsThreeVertical, color: s.ink2),
            onSelected: (v) {
              if (v == 'organize') _organize();
              if (v == 'template') _saveAsTemplate();
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'organize', child: Text('Project & tags')),
              PopupMenuItem(value: 'template', child: Text('Save as template')),
              PopupMenuItem(value: 'delete', child: Text('Delete note')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ContentWidth(
              maxWidth: 720,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  26,
                  8,
                  26,
                  MediaQuery.paddingOf(context).bottom + 32,
                ),
                children: [
                  // Where it lives, at a glance; tap to change.
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _organize,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: WsDot(
                                  s.workspaceColor(
                                    _note.workspace == Workspace.work,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(
                              text: [
                                _note.workspace.label,
                                project?.name ?? 'No project',
                              ].join(' · '),
                            ),
                            TextSpan(
                              text: tags.isEmpty
                                  ? ' · + Tags'
                                  : ' · ${tags.map((t) => '#$t').join(' ')}',
                              style: TextStyle(color: s.accentText),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: s.ink2,
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _title,
                    autofocus: !_stored && widget.taskId.isEmpty,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    style: s.display(28),
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  if (task != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Panel(
                        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                        onTap: () => context.push('/task/${task.id}'),
                        child: Row(
                          children: [
                            Icon(Ph.checkSquare, size: 18, color: s.accentText),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'For: ${task.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: s.ink2,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Unlink from task',
                              icon: Icon(Ph.x, size: 18, color: s.ink3),
                              onPressed: () =>
                                  _update((n) => n.copyWith(taskId: '')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _body,
                    focusNode: _bodyFocus,
                    autofocus: !_stored && widget.taskId.isNotEmpty,
                    minLines: 10,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                      color: s.ink,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Write anything. One idea per line makes "Make tasks" '
                          'easy. Add #tags as you go, and type [[ to link a task '
                          'or note.',
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
                  NoteLinksPanel(
                    text: '${_title.text}\n${_body.text}',
                    title: _title.text,
                    noteId: _note.id,
                    workspace: _note.workspace,
                    projectId: _note.projectId,
                  ),
                ],
              ),
            ),
          ),
          if (_openLink case final open?)
            LinkSuggestionBar(
              query: open.query,
              workspace: _note.workspace,
              excludeNoteId: _note.id,
              onPick: _pickLink,
            ),
        ],
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
                  icon: const Icon(Ph.plusBold),
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
                      icon: Ph.plusBold,
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
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, Gap.s4),
            child: SheetTitle(
              'Make tasks',
              subtitle: 'Tick the lines that are things to do.',
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                for (final (i, line) in widget.lines.indexed)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: s.line)),
                    ),
                    child: ChecklistRow(
                      item: ChecklistItem(line, done: _picked.contains(i)),
                      onToggle: () => setState(
                        () => _picked.contains(i)
                            ? _picked.remove(i)
                            : _picked.add(i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, Gap.s8, 24, 16),
            child: PrimaryButton(
              label: n == 0
                  ? 'Make tasks'
                  : 'Make $n ${n == 1 ? 'task' : 'tasks'}',
              onPressed: n == 0
                  ? null
                  : () => Navigator.pop(context, [
                      for (final i in _picked.toList()..sort()) widget.lines[i],
                    ]),
            ),
          ),
        ],
      ),
    );
  }
}
