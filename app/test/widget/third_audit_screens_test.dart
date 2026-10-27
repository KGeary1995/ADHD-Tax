// A third code audit's findings on screens: leaving the focus screen from
// under a dialog, sessions opened or closed from outside the app, the
// celebration queue after an Undo, XP that a later count takes back, and
// a wrap-up pin for a task finished since.

import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/focus/focus_screen.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/settings/settings_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp, pastStarted;

Future<void> frames(WidgetTester tester, [int n = 5]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('time running out under the Stop dialog: Finished still leaves '
      'the focus screen', (tester) async {
    var now = DateTime(2026, 10, 27, 10);
    final c = await pumpApp(
      tester,
      size: const Size(390, 844),
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Write report');
    c.read(routerProvider).push('/focus/${t.id}?min=1');
    await tester.pump();
    await tester.pump();
    await pastStarted(tester);

    await tester.tap(find.byTooltip('Stop'));
    await frames(tester, 2);
    expect(find.text('Stop this session?'), findsOneWidget);

    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    await frames(tester, 2);
    await tester.tap(find.text('Finished'));
    await frames(tester);

    expect(find.byType(FocusScreen), findsNothing);
    expect(find.text('Stop this session?'), findsNothing);
    expect(tasks.byId(t.id)!.status, TaskStatus.done);
  });

  testWidgets('outside links mid-session: the same Start opens nothing new, '
      'and a session closed from outside still counts its time', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 27, 10);
    final c = await pumpApp(
      tester,
      size: const Size(390, 844),
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Inbox zero');
    final router = c.read(routerProvider);
    router.push('/focus/${t.id}?min=25');
    await tester.pump();
    await tester.pump();
    await pastStarted(tester);
    now = now.add(const Duration(minutes: 3));

    // The widget's Start for the same task again: nothing new opens.
    expect(openFromOutside(router, '/focus/${t.id}?min=25'), isTrue);
    await frames(tester, 2);
    expect(find.byType(FocusScreen, skipOffstage: false), findsOneWidget);

    // Wrap-up opens on top of the session; back returns to it.
    expect(openFromOutside(router, '/wrapup'), isTrue);
    await frames(tester, 2);
    expect(find.byType(FocusScreen, skipOffstage: false), findsOneWidget);
    router.pop();
    await frames(tester, 2);

    // A check-back notification opens Tasks in its place: the session
    // closes, and its three minutes still count.
    expect(openFromOutside(router, '/tasks'), isTrue);
    await frames(tester, 2);
    expect(find.byType(FocusScreen, skipOffstage: false), findsNothing);
    expect(tasks.byId(t.id)!.actualMin, 3);

    // Links that aren't one of the app's outside routes do nothing.
    expect(openFromOutside(router, '/task/${t.id}'), isFalse);
    expect(openFromOutside(router, 'https://example.com'), isFalse);
  });

  testWidgets('Undo, then another finish: the second celebration still shows', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: const Size(390, 844));
    final tasks = c.read(tasksProvider.notifier);
    final progress = c.read(progressProvider.notifier);
    final a = tasks.create(title: 'Task A');
    final b = tasks.create(title: 'Task B');

    final shown = progress.recordCompletion(a, actualMin: null); // a toast
    await frames(tester, 1);
    progress.revoke(shown);
    progress.recordCompletion(b, actualMin: 20); // the full card
    await frames(tester, 4);
    expect(find.text('Nice'), findsOneWidget);
  });

  testWidgets('XP for starting and finishing a task comes once a day', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: const Size(390, 844));
    final t = c.read(tasksProvider.notifier).create(title: 'Laundry');
    final progress = c.read(progressProvider.notifier);

    progress.recordStart(t);
    final afterStart = c.read(progressProvider).xp;
    expect(progress.recordStart(t).award.total, 0);
    expect(c.read(progressProvider).xp, afterStart);

    progress.recordCompletion(t, actualMin: 10);
    final afterFinish = c.read(progressProvider).xp;
    // Done, reopened and done again: nothing a later count takes back.
    expect(progress.recordCompletion(t, actualMin: 10).award.total, 0);
    expect(c.read(progressProvider).xp, afterFinish);
    expect(c.read(progressProvider).completed, 1);
    await frames(tester, 12);
  });

  testWidgets('Wrap-up doesn\'t pin a task finished since it was chosen', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 27, 20);
    final c = await pumpApp(
      tester,
      size: const Size(390, 844),
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Call the bank');
    c
        .read(settingsProvider.notifier)
        .update((s) => s.pinForTomorrow(t.id, now));
    tasks.complete(t.id, minutesWorked: 0);

    c.read(routerProvider).push('/wrapup');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done for today').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Call the bank'), findsNothing);
    expect(
      c.read(settingsProvider).pinnedFor(DateTime(2026, 10, 28, 9)),
      isNull,
    );
  });
}
