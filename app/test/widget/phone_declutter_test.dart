import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/capture/quick_add_sheet.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(390, 844);

void main() {
  testWidgets('phone Quick add: a title and a length; More options is '
      'remembered', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    Future<void> open() async {
      showQuickAdd(tester.element(find.byType(Scaffold).first));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('How long?'), findsOneWidget);
    expect(find.text('Priority'), findsNothing);
    expect(find.widgetWithText(Pill, 'Leave the house'), findsNothing);

    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Priority'), findsOneWidget);
    expect(find.widgetWithText(Pill, 'Leave the house'), findsOneWidget);
    expect(c.read(keyValueStoreProvider).read('quickadd.more'), 'open');

    // Typed extras still work with the options closed.
    await tester.tap(find.text('Fewer options'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Call billing urgent');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final t = c.read(tasksProvider).single;
    expect(t.title, 'Call billing');
    expect(t.priority, Priority.p1);

    await open();
    expect(find.text('Priority'), findsNothing);
  });

  testWidgets('phone Tasks: one filter button, short task rows', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _phone);
    final tasks = c.read(tasksProvider.notifier);
    tasks.create(
      title: 'Draft the cheat sheet',
      priority: Priority.p1,
      workspace: Workspace.work,
      tags: 'training',
      estimateMin: 60,
    );
    tasks.create(title: 'Water plants');
    c.read(routerProvider).go('/tasks');
    await tester.pumpAndSettle();

    // Only how long it takes; priority, workspace and tags are in the
    // editor.
    expect(find.text('1h'), findsOneWidget);
    expect(find.textContaining('#training'), findsNothing);
    expect(find.textContaining('Critical'), findsNothing);
    expect(find.widgetWithText(Pill, 'All projects'), findsNothing);

    await tester.tap(find.widgetWithText(Pill, 'Everything'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Pill, 'Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Pill, 'Work'), findsOneWidget);
    expect(find.text('Draft the cheat sheet'), findsOneWidget);
    expect(find.text('Water plants'), findsNothing);
  });

  testWidgets('phone Today: short card line, no counts at the bottom', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 19, 10);
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Renew license', estimateMin: 15);
    // The card reads the real clock for "tomorrow".
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    tasks.save(
      t.copyWith(
        dueAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('15 min · due tomorrow'), findsOneWidget);
    expect(find.textContaining('done today'), findsNothing);
    expect(find.text('Overwhelmed?'), findsOneWidget);
  });
}
