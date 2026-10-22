import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/tasks/weekly_reset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sunday.
  final now = DateTime(2026, 10, 25, 10);
  Task t(
    String id, {
    int ageDays = 10,
    TaskStatus status = TaskStatus.todo,
    Repeat repeat = Repeat.none,
    DateTime? scheduledStart,
    DateTime? reviewedAt,
  }) {
    final at = now.subtract(Duration(days: ageDays));
    return Task(
      id: id,
      title: id,
      createdAt: at,
      updatedAt: at,
      status: status,
      repeat: repeat,
      scheduledStart: scheduledStart,
      reviewedAt: reviewedAt,
    );
  }

  test('stale: open and undecided for a week, oldest first', () {
    final list = staleTasks([
      t('fresh', ageDays: 3),
      t('old', ageDays: 30),
      t('older', ageDays: 40),
      t('doing', status: TaskStatus.doing),
      t('waiting', status: TaskStatus.waiting),
      t('done', status: TaskStatus.done),
      t('repeats', repeat: Repeat.weekly),
      t('snoozed', scheduledStart: now.add(const Duration(days: 2))),
      t('kept', ageDays: 30, reviewedAt: now.subtract(const Duration(days: 2))),
      t('kept long ago', ageDays: 60, reviewedAt: DateTime(2026, 10, 1)),
    ], now);
    expect(list.map((x) => x.id), ['older', 'old', 'kept long ago']);
  });

  test('offered on weekends once a week; weekdays only for a big pile', () {
    expect(resetDue(staleCount: 0, lastReset: null, now: now), isFalse);
    expect(resetDue(staleCount: 1, lastReset: null, now: now), isTrue);
    expect(
      resetDue(
        staleCount: 3,
        lastReset: now.subtract(const Duration(days: 1)),
        now: now,
      ),
      isFalse,
    );
    final monday = DateTime(2026, 10, 26, 10);
    expect(resetDue(staleCount: 3, lastReset: null, now: monday), isFalse);
    expect(resetDue(staleCount: 6, lastReset: null, now: monday), isTrue);
    expect(
      resetDue(
        staleCount: 6,
        lastReset: monday.subtract(const Duration(days: 3)),
        now: monday,
      ),
      isFalse,
    );
  });

  test('reviewedAt round-trips and older records default to none', () {
    final x = t('a', reviewedAt: now);
    expect(Task.fromJson(x.toJson()).reviewedAt, now);
    expect(Task.fromJson(x.toJson()..remove('reviewedAt')).reviewedAt, isNull);
  });
}
