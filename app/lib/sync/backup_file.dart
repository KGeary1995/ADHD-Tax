import 'dart:convert';

import '../data/models/task.dart';
import 'replica.dart';

/// A backup file the user keeps themselves: both workspaces' replicas,
/// clocks included, so restoring is a CRDT merge. Restoring an old file
/// never undoes newer edits, and restoring the same file twice is harmless.
class BackupFile {
  const BackupFile({required this.replicas, this.exportedAt});

  final Map<Workspace, Replica> replicas;
  final DateTime? exportedAt;

  static const kind = 'unstuck-backup';
  static const version = 1;

  /// Open (not deleted) tasks in the file, for the confirmation message.
  int get taskCount => replicas.values.fold(
    0,
    (n, r) =>
        n + r.collection('tasks').values.where((x) => !x.isDeleted).length,
  );

  String encode(DateTime now) => const JsonEncoder.withIndent(' ').convert({
    'app': 'Unstuck',
    'kind': kind,
    'v': version,
    'exportedAt': now.toUtc().toIso8601String(),
    'workspaces': {
      for (final e in replicas.entries) e.key.name: e.value.toJson(),
    },
  });

  /// Throws a [FormatException] with a message fit to show the user.
  static BackupFile decode(String text) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      throw const FormatException("That file isn't an Unstuck backup.");
    }
    if (j is! Map || j['kind'] != kind) {
      throw const FormatException("That file isn't an Unstuck backup.");
    }
    final v = j['v'];
    if (v is! int || v > version) {
      throw const FormatException(
        'That backup is from a newer version of Unstuck. Update the app, '
        'then try again.',
      );
    }
    final ws = j['workspaces'];
    if (ws is! Map) {
      throw const FormatException("That backup file looks damaged.");
    }
    final replicas = <Workspace, Replica>{};
    try {
      for (final w in Workspace.values) {
        final r = ws[w.name];
        if (r is Map) {
          // Re-owned so none of its writes count as this device's.
          replicas[w] = Replica.fromJson(
            Map<String, Object?>.from(r),
            node: 'backup',
          );
        }
      }
    } on Object {
      throw const FormatException("That backup file looks damaged.");
    }
    return BackupFile(
      replicas: replicas,
      exportedAt: DateTime.tryParse(j['exportedAt'] as String? ?? ''),
    );
  }
}

/// `Unstuck backup 2026-10-18.json`
String backupFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Unstuck backup ${now.year}-${two(now.month)}-${two(now.day)}.json';
}
