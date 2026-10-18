import 'dart:async';

import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/focus/focus_screen.dart';
import 'package:adhd_tax/features/outside/android_bridge.dart';
import 'package:adhd_tax/features/settings/settings_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(390, 844);

class FakeBridge implements AndroidBridge {
  final incoming = StreamController<OutsideRequest>.broadcast();
  final widgetUpdates = <Map<String, String>>[];
  @override
  Stream<OutsideRequest> get requests => incoming.stream;
  @override
  Future<void> updateWidget(Map<String, String> data) async =>
      widgetUpdates.add(data);
}

void main() {
  testWidgets('waiting on someone: check back when the date comes', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 19, 10);
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Prior auth for Thursday');

    c.read(routerProvider).go('/tasks');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Waiting on someone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Insurance callback');
    await tester.tap(find.text('Tomorrow'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = tasks.byId(t.id)!;
    expect(saved.status, TaskStatus.waiting);
    expect(saved.waitingOn, 'Insurance callback');
    expect(saved.followUpAt, DateTime(2026, 10, 20, 9));
    expect(find.text('Check back'), findsNothing);

    // The next morning it comes back to the top of Tasks and Home.
    now = DateTime(2026, 10, 20, 9, 30);
    c.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    expect(find.text('Check back: Insurance callback'), findsOneWidget);
    await tester.tap(find.text('Check back: Insurance callback'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Waiting on Insurance callback'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to my list'));
    await tester.pumpAndSettle();
    expect(tasks.byId(t.id)!.status, TaskStatus.todo);
    expect(tasks.byId(t.id)!.followUpAt, isNull);
  });

  testWidgets("wrap-up: tomorrow's first thing shows first on Home", (
    tester,
  ) async {
    var now = DateTime(2026, 10, 19, 20, 30);
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    tasks.create(title: 'Urgent thing', priority: Priority.p1);
    final small = tasks.create(title: 'Schedule dentist', estimateMin: 5);

    c.read(routerProvider).push('/wrapup');
    await tester.pumpAndSettle();
    expect(find.text('Wrap up the day'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Schedule dentist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Find the number');
    await tester.ensureVisible(find.text('Done for today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done for today'));
    await tester.pumpAndSettle();

    expect(tasks.byId(small.id)!.firstStep, 'Find the number');
    expect(c.read(settingsProvider).pinnedTaskId, small.id);

    // Tonight Home still picks normally; tomorrow the chosen one leads.
    expect(find.text('Urgent thing'), findsOneWidget);
    now = DateTime(2026, 10, 20, 8);
    c.read(tasksProvider.notifier).create(title: 'nudge a rebuild');
    await tester.pumpAndSettle();
    expect(find.text('Schedule dentist'), findsOneWidget);
    expect(find.textContaining('Find the number'), findsOneWidget);

    // Passing on it lets the picker choose again.
    await tester.tap(find.text('Not this one'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule dentist'), findsNothing);
  });

  testWidgets('shared text opens Quick add; the widget gets the pick', (
    tester,
  ) async {
    final bridge = FakeBridge();
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [androidBridgeProvider.overrideWithValue(bridge)],
    );
    await tester.pump(const Duration(seconds: 1));
    expect(bridge.widgetUpdates.last['empty'], contains('list is empty'));

    bridge.incoming.add(
      const SharedText(text: 'Call IT about printer\nTicket 4411'),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Call IT about printer'),
      findsOneWidget,
    );
    expect(find.textContaining('Ticket 4411'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final t = c.read(tasksProvider).single;
    expect(t.notes, 'Ticket 4411');

    c
        .read(tasksProvider.notifier)
        .create(title: 'Water plants', estimateMin: 5);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    // The large widget lists what else fits right now.
    expect(bridge.widgetUpdates.last['alt1Title'], isNotNull);
    expect(bridge.widgetUpdates.last.containsKey('alt2Title'), isFalse);
    expect([
      bridge.widgetUpdates.last['title'],
      bridge.widgetUpdates.last['alt1Title'],
    ], containsAll(['Call IT about printer', 'Water plants']));
    c
        .read(tasksProvider.notifier)
        .delete(
          c.read(tasksProvider).firstWhere((x) => x.title == 'Water plants').id,
        );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(bridge.widgetUpdates.last['title'], 'Call IT about printer');
    expect(bridge.widgetUpdates.last.containsKey('alt1Title'), isFalse);
    expect(bridge.widgetUpdates.last['startRoute'], '/focus/${t.id}?min=15');

    // Widget "+" opens Quick add; Start opens the focus session.
    bridge.incoming.add(const OpenRoute('/add'));
    await tester.pumpAndSettle();
    expect(find.text('Add a task'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    bridge.incoming.add(OpenRoute('/focus/${t.id}?min=15'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FocusScreen), findsOneWidget);
  });
}
