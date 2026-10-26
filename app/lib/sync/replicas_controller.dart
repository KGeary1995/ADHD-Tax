import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
const collRewards = 'rewards';
const collTemplates = 'templates';

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
    this.unsaved = const {},
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

  /// Workspaces whose latest change didn't reach this device's storage
  /// (retried until it does). The app shows a warning meanwhile.
  final Set<Workspace> unsaved;

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
    unsaved: unsaved,
  );

  ReplicaSet withUnsaved(Set<Workspace> unsaved) => ReplicaSet(
    _replicas,
    tasksVersion: tasksVersion,
    eventsVersion: eventsVersion,
    docsVersion: docsVersion,
    localWrites: localWrites,
    unsaved: unsaved,
  );
}

final replicasProvider = NotifierProvider<ReplicasController, ReplicaSet>(
  ReplicasController.new,
);

class ReplicasController extends Notifier<ReplicaSet> {
  KeyValueStore get _store => ref.read(keyValueStoreProvider);
  DateTime _now() => ref.read(clockProvider)();

  /// Per workspace, the number of the newest write started: only its
  /// outcome says whether the data on disk is current.
  final _writes = <Workspace, int>{};
  Timer? _retry;
  int _failures = 0;

  /// Waits between attempts to save again after a failed write.
  static const retryAfter = [
    Duration(seconds: 2),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 2),
  ];

  @override
  ReplicaSet build() {
    ref.onDispose(() => _retry?.cancel());
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
  /// True once they're on disk; sync only then records the files as read,
  /// or a failed write would leave them neither saved nor fetched again.
  Future<bool> remoteMerged(Workspace ws) {
    final saved = _persist(ws, state[ws]);
    state = state.bumped(tasks: true, events: true, docs: true);
    return saved;
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

  /// Writes [ws]'s whole replica. Each write is a full copy, so only the
  /// newest one matters: a failure marks the workspace unsaved and retries
  /// with backoff, and a later success clears it. Completes with whether
  /// the data is on disk.
  Future<bool> _persist(Workspace ws, Replica r) async {
    final n = _writes[ws] = (_writes[ws] ?? 0) + 1;
    try {
      await _store.write(_replicaKey(ws), r.encode());
    } on Object {
      if (_writes[ws] == n && ref.mounted) {
        state = state.withUnsaved({...state.unsaved, ws});
        _scheduleRetry();
      }
      return false;
    }
    if (_writes[ws] == n && ref.mounted && state.unsaved.contains(ws)) {
      _failures = 0;
      state = state.withUnsaved({...state.unsaved}..remove(ws));
      if (state.unsaved.isEmpty) _retry?.cancel();
    }
    return true;
  }

  void _scheduleRetry() {
    if (_retry?.isActive ?? false) return;
    final wait = retryAfter[math.min(_failures++, retryAfter.length - 1)];
    _retry = Timer(wait, () {
      if (!ref.mounted) return;
      for (final ws in state.unsaved) {
        _persist(ws, state[ws]);
      }
    });
  }

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

/// Reads a notes-style record (notes, projects, rewards, templates) with
/// [fromJson]; null when deleted or unreadable.
T? docFromRecord<T>(
  String id,
  Record rec,
  T Function(Map<String, Object?>) fromJson,
) {
  if (rec.isDeleted) return null;
  try {
    return fromJson({...rec.values, 'id': id});
  } on Object {
    return null; // Written by a newer build in a way we can't read: skip.
  }
}

/// A notes-style record's fields (the id is the record key).
Map<String, Object?> docFields(Map<String, Object?> json) => json
  ..remove('id')
  ..['deleted'] = false;
