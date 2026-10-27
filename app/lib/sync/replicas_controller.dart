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

  /// Workspaces whose migrated Phase 1 data isn't saved yet; the old keys
  /// are removed once this is empty.
  final _legacyWaiting = <Workspace>{};

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
    // Every workspace: the moved copy may arrive in the other workspace's
    // round, after the edit landed on the tombstone here.
    final moved = {for (final w in Workspace.values) ..._settleTombstones(w)};
    for (final other in moved) {
      if (other != ws) _persist(other, state[other]);
    }
    final saved = _persist(ws, state[ws]);
    state = state.bumped(tasks: true, events: true, docs: true);
    for (final w in moved) {
      state = state.bumped(localWrite: w);
    }
    return saved;
  }

  /// An edit synced in for a record that's deleted here (one device moved
  /// a task to the other workspace, or deleted it, while another edited
  /// it) would otherwise sit as hidden text in this workspace's account.
  /// Once the record's live copy in the other workspace is here too,
  /// carries each such edit there (where it's newer) and blanks it here.
  /// With no live copy (a plain delete), it's left as it was. Returns the
  /// workspaces written to.
  Set<Workspace> _settleTombstones(Workspace ws) {
    final now = _now();
    final r = state[ws];
    final touched = <Workspace>{};
    for (final coll in r.collections.toList()) {
      for (final MapEntry(key: id, value: rec)
          in r.collection(coll).entries.toList()) {
        if (!rec.isDeleted) continue;
        final stray = {
          for (final f in rec.values.entries)
            if (f.key != 'deleted' && f.value != null) f.key: f.value,
        };
        if (stray.isEmpty) continue;
        var carried = false;
        for (final (other, o) in state.entries) {
          if (other == ws) continue;
          final live = o.get(coll, id);
          if (live == null || live.isDeleted) continue;
          carried = true;
          final newer = {
            for (final f in stray.entries)
              // Which workspace it's in belongs to the move, not the edit.
              if (f.key != 'workspace' &&
                  (live.clocks[f.key] ?? '').compareTo(rec.clocks[f.key]!) < 0)
                f.key: f.value,
          };
          if (newer.isNotEmpty && o.put(coll, id, newer, now)) {
            touched.add(other);
          }
        }
        if (!carried) continue;
        r.put(coll, id, {for (final k in stray.keys) k: null}, now);
        touched.add(ws);
      }
    }
    return touched;
  }

  /// Another install is using this device's id (a phone restored from a
  /// backup of this one, while the old one is still in use): take a new id
  /// so the two stop writing one sync file and skipping each other's
  /// changes. Every replica is re-owned; sync then creates a new file per
  /// workspace, and the old file is read like any other device's.
  void changeDeviceId() {
    final id = const Uuid().v4();
    _store.write('device.id', id);
    ref.invalidate(deviceIdProvider);
    final replicas = {
      for (final (ws, r) in state.entries)
        ws: Replica.decode(r.encode(), node: id),
    };
    state = ReplicaSet(
      replicas,
      tasksVersion: state.tasksVersion + 1,
      eventsVersion: state.eventsVersion + 1,
      docsVersion: state.docsVersion + 1,
      localWrites: state.localWrites,
      unsaved: state.unsaved,
    );
    for (final e in replicas.entries) {
      _persist(e.key, e.value);
    }
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
    // Every write is a full copy, so any success saves the migrated data.
    if (_legacyWaiting.remove(ws) && _legacyWaiting.isEmpty) {
      _store.remove('tasks.v1');
      _store.remove('progress.v1');
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
  /// replicas once, so they start syncing. The old keys are only removed
  /// after the replicas are saved, and running it again (the app closed
  /// first) adds nothing twice and doesn't overwrite later edits.
  void _migrateLegacy(Map<Workspace, Replica> replicas) {
    final rawTasks = _store.read('tasks.v1');
    final rawProgress = _store.read('progress.v1');
    if (rawTasks == null && rawProgress == null) return;
    final now = _now();

    if (rawTasks != null) {
      for (final j in jsonDecode(rawTasks) as List<Object?>) {
        final t = Task.fromJson(j as Map<String, Object?>);
        final r = replicas[t.workspace]!;
        if (r.get(collTasks, t.id) != null) continue;
        r.put(collTasks, t.id, taskFields(t), now);
      }
    }
    if (rawProgress != null) {
      final s = ProgressStats.fromJson(
        jsonDecode(rawProgress) as Map<String, Object?>,
      );
      final e = ProgressEvent(
        id: 'legacy-progress',
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
      final r = replicas[Workspace.personal]!;
      if (r.get(collEvents, e.id) == null) {
        r.put(collEvents, e.id, e.toJson(), now);
      }
    }
    _legacyWaiting.addAll(replicas.keys);
    for (final e in replicas.entries) {
      _persist(e.key, e.value);
    }
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

/// Writes [fields] to record [id] in [coll], skipping those this build
/// reads back unchanged from what's stored ([normalize] parses a stored
/// record and writes it out again, e.g. `(j) => Task.fromJson(j).toJson()`).
/// A field this build reads with a fallback (a value from a newer build it
/// doesn't know, like a new kind of repeat) or doesn't know at all is left
/// as it is, instead of being stamped with this build's default and
/// overwriting the newer value on every device.
bool putChanged(
  Replica r,
  String coll,
  String id,
  Map<String, Object?> fields,
  Map<String, Object?> Function(Map<String, Object?>) normalize,
  DateTime now,
) {
  final stored = r.get(coll, id);
  if (stored == null || stored.isDeleted) return r.put(coll, id, fields, now);
  final Map<String, Object?> before;
  try {
    before = normalize({...stored.values, 'id': id});
  } on Object {
    return r.put(coll, id, fields, now);
  }
  return r.put(coll, id, {
    for (final e in fields.entries)
      if (e.key == 'deleted' ||
          !before.containsKey(e.key) ||
          before[e.key] != e.value)
        e.key: e.value,
  }, now);
}

/// A notes-style record's fields (the id is the record key).
Map<String, Object?> docFields(Map<String, Object?> json) => json
  ..remove('id')
  ..['deleted'] = false;
