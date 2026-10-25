import 'package:flutter/material.dart';

import '../settings/device_workspaces.dart';
import '../settings/settings_button.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import 'notes_controller.dart';
import '../../data/models/template.dart';
import '../templates/templates_screen.dart';
import '../../core/theme/ph.dart';

/// What the Notes list shows. Kept while switching tabs.
class NotesFilter {
  const NotesFilter({
    this.workspace,
    this.projectId,
    this.tag,
    this.query = '',
  });
  final Workspace? workspace;
  final String? projectId;
  final String? tag;
  final String query;

  bool shows(Note n) =>
      (workspace == null || n.workspace == workspace) &&
      (projectId == null || n.projectId == projectId) &&
      (tag == null || n.allTags.contains(tag)) &&
      n.matches(query);
}

final notesFilterProvider =
    NotifierProvider<NotesFilterController, NotesFilter>(
      NotesFilterController.new,
    );

class NotesFilterController extends Notifier<NotesFilter> {
  @override
  NotesFilter build() {
    ref.watch(deviceWorkspacesProvider); // reset when that changes
    return const NotesFilter();
  }

  void workspace(Workspace? w) => state = NotesFilter(
    workspace: w,
    // A project or tag from the other workspace would hide everything.
    projectId: null,
    tag: state.tag,
    query: state.query,
  );

  void project(String? id) => state = NotesFilter(
    workspace: state.workspace,
    projectId: id,
    tag: state.tag,
    query: state.query,
  );

  void tag(String? t) => state = NotesFilter(
    workspace: state.workspace,
    projectId: state.projectId,
    tag: t,
    query: state.query,
  );

  void query(String q) => state = NotesFilter(
    workspace: state.workspace,
    projectId: state.projectId,
    tag: state.tag,
    query: q,
  );
}

/// Opens a new note, filed under whatever the list is filtered to.
void openNewNote(BuildContext context, WidgetRef ref) {
  final f = ref.read(notesFilterProvider);
  final project = ref.read(projectsProvider.notifier).byId(f.projectId ?? '');
  final ws =
      project?.workspace ??
      f.workspace ??
      ref.read(deviceWorkspacesProvider).primary;
  final q = {'ws': ws.name, 'project': ?project?.id, 'tag': ?f.tag};
  context.push(Uri(path: '/note/new', queryParameters: q).toString());
}

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  late final _search = TextEditingController(
    text: ref.read(notesFilterProvider).query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final filter = ref.watch(notesFilterProvider);
    final ctl = ref.read(notesFilterProvider.notifier);
    final all = ref.watch(notesProvider);
    final projects = ref
        .watch(projectsProvider)
        .where(
          (p) => filter.workspace == null || p.workspace == filter.workspace,
        )
        .toList();
    final inWorkspace = all
        .where(
          (n) => filter.workspace == null || n.workspace == filter.workspace,
        )
        .toList();
    final tags = {for (final n in inWorkspace) ...n.allTags}.toList()..sort();
    final shown = all.where(filter.shows).toList();
    final pinned = shown.where((n) => n.pinned).toList();
    final rest = shown.where((n) => !n.pinned).toList();
    final filtered =
        filter.projectId != null ||
        filter.tag != null ||
        filter.query.trim().isNotEmpty;

    final single = ref.watch(deviceWorkspacesProvider).single;
    Future<void> fromTemplate() async {
      final t = await pickTemplate(context, ref, TemplateKind.note);
      if (t != null && context.mounted) useTemplate(context, ref, t);
    }

    final search = TextField(
      controller: _search,
      onChanged: ctl.query,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search notes and #tags',
        fillColor: Colors.transparent,
        prefixIcon: const Icon(Ph.magnifyingGlass, size: 19),
        suffixIcon: filter.query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Ph.x),
                onPressed: () {
                  _search.clear();
                  ctl.query('');
                },
              ),
      ),
    );

    final sidebar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!single)
          SideSection(
            label: 'Show',
            children: [
              for (final w in [null, ...Workspace.values])
                SideItem(
                  label: w?.label ?? 'Everything',
                  icon: switch (w) {
                    null => Ph.infinity,
                    Workspace.work => Ph.briefcase,
                    Workspace.personal => Ph.houseSimple,
                  },
                  count: all.where((n) => w == null || n.workspace == w).length,
                  selected: filter.workspace == w,
                  onTap: () => ctl.workspace(w),
                ),
            ],
          ),
        if (projects.isNotEmpty)
          SideSection(
            label: 'Projects',
            children: [
              for (final p in projects)
                SideItem(
                  label: p.name,
                  dot: s.projectColor(p.color),
                  count: all.where((n) => n.projectId == p.id).length,
                  selected: filter.projectId == p.id,
                  onTap: () =>
                      ctl.project(filter.projectId == p.id ? null : p.id),
                ),
            ],
          ),
        if (tags.isNotEmpty)
          SideSection(
            label: 'Tags',
            children: [
              for (final t in tags)
                SideItem(
                  label: '#$t',
                  icon: Ph.hash,
                  count: inWorkspace.where((n) => n.allTags.contains(t)).length,
                  selected: filter.tag == t,
                  onTap: () => ctl.tag(filter.tag == t ? null : t),
                ),
            ],
          ),
        SideSection(
          label: 'Start from',
          children: [
            SideItem(label: 'A template', icon: Ph.note, onTap: fromTemplate),
          ],
        ),
      ],
    );

    return SidebarLayout(
      sidebar: sidebar,
      builder: (context, wide) => ListView(
        padding: EdgeInsets.fromLTRB(
          wide ? 12 : 22,
          wide ? 40 : 24,
          22,
          navClearance(context),
        ),
        children: [
          PageHeader(
            'Notes',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SquareIconButton(
                  icon: Ph.notePencil,
                  tooltip: 'New note',
                  onPressed: () => openNewNote(context, ref),
                ),
                if (hasSettingsButton(context)) ...[
                  const SizedBox(width: Gap.s4),
                  const SettingsButton(),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gap.s6),
          search,
          if (!wide) ...[
            const SizedBox(height: Gap.s5),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (!single)
                  for (final w in [null, ...Workspace.values])
                    Pill(
                      label: w?.label ?? 'All',
                      dot: switch (w) {
                        null => s.star,
                        Workspace.personal => s.personal,
                        Workspace.work => s.work,
                      },
                      selected: filter.workspace == w,
                      solid: true,
                      onTap: () => ctl.workspace(w),
                    ),
                _TagsPill(
                  active: filter.projectId != null || filter.tag != null,
                  label: switch ((filter.projectId, filter.tag)) {
                    (_, final String tag) => tag,
                    (final String id, _) =>
                      projects.where((p) => p.id == id).firstOrNull?.name ??
                          'Tags',
                    _ => 'Tags',
                  },
                  onTap: () => _showTagsSheet(
                    context,
                    projects: projects,
                    tags: tags,
                    fromTemplate: fromTemplate,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get it out of your head.', style: s.display(24)),
                  const SizedBox(height: Gap.s4),
                  Text(
                    'Jot it down now, sort it later. Put it in a project, '
                    'tag it with #words, and turn any line into a task when '
                    'you\'re ready.',
                    style: TextStyle(color: s.ink2, height: 1.45),
                  ),
                  const SizedBox(height: Gap.s7),
                  SizedBox(
                    width: 180,
                    child: PrimaryButton(
                      label: 'New note',
                      onPressed: () => openNewNote(context, ref),
                    ),
                  ),
                ],
              ),
            )
          else if (shown.isEmpty)
            Text(
              filtered ? 'No notes match.' : 'No notes here yet.',
              style: TextStyle(color: s.muted),
            ),
          if (pinned.isNotEmpty) ...[
            Row(
              children: [
                Icon(Ph.pushPinFill, size: 16, color: s.accentText),
                const SizedBox(width: Gap.s3),
                Text('Pinned', style: s.display(15)),
              ],
            ),
            const SizedBox(height: Gap.s2),
            _NoteGrid(notes: pinned),
            const SizedBox(height: Gap.s9),
          ],
          if (rest.isNotEmpty) ...[
            if (pinned.isNotEmpty) ...[
              Text('Recent', style: s.display(15)),
              const SizedBox(height: Gap.s2),
            ],
            _NoteGrid(notes: rest),
          ],
        ],
      ),
    );
  }
}

/// Notes in one column on a phone, two or three side by side when there's
/// room.
class _NoteGrid extends StatelessWidget {
  const _NoteGrid({required this.notes});
  final List<Note> notes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
      if (cols == 1) {
        return Column(children: [for (final n in notes) NoteTile(note: n)]);
      }
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        children: [
          for (final n in notes)
            SizedBox(
              width: w,
              child: NoteTile(note: n),
            ),
        ],
      );
    },
  );
}

/// Deletes a note with an Undo bar, like tasks.
void deleteNoteWithUndo(BuildContext context, WidgetRef ref, Note n) {
  final notes = ref.read(notesProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  notes.delete(n.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Deleted: ${n.heading}'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notes.restore(n),
        ),
      ),
    );
}

class NoteTile extends ConsumerWidget {
  const NoteTile({super.key, required this.note, this.showProject = true});
  final Note note;
  final bool showProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final project = showProject
        ? ref.watch(
            projectsProvider.select(
              (ps) => ps.where((p) => p.id == note.projectId).firstOrNull,
            ),
          )
        : null;
    final now = ref.read(clockProvider)();
    final tags = note.allTags;
    final meta = [_when(note.updatedAt, now), ?project?.name].join(' · ');
    return SwipeActions(
      key: ValueKey('note-${note.id}'),
      onDelete: () => deleteNoteWithUndo(context, ref, note),
      child: InkWell(
        onTap: () => context.push('/note/${note.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: s.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.heading,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.ink,
                ),
              ),
              if (note.preview.isNotEmpty) ...[
                const SizedBox(height: Gap.s2),
                Text(
                  note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: s.ink2, height: 1.45),
                ),
              ],
              const SizedBox(height: Gap.s3),
              Text.rich(
                TextSpan(
                  text: meta,
                  children: [
                    if (tags.isNotEmpty)
                      TextSpan(
                        text:
                            ' · ${tags.take(4).map((t) => '#$t').join(' ')}'
                            '${tags.length > 4 ? ' +${tags.length - 4}' : ''}',
                        style: TextStyle(
                          color: s.accentText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                style: s.caption(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "# Tags": opens projects, tags and templates. Shows what's chosen.
class _TagsPill extends StatelessWidget {
  const _TagsPill({
    required this.active,
    required this.label,
    required this.onTap,
  });
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final fg = active ? s.bg : s.ink;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(color: active ? s.ink : s.line2, width: 2),
    );
    return Semantics(
      button: true,
      label: 'Projects and tags',
      child: Material(
        color: active ? s.ink : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: active ? s.bg : s.ink3,
                    ),
                  ),
                  const SizedBox(width: Gap.s3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: fg,
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

/// Phone: pick a project or a tag, or start from a template.
Future<void> _showTagsSheet(
  BuildContext context, {
  required List<Project> projects,
  required List<String> tags,
  required Future<void> Function() fromTemplate,
}) => showAppSheet<void>(
  context: context,
  builder: (ctx) => SafeArea(
    child: SingleChildScrollView(
      padding: sheetPadding,
      child: Consumer(
        builder: (ctx, ref, _) {
          final filter = ref.watch(notesFilterProvider);
          final ctl = ref.read(notesFilterProvider.notifier);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('Projects and tags'),
              const SizedBox(height: Gap.s7),
              if (projects.isNotEmpty) ...[
                const OptionLabel('Project'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in projects)
                      Pill(
                        label: p.name,
                        dot: ctx.spec.projectColor(p.color),
                        selected: filter.projectId == p.id,
                        onTap: () =>
                            ctl.project(filter.projectId == p.id ? null : p.id),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.s7),
              ],
              if (tags.isNotEmpty) ...[
                const OptionLabel('Tag'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in tags)
                      Pill(
                        label: '#$t',
                        selected: filter.tag == t,
                        onTap: () => ctl.tag(filter.tag == t ? null : t),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.s7),
              ],
              OutlineButton(
                label: 'From a template',
                icon: Ph.copySimple,
                quiet: true,
                fontSize: 15,
                height: 48,
                onPressed: () {
                  Navigator.pop(ctx);
                  fromTemplate();
                },
              ),
              const SizedBox(height: Gap.s6),
              PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
            ],
          );
        },
      ),
    ),
  ),
);

String _when(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final d = today.difference(day).inDays;
  if (d == 0) return formatClock(at);
  if (d == 1) return 'Yesterday';
  return formatDate(at);
}
