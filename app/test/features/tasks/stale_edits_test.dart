// Things that changed under an open screen or with time: an editor opened
// before a task was marked done, Undo after a repeat, hidden workspaces,
// minutes across sessions, a snooze running out.

import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/data/storage/key_value_store.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/picker/picker_controller.dart';
import 'package:adhd_tax/features/settings/device_workspaces.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../widget/app_flow_test.dart' show pumpApp;

ProviderContainer container() {
  final c = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(MemoryStore())],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('saving an editor opened before the task was done keeps it done', () {
    final c = container();
    final tasks = c.read(tasksProvider.notifier);
    final opened = tasks.create(title: 'Original');
    tasks.complete(opened.id, minutesWorked: 5);
    tasks.saveEdits(opened, opened.copyWith(title: 'Renamed'));
    final t = tasks.byId(opened.id)!;
    expect(t.title, 'Renamed');
    expect(t.status, TaskStatus.done);
    expect(t.actualMin, 5);
  });

  test('Undo of a repeat only removes a next copy it made', () {
    final c = container();
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Water plants');
    tasks.save(t.copyWith(repeat: Repeat.daily));
    final first = tasks.complete(t.id, minutesWorked: 0);
    expect(first.created, isTrue);
    tasks.save(first.next!.copyWith(title: 'Water plants (edited)'));
    tasks.reopen(t.id);

    final before = tasks.byId(t.id)!;
    final again = tasks.complete(t.id, minutesWorked: 0);
    expect(again.created, isFalse);
    tasks.undoComplete(before, again);
    expect(tasks.byId(t.id)!.status, TaskStatus.todo);
    expect(tasks.byId(first.next!.id)?.title, 'Water plants (edited)');

    // A copy this completion did make goes away with the undo.
    tasks.delete(first.next!.id);
    final third = tasks.complete(t.id, minutesWorked: 0);
    expect(third.created, isTrue);
    tasks.undoComplete(before, third);
    expect(tasks.byId(third.next!.id), isNull);
  });

  test('a workspace this device hides keeps its task titles out of Progress, '
      'but its XP still counts', () {
    final c = container();
    final t = c
        .read(tasksProvider.notifier)
        .create(title: 'Quarterly numbers', workspace: Workspace.work);
    c.read(progressProvider.notifier).recordStart(t);
    final xp = c.read(progressProvider).xp;
    c.read(deviceWorkspacesProvider.notifier).set(DeviceWorkspaces.personal);
    final progress = c.read(progressProvider);
    expect(progress.xp, xp);
    expect(progress.recent.map((e) => e.label), ['Started: a Work task']);
  });

  test(
    'a stopped session and the one that finishes count each minute once',
    () {
      final c = container();
      final tasks = c.read(tasksProvider.notifier);
      final progress = c.read(progressProvider.notifier);
      final t = tasks.create(title: 'Two sittings', estimateMin: 30);
      tasks.pause(t.id, minutesWorked: 10);
      progress.recordPartial(t, 10);
      final before = tasks.byId(t.id)!;
      tasks.complete(t.id, minutesWorked: 5);
      // What FocusScreen passes when it finishes.
      progress.recordCompletion(
        before,
        actualMin: (before.actualMin ?? 0) + 5,
        sessionMin: 5,
      );
      expect(tasks.byId(t.id)!.actualMin, 15);
      expect(c.read(progressProvider).focusMinutes, 15);
    },
  );

  test('the picks look again when a snooze ends or the day changes', () {
    final now = DateTime(2026, 10, 25, 9);
    Task task({DateTime? from, TaskStatus status = TaskStatus.todo}) => Task(
      id: '$from$status',
      title: 'x',
      scheduledStart: from,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    expect(nextPickerBoundary([task()], now), DateTime(2026, 10, 26));
    expect(
      nextPickerBoundary([
        task(from: DateTime(2026, 10, 25, 14)),
        task(from: DateTime(2026, 10, 25, 10)),
        task(from: DateTime(2026, 10, 25, 8)), // already passed
        task(from: DateTime(2026, 10, 25, 9, 30), status: TaskStatus.done),
      ], now),
      DateTime(2026, 10, 25, 10),
    );
  });

  testWidgets('a snoozed task comes back when its time passes', (tester) async {
    var now = DateTime(2026, 10, 25, 9);
    final c = await pumpApp(
      tester,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Later');
    tasks.save(t.copyWith(scheduledStart: DateTime(2026, 10, 25, 10)));
    await tester.pump();
    expect(c.read(pickResultProvider).suggestion, isNull);
    now = DateTime(2026, 10, 25, 10, 1);
    await tester.pump(const Duration(hours: 1, seconds: 1));
    expect(c.read(pickResultProvider).suggestion?.task.id, t.id);
  });

  testWidgets('closing a note nobody typed in leaves a deletion from another '
      'device alone', (tester) async {
    final c = await pumpApp(tester);
    final notes = c.read(notesProvider.notifier);
    final n = notes.create(title: 'Deleted elsewhere');
    c.read(routerProvider).push('/note/${n.id}');
    await tester.pumpAndSettle();
    notes.delete(n.id); // what a sync bringing the deletion does
    c.read(routerProvider).go('/notes');
    await tester.pumpAndSettle();
    expect(c.read(notesProvider.notifier).byId(n.id), isNull);
  });

  testWidgets('typing in a note keeps a change made elsewhere to another '
      'field', (tester) async {
    final c = await pumpApp(tester);
    final notes = c.read(notesProvider.notifier);
    final n = notes.create(title: 'Shopping', body: 'eggs');
    c.read(routerProvider).push('/note/${n.id}');
    await tester.pumpAndSettle();
    notes.save(notes.byId(n.id)!.copyWith(pinned: true)); // pinned elsewhere
    await tester.enterText(
      find.widgetWithText(TextField, 'eggs'),
      'eggs, milk',
    );
    c.read(routerProvider).go('/notes');
    await tester.pumpAndSettle();
    final saved = notes.byId(n.id)!;
    expect(saved.body, 'eggs, milk');
    expect(saved.pinned, isTrue);
  });
}
