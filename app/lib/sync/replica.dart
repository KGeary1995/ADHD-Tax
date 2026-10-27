/// Last-writer-wins document store that merges deterministically.
///
/// Every field carries the [Hlc] of its last write. Merging two replicas
/// takes, field by field, the value with the later clock, so merges are
/// commutative, associative and idempotent: devices converge no matter what
/// order they see each other's state in. Deletes are tombstones. Pure Dart.
library;

import 'dart:convert';

import '../core/hlc.dart';

class Record {
  Record([Map<String, Object?>? values, Map<String, String>? clocks])
    : values = values ?? {},
      clocks = clocks ?? {};

  /// JSON-compatible scalar values.
  final Map<String, Object?> values;

  /// Field → packed [Hlc] of its last write.
  final Map<String, String> clocks;

  bool get isDeleted => values['deleted'] == true;

  Record copy() => Record({...values}, {...clocks});

  Object toJson() {
    // Most records are written in one go; store one clock instead of many.
    final distinct = clocks.values.toSet();
    return {
      'f': values,
      't': distinct.length == 1 && clocks.length == values.length
          ? distinct.first
          : clocks,
    };
  }

  factory Record.fromJson(Map<String, Object?> j) {
    final values = Map<String, Object?>.from(j['f'] as Map);
    final t = j['t'];
    final clocks = t is String
        ? {for (final k in values.keys) k: t}
        : Map<String, String>.from(t as Map);
    return Record(values, clocks);
  }
}

class Replica {
  Replica(
    this.node, {
    Hlc? clock,
    this.lastLocalWrite,
    Map<String, Map<String, Record>>? data,
  }) : clock = clock ?? Hlc.zero(node),
       _data = data ?? {};

  /// This device's id; stamps every local write.
  final String node;

  /// Latest clock this replica has issued or seen.
  Hlc clock;

  /// Packed clock of the latest write made on this device. Merges don't
  /// touch it, so sync uploads only when there is something new of ours.
  String? lastLocalWrite;
  final Map<String, Map<String, Record>> _data;

  Iterable<String> get collections => _data.keys;

  Map<String, Record> collection(String name) => _data[name] ?? const {};

  Record? get(String coll, String id) => _data[coll]?[id];

  /// Writes the given fields of a record. Unchanged fields keep their old
  /// clocks, so concurrent edits to different fields both survive.
  /// Returns true if anything changed.
  bool put(String coll, String id, Map<String, Object?> fields, DateTime now) {
    final rec = (_data[coll] ??= {})[id] ??= Record();
    Hlc? stamp;
    for (final e in fields.entries) {
      if (rec.values.containsKey(e.key) && rec.values[e.key] == e.value) {
        continue;
      }
      stamp ??= clock = clock.send(now);
      rec.values[e.key] = e.value;
      rec.clocks[e.key] = stamp.pack();
    }
    if (stamp != null) lastLocalWrite = stamp.pack();
    return stamp != null;
  }

  /// Tombstones a record: blanks every field so nothing sensitive lingers
  /// in synced copies, and marks it deleted.
  bool delete(String coll, String id, DateTime now) {
    final rec = get(coll, id);
    if (rec == null || rec.isDeleted) return false;
    return put(coll, id, {
      for (final k in rec.values.keys) k: null,
      'deleted': true,
    }, now);
  }

  /// Folds [other] into this replica. Returns true if any value changed.
  bool merge(Replica other, DateTime now) {
    var changed = false;
    for (final c in other._data.entries) {
      final mine = _data[c.key] ??= {};
      for (final r in c.value.entries) {
        final theirs = r.value;
        final local = mine[r.key];
        if (local == null) {
          mine[r.key] = theirs.copy();
          changed = true;
          continue;
        }
        for (final f in theirs.clocks.entries) {
          final current = local.clocks[f.key];
          if (current == null || f.value.compareTo(current) > 0) {
            local.values[f.key] = theirs.values[f.key];
            local.clocks[f.key] = f.value;
            changed = true;
          }
        }
      }
    }
    if (other.clock > clock) clock = clock.receive(other.clock, now);
    return changed;
  }

  /// Whether [other] holds a write stamped with this replica's [node] that
  /// this replica doesn't have. A copy of our own file should only ever
  /// hold our older writes; anything newer came from another install using
  /// the same id (or from before this device's storage was rolled back).
  bool lacksOwnWritesIn(Replica other) {
    final mark = '-$node';
    for (final c in other._data.entries) {
      for (final r in c.value.entries) {
        for (final f in r.value.clocks.entries) {
          if (!f.value.endsWith(mark)) continue;
          final mine = _data[c.key]?[r.key]?.clocks[f.key];
          if (mine == null || f.value.compareTo(mine) > 0) return true;
        }
      }
    }
    return false;
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'node': node,
    'clock': clock.pack(),
    'local': lastLocalWrite,
    'c': {
      for (final c in _data.entries)
        c.key: {for (final r in c.value.entries) r.key: r.value.toJson()},
    },
  };

  /// Loads a replica, re-owning it as [node] (a remote file keeps its
  /// author's records and clocks, but local writes are ours).
  factory Replica.fromJson(Map<String, Object?> j, {String? node}) {
    final owner = node ?? j['node'] as String;
    final data = <String, Map<String, Record>>{};
    final c = j['c'] as Map? ?? const {};
    for (final coll in c.entries) {
      data[coll.key as String] = {
        for (final r in (coll.value as Map).entries)
          r.key as String: Record.fromJson(Map<String, Object?>.from(r.value)),
      };
    }
    final packed = j['clock'] as String?;
    final clock = packed == null ? Hlc.zero(owner) : Hlc.parse(packed);
    return Replica(
      owner,
      clock: Hlc(clock.millis, clock.counter, owner),
      // Our own saved replica keeps its record of our latest write (sync
      // compares it with what was uploaded). Anyone else's file re-owned as
      // ours, e.g. a backup from another device: none of its writes are ours.
      lastLocalWrite: node == null || node == j['node']
          ? j['local'] as String?
          : null,
      data: data,
    );
  }

  String encode() => jsonEncode(toJson());

  static Replica decode(String s, {String? node}) =>
      Replica.fromJson(jsonDecode(s) as Map<String, Object?>, node: node);
}
