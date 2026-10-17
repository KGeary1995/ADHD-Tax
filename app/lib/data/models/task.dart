/// Core task model. Pure Dart: no Flutter imports, so it can be shared with
/// the picker engine, the sync layer and tests.
library;

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

  bool get isOpen =>
      status == TaskStatus.inbox ||
      status == TaskStatus.todo ||
      status == TaskStatus.doing;

  /// The text shown when it's time to start.
  String get startLine => firstStep.trim().isEmpty ? title : firstStep;

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
  };

  factory Task.fromJson(Map<String, Object?> j) {
    DateTime? date(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    T byName<T extends Enum>(List<T> values, String k, T fallback) =>
        values.asNameMap()[j[k]] ?? fallback;

    return Task(
      id: j['id'] as String,
      title: j['title'] as String,
      notes: j['notes'] as String? ?? '',
      firstStep: j['firstStep'] as String? ?? '',
      estimateMin: j['estimateMin'] as int? ?? 15,
      requiresLeavingHouse: j['requiresLeavingHouse'] as bool? ?? false,
      location: j['location'] as String? ?? '',
      priority: byName(Priority.values, 'priority', Priority.p3),
      dueAt: date('dueAt'),
      hardDeadline: j['hardDeadline'] as bool? ?? false,
      ugh: (j['ugh'] as int? ?? 0).clamp(0, 3),
      energy: byName(Energy.values, 'energy', Energy.medium),
      workspace: byName(Workspace.values, 'workspace', Workspace.personal),
      status: byName(TaskStatus.values, 'status', TaskStatus.todo),
      chunkable: j['chunkable'] as bool? ?? false,
      scheduledStart: date('scheduledStart'),
      createdAt: date('createdAt')!,
      updatedAt: date('updatedAt')!,
      startedAt: date('startedAt'),
      completedAt: date('completedAt'),
      actualMin: j['actualMin'] as int?,
      skipCount: j['skipCount'] as int? ?? 0,
      lastSkippedAt: date('lastSkippedAt'),
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
