/// Core task model. Pure Dart: no Flutter imports, so it can be shared with
/// the picker engine, the sync layer and tests.
library;

import 'checklist.dart';

export 'checklist.dart';

enum TaskStatus { inbox, todo, doing, waiting, done, archived }

enum Priority {
  p1('Critical', 4.0),
  p2('High', 3.0),
  p3('Normal', 2.0),
  p4('Someday', 0.5);

  const Priority(this.label, this.weight);
  final String label;
  final double weight;
}

enum Energy {
  low('Low'),
  medium('Medium'),
  high('High');

  const Energy(this.label);
  final String label;
}

enum Workspace {
  personal('Personal'),
  work('Work');

  const Workspace(this.label);
  final String label;
}

/// How often a task comes back after it's done.
enum Repeat {
  none("Doesn't repeat", ''),
  daily('Every day', 'Daily'),
  weekdays('Every weekday (Mon–Fri)', 'Weekdays'),
  weekly('Every week', 'Weekly'),
  biweekly('Every 2 weeks', 'Every 2 wks'),
  monthly('Every month', 'Monthly');

  const Repeat(this.label, this.short);
  final String label;

  /// For chips.
  final String short;
}

/// How much the user does not want to do a task.
const ughLabels = ['Fine', 'Meh', 'Ugh', 'Dreading it'];

/// Quick-pick estimate chips, in minutes.
const estimatePresets = [5, 15, 30, 60, 120];

const _unset = Object();

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.firstStep = '',
    this.estimateMin = 15,
    this.requiresLeavingHouse = false,
    this.location = '',
    this.priority = Priority.p3,
    this.dueAt,
    this.hardDeadline = false,
    this.ugh = 0,
    this.energy = Energy.medium,
    this.workspace = Workspace.personal,
    this.status = TaskStatus.todo,
    this.chunkable = false,
    this.scheduledStart,
    this.startedAt,
    this.completedAt,
    this.actualMin,
    this.skipCount = 0,
    this.lastSkippedAt,
    this.repeat = Repeat.none,
    this.repeatFromDone = false,
    this.waitingOn = '',
    this.followUpAt,
    this.projectId = '',
    this.checklist = '',
    this.tags = '',
    this.reviewedAt,
    this.repeatFrom,
    this.repeatDay = 0,
  }) : assert(ugh >= 0 && ugh <= 3);

  final String id;
  final String title;
  final String notes;

  /// The tiny "first 2 minutes" action shown on the focus screen.
  final String firstStep;
  final int estimateMin;
  final bool requiresLeavingHouse;
  final String location;
  final Priority priority;
  final DateTime? dueAt;
  final bool hardDeadline;

  /// 0..3, see [ughLabels].
  final int ugh;
  final Energy energy;
  final Workspace workspace;
  final TaskStatus status;

  /// Long tasks the picker may offer as "work on it for N minutes".
  final bool chunkable;

  /// When set in the future, the picker leaves the task alone until then.
  final DateTime? scheduledStart;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? actualMin;
  final int skipCount;
  final DateTime? lastSkippedAt;
  final Repeat repeat;

  /// Count the next one from when this one was finished ("water the plants
  /// a week after last time"), not from the due date ("report every Friday").
  final bool repeatFromDone;

  /// Who or what a "Waiting on someone" task is waiting for.
  final String waitingOn;

  /// When to check back on a waiting task.
  final DateTime? followUpAt;

  /// The project it belongs to, in the same workspace; '' for none.
  final String projectId;

  /// Sub-steps, encoded by [encodeChecklist]. '' for none.
  final String checklist;

  /// Comma-separated lowercase tags without '#', like `Note.tags` but kept
  /// as one string so it syncs as a scalar. '' for none.
  final String tags;

  /// Last time it was kept on purpose in the weekly reset, so it isn't
  /// asked about again for another week.
  final DateTime? reviewedAt;

  /// A repeating copy with no due date: the day it was scheduled for, which
  /// the next copy counts from. Start and Later change [scheduledStart], so
  /// that can't be the anchor. Null for anything else.
  final DateTime? repeatFrom;

  /// A monthly series' day of the month (31 for "the 31st"), so a copy
  /// moved to Feb 28 comes back on Mar 31. 0 when unknown.
  final int repeatDay;

  List<ChecklistItem> get steps => parseChecklist(checklist);

  List<String> get tagList => [
    for (final t in tags.split(','))
      if (t.trim().isNotEmpty) t.trim(),
  ];

  /// What to do next: the first unticked checklist item, else the first
  /// step. '' once every item is ticked, so the title shows.
  String get nextStep {
    final items = steps;
    if (items.isEmpty) return firstStep.trim();
    return items.where((i) => !i.done).firstOrNull?.text ?? '';
  }

  /// Ticks or unticks checklist item [index].
  Task toggleStep(int index) {
    final items = steps;
    if (index < 0 || index >= items.length) return this;
    items[index] = items[index].toggled();
    return copyWith(checklist: encodeChecklist(items));
  }

  bool get isOpen =>
      status == TaskStatus.inbox ||
      status == TaskStatus.todo ||
      status == TaskStatus.doing;

  /// The text shown when it's time to start.
  String get startLine => nextStep.isEmpty ? title : nextStep;

  Task copyWith({
    String? title,
    String? notes,
    String? firstStep,
    int? estimateMin,
    bool? requiresLeavingHouse,
    String? location,
    Priority? priority,
    Object? dueAt = _unset,
    bool? hardDeadline,
    int? ugh,
    Energy? energy,
    Workspace? workspace,
    TaskStatus? status,
    bool? chunkable,
    Object? scheduledStart = _unset,
    DateTime? updatedAt,
    Object? startedAt = _unset,
    Object? completedAt = _unset,
    Object? actualMin = _unset,
    int? skipCount,
    Object? lastSkippedAt = _unset,
    Repeat? repeat,
    bool? repeatFromDone,
    String? waitingOn,
    Object? followUpAt = _unset,
    String? projectId,
    String? checklist,
    String? tags,
    Object? reviewedAt = _unset,
    Object? repeatFrom = _unset,
    int? repeatDay,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      firstStep: firstStep ?? this.firstStep,
      estimateMin: estimateMin ?? this.estimateMin,
      requiresLeavingHouse: requiresLeavingHouse ?? this.requiresLeavingHouse,
      location: location ?? this.location,
      priority: priority ?? this.priority,
      dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as DateTime?,
      hardDeadline: hardDeadline ?? this.hardDeadline,
      ugh: ugh ?? this.ugh,
      energy: energy ?? this.energy,
      workspace: workspace ?? this.workspace,
      status: status ?? this.status,
      chunkable: chunkable ?? this.chunkable,
      scheduledStart: identical(scheduledStart, _unset)
          ? this.scheduledStart
          : scheduledStart as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: identical(startedAt, _unset)
          ? this.startedAt
          : startedAt as DateTime?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      actualMin: identical(actualMin, _unset)
          ? this.actualMin
          : actualMin as int?,
      skipCount: skipCount ?? this.skipCount,
      lastSkippedAt: identical(lastSkippedAt, _unset)
          ? this.lastSkippedAt
          : lastSkippedAt as DateTime?,
      repeat: repeat ?? this.repeat,
      repeatFromDone: repeatFromDone ?? this.repeatFromDone,
      waitingOn: waitingOn ?? this.waitingOn,
      followUpAt: identical(followUpAt, _unset)
          ? this.followUpAt
          : followUpAt as DateTime?,
      projectId: projectId ?? this.projectId,
      checklist: checklist ?? this.checklist,
      tags: tags ?? this.tags,
      reviewedAt: identical(reviewedAt, _unset)
          ? this.reviewedAt
          : reviewedAt as DateTime?,
      repeatFrom: identical(repeatFrom, _unset)
          ? this.repeatFrom
          : repeatFrom as DateTime?,
      repeatDay: repeatDay ?? this.repeatDay,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'firstStep': firstStep,
    'estimateMin': estimateMin,
    'requiresLeavingHouse': requiresLeavingHouse,
    'location': location,
    'priority': priority.name,
    'dueAt': dueAt?.toIso8601String(),
    'hardDeadline': hardDeadline,
    'ugh': ugh,
    'energy': energy.name,
    'workspace': workspace.name,
    'status': status.name,
    'chunkable': chunkable,
    'scheduledStart': scheduledStart?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'actualMin': actualMin,
    'skipCount': skipCount,
    'lastSkippedAt': lastSkippedAt?.toIso8601String(),
    'repeat': repeat.name,
    'repeatFromDone': repeatFromDone,
    'waitingOn': waitingOn,
    'followUpAt': followUpAt?.toIso8601String(),
    'projectId': projectId,
    'checklist': checklist,
    'tags': tags,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'repeatFrom': repeatFrom?.toIso8601String(),
    'repeatDay': repeatDay,
  };

  factory Task.fromJson(Map<String, Object?> j) {
    DateTime? date(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    T byName<T extends Enum>(List<T> values, String k, T fallback) =>
        values.asNameMap()[j[k]] ?? fallback;
    // Whole numbers may arrive as 15.0 from a JSON writer other than Dart's.
    int? intAt(String k) => (j[k] as num?)?.toInt();

    return Task(
      id: j['id'] as String,
      title: j['title'] as String,
      notes: j['notes'] as String? ?? '',
      firstStep: j['firstStep'] as String? ?? '',
      estimateMin: intAt('estimateMin') ?? 15,
      requiresLeavingHouse: j['requiresLeavingHouse'] as bool? ?? false,
      location: j['location'] as String? ?? '',
      priority: byName(Priority.values, 'priority', Priority.p3),
      dueAt: date('dueAt'),
      hardDeadline: j['hardDeadline'] as bool? ?? false,
      ugh: (intAt('ugh') ?? 0).clamp(0, 3),
      energy: byName(Energy.values, 'energy', Energy.medium),
      workspace: byName(Workspace.values, 'workspace', Workspace.personal),
      status: byName(TaskStatus.values, 'status', TaskStatus.todo),
      chunkable: j['chunkable'] as bool? ?? false,
      scheduledStart: date('scheduledStart'),
      createdAt: date('createdAt')!,
      updatedAt: date('updatedAt')!,
      startedAt: date('startedAt'),
      completedAt: date('completedAt'),
      actualMin: intAt('actualMin'),
      skipCount: intAt('skipCount') ?? 0,
      lastSkippedAt: date('lastSkippedAt'),
      repeat: byName(Repeat.values, 'repeat', Repeat.none),
      repeatFromDone: j['repeatFromDone'] as bool? ?? false,
      waitingOn: j['waitingOn'] as String? ?? '',
      followUpAt: date('followUpAt'),
      projectId: j['projectId'] as String? ?? '',
      checklist: j['checklist'] as String? ?? '',
      tags: j['tags'] as String? ?? '',
      reviewedAt: date('reviewedAt'),
      repeatFrom: date('repeatFrom'),
      repeatDay: intAt('repeatDay') ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Task && _jsonEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hash(id, updatedAt);
}

bool _jsonEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (a[k] != b[k]) return false;
  }
  return true;
}

String formatMinutes(int min) {
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
