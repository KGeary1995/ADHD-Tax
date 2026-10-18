import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/sync/backup_file.dart';
import 'package:adhd_tax/sync/replica.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var tick = DateTime.utc(2026, 10, 18, 12);
  DateTime now() => tick = tick.add(const Duration(seconds: 1));

  BackupFile roundTrip(Map<Workspace, Replica> replicas) =>
      BackupFile.decode(BackupFile(replicas: replicas).encode(now()));

  test('round-trips both workspaces with their clocks', () {
    final personal = Replica('phone')
      ..put('tasks', 'a', {'title': 'Renew passport'}, now())
      ..put('tasks', 'b', {'title': 'Gone'}, now())
      ..delete('tasks', 'b', now());
    final work = Replica('phone')
      ..put('tasks', 'c', {'title': 'Order lens cleaner'}, now());

    final back = roundTrip({
      Workspace.personal: personal,
      Workspace.work: work,
    });

    expect(back.taskCount, 2); // the deleted one doesn't count
    expect(back.exportedAt, isNotNull);
    expect(
      back.replicas[Workspace.personal]!.get('tasks', 'a')!.clocks,
      personal.get('tasks', 'a')!.clocks,
    );
    expect(back.replicas[Workspace.work]!.get('tasks', 'c')!.values, {
      'title': 'Order lens cleaner',
    });
  });

  test('restoring an old backup brings back lost tasks but keeps newer '
      'edits', () {
    final phone = Replica('phone')
      ..put('tasks', 'a', {'title': 'Call bank', 'ugh': 1}, now())
      ..put('tasks', 'b', {'title': 'Book dentist'}, now());
    final backup = roundTrip({Workspace.personal: phone});

    // Later: a new phone has only an edited copy of one task.
    final fresh = Replica.decode(phone.encode(), node: 'new-phone')
      ..delete('tasks', 'b', now());
    // ...and a deliberately newer edit.
    fresh.put('tasks', 'a', {'title': 'Call bank about fee'}, now());

    // Everything in the old backup is older than what's here.
    expect(fresh.merge(backup.replicas[Workspace.personal]!, now()), isFalse);
    expect(fresh.get('tasks', 'a')!.values['title'], 'Call bank about fee');
    // Deleted after the backup was made, so it stays deleted.
    expect(fresh.get('tasks', 'b')!.isDeleted, isTrue);

    final empty = Replica('wiped');
    expect(empty.merge(backup.replicas[Workspace.personal]!, now()), isTrue);
    expect(empty.get('tasks', 'b')!.values['title'], 'Book dentist');
    // Restoring twice changes nothing.
    expect(empty.merge(backup.replicas[Workspace.personal]!, now()), isFalse);
  });

  test('rejects files that are not backups, with a readable message', () {
    for (final text in ['not json', '{"tasks": []}', '[1, 2]']) {
      expect(
        () => BackupFile.decode(text),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains("isn't an Unstuck backup"),
          ),
        ),
      );
    }
    expect(
      () => BackupFile.decode('{"kind": "unstuck-backup", "v": 99}'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('newer version'),
        ),
      ),
    );
    expect(
      () => BackupFile.decode(
        '{"kind": "unstuck-backup", "v": 1, '
        '"workspaces": {"personal": {"c": 5}}}',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('file name carries the date', () {
    expect(
      backupFileName(DateTime(2026, 3, 7, 22)),
      'Unstuck backup 2026-03-07.json',
    );
  });
}
