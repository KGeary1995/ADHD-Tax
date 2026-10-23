import 'links.dart' show withoutLinkBrackets;
import 'task.dart' show Workspace;

/// A note: free text kept next to the tasks, in one workspace.
///
/// Stored like tasks: one replica record per note, every field synced
/// independently. [Note.fromJson] defaults every field so notes written by
/// older or newer builds still load. Pure Dart.
class Note {
  const Note({
    required this.id,
    this.workspace = Workspace.personal,
    this.title = '',
    this.body = '',
    this.pinned = false,
    this.projectId = '',
    this.taskId = '',
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final Workspace workspace;
  final String title;
  final String body;
  final bool pinned;

  /// The project it belongs to, in the same workspace; '' for none.
  final String projectId;

  /// The task it's about, if any; '' for none.
  final String taskId;

  /// Tags added with the tag chips (lowercase, no '#'). See [allTags] for
  /// these plus the #hashtags typed in the body.
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The title, or the first line of the body when there's no title.
  /// `[[links]]` show as plain names.
  String get heading {
    if (title.trim().isNotEmpty) return withoutLinkBrackets(title.trim());
    final first = body
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return first.isEmpty ? 'Untitled note' : withoutLinkBrackets(first);
  }

  /// The body without the line already used as the heading.
  String get preview {
    final lines = withoutLinkBrackets(body)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (title.trim().isEmpty && lines.isNotEmpty) lines.removeAt(0);
    return lines.join(' · ');
  }

  /// Chip tags plus #hashtags written anywhere in the title or body.
  List<String> get allTags =>
      {...tags, ...hashtagsIn(title), ...hashtagsIn(body)}.toList()..sort();

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty ||
        title.toLowerCase().contains(q) ||
        body.toLowerCase().contains(q) ||
        allTags.any((t) => t.contains(q.replaceFirst('#', '')));
  }

  Note copyWith({
    Workspace? workspace,
    String? title,
    String? body,
    bool? pinned,
    String? projectId,
    String? taskId,
    List<String>? tags,
    DateTime? updatedAt,
  }) => Note(
    id: id,
    workspace: workspace ?? this.workspace,
    title: title ?? this.title,
    body: body ?? this.body,
    pinned: pinned ?? this.pinned,
    projectId: projectId ?? this.projectId,
    taskId: taskId ?? this.taskId,
    tags: tags ?? this.tags,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'workspace': workspace.name,
    'title': title,
    'body': body,
    'pinned': pinned,
    'projectId': projectId,
    'taskId': taskId,
    // One string, not a list: replica fields are compared by value, and a
    // list would look changed on every save.
    'tags': tags.join(','),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, Object?> j) {
    final created =
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime(2026);
    return Note(
      id: j['id'] as String,
      workspace: Workspace.values.firstWhere(
        (w) => w.name == j['workspace'],
        orElse: () => Workspace.personal,
      ),
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      pinned: j['pinned'] as bool? ?? false,
      projectId: j['projectId'] as String? ?? '',
      taskId: j['taskId'] as String? ?? '',
      tags: parseTags(j['tags'] as String? ?? ''),
      createdAt: created,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? created,
    );
  }
}

/// "Billing, #Insurance,  billing" → [billing, insurance].
List<String> parseTags(String text) => {
  for (final t in text.split(RegExp(r'[,\n]')))
    if (normalizeTag(t) case final tag when tag.isNotEmpty) tag,
}.toList();

String normalizeTag(String raw) => raw
    .trim()
    .replaceFirst(RegExp(r'^#+'), '')
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '-');

/// `#word` tags in free text. Needs a letter, so "#2" or "#" don't count.
List<String> hashtagsIn(String text) => [
  for (final m in RegExp(r'(?:^|\s)#([A-Za-z][\w-]*)').allMatches(text))
    m.group(1)!.toLowerCase(),
];

/// Lines of a note worth turning into tasks: non-empty, with list markers
/// ("- ", "* ", "1. ", "[ ] ") stripped.
List<String> taskLinesOf(String body) => [
  for (final raw in body.split('\n'))
    if (raw
            .trim()
            .replaceFirst(RegExp(r'^([-*•]|\d+[.)]|\[[ xX]?\])\s*'), '')
            .trim()
        case final line when line.isNotEmpty)
      line,
];

/// A named group of tasks and notes in one workspace.
class Project {
  const Project({
    required this.id,
    required this.name,
    this.workspace = Workspace.personal,
    this.color = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final Workspace workspace;

  /// Index into the project palette (`projectColors`).
  final int color;
  final DateTime createdAt;

  Project copyWith({String? name, int? color}) => Project(
    id: id,
    name: name ?? this.name,
    workspace: workspace,
    color: color ?? this.color,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'workspace': workspace.name,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Project.fromJson(Map<String, Object?> j) => Project(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Project',
    workspace: Workspace.values.firstWhere(
      (w) => w.name == j['workspace'],
      orElse: () => Workspace.personal,
    ),
    color: j['color'] as int? ?? 0,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime(2026),
  );
}
