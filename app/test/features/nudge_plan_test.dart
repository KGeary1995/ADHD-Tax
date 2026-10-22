import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/reminders/nudge_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const am845 = 8 * 60 + 45, pm115 = 13 * 60 + 15;
  final friMorning = DateTime(2026, 10, 9, 7); // Friday 7am

  test('both times today and every following day', () {
    final n = planNudges(
      times: [pm115, am845],
      weekdaysOnly: false,
      now: friMorning,
      days: 3,
    );
    expect(n.map((x) => x.at), [
      DateTime(2026, 10, 9, 8, 45),
      DateTime(2026, 10, 9, 13, 15),
      DateTime(2026, 10, 10, 8, 45),
      DateTime(2026, 10, 10, 13, 15),
      DateTime(2026, 10, 11, 8, 45),
      DateTime(2026, 10, 11, 13, 15),
    ]);
  });

  test('times already past today are skipped', () {
    final n = planNudges(
      times: [am845, pm115],
      weekdaysOnly: false,
      now: DateTime(2026, 10, 9, 12),
      days: 1,
    );
    expect(n.map((x) => x.at), [DateTime(2026, 10, 9, 13, 15)]);
  });

  test('weekdays only skips Saturday and Sunday', () {
    final n = planNudges(
      times: [am845],
      weekdaysOnly: true,
      now: friMorning,
      days: 4,
    );
    expect(n.map((x) => x.at), [
      DateTime(2026, 10, 9, 8, 45),
      DateTime(2026, 10, 12, 8, 45),
    ]);
  });

  test('quiet for 90 minutes after you started something', () {
    final n = planNudges(
      times: [am845, pm115],
      weekdaysOnly: false,
      now: friMorning,
      lastActive: DateTime(2026, 10, 9, 7, 30),
      days: 1,
    );
    expect(n.map((x) => x.at), [DateTime(2026, 10, 9, 13, 15)]);
  });

  test('messages rotate', () {
    final n = planNudges(
      times: [am845, pm115],
      weekdaysOnly: false,
      now: friMorning,
      days: 3,
    );
    expect(n[0].message, isNot(n[1].message));
    expect(n.map((x) => x.message).toSet().length, greaterThan(3));
  });

  test('no times, no nudges', () {
    expect(
      planNudges(times: [], weekdaysOnly: false, now: friMorning),
      isEmpty,
    );
  });

  test('a reminder for each waiting task with a check-back date ahead', () {
    Task t(String id, TaskStatus st, DateTime? at, [String who = '']) => Task(
      id: id,
      title: 'Task $id',
      status: st,
      followUpAt: at,
      waitingOn: who,
      createdAt: friMorning,
      updatedAt: friMorning,
    );
    final n = planFollowUps([
      t('a', TaskStatus.waiting, DateTime(2026, 10, 12, 9), 'IT'),
      t('b', TaskStatus.waiting, DateTime(2026, 10, 8, 9)), // already passed
      t('c', TaskStatus.todo, DateTime(2026, 10, 12, 9)), // not waiting
      t('d', TaskStatus.waiting, null), // no date
    ], friMorning);
    expect(n, hasLength(1));
    expect(n.single.at, DateTime(2026, 10, 12, 9));
    expect(n.single.message, 'Task a: any news from IT?');
    expect(n.single.route, '/tasks');
  });

  test('wrap-up every evening, starting tonight', () {
    final n = planWrapUps(time: 20 * 60 + 30, now: friMorning, days: 3);
    expect(n.map((x) => x.at), [
      DateTime(2026, 10, 9, 20, 30),
      DateTime(2026, 10, 10, 20, 30),
      DateTime(2026, 10, 11, 20, 30),
    ]);
    expect(n.every((x) => x.route == '/wrapup'), isTrue);
    final late = planWrapUps(
      time: 20 * 60 + 30,
      now: DateTime(2026, 10, 9, 21),
      days: 2,
    );
    expect(late.first.at, DateTime(2026, 10, 10, 20, 30));
  });
}
