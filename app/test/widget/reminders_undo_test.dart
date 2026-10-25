import 'dart:async';

import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/reminders/reminders.dart';
import 'package:adhd_tax/features/settings/settings_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pastStarted, pumpApp;

/// Records what the app asked the notification system to do.
class FakeReminders implements Reminders {
  FakeReminders({this.granted = true});
  bool granted;
  final calls = <String>[];
  List<Nudge> nudges = [];

  @override
  bool get supported => true;
  @override
  Future<bool> permissionGranted() async => granted;
  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    return granted;
  }

  @override
  Future<void> focusRunning({
    required String title,
    required DateTime endsAt,
  }) async => calls.add('running:$title');
  @override
  Future<void> focusPaused({
    required String title,
    required Duration left,
  }) async => calls.add('paused:$title');
  @override
  Future<void> focusTimeUp() async => calls.add('timeUp');
  @override
  Future<void> focusEnded() async => calls.add('ended');
  @override
  Future<void> scheduleNudges(List<Nudge> n) async {
    calls.add('nudges');
    nudges = n;
  }

  final taps = StreamController<String>.broadcast();
  @override
  Stream<String> get opened => taps.stream;
}

const _phone = Size(390, 844);

void main() {
  testWidgets('first launch asks for notifications once and plans nudges', (
    tester,
  ) async {
    final fake = FakeReminders();
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [remindersProvider.overrideWithValue(fake)],
    );
    await tester.pump(const Duration(seconds: 1));
    expect(fake.calls.where((x) => x == 'request'), hasLength(1));
    expect(c.read(settingsProvider).askedForNotifications, isTrue);
    expect(fake.nudges, isNotEmpty);

    // The evening wrap-up is scheduled too, and opens its screen.
    expect(fake.nudges.where((n) => n.route == '/wrapup'), isNotEmpty);

    // Turning check-ins off clears them; the wrap-up has its own switch.
    c.read(settingsProvider.notifier).update((s) => s.copyWith(nudges: false));
    await tester.pump(const Duration(seconds: 1));
    expect(fake.nudges.where((n) => n.route == null), isEmpty);
    c.read(settingsProvider.notifier).update((s) => s.copyWith(wrapUp: false));
    await tester.pump(const Duration(seconds: 1));
    expect(fake.nudges, isEmpty);
  });

  testWidgets('focus session mirrors the timer into notifications', (
    tester,
  ) async {
    final fake = FakeReminders();
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [remindersProvider.overrideWithValue(fake)],
    );
    final t = c
        .read(tasksProvider.notifier)
        .create(title: 'Call insurance', firstStep: 'Find the card');
    c.read(routerProvider).push('/focus/${t.id}?min=15');
    await tester.pump();
    await tester.pump();
    expect(fake.calls.last, 'running:Find the card');

    await pastStarted(tester);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(fake.calls.last, 'paused:Find the card');

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(fake.calls.last, 'running:Find the card');

    // Leaving the screen any way at all clears the notification.
    c.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    // (Nudges get re-planned too, since you just started something.)
    expect(fake.calls.where((x) => x.startsWith('running')).length, 2);
    expect(
      fake.calls.indexOf('ended'),
      greaterThan(fake.calls.lastIndexOf('running:Find the card')),
    );
  });

  testWidgets('timer alerts off: focus leaves notifications alone', (
    tester,
  ) async {
    final fake = FakeReminders();
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [remindersProvider.overrideWithValue(fake)],
    );
    c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(timerAlerts: false));
    final t = c.read(tasksProvider.notifier).create(title: 'Laundry');
    c.read(routerProvider).push('/focus/${t.id}?min=15');
    await tester.pump();
    await tester.pump();
    c.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    expect(
      fake.calls.where((x) => x.startsWith('running') || x == 'ended'),
      isEmpty,
    );
  });

  testWidgets('Mark done on a repeating task, then Undo puts it all back', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _phone);
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Laundry');
    tasks.save(tasks.byId(t.id)!.copyWith(repeat: Repeat.weekly));
    final xpBefore = c.read(progressProvider).xp;

    c.read(routerProvider).go('/tasks');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();

    expect(tasks.byId(t.id)!.status, TaskStatus.done);
    final open = c.read(tasksProvider).where((x) => x.isOpen).toList();
    expect(open, hasLength(1), reason: 'next week\'s copy');
    expect(open.single.scheduledStart, isNotNull);
    expect(c.read(progressProvider).xp, greaterThan(xpBefore));
    expect(find.text('Coming up 1'), findsOneWidget);
    expect(find.textContaining('next one'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tasks.byId(t.id)!.status, TaskStatus.todo);
    expect(c.read(tasksProvider).where((x) => x.isOpen), hasLength(1));
    expect(tasks.byId(open.single.id), isNull);
    expect(c.read(progressProvider).xp, xpBefore);
  });

  testWidgets('Delete from the list can be undone', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Renew license', estimateMin: 30);

    c.read(routerProvider).go('/tasks');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(tasks.byId(t.id), isNull);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tasks.byId(t.id)?.estimateMin, 30);
    expect(find.text('Renew license'), findsOneWidget);
  });

  testWidgets('Reminders settings fit a phone and edit nudge times', (
    tester,
  ) async {
    final c = await pumpApp(
      tester,
      size: const Size(360, 800),
      overrides: [
        remindersProvider.overrideWithValue(FakeReminders(granted: false)),
      ],
    );
    c.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Weekdays only'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Allow notifications'), findsOneWidget);
    expect(find.text('8:45 AM'), findsOneWidget);

    await tester.ensureVisible(find.text('8:45 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).nudgeTimes, [13 * 60 + 15]);
    expect(tester.takeException(), isNull);
  });
}
