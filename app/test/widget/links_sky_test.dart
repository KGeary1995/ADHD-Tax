import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(390, 844);

TextField _body(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).at(1));

/// Scrolls the screen in front until [f] is built and on screen. Lists
/// build lazily, so a far-down section may not exist until scrolled to.
Future<void> _show(WidgetTester tester, Finder f) async {
  final front = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .hitTestable()
      .last;
  await tester.scrollUntilVisible(f, 200, scrollable: front);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('typing [[ suggests tasks; the link opens the task, which '
      'lists the note under Related', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    final t = c.read(tasksProvider.notifier).create(title: 'Renew license');
    c.read(routerProvider).push('/note/new');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Call about [[ren');
    await tester.pump();
    expect(find.widgetWithText(Pill, 'Renew license'), findsOneWidget);
    await tester.tap(find.widgetWithText(Pill, 'Renew license'));
    await tester.pump(const Duration(seconds: 1)); // autosave
    expect(_body(tester).controller!.text, 'Call about [[Renew license]]');
    // The bar goes away once the link is closed.
    expect(find.widgetWithText(Pill, 'Renew license'), findsNothing);

    final row = find.text('Task');
    await _show(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, '/task/${t.id}');
    await _show(tester, find.text('Note that links here'));
    expect(find.text('Call about Renew license'), findsOneWidget);
  });

  testWidgets('the link button starts a link; a link to nothing can become '
      'a task', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    c.read(routerProvider).push('/note/new');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Need ');
    await tester.tap(find.byTooltip('Link a task or note'));
    await tester.pump();
    expect(_body(tester).controller!.text, 'Need [[');
    expect(find.text('Type the name of a task or note'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Need [[Order paper');
    await tester.pump();
    await tester.tap(find.widgetWithText(Pill, 'Link "Order paper"'));
    await tester.pump(const Duration(seconds: 1));
    expect(_body(tester).controller!.text, 'Need [[Order paper]]');

    final make = find.text('Make task');
    await _show(tester, make);
    expect(find.text('Not a task or note yet'), findsOneWidget);
    await tester.tap(make);
    await tester.pumpAndSettle();
    expect(c.read(tasksProvider).map((t) => t.title), ['Order paper']);
    expect(find.text('Not a task or note yet'), findsNothing);
    // The note is saved with the link in it.
    expect(c.read(notesProvider).single.body, 'Need [[Order paper]]');
  });

  testWidgets('Related lists unfinished tasks that share a tag', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _phone);
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Draft cheat sheet', tags: 'training');
    tasks.create(title: 'Shadow a Monday', tags: 'training');
    tasks.create(title: 'Water plants');
    c.read(routerProvider).go('/task/${t.id}');
    await tester.pumpAndSettle();
    await _show(tester, find.text('Shadow a Monday'));
    expect(find.text('Related'), findsOneWidget);
    expect(find.text('#training'), findsOneWidget);
    expect(find.text('Water plants'), findsNothing);
  });

  testWidgets('a task with no connections has no Related section', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _phone);
    final t = c.read(tasksProvider.notifier).create(title: 'Lonely task');
    c.read(routerProvider).go('/task/${t.id}');
    await tester.pumpAndSettle();
    await _show(tester, find.text('Add a note'));
    expect(find.text('Related'), findsNothing);
  });

  testWidgets('Progress draws a star for each start', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    final tasks = c.read(tasksProvider.notifier);
    final progress = c.read(progressProvider.notifier);
    progress.recordStart(
      tasks.create(title: 'One', workspace: Workspace.personal),
    );
    progress.recordStart(tasks.create(title: 'Two'));
    final semantics = tester.ensureSemantics();
    c.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    await _show(tester, find.text('Your sky'));
    expect(find.text('2 starts · 12 weeks'), findsOneWidget);
    expect(
      find.bySemanticsLabel('2 tasks started in the last 12 weeks'),
      findsOneWidget,
    );
    expect(find.textContaining('first star appears'), findsNothing);
    semantics.dispose();
  });

  testWidgets('an empty sky says how to get the first star', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    c.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    await _show(tester, find.text('Your sky'));
    expect(find.textContaining('first star appears'), findsOneWidget);
  });
}
