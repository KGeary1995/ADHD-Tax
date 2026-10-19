import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/picker/picker_controller.dart';
import 'package:adhd_tax/features/settings/device_workspaces.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/sync/replicas_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(390, 844);

void main() {
  testWidgets('a Work-only copy shows, picks and adds only Work, and says '
      'what it hides', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    final tasks = c.read(tasksProvider.notifier);
    tasks.create(title: 'Buy groceries');
    tasks.create(title: 'Restock exam room', workspace: Workspace.work);
    c.read(notesProvider.notifier).create(body: 'Gift ideas');
    await tester.pumpAndSettle();

    // Settings → Show on this device → Work.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').first);
    await tester.pumpAndSettle();
    expect(c.read(deviceWorkspacesProvider), DeviceWorkspaces.work);
    expect(
      find.textContaining(
        '1 open task and 1 note from the other side are '
        'hidden on this device, not deleted.',
      ),
      findsOneWidget,
    );
    // Sync's account rows are filtered the same way, but this test build
    // has no Google keys, so Sync only shows its "not set up" note.

    // Lists, picker and notes see Work only; nothing was deleted.
    expect(c.read(tasksProvider).map((t) => t.title), ['Restock exam room']);
    expect(c.read(notesProvider), isEmpty);
    expect(c.read(pickerInputsProvider).workspaces, {Workspace.work});
    expect(
      c.read(replicasProvider)[Workspace.personal].collection(collTasks),
      hasLength(1),
    );

    // Tasks has no Personal/Work pills; Quick add has no workspace switch
    // and files into Work.
    await tester.tap(find.byTooltip('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Everything'), findsNothing);
    await tester.tap(find.byTooltip('Add a task'));
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsNothing);
    await tester.enterText(
      find.byType(TextField).first,
      'Call IT about printer',
    );
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(
      c
          .read(tasksProvider)
          .firstWhere((t) => t.title == 'Call IT about printer')
          .workspace,
      Workspace.work,
    );

    // Remembered on this device.
    expect(c.read(keyValueStoreProvider).read('device.workspaces'), 'work');
  });
}
