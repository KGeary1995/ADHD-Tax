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
  });

  final String? ownFileId;

  /// Remote file name → checksum last merged.
  final Map<String, String> seen;

  /// [Replica.lastLocalWrite] at our last upload; a newer local write means
  /// re-upload.
  final String? uploadedClock;
  final DateTime? lastSyncedAt;
  final String? email;

  SyncState copyWith({
    String? ownFileId,
    Map<String, String>? seen,
    String? uploadedClock,
    DateTime? lastSyncedAt,
    String? email,
  }) => SyncState(
    ownFileId: ownFileId ?? this.ownFileId,
    seen: seen ?? this.seen,
    uploadedClock: uploadedClock ?? this.uploadedClock,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    email: email ?? this.email,
  );

  Map<String, Object?> toJson() => {
    'ownFileId': ownFileId,
    'seen': seen,
    'uploadedClock': uploadedClock,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'email': email,
  };

  factory SyncState.fromJson(Map<String, Object?> j) => SyncState(
    ownFileId: j['ownFileId'] as String?,
    seen: Map<String, String>.from(j['seen'] as Map? ?? const {}),
    uploadedClock: j['uploadedClock'] as String?,
    lastSyncedAt: j['lastSyncedAt'] == null
        ? null
        : DateTime.parse(j['lastSyncedAt'] as String),
    email: j['email'] as String?,
  );
}

class SyncOutcome {
  const SyncOutcome({
    required this.state,
    required this.merged,
    required this.uploaded,
    this.skipped = const [],
  });

  final SyncState state;

  /// Remote changes were merged into the local replica.
  final bool merged;
  final bool uploaded;

  /// Remote files that couldn't be read or parsed; retried next round.
  final List<String> skipped;
}

String filePrefix(String workspace) => 'state.$workspace.';

String fileName(String workspace, String deviceId) =>
    '${filePrefix(workspace)}$deviceId.json';

/// Runs one round. Mutates [replica] in place when remote changes merge.
Future<SyncOutcome> syncOnce({
  required Replica replica,
  required RemoteStore remote,
  required String workspace,
  required SyncState state,
  required DateTime Function() now,
}) async {
  final ownName = fileName(workspace, replica.node);
  final files = await remote.list(filePrefix(workspace));
  final seen = {...state.seen};
  final skipped = <String>[];
  var merged = false;
  String? ownFileId = state.ownFileId;

  for (final f in files) {
    if (f.name == ownName) {
      ownFileId ??= f.id;
      continue;
    }
    if (seen[f.name] == f.checksum) continue;
    try {
      final bytes = await remote.read(f.id);
      final theirs = Replica.decode(utf8.decode(bytes));
      if (replica.merge(theirs, now())) merged = true;
      seen[f.name] = f.checksum;
    } on FormatException {
      skipped.add(f.name);
    } on TypeError {
      skipped.add(f.name);
    }
  }

  // Our own file went missing (deleted in Drive, or a different account):
  // forget its id so we recreate it.
  if (ownFileId != null && !files.any((f) => f.id == ownFileId)) {
    ownFileId = null;
  }

  final local = replica.lastLocalWrite;
  var uploaded = false;
  if (ownFileId == null || local != state.uploadedClock) {
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
    ),
    merged: merged,
    uploaded: uploaded,
    skipped: skipped,
  );
}
