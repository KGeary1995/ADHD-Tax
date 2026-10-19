import 'package:flutter/material.dart';

import '../settings/device_workspaces.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import 'notes_controller.dart';
import 'project_widgets.dart';

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

    return ContentWidth(
      child: ListView(
        padding: EdgeInsets.fromLTRB(22, 24, 22, navClearance(context)),
        children: [
          PageHeader(
            'Notes',
            subtitle: all.isEmpty
                ? 'Thoughts, call outcomes, meeting notes'
                : '${all.length} ${all.length == 1 ? 'note' : 'notes'}',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _search,
            onChanged: ctl.query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search notes and #tags',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        ctl.query('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in [
                if (!ref.watch(deviceWorkspacesProvider).single) ...[
                  null,
                  ...Workspace.values,
                ],
              ])
                Pill(
                  label: w?.label ?? 'Everything',
                  selected: filter.workspace == w,
                  solid: true,
                  onTap: () => ctl.workspace(w),
                ),
            ],
          ),
          if (projects.isNotEmpty) ...[
            const SizedBox(height: 14),
            const FieldLabel('Projects'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in projects)
                  Pill(
                    label: p.name,
                    icon: Icons.circle,
                    iconColor: s.projectColor(p.color),
                    selected: filter.projectId == p.id,
                    onTap: () =>
                        ctl.project(filter.projectId == p.id ? null : p.id),
                  ),
              ],
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            const FieldLabel('Tags'),
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
          ],
          const SizedBox(height: 22),
          if (all.isEmpty)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get it out of your head.', style: s.display(24)),
                  const SizedBox(height: 8),
                  Text(
                    'Jot it down now, sort it later. Put it in a project, '
                    'tag it with #words, and turn any line into a task when '
                    'you\'re ready.',
                    style: TextStyle(color: s.muted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => openNewNote(context, ref),
                    child: const Text('New note'),
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
            SectionTitle('Pinned', count: pinned.length),
            for (final n in pinned) NoteTile(note: n),
            const SizedBox(height: 22),
          ],
          if (rest.isNotEmpty) ...[
            if (pinned.isNotEmpty) SectionTitle('Notes', count: rest.length),
            for (final n in rest) NoteTile(note: n),
          ],
        ],
      ),
    );
  }
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Panel(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        onTap: () => context.push('/note/${note.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.heading,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface,
                    ),
                  ),
                ),
                if (note.pinned)
                  Icon(Icons.push_pin_rounded, size: 16, color: s.primary),
              ],
            ),
            if (note.preview.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: s.text2, height: 1.35),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _when(note.updatedAt, now),
                  style: s.mono(12, color: s.muted),
                ),
                ?(project == null ? null : ProjectLabel(project)),
                for (final t in tags.take(4))
                  Text('#$t', style: TextStyle(fontSize: 13, color: s.primary)),
                if (tags.length > 4)
                  Text(
                    '+${tags.length - 4}',
                    style: TextStyle(fontSize: 13, color: s.muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _when(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final d = today.difference(day).inDays;
  if (d == 0) return formatClock(at);
  if (d == 1) return 'Yesterday';
  return formatDate(at);
}
