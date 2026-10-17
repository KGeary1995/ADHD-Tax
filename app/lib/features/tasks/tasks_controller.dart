import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/models/task.dart';

const _tasksKey = 'tasks.v1';
const _uuid = Uuid();

final tasksProvider = NotifierProvider<TasksController, List<Task>>(
  TasksController.new,
);

class TasksController extends Notifier<List<Task>> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  List<Task> build() {
    final raw = ref.read(keyValueStoreProvider).read(_tasksKey);
    if (raw == null) return const [];
    return [
      for (final j in jsonDecode(raw) as List<Object?>)
        Task.fromJson(j as Map<String, Object?>),
    ];
  }

  Task? byId(String id) {
    for (final t in state) {
      if (t.id == id) return t;
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
  }) {
    final now = _now();
    final t = Task(
      id: _uuid.v4(),
      title: title.trim(),
      firstStep: firstStep,
      estimateMin: estimateMin,
      priority: priority,
      requiresLeavingHouse: requiresLeavingHouse,
      ugh: ugh,
      workspace: workspace,
      chunkable: estimateMin >= 60,
      createdAt: now,
      updatedAt: now,
    );
    _set([...state, t]);
    return t;
  }

  /// Brain dump: one task per non-empty line, with shared defaults.
  List<Task> createMany(Iterable<String> titles, {Workspace? workspace}) {
    return [
      for (final line in titles)
        if (line.trim().isNotEmpty)
          create(
            title: line.trim(),
            workspace: workspace ?? Workspace.personal,
          ),
    ];
  }

  /// Inserts or updates. A task with an empty id is new and gets one.
  void save(Task t) {
    if (t.id.isEmpty) {
      t = Task.fromJson({...t.toJson(), 'id': _uuid.v4()});
    }
    final updated = t.copyWith(updatedAt: _now());
    final exists = state.any((x) => x.id == t.id);
    _set(
      exists
          ? [for (final x in state) x.id == t.id ? updated : x]
          : [...state, updated],
    );
  }

  void delete(String id) => _set(state.where((t) => t.id != id).toList());

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

  void complete(String id, {required int minutesWorked}) => _update(id, (t) {
    return t.copyWith(
      status: TaskStatus.done,
      completedAt: _now(),
      actualMin: (t.actualMin ?? 0) + minutesWorked,
    );
  });

  void reopen(String id) => _update(id, (t) {
    return t.copyWith(status: TaskStatus.todo, completedAt: null);
  });

  void setStatus(String id, TaskStatus status) =>
      _update(id, (t) => t.copyWith(status: status));

  /// "Not this one": the picker penalizes it for a while, then it returns.
  void skip(String id) => _update(id, (t) {
    return t.copyWith(skipCount: t.skipCount + 1, lastSkippedAt: _now());
  });

  void snooze(String id, Duration d) =>
      _update(id, (t) => t.copyWith(scheduledStart: _now().add(d)));

  void _update(String id, Task Function(Task) f) {
    _set([
      for (final t in state)
        if (t.id == id) f(t).copyWith(updatedAt: _now()) else t,
    ]);
  }

  void _set(List<Task> tasks) {
    state = tasks;
    ref
        .read(keyValueStoreProvider)
        .write(_tasksKey, jsonEncode([for (final t in tasks) t.toJson()]));
  }
}
