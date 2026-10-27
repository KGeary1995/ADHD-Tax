/// One sync round between a local replica and a remote folder. Pure Dart
/// apart from the [RemoteStore] it talks to.
///
/// Each device owns exactly one remote file per workspace,
/// `state.<workspace>.<deviceId>.json`, holding its full replica. A round
/// downloads other devices' files that changed since last time, merges them,
/// and uploads our own file if we have local writes it doesn't have yet.
/// Devices never write the same file, so there are no write conflicts, and
/// merging is order-independent, so every device converges.
library;

import 'dart:convert';

import 'remote_store.dart';
import 'replica.dart';

/// What the engine remembers between rounds.
class SyncState {
  const SyncState({
    this.ownFileId,
    this.seen = const {},
    this.uploadedClock,
    this.lastSyncedAt,
    this.email,
    this.uploadOwed = false,
  });

  final String? ownFileId;

  /// Remote file name → checksum last merged.
  final Map<String, String> seen;

  /// [Replica.lastLocalWrite] at our last upload; a newer local write means
  /// re-upload.
  final String? uploadedClock;
  final DateTime? lastSyncedAt;
  final String? email;

  /// Other devices' changes were merged and saved here but not uploaded
  /// yet: the next round rewrites our file even with no local edits.
  /// Stored, so a restart in between doesn't forget it.
  final bool uploadOwed;

  /// [uploadedClock] can be set back to null (nothing of ours uploaded
  /// yet); leaving it out keeps the current value.
  SyncState copyWith({
    String? ownFileId,
    Map<String, String>? seen,
    Object? uploadedClock = _keep,
    DateTime? lastSyncedAt,
    String? email,
    bool? uploadOwed,
  }) => SyncState(
    ownFileId: ownFileId ?? this.ownFileId,
    seen: seen ?? this.seen,
    uploadedClock: identical(uploadedClock, _keep)
        ? this.uploadedClock
        : uploadedClock as String?,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    email: email ?? this.email,
    uploadOwed: uploadOwed ?? this.uploadOwed,
  );

  Map<String, Object?> toJson() => {
    'ownFileId': ownFileId,
    'seen': seen,
    'uploadedClock': uploadedClock,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'email': email,
    if (uploadOwed) 'uploadOwed': true,
  };

  factory SyncState.fromJson(Map<String, Object?> j) => SyncState(
    ownFileId: j['ownFileId'] as String?,
    seen: Map<String, String>.from(j['seen'] as Map? ?? const {}),
    uploadedClock: j['uploadedClock'] as String?,
    lastSyncedAt: j['lastSyncedAt'] == null
        ? null
        : DateTime.parse(j['lastSyncedAt'] as String),
    email: j['email'] as String?,
    uploadOwed: j['uploadOwed'] == true,
  );
}

const _keep = Object();

class SyncOutcome {
  const SyncOutcome({
    required this.state,
    required this.merged,
    required this.uploaded,
    this.skipped = const [],
    this.cloned = false,
  });

  final SyncState state;

  /// Remote changes were merged into the local replica.
  final bool merged;
  final bool uploaded;

  /// Remote files that couldn't be read or parsed; retried next round.
  final List<String> skipped;

  /// Our own cloud file holds writes stamped with this device's id that
  /// this device never made: another install has the same id (a phone
  /// restored from a backup of this one). The caller should take a new id.
  final bool cloned;
}

String filePrefix(String workspace) => 'state.$workspace.';

String fileName(String workspace, String deviceId) =>
    '${filePrefix(workspace)}$deviceId.json';

/// The round was abandoned because [syncOnce]'s `current` said so (the
/// workspace was disconnected or switched account meanwhile).
class SyncCancelled implements Exception {
  const SyncCancelled();
}

/// Runs one round. Mutates [replica] in place when remote changes merge.
///
/// [onMerged] runs after the downloads merged something and before the
/// upload, so the caller can save and show them even if the upload then
/// fails; it also runs when a later download fails, so what already merged
/// isn't left unsaved and unshown. [SyncState.uploadOwed] rewrites our file
/// even without new local writes. [checkOwn] also merges our own file when
/// it changed since we last looked: after this device's storage is rolled
/// back (an OS snapshot), the cloud copy can be newer than local data.
/// [current] is checked after every network call; once false, the round
/// stops with [SyncCancelled] before touching [replica] again.
Future<SyncOutcome> syncOnce({
  required Replica replica,
  required RemoteStore remote,
  required String workspace,
  required SyncState state,
  required DateTime Function() now,
  Future<void> Function()? onMerged,
  bool checkOwn = false,
  bool Function()? current,
}) async {
  void check() {
    if (current != null && !current()) throw const SyncCancelled();
  }

  final ownName = fileName(workspace, replica.node);
  final files = await remote.list(filePrefix(workspace));
  check();
  final seen = {...state.seen};
  final skipped = <String>[];
  var merged = false;
  var cloned = false;
  // The id must still name this device's file: after the device id
  // changes, the old id points at a file we no longer own.
  String? ownFileId =
      files.any((f) => f.id == state.ownFileId && f.name == ownName)
      ? state.ownFileId
      : null;

  try {
    for (final f in files) {
      if (f.name == ownName) {
        ownFileId ??= f.id;
        if (!checkOwn) continue;
      }
      if (seen[f.name] == f.checksum) continue;
      try {
        final bytes = await remote.read(f.id);
        check();
        final theirs = Replica.decode(utf8.decode(bytes));
        if (f.name == ownName && replica.lacksOwnWritesIn(theirs)) {
          cloned = true;
        }
        if (replica.merge(theirs, now())) merged = true;
        seen[f.name] = f.checksum;
      } on FormatException {
        skipped.add(f.name);
      } on TypeError {
        skipped.add(f.name);
      } on ArgumentError {
        // Includes RangeError: a clock that doesn't parse (a damaged file,
        // or a newer build's format). Skip the file, keep syncing the rest.
        skipped.add(f.name);
      }
    }
  } on SyncCancelled {
    rethrow;
  } on Object {
    // A later file failed: save and show what the earlier ones brought.
    if (merged && onMerged != null) await onMerged();
    rethrow;
  }

  if (merged && onMerged != null) await onMerged();
  check();

  final local = replica.lastLocalWrite;
  var uploaded = false;
  // Also rewrite our file after merging someone else's changes: otherwise
  // it keeps old text of things since edited, deleted or moved to the other
  // workspace (e.g. a Work task in the Personal account) until this device
  // happens to edit something. It can't ping-pong: the next round merges
  // nothing new, so nobody uploads again.
  // A clone's own file belongs to the other install now: never overwrite
  // it. The caller takes a new id, and the next round uploads under it.
  if (!cloned &&
      (ownFileId == null ||
          local != state.uploadedClock ||
          merged ||
          state.uploadOwed)) {
    final bytes = utf8.encode(replica.encode());
    if (ownFileId == null) {
      ownFileId = await remote.create(ownName, bytes);
    } else {
      await remote.update(ownFileId, bytes);
    }
    uploaded = true;
  }

  return SyncOutcome(
    state: state.copyWith(
      ownFileId: ownFileId,
      seen: seen,
      uploadedClock: uploaded ? local : state.uploadedClock,
      lastSyncedAt: now(),
      uploadOwed: uploaded ? false : state.uploadOwed,
    ),
    merged: merged,
    uploaded: uploaded,
    skipped: skipped,
    cloned: cloned,
  );
}
