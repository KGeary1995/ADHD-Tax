import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../sync/backup_file.dart';
import '../../sync/replicas_controller.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import 'backup_files.dart';

const _lastSavedKey = 'backup.lastSavedAt';

/// When this device last saved a backup file (device-local).
final lastBackupProvider = NotifierProvider<LastBackup, DateTime?>(
  LastBackup.new,
);

class LastBackup extends Notifier<DateTime?> {
  @override
  DateTime? build() => DateTime.tryParse(
    ref.read(keyValueStoreProvider).read(_lastSavedKey) ?? '',
  );

  void saved(DateTime at) {
    ref.read(keyValueStoreProvider).write(_lastSavedKey, at.toIso8601String());
    state = at;
  }
}

/// "Save a backup file" and "Restore from a backup file": a copy of every
/// task and all XP that the user keeps, with no Google account needed.
class BackupGroup extends ConsumerWidget {
  const BackupGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final last = ref.watch(lastBackupProvider);
    final now = ref.read(clockProvider)();
    return Group(
      label: 'Backup file',
      children: [
        GroupRow(
          title: 'Save a backup file',
          subtitle: last == null
              ? 'Every task and all your XP, in one file you keep'
              : 'Last saved ${_ago(last, now)}',
          trailing: Icon(Icons.save_alt_rounded, color: s.muted),
          onTap: () => _save(context, ref),
        ),
        GroupRow(
          title: 'Restore from a backup file',
          subtitle: 'Adds it back in. Nothing newer here is lost.',
          trailing: Icon(Icons.restore_rounded, color: s.muted),
          onTap: () => _restore(context, ref),
        ),
      ],
    );
  }
}

String _ago(DateTime at, DateTime now) {
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  return switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    < 7 => '$days days ago',
    _ => 'on ${formatDate(at)}',
  };
}

Future<void> _save(BuildContext context, WidgetRef ref) async {
  final now = ref.read(clockProvider)();
  final replicas = ref.read(replicasProvider);
  // Built before any await: browsers only open the share sheet straight
  // after the tap.
  final json = BackupFile(
    replicas: {for (final (ws, r) in replicas.entries) ws: r},
  ).encode(now);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final saved = await ref
        .read(backupFilesProvider)
        .save(backupFileName(now), json);
    if (!saved) return;
    ref.read(lastBackupProvider.notifier).saved(now);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Backup saved. Keep it somewhere off this device.'),
      ),
    );
  } on Object catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text("Couldn't save the backup: $e")),
    );
  }
}

Future<void> _restore(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final BackupFile backup;
  try {
    final text = await ref.read(backupFilesProvider).open();
    if (text == null) return;
    backup = BackupFile.decode(text);
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  } on Object catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text("Couldn't open that file: $e")),
    );
    return;
  }
  if (!context.mounted) return;

  final n = backup.taskCount;
  final from = backup.exportedAt == null
      ? ''
      : ' from ${formatDate(backup.exportedAt!.toLocal())}';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Restore this backup?'),
      content: Text(
        'The backup$from has $n ${n == 1 ? 'task' : 'tasks'}. They are added '
        'back alongside what is here; anything you changed more recently on '
        'this device stays as it is.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Restore'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final changed = ref.read(replicasProvider.notifier).restore(backup);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        changed
            ? 'Restored. Your tasks and XP from the backup are back.'
            : 'Nothing new in that backup: this device already has it all.',
      ),
    ),
  );
}
