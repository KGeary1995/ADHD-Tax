/// XP history as immutable events, so progress syncs without conflicts:
/// every device only ever adds events, and stats are a fold over all of
/// them. Pure Dart.
library;

import 'achievements.dart';
import 'xp_rules.dart';

enum ProgressKind {
  started,
  completed,
  partial,
  carryover,

  /// Coins spent in the reward shop: negative [ProgressEvent.coins], no XP.
  /// Older builds read it as `partial`, which still subtracts the coins.
  redeemed,
}

/// One XP-earning moment. Counter fields are deltas.
class ProgressEvent {
  const ProgressEvent({
    required this.id,
    required this.at,
    required this.kind,
    required this.label,
    this.xp = 0,
    this.coins = 0,
    this.started = 0,
    this.completed = 0,
    this.ughCompleted = 0,
    this.accurate = 0,
    this.oldCleared = 0,
    this.focusMinutes = 0,
    this.keptGoing = 0,
    this.panic = 0,
    this.errands = 0,
    this.days = const [],
    this.taskId = '',
  });

  final String id;
  final DateTime at;
  final ProgressKind kind;
  final String label;
  final int xp;
  final int coins;
  final int started;
  final int completed;
  final int ughCompleted;
  final int accurate;
  final int oldCleared;
  final int focusMinutes;
  final int keptGoing;
  final int panic;
  final int errands;

  /// Extra active days (yyyy-mm-dd), only for [ProgressKind.carryover].
  final List<String> days;

  /// The task a completion was for ('' on other kinds, and on events from
  /// before it was recorded). [foldEvents] counts one completion per task
  /// per day, so two devices finishing the same task offline don't earn it
  /// twice.
  final String taskId;

  ProgressEvent copyWith({
    String? label,
    int? started,
    int? completed,
    int? ughCompleted,
    int? accurate,
    int? oldCleared,
    int? focusMinutes,
    int? keptGoing,
    int? panic,
    int? errands,
    String? taskId,
  }) => ProgressEvent(
    id: id,
    at: at,
    kind: kind,
    label: label ?? this.label,
    xp: xp,
    coins: coins,
    started: started ?? this.started,
    completed: completed ?? this.completed,
    ughCompleted: ughCompleted ?? this.ughCompleted,
    accurate: accurate ?? this.accurate,
    oldCleared: oldCleared ?? this.oldCleared,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    keptGoing: keptGoing ?? this.keptGoing,
    panic: panic ?? this.panic,
    errands: errands ?? this.errands,
    days: days,
    taskId: taskId ?? this.taskId,
  );

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'kind': kind.name,
    'label': label,
    'xp': xp,
    'coins': coins,
    'started': started,
    'completed': completed,
    'ughCompleted': ughCompleted,
    'accurate': accurate,
    'oldCleared': oldCleared,
    'focusMinutes': focusMinutes,
    'keptGoing': keptGoing,
    'panic': panic,
    'errands': errands,
    if (days.isNotEmpty) 'days': days.join(','),
    if (taskId.isNotEmpty) 'task': taskId,
  };

  factory ProgressEvent.fromJson(String id, Map<String, Object?> j) {
    int i(String k) => j[k] as int? ?? 0;
    final days = j['days'] as String?;
    return ProgressEvent(
      id: id,
      at: DateTime.parse(j['at'] as String),
      kind: ProgressKind.values.asNameMap()[j['kind']] ?? ProgressKind.partial,
      label: j['label'] as String? ?? '',
      xp: i('xp'),
      coins: i('coins'),
      started: i('started'),
      completed: i('completed'),
      ughCompleted: i('ughCompleted'),
      accurate: i('accurate'),
      oldCleared: i('oldCleared'),
      focusMinutes: i('focusMinutes'),
      keptGoing: i('keptGoing'),
      panic: i('panic'),
      errands: i('errands'),
      days: days == null || days.isEmpty ? const [] : days.split(','),
      taskId: j['task'] as String? ?? '',
    );
  }
}

/// Applies one event and reports the achievements it unlocked.
(ProgressStats, List<Achievement>) applyEvent(
  ProgressStats s,
  ProgressEvent e,
) {
  // Spending isn't activity: it doesn't extend a streak or show as XP.
  if (e.kind == ProgressKind.redeemed) {
    return (s.copyWith(coins: s.coins + e.coins), const []);
  }
  final day = dayKey(e.at);
  var next = s.copyWith(
    xp: s.xp + e.xp,
    coins: s.coins + e.coins,
    started: s.started + e.started,
    completed: s.completed + e.completed,
    ughCompleted: s.ughCompleted + e.ughCompleted,
    accurateEstimates: s.accurateEstimates + e.accurate,
    oldTasksCleared: s.oldTasksCleared + e.oldCleared,
    focusMinutes: s.focusMinutes + e.focusMinutes,
    justFiveKeptGoing: s.justFiveKeptGoing + e.keptGoing,
    panicStarts: s.panicStarts + e.panic,
    completionsByDay: e.completed == 0
        ? s.completionsByDay
        : {
            ...s.completionsByDay,
            day: (s.completionsByDay[day] ?? 0) + e.completed,
          },
    // A carryover holds totals from before events existed, not starts made
    // on its day, so it isn't drawn as stars.
    startsByDay: e.started == 0 || e.kind == ProgressKind.carryover
        ? s.startsByDay
        : {...s.startsByDay, day: (s.startsByDay[day] ?? 0) + e.started},
    errandsByDay: e.errands == 0
        ? s.errandsByDay
        : {...s.errandsByDay, day: (s.errandsByDay[day] ?? 0) + e.errands},
    // Like [recent], a carryover's lump of old XP isn't today's.
    xpByDay: e.xp == 0 || e.kind == ProgressKind.carryover
        ? s.xpByDay
        : {...s.xpByDay, day: (s.xpByDay[day] ?? 0) + e.xp},
    activeDays: {
      ...s.activeDays,
      dayOnly(e.at),
      for (final d in e.days) DateTime.parse(d),
    },
    lastActiveAt: s.lastActiveAt == null || e.at.isAfter(s.lastActiveAt!)
        ? e.at
        : s.lastActiveAt,
    recent: e.kind == ProgressKind.carryover
        ? s.recent
        : [
            XpLogEntry(e.at, e.label, e.xp),
            ...s.recent,
          ].take(ProgressStats.recentCap).toList(),
  );
  final unlocked = newlyUnlocked(
    next,
    AchievementEvent(e.at, justCompleted: e.kind == ProgressKind.completed),
  );
  if (unlocked.isNotEmpty) {
    next = next.copyWith(
      unlocked: {...next.unlocked, for (final a in unlocked) a.id: e.at},
    );
  }
  return (next, unlocked);
}

/// Replays events in time order. Events before [resetAt] are ignored, and
/// so is a second completion of the same task on the same day: two devices
/// that each finished it before hearing from the other.
ProgressStats foldEvents(Iterable<ProgressEvent> events, {DateTime? resetAt}) {
  final sorted =
      events.where((e) => resetAt == null || !e.at.isBefore(resetAt)).toList()
        ..sort((a, b) {
          final c = a.at.compareTo(b.at);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
  var s = const ProgressStats();
  final finished = <String>{};
  for (final e in sorted) {
    if (e.kind == ProgressKind.completed &&
        e.taskId.isNotEmpty &&
        !finished.add('${e.taskId} ${dayKey(e.at)}')) {
      continue;
    }
    s = applyEvent(s, e).$1;
  }
  return s;
}
