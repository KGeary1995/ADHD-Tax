import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/models/task.dart';
import '../../sync/replicas_controller.dart';
import 'achievements.dart';
import 'progress_event.dart';
import 'xp_rules.dart';

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

/// Progress is a fold over XP events stored in the workspace replicas, so it
/// syncs without conflicts: devices only ever add events.
class ProgressController extends Notifier<ProgressStats> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  ProgressStats build() {
    ref.watch(replicasProvider.select((s) => s.eventsVersion));
    final set = ref.read(replicasProvider);
    DateTime? resetAt;
    final events = <ProgressEvent>[];
    for (final (_, r) in set.entries) {
      final reset = r.get(collMeta, _progressMeta)?.values['resetAt'];
      if (reset is String) {
        final at = DateTime.parse(reset);
        if (resetAt == null || at.isAfter(resetAt)) resetAt = at;
      }
      for (final e in r.collection(collEvents).entries) {
        if (e.value.isDeleted) continue;
        try {
          events.add(ProgressEvent.fromJson(e.key, e.value.values));
        } on Object {
          // Unreadable event from another app version: leave it out.
        }
      }
    }
    return foldEvents(events, resetAt: resetAt);
  }

  CelebrationEvent recordStart(Task t, {bool panic = false}) {
    final award = startXp(t);
    return _record(
      t,
      award,
      CelebrationKind.started,
      (e) => e.copyWith(started: 1, panic: panic ? 1 : 0),
    );
  }

  CelebrationEvent recordCompletion(
    Task t, {
    required int actualMin,
    bool keptGoingAfterFive = false,
  }) {
    final now = _now();
    final award = completionXp(
      t,
      now: now,
      actualMin: actualMin,
      firstOfDay: state.completedOn(now) == 0,
    );
    final tolerance = math.max(1, (t.estimateMin * 0.1).round());
    return _record(
      t,
      award,
      CelebrationKind.completed,
      (e) => e.copyWith(
        completed: 1,
        ughCompleted: t.ugh >= 2 ? 1 : 0,
        accurate: (actualMin - t.estimateMin).abs() <= tolerance ? 1 : 0,
        oldCleared: now.difference(t.createdAt).inDays >= 7 ? 1 : 0,
        focusMinutes: actualMin,
        keptGoing: keptGoingAfterFive ? 1 : 0,
        errands: t.requiresLeavingHouse ? 1 : 0,
      ),
    );
  }

  /// Stopped before finishing — still progress, still XP.
  CelebrationEvent recordPartial(
    Task t,
    int minutes, {
    bool keptGoingAfterFive = false,
  }) {
    return _record(
      t,
      partialXp(minutes),
      CelebrationKind.partial,
      (e) => e.copyWith(
        focusMinutes: minutes,
        keptGoing: keptGoingAfterFive ? 1 : 0,
      ),
    );
  }

  /// Starts progress over on every device. Old events stay (they're what
  /// other devices already have) but are ignored from here on.
  void reset() {
    final at = _now().toIso8601String();
    for (final ws in Workspace.values) {
      ref
          .read(replicasProvider.notifier)
          .write(
            ws,
            (r, now) => r.put(collMeta, _progressMeta, {'resetAt': at}, now),
            events: true,
          );
    }
  }

  CelebrationEvent _record(
    Task t,
    XpAward award,
    CelebrationKind kind,
    ProgressEvent Function(ProgressEvent) counters,
  ) {
    final now = _now();
    final event = counters(
      ProgressEvent(
        id: _uuid.v4(),
        at: now,
        kind: switch (kind) {
          CelebrationKind.started => ProgressKind.started,
          CelebrationKind.completed => ProgressKind.completed,
          CelebrationKind.partial => ProgressKind.partial,
        },
        label: '${_verb(kind)}: ${t.title}',
        xp: award.total,
        coins: award.coins,
      ),
    );
    final before = state;
    final (after, unlocked) = applyEvent(before, event);

    // XP lives with the task's workspace, so Work history stays in the
    // Work account.
    ref
        .read(replicasProvider.notifier)
        .write(
          t.workspace,
          (r, now) => r.put(collEvents, event.id, event.toJson(), now),
          events: true,
        );

    final celebration = CelebrationEvent(
      kind: kind,
      taskTitle: t.title,
      award: award,
      levelBefore: before.level,
      levelAfter: after.level,
      achievements: unlocked,
    );
    ref.read(celebrationQueueProvider.notifier).push(celebration);
    return celebration;
  }
}

const _progressMeta = 'progress';
const _uuid = Uuid();

String _verb(CelebrationKind k) => switch (k) {
  CelebrationKind.started => 'Started',
  CelebrationKind.completed => 'Finished',
  CelebrationKind.partial => 'Progress',
};
