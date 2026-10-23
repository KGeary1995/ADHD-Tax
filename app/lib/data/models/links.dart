/// `[[Name]]` links between notes and tasks, and what counts as related.
///
/// A link is just text in a note's body, matched by name like a wiki: no ids
/// are stored, so nothing new syncs and older builds show the brackets as
/// plain text. Links only resolve inside the note's own workspace, so a
/// Personal note never points into Work. Pure Dart.
library;

import 'note.dart';
import 'task.dart';

/// `[[Name]]`: no brackets or line breaks inside, so a stray `[[` never
/// swallows the rest of a note.
final wikiLinkPattern = RegExp(r'\[\[([^\[\]\n]+)\]\]');

/// The names linked in [text], in order, each once (ignoring case).
List<String> wikiLinksIn(String text) {
  final seen = <String>{};
  return [
    for (final m in wikiLinkPattern.allMatches(text))
      if (m.group(1)!.trim() case final name
          when name.isNotEmpty && seen.add(linkKey(name)))
        name,
  ];
}

/// [text] with `[[Name]]` shown as `Name`, for previews and headings.
String withoutLinkBrackets(String text) =>
    text.replaceAllMapped(wikiLinkPattern, (m) => m.group(1)!.trim());

/// How names are compared: case, extra spaces and the edges don't matter.
String linkKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// What `[[name]]` points at.
sealed class LinkTarget {
  const LinkTarget(this.name);
  final String name;
}

class TaskLink extends LinkTarget {
  const TaskLink(super.name, this.task);
  final Task task;
}

class NoteLink extends LinkTarget {
  const NoteLink(super.name, this.note);
  final Note note;
}

/// Nothing has that name yet; the editor offers to make it a task.
class MissingLink extends LinkTarget {
  const MissingLink(super.name);
}

bool _active(Task t) =>
    t.status != TaskStatus.done && t.status != TaskStatus.archived;

/// Finds what [name] names in [workspace]. A task wins over a note, and an
/// unfinished task over a finished one with the same title (a repeating
/// task leaves finished copies behind).
LinkTarget resolveLink(
  String name, {
  required Workspace workspace,
  required Iterable<Task> tasks,
  required Iterable<Note> notes,
  String excludeNoteId = '',
}) {
  final key = linkKey(name);
  Task? done;
  for (final t in tasks) {
    if (t.workspace != workspace || linkKey(t.title) != key) continue;
    if (_active(t)) return TaskLink(name, t);
    done ??= t;
  }
  if (done != null) return TaskLink(name, done);
  for (final n in notes) {
    if (n.id == excludeNoteId || n.workspace != workspace) continue;
    if (linkKey(n.heading) == key) return NoteLink(name, n);
  }
  return MissingLink(name);
}

/// Notes in [workspace] that link to [name], most recently edited first.
List<Note> notesLinkingTo(
  String name, {
  required Workspace workspace,
  required Iterable<Note> notes,
  String excludeNoteId = '',
}) {
  final key = linkKey(name);
  if (key.isEmpty) return const [];
  return [
    for (final n in notes)
      if (n.id != excludeNoteId &&
          n.workspace == workspace &&
          wikiLinksIn('${n.title}\n${n.body}').any((l) => linkKey(l) == key))
        n,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

/// Unfinished tasks that share a tag or the project with [task], the most
/// in common first, then the soonest due. At most [limit].
List<Task> relatedTasks(Task task, Iterable<Task> all, {int limit = 5}) {
  final tags = {for (final t in task.tagList) t.toLowerCase()};
  int score(Task t) {
    final shared = t.tagList.where((x) => tags.contains(x.toLowerCase()));
    final sameProject =
        task.projectId.isNotEmpty && t.projectId == task.projectId;
    return shared.length * 2 + (sameProject ? 1 : 0);
  }

  final scored = [
    for (final t in all)
      if (t.id != task.id &&
          t.workspace == task.workspace &&
          _active(t) &&
          score(t) > 0)
        (t, score(t)),
  ];
  scored.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    if (c != 0) return c;
    final ad = a.$1.dueAt, bd = b.$1.dueAt;
    if (ad != null && bd != null) return ad.compareTo(bd);
    if (ad != null) return -1;
    if (bd != null) return 1;
    return b.$1.updatedAt.compareTo(a.$1.updatedAt);
  });
  return [for (final (t, _) in scored.take(limit)) t];
}

/// The `[[` link being typed at [cursor] in [text], if any: the text after
/// the brackets, and where the `[[` starts.
({String query, int start})? openLinkAt(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final m = RegExp(r'\[\[([^\[\]\n]*)$').firstMatch(text.substring(0, cursor));
  if (m == null) return null;
  return (query: m.group(1)!, start: m.start);
}

/// Completes the link typed at [cursor] as `[[name]]`. Returns the new text
/// and where the cursor goes (just after the closing brackets).
({String text, int cursor}) completeLink(String text, int cursor, String name) {
  final open = openLinkAt(text, cursor);
  if (open == null) return (text: text, cursor: cursor);
  // Swallow brackets already typed after the cursor, so `[[ren|]]` doesn't
  // end up as `[[Renew]]]]`.
  var end = cursor;
  if (text.startsWith(']]', end)) end += 2;
  final link = '[[${name.trim()}]]';
  return (
    text: text.replaceRange(open.start, end, link),
    cursor: open.start + link.length,
  );
}
