import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/capture/quick_add_sheet.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _desktop = Size(1440, 900);

void main() {
  testWidgets('desktop Tasks: filters in a sidebar, view switch in the '
      'header', (tester) async {
    final c = await pumpApp(tester, size: _desktop);
    final p = c
        .read(projectsProvider.notifier)
        .create('Front desk training', Workspace.work);
    final tasks = c.read(tasksProvider.notifier);
    tasks.create(
      title: 'Write the cheat sheet',
      workspace: Workspace.work,
      projectId: p.id,
    );
    tasks.create(title: 'Laundry');
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.byType(SideItem), findsWidgets);
    expect(find.widgetWithText(SideItem, 'Everything'), findsOneWidget);
    expect(find.widgetWithText(SideItem, 'Weekly reset'), findsOneWidget);
    // No phone pills duplicating the sidebar.
    expect(find.widgetWithText(Pill, 'All projects'), findsNothing);

    await tester.tap(find.widgetWithText(SideItem, 'Front desk training'));
    await tester.pumpAndSettle();
    expect(find.text('Write the cheat sheet'), findsOneWidget);
    expect(find.text('Laundry'), findsNothing);
    expect(find.byTooltip('Project options'), findsOneWidget);

    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    expect(find.text('To do'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop Notes: sidebar and a grid; Quick add is a window', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _desktop);
    final notes = c.read(notesProvider.notifier);
    for (final t in ['One #a', 'Two #b', 'Three #a']) {
      notes.create(title: t);
    }
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SideItem, '#a'), findsOneWidget);
    // Side by side: two tiles share a row.
    final rows = {
      for (final t in ['One #a', 'Two #b', 'Three #a'])
        tester.getTopLeft(find.text(t)).dy.round(),
    };
    expect(rows, hasLength(2));

    await tester.tap(find.widgetWithText(SideItem, '#a'));
    await tester.pumpAndSettle();
    expect(find.text('Two #b'), findsNothing);

    showQuickAdd(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('Type when, how long'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
