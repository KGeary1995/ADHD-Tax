import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/task.dart';
import 'achievements.dart';
import 'xp_rules.dart';

const _progressKey = 'progress.v1';

enum CelebrationKind { started, completed, partial }

class CelebrationEvent {
  const CelebrationEvent({
    required this.kind,
    required this.taskTitle,
    required this.award,
    required this.levelBefore,
    required this.levelAfter,
    this.achievements = const [],
  });

  final CelebrationKind kind;
  final String taskTitle;
  final XpAward award;
  final int levelBefore;
  final int levelAfter;
  final List<Achievement> achievements;

  bool get leveledUp => levelAfter > levelBefore;

  /// Finishes get the full card. Starts always get a toast: interrupting
  /// the moment someone finally starts would defeat the point.
  bool get isBig => switch (kind) {
    CelebrationKind.completed => true,
    CelebrationKind.partial => leveledUp || achievements.isNotEmpty,
    CelebrationKind.started => false,
  };
}

/// Pending celebrations, shown one at a time by the overlay.
final celebrationQueueProvider =
    NotifierProvider<CelebrationQueue, List<CelebrationEvent>>(
      CelebrationQueue.new,
    );

class CelebrationQueue extends Notifier<List<CelebrationEvent>> {
  @override
  List<CelebrationEvent> build() => const [];

  void push(CelebrationEvent e) => state = [...state, e];

  void pop() {
    if (state.isNotEmpty) state = state.sublist(1);
  }
}

final progressProvider = NotifierProvider<ProgressController, ProgressStats>(
  ProgressController.new,
);

class ProgressController extends Notifier<ProgressStats> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  ProgressStats build() {
    final raw = ref.read(keyValueStoreProvider).read(_progressKey);
    if (raw == null) return const ProgressStats();
    return ProgressStats.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  CelebrationEvent recordStart(Task t, {bool panic = false}) {
    final now = _now();
    final s = state.copyWith(
      started: state.started + 1,
      panicStarts: state.panicStarts + (panic ? 1 : 0),
    );
    return _apply(s, startXp(t), CelebrationKind.started, t, now);
  }

  CelebrationEvent recordCompletion(
    Task t, {
    required int actualMin,
    bool keptGoingAfterFive = false,
  }) {
    final now = _now();
    final today = dayKey(now);
    final award = completionXp(
      t,
      now: now,
      actualMin: actualMin,
      firstOfDay: state.completedOn(now) == 0,
    );
    final tolerance = math.max(1, (t.estimateMin * 0.1).round());
    final s = state.copyWith(
      completed: state.completed + 1,
      ughCompleted: state.ughCompleted + (t.ugh >= 2 ? 1 : 0),
      accurateEstimates:
          state.accurateEstimates +
          ((actualMin - t.estimateMin).abs() <= tolerance ? 1 : 0),
      oldTasksCleared:
          state.oldTasksCleared +
          (now.difference(t.createdAt).inDays >= 7 ? 1 : 0),
      focusMinutes: state.focusMinutes + actualMin,
      justFiveKeptGoing: state.justFiveKeptGoing + (keptGoingAfterFive ? 1 : 0),
      completionsByDay: _bump(state.completionsByDay, today, now),
      errandsByDay: t.requiresLeavingHouse
          ? _bump(state.errandsByDay, today, now)
          : state.errandsByDay,
    );
    return _apply(
      s,
      award,
      CelebrationKind.completed,
      t,
      now,
      justCompleted: true,
    );
  }

  /// Stopped before finishing — still progress, still XP.
  CelebrationEvent recordPartial(
    Task t,
    int minutes, {
    bool keptGoingAfterFive = false,
  }) {
    final now = _now();
    final s = state.copyWith(
      focusMinutes: state.focusMinutes + minutes,
      justFiveKeptGoing: state.justFiveKeptGoing + (keptGoingAfterFive ? 1 : 0),
    );
    return _apply(s, partialXp(minutes), CelebrationKind.partial, t, now);
  }

  void reset() {
    state = const ProgressStats();
    ref.read(keyValueStoreProvider).remove(_progressKey);
  }

  CelebrationEvent _apply(
    ProgressStats s,
    XpAward award,
    CelebrationKind kind,
    Task t,
    DateTime now, {
    bool justCompleted = false,
  }) {
    final levelBefore = state.level;
    var next = s.copyWith(
      xp: s.xp + award.total,
      coins: s.coins + award.coins,
      activeDays: {...s.activeDays, dayOnly(now)},
      lastActiveAt: now,
      recent: [
        XpLogEntry(now, '${_verb(kind)}: ${t.title}', award.total),
        ...s.recent,
      ].take(ProgressStats.recentCap).toList(),
    );
    final unlocked = newlyUnlocked(
      next,
      AchievementEvent(now, justCompleted: justCompleted),
    );
    if (unlocked.isNotEmpty) {
      next = next.copyWith(
        unlocked: {...next.unlocked, for (final a in unlocked) a.id: now},
      );
    }
    state = next;
    ref
        .read(keyValueStoreProvider)
        .write(_progressKey, jsonEncode(next.toJson()));

    final event = CelebrationEvent(
      kind: kind,
      taskTitle: t.title,
      award: award,
      levelBefore: levelBefore,
      levelAfter: next.level,
      achievements: unlocked,
    );
    ref.read(celebrationQueueProvider.notifier).push(event);
    return event;
  }
}

String _verb(CelebrationKind k) => switch (k) {
  CelebrationKind.started => 'Started',
  CelebrationKind.completed => 'Finished',
  CelebrationKind.partial => 'Progress',
};

/// Increments today's counter and drops entries older than 60 days.
Map<String, int> _bump(Map<String, int> m, String key, DateTime now) {
  final cutoff = dayKey(now.subtract(const Duration(days: 60)));
  return {
    for (final e in m.entries)
      if (e.key.compareTo(cutoff) >= 0) e.key: e.value,
    key: (m[key] ?? 0) + 1,
  };
}
