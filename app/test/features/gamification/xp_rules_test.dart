import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/gamification/achievements.dart';
import 'package:adhd_tax/features/gamification/xp_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 17, 14);

Task t({
  int est = 30,
  Priority p = Priority.p3,
  int ugh = 0,
  bool out = false,
  int ageDays = 0,
}) => Task(
  id: 'x',
  title: 'x',
  estimateMin: est,
  priority: p,
  ugh: ugh,
  requiresLeavingHouse: out,
  createdAt: now.subtract(Duration(days: ageDays)),
  updatedAt: now,
);

void main() {
  group('xp', () {
    test('starting earns XP, more for dreaded tasks', () {
      expect(startXp(t()).total, 10);
      expect(startXp(t(ugh: 2)).total, 20);
    });

    test('completion scales with size, priority and dread', () {
      final base = completionXp(
        t(),
        now: now,
        actualMin: 40,
        firstOfDay: false,
      );
      final p1 = completionXp(
        t(p: Priority.p1),
        now: now,
        actualMin: 40,
        firstOfDay: false,
      );
      final ugh = completionXp(
        t(ugh: 2),
        now: now,
        actualMin: 40,
        firstOfDay: false,
      );
      expect(base.total, 25); // 10 + 30/2
      expect(p1.total, 50);
      expect(ugh.total, 50);
    });

    test('bonuses: first of day, beat estimate, old task, errand', () {
      final a = completionXp(
        t(out: true, ageDays: 8),
        now: now,
        actualMin: 20,
        firstOfDay: true,
      );
      final labels = a.lines.map((l) => l.label).toList();
      expect(
        labels,
        containsAll([
          'First win of the day',
          'Beat your estimate',
          'Cleared an old task',
          'Got out the door',
        ]),
      );
    });

    test('coins are a tenth of XP, at least one', () {
      expect(const XpAward([XpLine('a', 5)]).coins, 1);
      expect(const XpAward([XpLine('a', 57)]).coins, 5);
    });
  });

  group('levels', () {
    test('curve is monotonic and level 1 starts at 0', () {
      expect(xpForLevel(1), 0);
      expect(xpForLevel(2), 100);
      for (var l = 1; l < 50; l++) {
        expect(xpForLevel(l + 1), greaterThan(xpForLevel(l)));
      }
    });

    test('levelForXp inverts xpForLevel', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(99), 1);
      expect(levelForXp(100), 2);
      expect(levelForXp(xpForLevel(10)), 10);
      expect(levelForXp(xpForLevel(10) - 1), 9);
    });

    test('progress is within [0, 1)', () {
      for (final xp in [0, 50, 100, 999, 12345]) {
        expect(levelProgress(xp), inInclusiveRange(0, 1));
      }
    });

    test('ranks change every 5 levels and cap at the last', () {
      expect(rankForLevel(1), ranks[0]);
      expect(rankForLevel(5), ranks[0]);
      expect(rankForLevel(6), ranks[1]);
      expect(rankForLevel(999), ranks.last);
    });
  });

  group('streak with grace', () {
    DateTime d(int daysAgo) => now.subtract(Duration(days: daysAgo));

    test('consecutive days', () {
      expect(streakWithGrace({d(0), d(1), d(2)}, now), 3);
    });

    test('today not yet active does not break it', () {
      expect(streakWithGrace({d(1), d(2)}, now), 2);
    });

    test('up to 2 missed days a week are forgiven', () {
      expect(streakWithGrace({d(0), d(2), d(4), d(5)}, now), 4);
    });

    test('a third miss in a week ends the streak', () {
      expect(streakWithGrace({d(0), d(4), d(5)}, now), 1);
    });

    test('empty is zero', () {
      expect(streakWithGrace({}, now), 0);
    });
  });

  group('achievements', () {
    test('first start and first finish unlock', () {
      final ids = newlyUnlocked(
        const ProgressStats(started: 1, completed: 1),
        AchievementEvent(now),
      ).map((a) => a.id);
      expect(ids, containsAll(['first_spark', 'first_win']));
    });

    test('already unlocked achievements are not repeated', () {
      final s = ProgressStats(started: 1, unlocked: {'first_spark': now});
      expect(
        newlyUnlocked(s, AchievementEvent(now)).map((a) => a.id),
        isNot(contains('first_spark')),
      );
    });

    test('night owl only fires on a completion', () {
      final late = DateTime(2026, 10, 17, 23);
      const s = ProgressStats(completed: 5, unlocked: {});
      expect(
        newlyUnlocked(s, AchievementEvent(late)).map((a) => a.id),
        isNot(contains('night_owl')),
      );
      expect(
        newlyUnlocked(
          s,
          AchievementEvent(late, justCompleted: true),
        ).map((a) => a.id),
        contains('night_owl'),
      );
    });

    test('errand runner counts today only', () {
      final s = ProgressStats(errandsByDay: {dayKey(now): 3});
      expect(
        newlyUnlocked(s, AchievementEvent(now)).map((a) => a.id),
        contains('errand_runner'),
      );
    });

    test('stats survive a JSON round trip', () {
      final s = ProgressStats(
        xp: 123,
        coins: 7,
        completed: 4,
        activeDays: {DateTime(2026, 10, 16)},
        unlocked: {'first_win': now},
        completionsByDay: {dayKey(now): 2},
        recent: [XpLogEntry(now, 'Finished: x', 30)],
      );
      final back = ProgressStats.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
    });
  });
}
