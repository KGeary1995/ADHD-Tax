import 'dart:math' as math;

import 'package:adhd_tax/sync/replica.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var tick = DateTime.utc(2026, 10, 17);
  DateTime now() => tick = tick.add(const Duration(milliseconds: 1));

  test('put only stamps changed fields', () {
    final r = Replica('a');
    expect(r.put('tasks', '1', {'title': 'x', 'ugh': 0}, now()), isTrue);
    final c1 = r.get('tasks', '1')!.clocks['ugh'];
    expect(r.put('tasks', '1', {'title': 'y', 'ugh': 0}, now()), isTrue);
    expect(r.get('tasks', '1')!.clocks['ugh'], c1);
    expect(r.put('tasks', '1', {'title': 'y'}, now()), isFalse);
  });

  test('concurrent edits to different fields both survive', () {
    final a = Replica('a')
      ..put('tasks', '1', {'title': 'Call', 'ugh': 0}, now());
    final b = Replica.decode(a.encode(), node: 'b');
    a.put('tasks', '1', {'title': 'Call insurance'}, now());
    b.put('tasks', '1', {'ugh': 3}, now());
    a.merge(b, now());
    b.merge(a, now());
    for (final r in [a, b]) {
      expect(r.get('tasks', '1')!.values, {
        'title': 'Call insurance',
        'ugh': 3,
      });
    }
  });

  test('same field: later write wins on both sides', () {
    final a = Replica('a')..put('tasks', '1', {'title': 'v1'}, now());
    final b = Replica.decode(a.encode(), node: 'b');
    a.put('tasks', '1', {'title': 'from a'}, now());
    b.put('tasks', '1', {'title': 'from b'}, now()); // later
    a.merge(b, now());
    b.merge(a, now());
    expect(a.get('tasks', '1')!.values['title'], 'from b');
    expect(b.get('tasks', '1')!.values['title'], 'from b');
  });

  test('delete blanks fields and marks deleted', () {
    final r = Replica('a')
      ..put('tasks', '1', {'title': 'pt John Smith'}, now());
    expect(r.delete('tasks', '1', now()), isTrue);
    final rec = r.get('tasks', '1')!;
    expect(rec.isDeleted, isTrue);
    expect(rec.values['title'], isNull);
    expect(r.delete('tasks', '1', now()), isFalse);
  });

  test('merge is idempotent and reports no change the second time', () {
    final a = Replica('a')..put('tasks', '1', {'title': 'x'}, now());
    final b = Replica('b');
    expect(b.merge(a, now()), isTrue);
    expect(b.merge(a, now()), isFalse);
  });

  test('merging does not count as a local write', () {
    final a = Replica('a')..put('tasks', '1', {'title': 'x'}, now());
    final b = Replica('b');
    b.merge(a, now());
    expect(b.lastLocalWrite, isNull);
  });

  test('JSON round trip preserves values and clocks (compact form)', () {
    final r = Replica('a')
      ..put('events', 'e1', {'xp': 10, 'label': 'Started'}, now())
      ..put('tasks', '1', {'title': 'x', 'ugh': 1}, now())
      ..put('tasks', '1', {'ugh': 2}, now());
    final back = Replica.decode(r.encode());
    expect(back.encode(), r.encode());
    expect(back.lastLocalWrite, r.lastLocalWrite);
  });

  test('randomized: three replicas converge regardless of merge order', () {
    final rnd = math.Random(42);
    for (var round = 0; round < 25; round++) {
      final reps = [Replica('a'), Replica('b'), Replica('c')];
      for (var i = 0; i < 40; i++) {
        final r = reps[rnd.nextInt(3)];
        final id = 't${rnd.nextInt(5)}';
        if (rnd.nextInt(10) == 0) {
          r.delete('tasks', id, now());
        } else {
          r.put('tasks', id, {
            ['title', 'ugh', 'priority'][rnd.nextInt(3)]: rnd.nextInt(100),
          }, now());
        }
        if (rnd.nextInt(4) == 0) {
          reps[rnd.nextInt(3)].merge(reps[rnd.nextInt(3)], now());
        }
      }
      // Full exchange in a random order, twice.
      for (var pass = 0; pass < 2; pass++) {
        final order = [
          for (var x = 0; x < 3; x++)
            for (var y = 0; y < 3; y++) (x, y),
        ]..shuffle(rnd);
        for (final (x, y) in order) {
          if (x != y) reps[x].merge(reps[y], now());
        }
      }
      Object? data(Replica r) => r.toJson()['c'];
      expect(data(reps[1]), data(reps[0]), reason: 'round $round');
      expect(data(reps[2]), data(reps[0]), reason: 'round $round');
    }
  });
}
