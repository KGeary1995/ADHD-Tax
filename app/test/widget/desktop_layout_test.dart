import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/capture/quick_add_sheet.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/tasks/checklist_editor.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'app_flow_test.dart' show pumpApp;

import 'package:adhd_tax/core/theme/ph.dart';

const _desktop = Size(1440, 900);

void main() {
  testWidgets('desktop Tasks: filter pills, the list, and a detail pane '
      'for the selected task', (tester) async {
    final c = await pumpApp(tester, size: _desktop);
    final p = c
        .read(projectsProvider.notifier)
        .create('Front desk training', Workspace.work);
    final tasks = c.read(tasksProvider.notifier);
    final sheet = tasks.create(
      title: 'Write the cheat sheet',
      workspace: Workspace.work,
      projectId: p.id,
      checklist: '[ ] List the calls\n[ ] Ask a senior',
    );
    tasks.create(title: 'Laundry');
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    // No second sidebar: the filters are pills above the list.
    expect(find.widgetWithText(SideItem, 'Everything'), findsNothing);
    expect(find.widgetWithText(Pill, 'All'), findsOneWidget);
    expect(find.widgetWithText(Pill, 'Projects'), findsOneWidget);

    // Tapping a row shows it in the pane instead of opening the editor;
    // a step can be ticked there.
    await tester.tap(find.text('Write the cheat sheet').first);
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, '/tasks');
    expect(find.text('STEPS'), findsOneWidget);
    expect(find.text('Work · Front desk training'), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(ChecklistRow).first,
            matching: find.byType(InkResponse),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tasks.byId(sheet.id)!.steps.first.done, isTrue);

    await tester.tap(find.widgetWithText(Pill, 'Work'));
    await tester.pumpAndSettle();
    expect(find.text('Laundry'), findsNothing);

    // Projects and List/Board are in the sheet behind the Projects pill.
    await tester.tap(find.widgetWithText(Pill, 'Projects'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(Pill, 'Front desk training'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Project options'), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Add a task'),
      ),
      findsOneWidget,
    );
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

    // Home: the task on the left; the picker's controls on the right,
    // live, with no sheet to open.
    expect(
      tester.getTopLeft(find.text('Right now')).dx -
          tester.getTopLeft(find.text('Renew the parking permit')).dx,
      greaterThan(300),
    );
    expect(find.text('How much time do you have?'), findsOneWidget);
    expect(find.byIcon(Ph.pencilSimple), findsNothing);
    await tester.tap(find.text('10m'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Renew the parking permit'), findsNothing);
    await tester.tap(find.text('30m'));
    await tester.pumpAndSettle();
    expect(find.text('Renew the parking permit'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    // The sky across the top, then two columns under it.
    expect(
      tester.getTopLeft(find.text('Reward shop')).dx -
          tester.getTopLeft(find.textContaining('Level ').first).dx,
      greaterThan(300),
    );

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
    sideBySide(find.text('FIRST 2-MINUTE STEP'), find.text('DETAILS'));
    expect(tester.takeException(), isNull);
  });
}
