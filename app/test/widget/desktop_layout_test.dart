import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/capture/quick_add_sheet.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('desktop pages use the width: two columns, not a phone strip', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _desktop);
    final t = c
        .read(tasksProvider.notifier)
        .create(title: 'Renew the parking permit');
    await tester.pumpAndSettle();

    // Left of [b] by a column's width, and starting near the same height.
    void sideBySide(Finder a, Finder b) {
      final pa = tester.getTopLeft(a), pb = tester.getTopLeft(b);
      expect(pb.dx - pa.dx, greaterThan(300), reason: 'columns');
      expect((pb.dy - pa.dy).abs(), lessThan(200), reason: 'same height');
    }

    // Home: the task card on the left; the picker's controls on the
    // right, live, with no sheet to open.
    sideBySide(find.text('Renew the parking permit'), find.text('Right now'));
    expect(find.text('How much time do you have?'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await tester.tap(find.text('10m'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Renew the parking permit'), findsNothing);
    await tester.tap(find.text('30m'));
    await tester.pumpAndSettle();
    expect(find.text('Renew the parking permit'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    sideBySide(find.textContaining('Level '), find.text('Reward shop'));

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // Settings: a section list, one section open at a time; its pickers
    // open as windows, not sheets from the bottom.
    expect(find.widgetWithText(SideItem, 'Backup'), findsOneWidget);
    expect(find.text('Save a backup file'), findsNothing);
    await tester.tap(find.text('Celebrations'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SideItem, 'Backup'));
    await tester.pumpAndSettle();
    expect(find.text('Save a backup file'), findsOneWidget);
    expect(find.text('Celebrations'), findsNothing);

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push('/task/${t.id}');
    await tester.pumpAndSettle();
    sideBySide(find.text('Task'), find.text('Workspace'));
    expect(tester.takeException(), isNull);
  });
}
