import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/features/settings/backup_files.dart';
import 'package:adhd_tax/features/settings/settings_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(390, 844);

class FakeBackupFiles implements BackupFiles {
  String? saved;
  String? savedName;
  String? toOpen;

  @override
  Future<bool> save(String name, String json) async {
    savedName = name;
    saved = json;
    return true;
  }

  @override
  Future<String?> open() async => toOpen;
}

Future<void> openSettingsRow(WidgetTester tester, String row) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  // Settings is a lazy list: scroll until the row is built.
  await tester.dragUntilVisible(
    find.text(row),
    find.byType(ListView).first,
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(row));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('save a backup on one phone, restore it on a wiped one', (
    tester,
  ) async {
    final files = FakeBackupFiles();
    final old = await pumpApp(
      tester,
      size: _phone,
      overrides: [backupFilesProvider.overrideWithValue(files)],
    );
    old.read(tasksProvider.notifier)
      ..create(title: 'Renew car registration')
      ..create(title: 'Send rota', workspace: Workspace.work);
    await tester.pumpAndSettle();

    await openSettingsRow(tester, 'Save a backup file');
    expect(files.saved, isNotNull);
    expect(files.savedName, startsWith('Unstuck backup '));
    expect(find.textContaining('Backup saved'), findsOneWidget);
    expect(find.textContaining('Last saved today'), findsOneWidget);
    // Let the snackbar time out; the next app reuses the same messenger.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // A new, empty install.
    final restoreFiles = FakeBackupFiles()..toOpen = files.saved;
    final fresh = await pumpApp(
      tester,
      size: _phone,
      overrides: [backupFilesProvider.overrideWithValue(restoreFiles)],
    );
    expect(fresh.read(tasksProvider), isEmpty);

    await openSettingsRow(tester, 'Restore from a backup file');
    expect(find.textContaining('has 2 tasks'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Restored.'), findsOneWidget);
    expect(fresh.read(tasksProvider).map((t) => t.title).toSet(), {
      'Renew car registration',
      'Send rota',
    });
    expect(
      fresh
          .read(tasksProvider)
          .firstWhere((t) => t.title == 'Send rota')
          .workspace,
      Workspace.work,
    );
  });

  testWidgets('a file that is not a backup is refused politely', (
    tester,
  ) async {
    final files = FakeBackupFiles()..toOpen = '{"hello": "world"}';
    await pumpApp(
      tester,
      size: _phone,
      overrides: [backupFilesProvider.overrideWithValue(files)],
    );
    await openSettingsRow(tester, 'Restore from a backup file');
    expect(find.text("That file isn't an Unstuck backup."), findsOneWidget);
    expect(find.text('Restore this backup?'), findsNothing);
  });

  testWidgets('settings travel in the backup; per-install and consent '
      'settings and secrets do not', (tester) async {
    final files = FakeBackupFiles();
    final old = await pumpApp(
      tester,
      size: _phone,
      overrides: [backupFilesProvider.overrideWithValue(files)],
    );
    old
        .read(settingsProvider.notifier)
        .update((x) => x.copyWith(celebration: CelebrationLevel.party));
    final oldStore = old.read(keyValueStoreProvider)
      ..write('focus.sound', 'rain')
      ..write('device.workspaces', 'personal')
      ..write('ai.allowWork', 'true');
    expect(oldStore.read('focus.sound'), 'rain');
    await tester.pumpAndSettle();
    await openSettingsRow(tester, 'Save a backup file');
    expect(files.saved, contains('focus.sound'));
    expect(files.saved, isNot(contains('device.workspaces')));
    expect(files.saved, isNot(contains('ai.allowWork')));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // The work-profile copy, set to Work only.
    final fresh = await pumpApp(
      tester,
      size: _phone,
      overrides: [
        backupFilesProvider.overrideWithValue(
          FakeBackupFiles()..toOpen = files.saved,
        ),
      ],
    );
    final store = fresh.read(keyValueStoreProvider)
      ..write('device.workspaces', 'work');
    await openSettingsRow(tester, 'Restore from a backup file');
    expect(find.text('Also restore its settings'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.textContaining('settings'), findsWidgets);
    expect(fresh.read(settingsProvider).celebration, CelebrationLevel.party);
    expect(store.read('focus.sound'), 'rain');
    expect(store.read('device.workspaces'), 'work');
    expect(store.read('ai.allowWork'), isNull);
  });
}
