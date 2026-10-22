import 'dart:convert';

import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/ai/ai_settings.dart';
import 'package:adhd_tax/features/focus/company.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/picker/picker_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(390, 844);

// A Sunday morning.
final _now = DateTime(2026, 10, 25, 10);

class FakeAmbient implements AmbientPlayer {
  final calls = <String>[];
  @override
  Future<void> play(FocusSound sound) async => calls.add('play:${sound.name}');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> stop() async => calls.add('stop');
}

class MemoryKeyStore implements AiKeyStore {
  MemoryKeyStore([this.key]);
  String? key;
  @override
  Future<String?> read() async => key;
  @override
  Future<void> write(String? k) async => key = k;
}

/// Lets animations run without pumpAndSettle, which never settles while
/// the focus timer ticks.
Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Task _old(String title, {int days = 12, bool out = false, String place = ''}) =>
    Task(
      id: '',
      title: title,
      requiresLeavingHouse: out,
      location: place,
      createdAt: _now.subtract(Duration(days: days)),
      updatedAt: _now.subtract(Duration(days: days)),
    );

void main() {
  testWidgets('weekly reset: offered on Sunday, keep / snooze / back / let '
      'go, then XP', (tester) async {
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => _now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    for (final t in ['Old A', 'Old B', 'Old C']) {
      tasks.save(_old(t));
    }
    tasks.create(title: 'Brand new');
    await tester.pumpAndSettle();

    expect(find.textContaining('Weekly reset: 3 tasks'), findsOneWidget);
    await tester.tap(find.textContaining('Weekly reset: 3 tasks'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);
    Task byTitle(String t) =>
        c.read(tasksProvider).firstWhere((x) => x.title == t);
    // Oldest first; all three are the same age, so take whatever shows.
    String shown() => [
      'Old A',
      'Old B',
      'Old C',
    ].firstWhere((t) => find.text(t).evaluate().isNotEmpty);
    final a = shown();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(byTitle(a).reviewedAt, _now);

    final b = shown();
    await tester.tap(find.text('Not this week'));
    await tester.pumpAndSettle();
    expect(byTitle(b).scheduledStart, _now.add(const Duration(days: 7)));

    // Back undoes the snooze.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(byTitle(b).scheduledStart, isNull);
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.tap(find.text('Not this week'));
    await tester.pumpAndSettle();

    final cTitle = shown();
    await tester.tap(find.text('Let it go'));
    await tester.pumpAndSettle();
    expect(
      c.read(tasksProvider.notifier).byId(byTitle(cTitle).id)!.status,
      TaskStatus.archived,
    );
    expect(find.text('All sorted.'), findsOneWidget);
    expect(find.textContaining('1 kept'), findsOneWidget);
    expect(c.read(progressProvider).xp, 20);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Weekly reset:'), findsNothing);
  });

  testWidgets('errand run: suggested when you can go out; tick them off', (
    tester,
  ) async {
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => _now)],
    );
    final tasks = c.read(tasksProvider.notifier);
    tasks.save(
      _old('Pick up prescription', days: 1, out: true, place: 'Pharmacy'),
    );
    tasks.save(
      _old('Mail the return', days: 1, out: true, place: 'Post office'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Errand run'), findsNothing);

    c.read(pickerInputsProvider.notifier).setWillingToLeave(true);
    c.read(pickerInputsProvider.notifier).setTime(60);
    await tester.pumpAndSettle();
    final banner = find.textContaining('Errand run:');
    expect(banner, findsOneWidget);
    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(find.text('Pharmacy + Post office'), findsOneWidget);
    expect(find.text('1. Pharmacy'), findsOneWidget);

    await tester.tap(find.text('Pick up prescription'));
    await tester.pumpAndSettle();
    expect(
      c
          .read(tasksProvider)
          .firstWhere((t) => t.title == 'Pick up prescription')
          .status,
      TaskStatus.done,
    );
    await tester.tap(find.text('Mail the return'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('All done. Head home.'), findsOneWidget);
  });

  testWidgets('company: pick a sound and a buddy; pause pauses the sound', (
    tester,
  ) async {
    final fake = FakeAmbient();
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [ambientPlayerProvider.overrideWithValue(fake)],
    );
    final t = c.read(tasksProvider.notifier).create(title: 'Write report');
    c.read(routerProvider).push('/focus/${t.id}?min=25');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Company'));
    await frames(tester);
    await tester.tap(find.text('Rain'));
    await tester.tap(find.text('Work alongside a buddy'));
    await tester.pump();
    await tester.tap(find.text('Done').last);
    await frames(tester);

    expect(fake.calls.last, 'play:rain');
    expect(find.textContaining('Your buddy ·'), findsOneWidget);
    expect(c.read(keyValueStoreProvider).read('focus.sound'), 'rain');

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(fake.calls.last, 'pause');
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(fake.calls.last, 'resume');

    // Leaving stops it.
    c.read(routerProvider).go('/');
    await tester.pump(const Duration(seconds: 1));
    expect(fake.calls.last, 'stop');
  });

  testWidgets('break it down: without a key it suggests built-in steps; with '
      'one, Claude\'s steps land in the checklist', (tester) async {
    final keys = MemoryKeyStore();
    late http.Request sent;
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [
        aiKeyStoreProvider.overrideWithValue(keys),
        httpClientProvider.overrideWithValue(
          MockClient((req) async {
            sent = req;
            return http.Response(
              jsonEncode({
                'stop_reason': 'end_turn',
                'content': [
                  {
                    'type': 'text',
                    'text': jsonEncode({
                      'steps': ['Open the folder', 'Find last year\'s form'],
                    }),
                  },
                ],
              }),
              200,
            );
          }),
        ),
      ],
    );
    final t = c.read(tasksProvider.notifier).create(title: 'Do taxes');
    c.read(routerProvider).push('/task/${t.id}');
    await tester.pumpAndSettle();
    final suggest = find.text('Suggest steps');
    await tester.dragUntilVisible(
      suggest,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.tap(suggest);
    await tester.pumpAndSettle();
    expect(find.text('Find the form or the website'), findsOneWidget);

    await c.read(aiSettingsProvider.notifier).setKey('sk-test');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final button = find.text('Break it down with AI');
    await tester.dragUntilVisible(
      button,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(sent.headers['x-api-key'], 'sk-test');
    expect(find.text('Open the folder'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = c.read(tasksProvider.notifier).byId(t.id)!.checklist;
    expect(saved, startsWith('[ ] Find the form or the website'));
    expect(saved, endsWith("[ ] Open the folder\n[ ] Find last year's form"));
  });
}
