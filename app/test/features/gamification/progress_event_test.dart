import 'package:adhd_tax/features/gamification/achievements.dart';
import 'package:adhd_tax/features/gamification/progress_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = DateTime(2026, 10, 17, 9);
  ProgressEvent ev(
    String id,
    int minutes,
    ProgressKind kind, {
    int xp = 10,
    int completed = 0,
    int started = 0,
    int errands = 0,
  }) => ProgressEvent(
    id: id,
    at: t.add(Duration(minutes: minutes)),
    kind: kind,
    label: id,
    xp: xp,
    coins: 1,
    completed: completed,
    started: started,
    errands: errands,
  );

  test('fold sums counters and is order-independent', () {
    final events = [
      ev('a', 0, ProgressKind.started, started: 1),
      ev('b', 10, ProgressKind.completed, xp: 40, completed: 1),
      ev('c', 20, ProgressKind.started, started: 1),
    ];
    final s1 = foldEvents(events);
    final s2 = foldEvents(events.reversed);
    expect(s1.toJson(), s2.toJson());
    expect(s1.xp, 60);
    expect(s1.started, 2);
    expect(s1.completed, 1);
    expect(s1.completedOn(t), 1);
    expect(s1.recent.first.label, 'c');
  });

  test('achievements unlock at the event that earned them', () {
    final s = foldEvents([
      ev('a', 0, ProgressKind.started, started: 1),
      ev('b', 30, ProgressKind.completed, completed: 1),
    ]);
    expect(s.unlocked['first_spark'], t);
    expect(s.unlocked['first_win'], t.add(const Duration(minutes: 30)));
  });

  test('errands on the same day unlock Errand Runner', () {
    final s = foldEvents([
      for (var i = 0; i < 3; i++)
        ev('e$i', i * 30, ProgressKind.completed, completed: 1, errands: 1),
    ]);
    expect(s.unlocked.containsKey('errand_runner'), isTrue);
  });

  test('reset ignores earlier events', () {
    final s = foldEvents([
      ev('old', 0, ProgressKind.completed, xp: 500, completed: 1),
      ev('new', 60, ProgressKind.started, started: 1),
    ], resetAt: t.add(const Duration(minutes: 30)));
    expect(s.xp, 10);
    expect(s.completed, 0);
  });

  test('carryover brings old totals and active days, but no log line', () {
    final s = foldEvents([
      ProgressEvent(
        id: 'carry',
        at: t,
        kind: ProgressKind.carryover,
        label: 'Carried over',
        xp: 640,
        completed: 19,
        days: [dayKey(t.subtract(const Duration(days: 1)))],
      ),
    ]);
    expect(s.xp, 640);
    expect(s.activeDays.length, 2);
    expect(s.recent, isEmpty);
  });

  test('spending coins takes coins only: no XP, no streak day, no log', () {
    final spend = ProgressEvent(
      id: 'r',
      at: t.add(const Duration(days: 3)),
      kind: ProgressKind.redeemed,
      label: 'Fancy coffee',
      coins: -25,
    );
    final s = foldEvents([
      ev('a', 0, ProgressKind.completed, xp: 300, completed: 1),
      spend,
    ]);
    expect(s.coins, 1 - 25);
    expect(s.xp, 300);
    expect(s.activeDays, hasLength(1));
    expect(s.recent.map((r) => r.label), ['a']);
    // Survives the trip through sync.
    final back = ProgressEvent.fromJson('r', spend.toJson());
    expect(back.kind, ProgressKind.redeemed);
    expect(back.coins, -25);
  });

  test('event JSON round trip', () {
    final e = ProgressEvent(
      id: 'x',
      at: t,
      kind: ProgressKind.carryover,
      label: 'l',
      xp: 5,
      panic: 1,
      days: const ['2026-10-16', '2026-10-15'],
    );
    expect(ProgressEvent.fromJson('x', e.toJson()).toJson(), e.toJson());
  });
}
