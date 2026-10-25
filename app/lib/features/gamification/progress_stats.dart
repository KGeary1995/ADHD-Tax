/// Persistent gamification counters. Pure Dart.
library;

import 'xp_rules.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, int> _intMap(Object? raw) =>
    (raw as Map<String, Object?>? ?? const {}).map(
      (k, v) => MapEntry(k, v as int),
    );

class XpLogEntry {
  const XpLogEntry(this.at, this.label, this.amount);
  final DateTime at;
  final String label;
  final int amount;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'label': label,
    'amount': amount,
  };

  factory XpLogEntry.fromJson(Map<String, Object?> j) => XpLogEntry(
    DateTime.parse(j['at'] as String),
    j['label'] as String,
    j['amount'] as int,
  );
}

class ProgressStats {
  const ProgressStats({
    this.xp = 0,
    this.coins = 0,
    this.started = 0,
    this.completed = 0,
    this.ughCompleted = 0,
    this.accurateEstimates = 0,
    this.oldTasksCleared = 0,
    this.focusMinutes = 0,
    this.justFiveKeptGoing = 0,
    this.panicStarts = 0,
    this.errandsByDay = const {},
    this.completionsByDay = const {},
    this.startsByDay = const {},
    this.recent = const [],
    this.activeDays = const {},
    this.unlocked = const {},
    this.lastActiveAt,
  });

  final int xp;
  final int coins;
  final int started;
  final int completed;
  final int ughCompleted;
  final int accurateEstimates;
  final int oldTasksCleared;
  final int focusMinutes;
  final int justFiveKeptGoing;
  final int panicStarts;

  /// yyyy-mm-dd → out-of-house tasks finished that day.
  final Map<String, int> errandsByDay;

  /// yyyy-mm-dd → tasks finished that day.
  final Map<String, int> completionsByDay;

  /// yyyy-mm-dd → tasks started that day (drawn as the constellation).
  final Map<String, int> startsByDay;

  /// Newest first, capped at [recentCap].
  final List<XpLogEntry> recent;
  final Set<DateTime> activeDays;

  /// Achievement id → unlock time.
  final Map<String, DateTime> unlocked;
  final DateTime? lastActiveAt;

  int get level => levelForXp(xp);

  static const recentCap = 30;

  int completedOn(DateTime day) => completionsByDay[dayKey(day)] ?? 0;

  int startedOn(DateTime day) => startsByDay[dayKey(day)] ?? 0;

  ProgressStats copyWith({
    int? xp,
    int? coins,
    int? started,
    int? completed,
    int? ughCompleted,
    int? accurateEstimates,
    int? oldTasksCleared,
    int? focusMinutes,
    int? justFiveKeptGoing,
    int? panicStarts,
    Map<String, int>? errandsByDay,
    Map<String, int>? completionsByDay,
    Map<String, int>? startsByDay,
    List<XpLogEntry>? recent,
    Set<DateTime>? activeDays,
    Map<String, DateTime>? unlocked,
    DateTime? lastActiveAt,
  }) {
    return ProgressStats(
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      started: started ?? this.started,
      completed: completed ?? this.completed,
      ughCompleted: ughCompleted ?? this.ughCompleted,
      accurateEstimates: accurateEstimates ?? this.accurateEstimates,
      oldTasksCleared: oldTasksCleared ?? this.oldTasksCleared,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      justFiveKeptGoing: justFiveKeptGoing ?? this.justFiveKeptGoing,
      panicStarts: panicStarts ?? this.panicStarts,
      errandsByDay: errandsByDay ?? this.errandsByDay,
      completionsByDay: completionsByDay ?? this.completionsByDay,
      startsByDay: startsByDay ?? this.startsByDay,
      recent: recent ?? this.recent,
      activeDays: activeDays ?? this.activeDays,
      unlocked: unlocked ?? this.unlocked,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, Object?> toJson() => {
    'xp': xp,
    'coins': coins,
    'started': started,
    'completed': completed,
    'ughCompleted': ughCompleted,
    'accurateEstimates': accurateEstimates,
    'oldTasksCleared': oldTasksCleared,
    'focusMinutes': focusMinutes,
    'justFiveKeptGoing': justFiveKeptGoing,
    'panicStarts': panicStarts,
    'errandsByDay': errandsByDay,
    'completionsByDay': completionsByDay,
    'startsByDay': startsByDay,
    'recent': [for (final r in recent) r.toJson()],
    'activeDays': [for (final d in activeDays) d.toIso8601String()],
    'unlocked': {
      for (final e in unlocked.entries) e.key: e.value.toIso8601String(),
    },
    'lastActiveAt': lastActiveAt?.toIso8601String(),
  };

  factory ProgressStats.fromJson(Map<String, Object?> j) {
    int i(String k) => j[k] as int? ?? 0;
    return ProgressStats(
      xp: i('xp'),
      coins: i('coins'),
      started: i('started'),
      completed: i('completed'),
      ughCompleted: i('ughCompleted'),
      accurateEstimates: i('accurateEstimates'),
      oldTasksCleared: i('oldTasksCleared'),
      focusMinutes: i('focusMinutes'),
      justFiveKeptGoing: i('justFiveKeptGoing'),
      panicStarts: i('panicStarts'),
      errandsByDay: _intMap(j['errandsByDay']),
      completionsByDay: _intMap(j['completionsByDay']),
      startsByDay: _intMap(j['startsByDay']),
      recent: [
        for (final r in j['recent'] as List<Object?>? ?? const [])
          XpLogEntry.fromJson(r as Map<String, Object?>),
      ],
      activeDays: {
        for (final d in j['activeDays'] as List<Object?>? ?? const [])
          DateTime.parse(d as String),
      },
      unlocked: (j['unlocked'] as Map<String, Object?>? ?? {}).map(
        (k, v) => MapEntry(k, DateTime.parse(v as String)),
      ),
      lastActiveAt: j['lastActiveAt'] == null
          ? null
          : DateTime.parse(j['lastActiveAt'] as String),
    );
  }
}
