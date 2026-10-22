/// XP and level math. Pure Dart.
///
/// Principle: starting is rewarded on its own, because starting is the hard
/// part. Completion XP scales with size, priority and dread.
library;

import 'dart:math' as math;

import '../../data/models/task.dart';

class XpLine {
  const XpLine(this.label, this.amount);
  final String label;
  final int amount;
}

class XpAward {
  const XpAward(this.lines);
  final List<XpLine> lines;

  int get total => lines.fold(0, (s, l) => s + l.amount);

  /// Reward-shop currency: 1 coin per 10 XP, at least 1.
  int get coins => math.max(1, total ~/ 10);
}

const _priorityMult = {
  Priority.p1: 2.0,
  Priority.p2: 1.5,
  Priority.p3: 1.0,
  Priority.p4: 0.75,
};

/// Awarded the moment the user presses Start.
XpAward startXp(Task t) {
  return XpAward([
    const XpLine('Started', 10),
    if (t.ugh >= 2) const XpLine('Started a task you were dreading', 10),
  ]);
}

/// Awarded when a task is marked done.
XpAward completionXp(
  Task t, {
  required DateTime now,
  required int? actualMin,
  required bool firstOfDay,
}) {
  final base = (10 + t.estimateMin / 2).clamp(10, 80).toDouble();
  final mult = _priorityMult[t.priority]! * (1 + 0.5 * t.ugh);
  final lines = <XpLine>[XpLine('Finished', (base * mult).round())];

  if (firstOfDay) lines.add(const XpLine('First win of the day', 15));
  // Untimed ("Mark done" without a focus session): nothing to beat.
  if (actualMin != null && actualMin <= t.estimateMin) {
    lines.add(const XpLine('Beat your estimate', 10));
  }
  if (now.difference(t.createdAt).inDays >= 7) {
    lines.add(const XpLine('Cleared an old task', 20));
  }
  if (t.requiresLeavingHouse) lines.add(const XpLine('Got out the door', 10));
  return XpAward(lines);
}

/// Small win for stopping after "just 5 minutes" — it still counts.
XpAward partialXp(int minutes) =>
    XpAward([XpLine('Made progress (${minutes}m)', math.max(5, minutes))]);

// ---------------------------------------------------------------------------
// Levels

/// Total XP needed to reach [level] (level 1 = 0 XP).
int xpForLevel(int level) {
  if (level <= 1) return 0;
  return (100 * math.pow(level - 1, 1.5)).round();
}

int levelForXp(int xp) {
  var level = 1;
  while (xpForLevel(level + 1) <= xp) {
    level++;
  }
  return level;
}

/// 0..1 progress from the current level to the next.
double levelProgress(int xp) {
  final l = levelForXp(xp);
  final lo = xpForLevel(l);
  final hi = xpForLevel(l + 1);
  return (xp - lo) / (hi - lo);
}

const ranks = [
  'Spark',
  'Starter',
  'Initiator',
  'Operator',
  'Specialist',
  'Commander',
  'Architect',
  'Vanguard',
  'Legend',
];

/// A new rank every 5 levels.
String rankForLevel(int level) =>
    ranks[math.min((level - 1) ~/ 5, ranks.length - 1)];

// ---------------------------------------------------------------------------
// Streaks with grace

/// Days in a row with at least one start or finish, allowing up to
/// [gracePerWeek] missed days in any 7-day stretch. Today not being active
/// yet never breaks the streak.
int streakWithGrace(
  Set<DateTime> activeDays,
  DateTime today, {
  int gracePerWeek = 2,
}) {
  final days = activeDays.map(dayOnly).toSet();
  var day = dayOnly(today);
  if (!days.contains(day)) day = day.subtract(const Duration(days: 1));

  var streak = 0;
  final misses = <DateTime>[];
  // Bound the walk so a corrupted set can't loop forever.
  for (var i = 0; i < 3650; i++) {
    if (days.contains(day)) {
      streak++;
    } else {
      misses.add(day);
      final recent = misses.where((m) => m.difference(day).inDays < 7).length;
      if (recent > gracePerWeek) break;
    }
    day = day.subtract(const Duration(days: 1));
    if (streak == 0 && misses.length > gracePerWeek) break;
  }
  return streak;
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
