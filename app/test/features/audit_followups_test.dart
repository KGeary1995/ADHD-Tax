// A second code audit's findings: changes made while an editor or an Undo
// was open, lists that go stale as time passes, old links, a busy day's
// XP, two devices finishing one task, sign-ins and keys that come back.

import 'dart:async';
import 'dart:convert';

import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/core/theme/ph.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/data/models/template.dart';
import 'package:adhd_tax/data/storage/key_value_store.dart';
import 'package:adhd_tax/features/ai/ai_settings.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/gamification/progress_event.dart';
import 'package:adhd_tax/features/gamification/rewards_controller.dart';
import 'package:adhd_tax/features/picker/errand_run_screen.dart';
import 'package:adhd_tax/features/settings/device_workspaces.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/features/templates/templates_controller.dart';
import 'package:adhd_tax/microsoft/microsoft_auth.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/app_flow_test.dart' show pumpApp, pastStarted;

ProviderContainer container() {
  final c = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(MemoryStore())],
  );
  addTearDown(c.dispose);
  return c;
}

ProgressEvent completion(String id, DateTime at, {String task = 't'}) =>
    ProgressEvent(
      id: id,
      at: at,
      kind: ProgressKind.completed,
      label: 'Finished: x',
      xp: 10,
      completed: 1,
      taskId: task,
    );

class _SlowKeyStore implements AiKeyStore {
  final loaded = Completer<String?>();
  @override
  Future<String?> read() => loaded.future;
  @override
  Future<void> write(String? key) async {}
}

class _Secrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  test('saving a template editor keeps a checklist changed meanwhile', () {
    final c = container();
    final templates = c.read(templatesProvider.notifier);
    final opened = templates.save(
      Template(
        id: '',
        kind: TemplateKind.task,
        name: 'Routine',
        createdAt: DateTime(2026, 10, 25),
      ),
    );
    templates.save(opened.copyWith(checklist: '[{"t":"Elsewhere","d":0}]'));
    templates.saveEdits(opened, opened.copyWith(name: 'Renamed'));
    final saved = templates.byId(opened.id)!;
    expect(saved.name, 'Renamed');
    expect(saved.checklist, contains('Elsewhere'));
  });

  test('Undo of done keeps an edit made after it, and still undoes', () {
    final c = container();
    final tasks = c.read(tasksProvider.notifier);
    final before = tasks.create(title: 'Original');
    final done = tasks.complete(before.id, minutesWorked: 0);
    tasks.save(tasks.byId(before.id)!.copyWith(title: 'Edited meanwhile'));
    tasks.undoComplete(before, done);
    final t = tasks.byId(before.id)!;
    expect(t.title, 'Edited meanwhile');
    expect(t.status, TaskStatus.todo);
    expect(t.completedAt, isNull);
  });

  test('Undo of archive puts back only the status', () {
    final c = container();
    final tasks = c.read(tasksProvider.notifier);
    final before = tasks.create(title: 'Keep me');
    tasks.setStatus(before.id, TaskStatus.archived);
    final archived = tasks.byId(before.id)!;
    tasks.save(archived.copyWith(notes: 'Added meanwhile'));
    tasks.revert(before, archived);
    final t = tasks.byId(before.id)!;
    expect(t.status, TaskStatus.todo);
    expect(t.notes, 'Added meanwhile');
  });

  test('a workspace this device hides keeps its reward names out of the '
      'shop', () {
    final c = container();
    c.read(deviceWorkspacesProvider.notifier).set(DeviceWorkspaces.work);
    c.read(progressProvider.notifier).recordBonus('Coins', 100, Workspace.work);
    final shop = c.read(rewardsProvider.notifier);
    expect(shop.redeem(shop.create('Private treat', 1)), isNotNull);
    expect(c.read(redemptionsProvider).single.label, 'Private treat');
    c.read(deviceWorkspacesProvider.notifier).set(DeviceWorkspaces.personal);
    expect(c.read(redemptionsProvider).single.label, 'A Work reward');
  });

  testWidgets('an old Focus link for a task already done doesn\'t start it '
      'until asked', (tester) async {
    final c = await pumpApp(tester, size: const Size(390, 844));
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Finished already');
    tasks.complete(t.id, minutesWorked: 0);
    final xp = c.read(progressProvider).xp;
    c.read(routerProvider).push('/focus/${t.id}?min=5');
    await tester.pump();
    await tester.pump();
    expect(find.text('This one\'s already done.'), findsOneWidget);
    expect(tasks.byId(t.id)!.status, TaskStatus.done);
    expect(c.read(progressProvider).xp, xp);

    await tester.tap(find.text('Start it again'));
    await pastStarted(tester);
    expect(tasks.byId(t.id)!.status, TaskStatus.doing);
    expect(tasks.byId(t.id)!.completedAt, isNull);
  });

  testWidgets('a snoozed errand joins the errand run when it comes back', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 25, 9);
    final c = await pumpApp(
      tester,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    // Short, so both fit in the time the picker has by default.
    tasks.create(
      title: 'Post office',
      estimateMin: 5,
      requiresLeavingHouse: true,
    );
    final later = tasks.create(
      title: 'Pharmacy',
      estimateMin: 5,
      requiresLeavingHouse: true,
    );
    tasks.save(later.copyWith(scheduledStart: DateTime(2026, 10, 25, 10)));
    final sub = c.listen(errandRunProvider, (_, _) {});
    addTearDown(sub.close);
    expect(sub.read(), isNull);
    now = DateTime(2026, 10, 25, 10, 1);
    await tester.pump(const Duration(hours: 1, seconds: 1));
    expect(sub.read()?.tasks, hasLength(2));
  });

  testWidgets('Tasks moves a snoozed task out of Coming up when its time '
      'comes', (tester) async {
    var now = DateTime(2026, 10, 25, 9);
    final c = await pumpApp(
      tester,
      size: const Size(390, 844),
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Snoozed task');
    tasks.save(t.copyWith(scheduledStart: DateTime(2026, 10, 25, 10)));
    c.read(routerProvider).go('/tasks');
    await tester.pumpAndSettle();
    final comingUp = find.byWidgetPredicate(
      (w) => w is SectionTitle && w.text == 'Coming up',
    );
    expect(comingUp, findsOneWidget);
    now = DateTime(2026, 10, 25, 10, 1);
    await tester.pump(const Duration(hours: 1, seconds: 1));
    expect(comingUp, findsNothing);
  });

  testWidgets('Today shows a check-back when its time comes', (tester) async {
    var now = DateTime(2026, 10, 25, 9);
    final c = await pumpApp(
      tester,
      size: const Size(360, 800),
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Waiting task');
    tasks.setWaiting(t.id, followUpAt: DateTime(2026, 10, 25, 10));
    await tester.pumpAndSettle();
    final badge = find.byTooltip('Check back on 1 waiting task');
    expect(badge, findsNothing);
    now = DateTime(2026, 10, 25, 10, 1);
    await tester.pump(const Duration(hours: 1, seconds: 1));
    expect(badge, findsOneWidget);
  });

  testWidgets('the date picker opens on a due date from years ago', (
    tester,
  ) async {
    final c = await pumpApp(
      tester,
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 25, 9)),
      ],
    );
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Old date');
    tasks.save(t.copyWith(dueAt: DateTime(2020, 1, 1, 17)));
    c.read(routerProvider).go('/task/${t.id}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Due'));
    await tester.tap(find.text('Due'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.byIcon(Ph.calendarBlank).last,
        matching: find.byType(OutlineButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('wrap-up counts all of a busy day\'s XP', (tester) async {
    final c = await pumpApp(
      tester,
      size: const Size(390, 844),
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 25, 21)),
      ],
    );
    final tasks = c.read(tasksProvider.notifier);
    tasks.complete(tasks.create(title: 'One').id, minutesWorked: 0);
    for (var i = 0; i < 31; i++) {
      c
          .read(progressProvider.notifier)
          .recordBonus('Bonus', 1, Workspace.personal);
    }
    expect(c.read(progressProvider).xpOn(DateTime(2026, 10, 25)), 31);
    c.read(routerProvider).go('/wrapup');
    await tester.pumpAndSettle();
    expect(find.text('31 XP. That counts.'), findsOneWidget);
  });

  test('two devices finishing one task offline count it once; a task done '
      'again another day counts again', () {
    final day = DateTime(2026, 10, 25, 9);
    final once = foldEvents([
      completion('a', day),
      completion('b', day.add(const Duration(hours: 2))),
      completion('other', day, task: 'u'),
    ]);
    expect(once.completed, 2);
    expect(once.xp, 20);
    final later = foldEvents([
      completion('a', day),
      completion('b', DateTime(2026, 10, 27, 9)),
    ]);
    expect(later.completed, 2);
    // Events from before task ids were recorded count as they always did.
    final old = foldEvents([
      completion('a', day, task: ''),
      completion('b', day, task: ''),
    ]);
    expect(old.completed, 2);
  });

  test('finishing records which task, for that check', () {
    final c = container();
    final t = c.read(tasksProvider.notifier).create(title: 'x');
    final e = c
        .read(progressProvider.notifier)
        .recordCompletion(t, actualMin: null);
    final json = ProgressEvent.fromJson(
      e.eventId,
      ProgressEvent(
        id: e.eventId,
        at: DateTime(2026),
        kind: ProgressKind.completed,
        label: '',
        taskId: t.id,
      ).toJson(),
    );
    expect(json.taskId, t.id);
    expect(c.read(progressProvider).completed, 1);
  });

  test(
    'removing the AI key while it\'s still loading keeps it removed',
    () async {
      final keys = _SlowKeyStore();
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryStore()),
          aiKeyStoreProvider.overrideWithValue(keys),
        ],
      );
      addTearDown(c.dispose);
      c.read(aiSettingsProvider);
      await c.read(aiSettingsProvider.notifier).setKey(null);
      keys.loaded.complete('old-key');
      await pumpEventQueue();
      expect(c.read(aiSettingsProvider).hasKey, isFalse);
    },
  );

  test('a Microsoft token renewal finishing after Disconnect doesn\'t save '
      'the sign-in again', () async {
    final secrets = _Secrets()
      ..values['microsoft.credentials.personal'] = jsonEncode({
        'refresh_token': 'old',
      });
    final entered = Completer<void>();
    final reply = Completer<http.Response>();
    final auth = MicrosoftAuth(
      secrets: secrets,
      catcher: () => throw UnimplementedError(),
      clientId: 'test-client',
      newClient: () => MockClient((req) async {
        if (req.url.host == 'login.microsoftonline.com') {
          entered.complete();
          return reply.future;
        }
        return http.Response('{}', 200);
      }),
    );
    final client = (await auth.restore(Workspace.personal))!;
    final pending = client.get(Uri.parse('https://graph.microsoft.com/me'));
    await entered.future;
    await auth.disconnect(Workspace.personal);
    reply.complete(
      http.Response(
        jsonEncode({
          'access_token': 'a',
          'refresh_token': 'rotated',
          'expires_in': 3600,
        }),
        200,
      ),
    );
    await pending;
    client.close();
    expect(secrets.values, isEmpty);
  });
}
