import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/links.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../widgets/ui.dart';
import '../tasks/tasks_controller.dart';
import 'notes_controller.dart';

/// A text controller that shows `[[links]]` in the accent color as you
/// type. While the keyboard is still composing a word it draws plain text,
/// so the composing underline keeps working.
class LinkTextController extends TextEditingController {
  LinkTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final s = context.spec;
    final link = TextStyle(color: s.primary, fontWeight: FontWeight.w600);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in wikiLinkPattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(text: m.group(0), style: link));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}

/// One tappable line pointing at a task or note.
class LinkRow extends StatelessWidget {
  const LinkRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.onTap,
    this.trailing,
    this.dim = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// For a link that doesn't point anywhere yet.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Panel(
        radius: 14,
        color: s.isDark ? null : s.background,
        padding: EdgeInsets.fromLTRB(14, 10, trailing == null ? 14 : 6, 10),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 18, color: dim ? s.faint : s.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: dim ? s.muted : s.onSurface,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: s.muted),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Tasks and notes to link to while typing `[[…`: the ones whose name
/// contains what's been typed, unfinished tasks first. With nothing typed
/// yet, the most recently touched ones.
List<LinkTarget> linkSuggestions(
  String query, {
  required Workspace workspace,
  required Iterable<Task> tasks,
  required Iterable<Note> notes,
  String excludeNoteId = '',
  int limit = 8,
}) {
  final q = linkKey(query);
  bool hit(String name) => q.isEmpty || linkKey(name).contains(q);
  final ts =
      [
        for (final t in tasks)
          if (t.workspace == workspace &&
              t.status != TaskStatus.archived &&
              t.title.trim().isNotEmpty &&
              hit(t.title))
            t,
      ]..sort((a, b) {
        final ad = a.status == TaskStatus.done ? 1 : 0;
        final bd = b.status == TaskStatus.done ? 1 : 0;
        if (ad != bd) return ad - bd;
        return b.updatedAt.compareTo(a.updatedAt);
      });
  final ns = [
    for (final n in notes)
      if (n.id != excludeNoteId &&
          n.workspace == workspace &&
          n.title.trim().isNotEmpty &&
          hit(n.heading))
        n,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  // One per name: a repeating task leaves finished copies with its title.
  final seen = <String>{};
  return [
    for (final t in ts)
      if (seen.add(linkKey(t.title))) TaskLink(t.title.trim(), t),
    for (final n in ns)
      if (seen.add(linkKey(n.heading))) NoteLink(n.heading, n),
  ].take(limit).toList();
}

/// The bar of choices above the keyboard while a `[[link` is being typed.
class LinkSuggestionBar extends ConsumerWidget {
  const LinkSuggestionBar({
    super.key,
    required this.query,
    required this.workspace,
    required this.excludeNoteId,
    required this.onPick,
  });

  final String query;
  final Workspace workspace;
  final String excludeNoteId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final found = linkSuggestions(
      query,
      workspace: workspace,
      tasks: ref.watch(tasksProvider),
      notes: ref.watch(notesProvider),
      excludeNoteId: excludeNoteId,
    );
    final typed = query.trim();
    final exact = found.any((f) => linkKey(f.name) == linkKey(typed));
    return Material(
      color: s.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: s.hairline)),
        ),
        child: SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              if (found.isEmpty && typed.isEmpty)
                Center(
                  child: Text(
                    'Type the name of a task or note',
                    style: TextStyle(color: s.muted, fontSize: 13),
                  ),
                ),
              for (final f in found)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Pill(
                    label: f.name,
                    icon: f is TaskLink
                        ? Icons.task_alt_rounded
                        : Icons.sticky_note_2_outlined,
                    selected: false,
                    onTap: () => onPick(f.name),
                  ),
                ),
              if (typed.isNotEmpty && !exact)
                Pill(
                  label: 'Link "$typed"',
                  icon: Icons.add_link_rounded,
                  selected: false,
                  onTap: () => onPick(typed),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Under a note: what its `[[links]]` point at, and the notes that link
/// to it. Hidden when there's neither.
class NoteLinksPanel extends ConsumerWidget {
  const NoteLinksPanel({
    super.key,
    required this.text,
    required this.title,
    required this.noteId,
    required this.workspace,
    required this.projectId,
  });

  /// Title and body, where the links are written.
  final String text;

  /// The note's own title; other notes link to it by this name.
  final String title;
  final String noteId;
  final Workspace workspace;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final notes = ref.watch(notesProvider);
    final targets = [
      for (final name in wikiLinksIn(text))
        resolveLink(
          name,
          workspace: workspace,
          tasks: tasks,
          notes: notes,
          excludeNoteId: noteId,
        ),
    ];
    final backlinks = title.trim().isEmpty
        ? const <Note>[]
        : notesLinkingTo(
            title,
            workspace: workspace,
            notes: notes,
            excludeNoteId: noteId,
          );
    if (targets.isEmpty && backlinks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (targets.isNotEmpty) ...[
            const FieldLabel('Links'),
            for (final t in targets)
              switch (t) {
                TaskLink(:final task) => LinkRow(
                  icon: task.status == TaskStatus.done
                      ? Icons.check_circle_rounded
                      : Icons.task_alt_rounded,
                  title: task.title,
                  subtitle: task.status == TaskStatus.done
                      ? 'Task, done'
                      : 'Task',
                  onTap: () => context.push('/task/${task.id}'),
                ),
                NoteLink(:final note) => LinkRow(
                  icon: Icons.sticky_note_2_outlined,
                  title: note.heading,
                  subtitle: 'Note',
                  onTap: () => context.push('/note/${note.id}'),
                ),
                MissingLink(:final name) => LinkRow(
                  icon: Icons.link_off_rounded,
                  title: name,
                  subtitle: 'Not a task or note yet',
                  dim: true,
                  trailing: TextButton(
                    onPressed: () {
                      ref
                          .read(tasksProvider.notifier)
                          .create(
                            title: name,
                            workspace: workspace,
                            projectId: projectId,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Made a task: $name')),
                      );
                    },
                    child: const Text('Make task'),
                  ),
                ),
              },
          ],
          if (backlinks.isNotEmpty) ...[
            if (targets.isNotEmpty) const SizedBox(height: 14),
            const FieldLabel('Linked from'),
            for (final n in backlinks)
              LinkRow(
                icon: Icons.sticky_note_2_outlined,
                title: n.heading,
                subtitle: 'Note',
                onTap: () => context.push('/note/${n.id}'),
              ),
          ],
        ],
      ),
    );
  }
}
