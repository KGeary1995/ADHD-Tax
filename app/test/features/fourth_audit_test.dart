// A fourth code audit's findings: the editor's Status, a second finish's
// minutes, settings that don't load, the picker's day count, coins for
// nothing, and a colon in the sensitive-info check.

import 'dart:convert';

import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/data/storage/key_value_store.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/gamification/xp_rules.dart';
import 'package:adhd_tax/features/picker/picker_engine.dart';
import 'package:adhd_tax/features/safety/phi_guard.dart';
import 'package:adhd_tax/features/settings/settings_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/icloud/icloud_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/app_flow_test.dart' show pumpApp;

ProviderContainer container([MemoryStore? store]) {
  final c = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store ?? MemoryStore()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('Status → Done in the editor makes the next repeat', (
    tester,
  ) async {
    final c = await pumpApp(tester);
    final tasks = c.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Water plants');
    tasks.save(t.copyWith(repeat: Repeat.weekly, dueAt: DateTime.now()));
    c.read(routerProvider).go('/task/${t.id}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Status'));
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    // The sheet has the option "Done", then its own Done button.
    final inSheet = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('Done'),
    );
    await tester.tap(inSheet.first);
    await tester.pumpAndSettle();
    await tester.tap(inSheet.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final copies = c
        .read(tasksProvider)
        .where((x) => x.title == 'Water plants')
        .toList();
    expect(copies, hasLength(2));
    expect(c.read(tasksProvider.notifier).byId(t.id)!.completedAt, isNotNull);
    expect(c.read(progressProvider).completed, 1);
  });

  test("a second finish the same day still counts its minutes", () {
    final c = container();
    final t = c.read(tasksProvider.notifier).create(title: 'x');
    final progress = c.read(progressProvider.notifier);
    progress.recordCompletion(t, actualMin: 10, sessionMin: 10);
    progress.recordCompletion(t, actualMin: 40, sessionMin: 30);
    expect(c.read(progressProvider).focusMinutes, 40);
    expect(c.read(progressProvider).completed, 1);
  });

  test('no XP, no coins', () {
    expect(const XpAward([]).coins, 0);
    expect(const XpAward([XpLine('Started', 5)]).coins, 1);
  });

  test('settings of the wrong type or damaged fall back to the defaults', () {
    final odd = container(
      MemoryStore({
        'settings.v1': jsonEncode({
          'nudgeWeekdaysOnly': [1, 2, 3],
          'quoteSeconds': '20',
          'wrapUp': false,
        }),
      }),
    );
    final s = odd.read(settingsProvider);
    expect(s.nudgeWeekdaysOnly, isFalse);
    expect(s.quoteSeconds, 20);
    expect(s.wrapUp, isFalse, reason: 'the good ones are kept');

    final damaged = container(MemoryStore({'settings.v1': '{"wrapUp": fa'}));
    expect(damaged.read(settingsProvider).wrapUp, isTrue);
  });

  test('pinning tomorrow keeps every other setting', () {
    const s = AppSettings(timerBlocks: true, wrapUp: false);
    final pinned = s.pinForTomorrow('t1', DateTime(2026, 11, 11, 21));
    expect(pinned.timerBlocks, isTrue);
    expect(pinned.wrapUp, isFalse);
    expect(pinned.pinnedFor(DateTime(2026, 11, 12, 8)), 't1');
  });

  test('"Due tomorrow" goes by calendar day', () {
    String reason(DateTime now, DateTime due) {
      final t = Task(
        id: 'a',
        title: 'a',
        dueAt: due,
        hardDeadline: true,
        createdAt: now,
        updatedAt: now,
      );
      return const PickerEngine()
          .rank([
            t,
          ], PickerContext(availableMin: 60, willingToLeave: false, now: now))
          .first
          .reasons
          .firstWhere((r) => r.startsWith('Due'));
    }

    // 11 pm Monday → Wednesday 9 am: 34 hours, but two days.
    expect(
      reason(DateTime(2026, 11, 9, 23), DateTime(2026, 11, 11, 9)),
      'Due in 2 days',
    );
    // 8 am Monday → Tuesday 8 pm: 36 hours, but tomorrow.
    expect(
      reason(DateTime(2026, 11, 9, 8), DateTime(2026, 11, 10, 20)),
      'Due tomorrow',
    );
  });

  test('"Patient: Smith" is flagged like "patient Smith"', () {
    expect(scanForPhi('Patient: Smith called'), isNotEmpty);
    expect(scanForPhi('Pt: Smith'), isNotEmpty);
  });

  test('an iCloud file still downloading is skipped, not read stale', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('test/icloud');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'notReady'),
        );
    final store = ICloudStore(Workspace.personal, channel: channel);
    await expectLater(store.read('personal/x'), throwsFormatException);
  });
}
