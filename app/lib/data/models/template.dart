import 'checklist.dart';
import 'task.dart' show Workspace;

enum TemplateKind {
  task('Task'),
  note('Note');

  const TemplateKind(this.label);
  final String label;
}

/// A reusable task (with its checklist) or note, like a start-of-day
/// checklist or a meeting-notes layout. Stored like notes: one replica record each,
/// every field a JSON scalar. Pure Dart.
class Template {
  const Template({
    required this.id,
    required this.kind,
    required this.name,
    required this.createdAt,
    this.workspace = Workspace.personal,
    this.title = '',
    this.body = '',
    this.checklist = '',
    this.estimateMin = 15,
    this.tags = '',
  });

  final String id;
  final TemplateKind kind;

  /// What it's called in the template list.
  final String name;
  final Workspace workspace;

  /// The new task's or note's title. `{date}` becomes today's date.
  final String title;

  /// Note templates: the note text. `{date}` works here too.
  final String body;

  /// Task templates: the checklist, see [encodeChecklist].
  final String checklist;
  final int estimateMin;

  /// Task templates: comma-separated tags, like `Task.tags`.
  final String tags;
  final DateTime createdAt;

  int get stepCount => parseChecklist(checklist).length;

  Template copyWith({
    TemplateKind? kind,
    String? name,
    Workspace? workspace,
    String? title,
    String? body,
    String? checklist,
    int? estimateMin,
    String? tags,
  }) => Template(
    id: id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    workspace: workspace ?? this.workspace,
    title: title ?? this.title,
    body: body ?? this.body,
    checklist: checklist ?? this.checklist,
    estimateMin: estimateMin ?? this.estimateMin,
    tags: tags ?? this.tags,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'workspace': workspace.name,
    'title': title,
    'body': body,
    'checklist': checklist,
    'estimateMin': estimateMin,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Template.fromJson(Map<String, Object?> j) => Template(
    id: j['id'] as String,
    kind: TemplateKind.values.asNameMap()[j['kind']] ?? TemplateKind.task,
    name: j['name'] as String? ?? '',
    workspace:
        Workspace.values.asNameMap()[j['workspace']] ?? Workspace.personal,
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    checklist: j['checklist'] as String? ?? '',
    estimateMin: ((j['estimateMin'] as num?)?.toInt() ?? 15).clamp(1, 1440),
    tags: j['tags'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Fills in `{date}` ("Oct 19") and `{weekday}` ("Monday").
String fillTemplate(String text, DateTime now) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return text
      .replaceAll('{date}', '${months[now.month - 1]} ${now.day}')
      .replaceAll('{weekday}', days[now.weekday - 1]);
}

/// Starters offered while there are no templates yet. Generic on purpose:
/// they should fit anyone's life or job.
List<Template> exampleTemplates(DateTime now) => [
  Template(
    id: '',
    kind: TemplateKind.task,
    name: 'Start the workday',
    workspace: Workspace.work,
    title: 'Start the day',
    estimateMin: 15,
    checklist: encodeChecklist(const [
      ChecklistItem('Check email and messages'),
      ChecklistItem("Look over today's calendar"),
      ChecklistItem('Pick the one thing that matters most today'),
      ChecklistItem('Clear the desk'),
      ChecklistItem('Fill a water bottle'),
    ]),
    createdAt: now,
  ),
  Template(
    id: '',
    kind: TemplateKind.note,
    name: 'Meeting notes',
    workspace: Workspace.work,
    title: 'Meeting {date}',
    body: 'Who:\n\nDecisions:\n\nQuestions:\n\nTo do:\n- ',
    createdAt: now,
  ),
  Template(
    id: '',
    kind: TemplateKind.task,
    name: 'Weekly reset',
    title: 'Weekly reset',
    estimateMin: 60,
    checklist: encodeChecklist(const [
      ChecklistItem('Laundry'),
      ChecklistItem('Clear the kitchen'),
      ChecklistItem('Trash and recycling out'),
      ChecklistItem('Plan meals for the week'),
      ChecklistItem("Look at next week's calendar"),
    ]),
    createdAt: now,
  ),
];
