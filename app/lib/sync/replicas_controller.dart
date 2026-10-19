import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/providers.dart';
import '../data/models/task.dart';
import '../data/storage/key_value_store.dart';
import '../features/gamification/achievements.dart';
import '../features/gamification/progress_event.dart';
import 'backup_file.dart';
import 'replica.dart';

const collTasks = 'tasks';
const collEvents = 'events';
const collMeta = 'meta';
const collNotes = 'notes';
const collProjects = 'projects';

String _replicaKey(Workspace ws) => 'replica.v1.${ws.name}';

/// This install's id. Stamps local writes and names our sync file.
final deviceIdProvider = Provider<String>((ref) {
  final store = ref.read(keyValueStoreProvider);
  final existing = store.read('device.id');
  if (existing != null) return existing;
  final id = const Uuid().v4();
  store.write('device.id', id);
  return id;
});

/// One replica per workspace. Personal and Work sync to different Google
/// accounts, so their data never mixes.
class ReplicaSet {
  const ReplicaSet(
    this._replicas, {
    this.tasksVersion = 0,
    this.eventsVersion = 0,
    this.docsVersion = 0,
    this.localWrites = const {},
  });

  final Map<Workspace, Replica> _replicas;

  /// Bumped when tasks change (locally or from a merge).
  final int tasksVersion;

  /// Bumped when XP events or the progress reset marker change.
  final int eventsVersion;

  /// Bumped when notes or projects change.
  final int docsVersion;

  /// Per-workspace count of local writes; sync listens to schedule uploads.
  final Map<Workspace, int> localWrites;

  Replica operator [](Workspace ws) => _replicas[ws]!;

  Iterable<(Workspace, Replica)> get entries =>
      _replicas.entries.map((e) => (e.key, e.value));

  ReplicaSet bumped({
    bool tasks = false,
    bool events = false,
    bool docs = false,
    Workspace? localWrite,
  }) => ReplicaSet(
    _replicas,
    tasksVersion: tasksVersion + (tasks ? 1 : 0),
    eventsVersion: eventsVersion + (events ? 1 : 0),
    docsVersion: docsVersion + (docs ? 1 : 0),
    localWrites: localWrite == null
        ? localWrites
        : {...localWrites, localWrite: (localWrites[localWrite] ?? 0) + 1},
  );
}

final replicasProvider = NotifierProvider<ReplicasController, ReplicaSet>(
  ReplicasController.new,
);

class ReplicasController extends Notifier<ReplicaSet> {
  KeyValueStore get _store => ref.read(keyValueStoreProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  ReplicaSet build() {
    final node = ref.read(deviceIdProvider);
    final replicas = {
      for (final ws in Workspace.values)
        ws: switch (_store.read(_replicaKey(ws))) {
          final String raw => Replica.decode(raw, node: node),
          null => Replica(node),
        },
    };
    _migrateLegacy(replicas);
    return ReplicaSet(replicas);
  }

  /// Applies a local change to one workspace's replica and persists it.
  void write(
    Workspace ws,
    bool Function(Replica r, DateTime now) change, {
    bool tasks = false,
    bool events = false,
    bool docs = false,
  }) {
    final r = state[ws];
    if (!change(r, _now())) return;
    _persist(ws, r);
    state = state.bumped(
      tasks: tasks,
      events: events,
      docs: docs,
      localWrite: ws,
    );
  }

  /// Called by sync after remote changes were merged into [ws]'s replica.
  void remoteMerged(Workspace ws) {
    _persist(ws, state[ws]);
    state = state.bumped(tasks: true, events: true, docs: true);
  }

  /// Merges a backup file in. Returns true if it added or changed anything.
  /// Restored data counts as a local write, so sync uploads it too.
  bool restore(BackupFile backup) {
    final now = _now();
    var any = false;
    for (final MapEntry(key: ws, value: theirs) in backup.replicas.entries) {
      final r = state[ws];
      if (!r.merge(theirs, now)) continue;
      r.clock = r.clock.send(now);
      r.lastLocalWrite = r.clock.pack();
      _persist(ws, r);
      state = state.bumped(
        tasks: true,
        events: true,
        docs: true,
        localWrite: ws,
      );
      any = true;
    }
    return any;
  }

  void _persist(Workspace ws, Replica r) =>
      _store.write(_replicaKey(ws), r.encode());

  /// Phase 1 kept tasks and progress as plain JSON. Move them into the
  /// replicas once, so they start syncing.
  void _migrateLegacy(Map<Workspace, Replica> replicas) {
    final rawTasks = _store.read('tasks.v1');
    final rawProgress = _store.read('progress.v1');
    if (rawTasks == null && rawProgress == null) return;
    final now = _now();

    if (rawTasks != null) {
      for (final j in jsonDecode(rawTasks) as List<Object?>) {
        final t = Task.fromJson(j as Map<String, Object?>);
        replicas[t.workspace]!.put(collTasks, t.id, taskFields(t), now);
      }
    }
    if (rawProgress != null) {
      final s = ProgressStats.fromJson(
        jsonDecode(rawProgress) as Map<String, Object?>,
      );
      final e = ProgressEvent(
        id: const Uuid().v4(),
        at: s.lastActiveAt ?? now,
        kind: ProgressKind.carryover,
        label: 'Progress from before sync',
        xp: s.xp,
        coins: s.coins,
        started: s.started,
        completed: s.completed,
        ughCompleted: s.ughCompleted,
        accurate: s.accurateEstimates,
        oldCleared: s.oldTasksCleared,
        focusMinutes: s.focusMinutes,
        keptGoing: s.justFiveKeptGoing,
        panic: s.panicStarts,
        days: [for (final d in s.activeDays) dayKey(d)],
      );
      replicas[Workspace.personal]!.put(collEvents, e.id, e.toJson(), now);
    }
    for (final e in replicas.entries) {
      _persist(e.key, e.value);
    }
    _store.remove('tasks.v1');
    _store.remove('progress.v1');
  }
}

/// A task as replica fields (the id is the record key). `deleted: false`
/// revives a record tombstoned earlier, e.g. a task moved Work → Personal
/// → Work.
Map<String, Object?> taskFields(Task t) => t.toJson()
  ..remove('id')
  ..['deleted'] = false;

Task? taskFromRecord(String id, Record rec) {
  if (rec.isDeleted) return null;
  try {
    return Task.fromJson({...rec.values, 'id': id});
  } on Object {
    // A record half-written by an older or newer app version: skip it
    // rather than break the list.
    return null;
  }
}
