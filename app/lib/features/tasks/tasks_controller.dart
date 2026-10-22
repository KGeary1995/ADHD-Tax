import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/device_workspaces.dart';

import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/models/task.dart';
import '../../sync/replicas_controller.dart';
import 'recurrence.dart';

const _uuid = Uuid();

final tasksProvider = NotifierProvider<TasksController, List<Task>>(
  TasksController.new,
);

/// Tasks from both workspaces. The replicas are the source of truth; this
/// rebuilds whenever they change, locally or from sync.
class TasksController extends Notifier<List<Task>> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  List<Task> build() {
    ref.watch(replicasProvider.select((s) => s.tasksVersion));
    final shown = ref.watch(deviceWorkspacesProvider).shown;
    final set = ref.read(replicasProvider);
    return [
      for (final (ws, r) in set.entries)
        if (shown.contains(ws))
          for (final e in r.collection(collTasks).entries)
            ?taskFromRecord(e.key, e.value),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Reads the replicas directly, so back-to-back edits never build on a
  /// list that hasn't rebuilt yet.
  Task? byId(String id) {
    for (final (_, r) in ref.read(replicasProvider).entries) {
      final rec = r.get(collTasks, id);
      final t = rec == null ? null : taskFromRecord(id, rec);
      if (t != null) return t;
    }
    return null;
  }

  Task create({
    required String title,
    int estimateMin = 15,
    Priority priority = Priority.p3,
    bool requiresLeavingHouse = false,
    int ugh = 0,
    Workspace workspace = Workspace.personal,
    String firstStep = '',
    String notes = '',
    String projectId = '',
    String checklist = '',
    String tags = '',
    DateTime? dueAt,
    Energy energy = Energy.medium,
  }) {
    final now = _now();
    final t = Task(
      id: _uuid.v4(),
      title: title.trim(),
      firstStep: firstStep,
      notes: notes,
      estimateMin: estimateMin,
      priority: priority,
      requiresLeavingHouse: requiresLeavingHouse,
      ugh: ugh,
      workspace: workspace,
      chunkable: estimateMin >= 60,
      projectId: projectId,
      checklist: checklist,
      tags: tags,
      dueAt: dueAt,
      energy: energy,
      createdAt: now,
      updatedAt: now,
    );
    _write(t);
    return t;
  }

  /// Inserts or updates. A task with an empty id is new and gets one.
  void save(Task t) {
    if (t.id.isEmpty) {
      t = Task.fromJson({...t.toJson(), 'id': _uuid.v4()});
    }
    _write(t.copyWith(updatedAt: _now()));
  }

  void delete(String id) {
    final t = byId(id);
    if (t == null) return;
    ref
        .read(replicasProvider.notifier)
        .write(
          t.workspace,
          (r, now) => r.delete(collTasks, id, now),
          tasks: true,
        );
  }

  void markStarted(String id) => _update(id, (t) {
    return t.copyWith(
      status: TaskStatus.doing,
      startedAt: t.startedAt ?? _now(),
      scheduledStart: null,
    );
  });

  /// Stopped early: back to the pile, still marked as in progress.
  void pause(String id, {required int minutesWorked}) => _update(id, (t) {
    return t.copyWith(actualMin: (t.actualMin ?? 0) + minutesWorked);
  });

  /// Marks it done. A repeating task also gets its next copy, which is
  /// returned so an undo can take it back.
  Task? complete(String id, {required int minutesWorked}) {
    final t = byId(id);
    if (t == null) return null;
    final now = _now();
    _write(
      t.copyWith(
        status: TaskStatus.done,
        completedAt: now,
        actualMin: minutesWorked == 0
            ? t.actualMin
            : (t.actualMin ?? 0) + minutesWorked,
        followUpAt: null,
        updatedAt: now,
      ),
    );
    final next = nextOccurrence(t, now);
    if (next == null) return null;
    // Already there if another device finished this one first.
    if (byId(next.id) == null) _write(next);
    return next;
  }

  /// Puts back a task exactly as it was before a change: undo for done,
  /// archive and delete. Also revives a deleted one.
  void restore(Task before) => _write(before.copyWith(updatedAt: _now()));

  void reopen(String id) => _update(id, (t) {
    return t.copyWith(
      status: TaskStatus.todo,
      completedAt: null,
      followUpAt: null,
    );
  });

  /// Parks it as "Waiting on someone", optionally with a date to check back.
  void setWaiting(String id, {String waitingOn = '', DateTime? followUpAt}) =>
      _update(id, (t) {
        return t.copyWith(
          status: TaskStatus.waiting,
          waitingOn: waitingOn.trim(),
          followUpAt: followUpAt,
        );
      });

  /// Ticks or unticks one checklist item.
  void toggleStep(String id, int index) =>
      _update(id, (t) => t.toggleStep(index));

  void setStatus(String id, TaskStatus status) =>
      _update(id, (t) => t.copyWith(status: status));

  /// "Not this one": the picker penalizes it for a while, then it returns.
  void skip(String id) => _update(id, (t) {
    return t.copyWith(skipCount: t.skipCount + 1, lastSkippedAt: _now());
  });

  void snooze(String id, Duration d) =>
      _update(id, (t) => t.copyWith(scheduledStart: _now().add(d)));

  void _update(String id, Task Function(Task) f) {
    final t = byId(id);
    if (t != null) _write(f(t).copyWith(updatedAt: _now()));
  }

  void _write(Task t) {
    final replicas = ref.read(replicasProvider.notifier);
    final previous = byId(t.id);
    // Moving between workspaces: tombstone it on the old side, so a Work
    // task doesn't linger in the Personal account's Drive (or vice versa).
    if (previous != null && previous.workspace != t.workspace) {
      replicas.write(
        previous.workspace,
        (r, now) => r.delete(collTasks, t.id, now),
        tasks: true,
      );
    }
    replicas.write(
      t.workspace,
      (r, now) => r.put(collTasks, t.id, taskFields(t), now),
      tasks: true,
    );
  }
}
