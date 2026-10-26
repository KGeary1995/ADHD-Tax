import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/models/task.dart';
import '../../sync/replicas_controller.dart';
import '../settings/device_workspaces.dart';
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
    this.quick = false,
    this.eventId = '',
    this.workspace = Workspace.personal,
  });

  final CelebrationKind kind;
  final String taskTitle;
  final XpAward award;
  final int levelBefore;
  final int levelAfter;
  final List<Achievement> achievements;

  /// Marked done from the list rather than at the end of a focus session.
  final bool quick;

  /// The XP event behind it, so it can be taken back by an undo.
  final String eventId;
  final Workspace workspace;

  bool get leveledUp => levelAfter > levelBefore;

  /// Finishes get the full card. Starts always get a toast: interrupting
  /// the moment someone finally starts would defeat the point.
  bool get isBig => switch (kind) {
    // A quick "Mark done" gets the toast (which still lists achievements
    // and level-ups), so the card never covers its Undo.
    CelebrationKind.completed => !quick,
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

  void remove(CelebrationEvent e) => state = [
    for (final x in state)
      if (!identical(x, e)) x,
  ];

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
    final shown = ref.watch(deviceWorkspacesProvider).shown;
    final set = ref.read(replicasProvider);
    DateTime? resetAt;
    final events = <ProgressEvent>[];
    for (final (ws, r) in set.entries) {
      final reset = r.get(collMeta, _progressMeta)?.values['resetAt'];
      if (reset is String) {
        final at = DateTime.parse(reset);
        if (resetAt == null || at.isAfter(resetAt)) resetAt = at;
      }
      for (final e in r.collection(collEvents).entries) {
        if (e.value.isDeleted) continue;
        try {
          final event = ProgressEvent.fromJson(e.key, e.value.values);
          // XP and counts stay whole, but a workspace this device doesn't
          // show keeps its task titles to itself.
          events.add(
            shown.contains(ws)
                ? event
                : event.copyWith(label: hiddenLabel(event, ws)),
          );
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
      t.title,
      t.workspace,
      award,
      CelebrationKind.started,
      (e) => e.copyWith(started: 1, panic: panic ? 1 : 0),
    );
  }

  /// [actualMin] is the task's whole time, null when it was marked done
  /// without being timed. [sessionMin] is this session's share of it (what
  /// counts as new focus time); left out, it's all of [actualMin]. Earlier
  /// sessions on the task already counted theirs through [recordPartial].
  CelebrationEvent recordCompletion(
    Task t, {
    required int? actualMin,
    int? sessionMin,
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
      t.title,
      t.workspace,
      award,
      CelebrationKind.completed,
      (e) => e.copyWith(
        taskId: t.id,
        completed: 1,
        ughCompleted: t.ugh >= 2 ? 1 : 0,
        accurate:
            actualMin != null && (actualMin - t.estimateMin).abs() <= tolerance
            ? 1
            : 0,
        oldCleared: now.difference(t.createdAt).inDays >= 7 ? 1 : 0,
        focusMinutes: sessionMin ?? actualMin ?? 0,
        keptGoing: keptGoingAfterFive ? 1 : 0,
        errands: t.requiresLeavingHouse ? 1 : 0,
      ),
      quick: actualMin == null,
    );
  }

  /// Stopped before finishing — still progress, still XP.
  CelebrationEvent recordPartial(
    Task t,
    int minutes, {
    bool keptGoingAfterFive = false,
  }) {
    return _record(
      t.title,
      t.workspace,
      partialXp(minutes),
      CelebrationKind.partial,
      (e) => e.copyWith(
        focusMinutes: minutes,
        keptGoing: keptGoingAfterFive ? 1 : 0,
      ),
    );
  }

  /// XP for something that isn't one task, like finishing the weekly
  /// reset. Counts as progress (an active day), not a start or a finish.
  CelebrationEvent recordBonus(String label, int xp, Workspace workspace) =>
      _record(
        label,
        workspace,
        XpAward([XpLine(label, xp)]),
        CelebrationKind.partial,
        (e) => e,
        eventLabel: label,
      );

  /// Takes back the XP from an undone action, on every device.
  void revoke(CelebrationEvent e) {
    if (e.eventId.isEmpty) return;
    ref.read(celebrationQueueProvider.notifier).remove(e);
    ref
        .read(replicasProvider.notifier)
        .write(
          e.workspace,
          (r, now) => r.delete(collEvents, e.eventId, now),
          events: true,
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
    String title,
    Workspace workspace,
    XpAward award,
    CelebrationKind kind,
    ProgressEvent Function(ProgressEvent) counters, {
    bool quick = false,
    String? eventLabel,
  }) {
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
        label: eventLabel ?? '${_verb(kind)}: $title',
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
          workspace,
          (r, now) => r.put(collEvents, event.id, event.toJson(), now),
          events: true,
        );

    final celebration = CelebrationEvent(
      kind: kind,
      taskTitle: title,
      award: award,
      levelBefore: before.level,
      levelAfter: after.level,
      achievements: unlocked,
      quick: quick,
      eventId: event.id,
      workspace: workspace,
    );
    ref.read(celebrationQueueProvider.notifier).push(celebration);
    return celebration;
  }
}

/// "Started: Send the report" from a hidden workspace → "Started: a Work
/// task"; a reward's name → "A Work reward".
String hiddenLabel(ProgressEvent e, Workspace ws) {
  if (e.kind == ProgressKind.redeemed) return 'A ${ws.label} reward';
  final colon = e.label.indexOf(': ');
  final what = 'a ${ws.label} task';
  return colon < 0
      ? '${ws.label} progress'
      : '${e.label.substring(0, colon)}: $what';
}

const _progressMeta = 'progress';
const _uuid = Uuid();

String _verb(CelebrationKind k) => switch (k) {
  CelebrationKind.started => 'Started',
  CelebrationKind.completed => 'Finished',
  CelebrationKind.partial => 'Progress',
};
