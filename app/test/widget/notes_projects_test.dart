import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(390, 844);

Future<void> tab(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip(name));
  await tester.pumpAndSettle();
}

/// Phone Tasks: workspace, project and list/board are in one sheet.
Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Show tasks'));
  await tester.pumpAndSettle();
}

Future<void> showBoard(WidgetTester tester) async {
  await openFilters(tester);
  await tester.tap(find.text('Board'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Done').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('write a note with #tags, find it, turn lines into tasks', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _phone);
    await tab(tester, 'Notes');
    expect(find.text('Get it out of your head.'), findsOneWidget);

    // + on the Notes tab starts a note, not a task.
    await tester.tap(find.byTooltip('Add a note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Vendor call');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Lens cleaner backordered #orders\n- Email rep for ETA\n- Check other supplier',
    );
    await tester.pump(const Duration(seconds: 1)); // autosave

    await tester.tap(find.byTooltip('Make tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email rep for ETA'));
    await tester.tap(find.text('Check other supplier'));
    await tester.pump();
    await tester.tap(find.text('Make 2 tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Made 2 tasks.'), findsOneWidget);
    expect(c.read(tasksProvider).map((t) => t.title).toSet(), {
      'Email rep for ETA',
      'Check other supplier',
    });

    // Back to the list: the note, its tag, and the tag filter.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Vendor call'), findsOneWidget);
    expect(find.textContaining('#orders'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'backordered');
    await tester.pumpAndSettle();
    expect(find.text('Vendor call'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'payroll');
    await tester.pumpAndSettle();
    expect(find.text('No notes match.'), findsOneWidget);
  });

  testWidgets('opening and closing a new note leaves nothing behind', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _phone);
    await tab(tester, 'Notes');
    await tester.tap(find.byTooltip('Add a note'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(c.read(notesProvider), isEmpty);
  });

  testWidgets('projects: create one, add into it, see it on the board, move '
      'a card to Done', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    c.read(tasksProvider.notifier).create(title: 'Loose task');
    await tab(tester, 'Tasks');

    await openFilters(tester);
    await tester.tap(find.text('+ New project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Move house');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Tasks now shows that project, so + files into it.
    expect(find.text('Move house'), findsWidgets);
    expect(find.text('Loose task'), findsNothing);
    await tester.tap(find.byTooltip('Add a task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Book movers');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final project = c.read(projectsProvider).single;
    final booked = c
        .read(tasksProvider)
        .firstWhere((t) => t.title == 'Book movers');
    expect(booked.projectId, project.id);

    // Board view, then Move to Done from the card's menu.
    await showBoard(tester);
    for (final col in ['To do', 'Doing', 'Waiting', 'Done']) {
      expect(find.text(col), findsWidgets);
    }
    await tester.tap(find.byTooltip('Move, start or delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to Done'));
    await tester.pumpAndSettle();
    expect(
      c.read(tasksProvider.notifier).byId(booked.id)!.status,
      TaskStatus.done,
    );
    expect(find.text('Done: Book movers'), findsOneWidget);

    // The choice of view sticks.
    expect(c.read(keyValueStoreProvider).read('tasks.view'), 'board');
  });

  testWidgets('phone board: tabs, swipe, and drop a card on a tab', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _phone);
    final tasks = c.read(tasksProvider.notifier);
    final a = tasks.create(title: 'Order toner');
    tasks.create(title: 'Book room');
    c.read(keyValueStoreProvider).write('tasks.view', 'board');
    await tab(tester, 'Tasks');

    // One column at a time: To do first.
    expect(find.text('Order toner'), findsOneWidget);
    await tester.tap(find.text('Doing'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing in Doing.'), findsOneWidget);
    expect(find.text('Order toner'), findsNothing);

    // Swipe right goes back to To do.
    await tester.fling(
      find.text('Nothing in Doing.'),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Order toner'), findsOneWidget);

    // Hold a card, drop it on the Doing tab.
    final g = await tester.startGesture(
      tester.getCenter(find.text('Order toner')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveTo(tester.getCenter(find.text('Doing')));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(tasks.byId(a.id)!.status, TaskStatus.doing);
  });

  testWidgets('swipe to delete tasks and notes, with Undo; swipe right '
      'marks a task done; the board menu deletes too', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    final tasks = c.read(tasksProvider.notifier);
    final a = tasks.create(title: 'Old idea');
    final b = tasks.create(title: 'Water plants');
    final d = tasks.create(title: 'Board card');
    c.read(notesProvider.notifier).create(title: 'Scratch note');
    await tab(tester, 'Tasks');

    await tester.drag(find.text('Old idea'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(tasks.byId(a.id), isNull);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tasks.byId(a.id), isNotNull);

    await tester.drag(find.text('Water plants'), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(tasks.byId(b.id)!.status, TaskStatus.done);

    await showBoard(tester);
    final menu = find.descendant(
      of: find
          .ancestor(of: find.text('Board card'), matching: find.byType(Row))
          .first,
      matching: find.byTooltip('Move, start or delete'),
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(tasks.byId(d.id), isNull);

    await tab(tester, 'Notes');
    await tester.drag(find.text('Scratch note'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(c.read(notesProvider), isEmpty);
    expect(find.textContaining('Deleted: Scratch note'), findsOneWidget);
  });

  testWidgets('a task\'s notes live in its editor', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    final t = c.read(tasksProvider.notifier).create(title: 'Insurance claim');
    await tab(tester, 'Tasks');
    await tester.tap(find.text('Insurance claim'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Add a note'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a note'));
    await tester.pumpAndSettle();
    expect(find.text('For: Insurance claim'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'Ref number in email');
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pumpAndSettle();

    final note = c.read(notesProvider).single;
    expect(note.taskId, t.id);
    expect(find.text('Ref number in email'), findsOneWidget);
  });
}
