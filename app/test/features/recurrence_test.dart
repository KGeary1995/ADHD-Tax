import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/tasks/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task({
  Repeat repeat = Repeat.weekly,
  bool fromDone = false,
  DateTime? due,
  DateTime? created,
  DateTime? scheduled,
}) {
  final c = created ?? DateTime(2026, 10, 5, 9); // Monday
  return Task(
    id: 'laundry',
    title: 'Laundry',
    createdAt: c,
    updatedAt: c,
    repeat: repeat,
    repeatFromDone: fromDone,
    dueAt: due,
    scheduledStart: scheduled,
    status: TaskStatus.doing,
    startedAt: c,
    actualMin: 25,
    skipCount: 3,
  );
}

void main() {
  test('non-repeating tasks have no next copy', () {
    expect(nextOccurrence(_task(repeat: Repeat.none), DateTime(2026)), isNull);
  });

  test('next copy is fresh: to-do, no progress, same details', () {
    final done = _task().copyWith(priority: Priority.p2, ugh: 2);
    final next = nextOccurrence(done, DateTime(2026, 10, 7, 18))!;
    expect(next.id, isNot(done.id));
    expect(next.title, 'Laundry');
    expect(next.priority, Priority.p2);
    expect(next.ugh, 2);
    expect(next.repeat, Repeat.weekly);
    expect(next.status, TaskStatus.todo);
    expect(next.startedAt, isNull);
    expect(next.completedAt, isNull);
    expect(next.actualMin, isNull);
    expect(next.skipCount, 0);
  });

  test('same finished task always gives the same next id (sync-safe)', () {
    final a = nextOccurrence(_task(), DateTime(2026, 10, 7, 18))!;
    final b = nextOccurrence(_task(), DateTime(2026, 10, 7, 19))!;
    expect(a.id, b.id);
  });

  group('without a due date', () {
    test('fixed schedule: weekly from the day it was created', () {
      // Created Monday, finished Wednesday → back next Monday.
      final next = nextOccurrence(_task(), DateTime(2026, 10, 7, 18))!;
      expect(next.scheduledStart, DateTime(2026, 10, 12));
      expect(next.dueAt, isNull);
    });

    test('fixed schedule follows the previous copy', () {
      final next = nextOccurrence(
        _task(scheduled: DateTime(2026, 10, 12)),
        DateTime(2026, 10, 13, 8),
      )!;
      expect(next.scheduledStart, DateTime(2026, 10, 19));
    });

    test('from when finished: a week after the day it was done', () {
      final next = nextOccurrence(
        _task(fromDone: true),
        DateTime(2026, 10, 7, 18),
      )!;
      expect(next.scheduledStart, DateTime(2026, 10, 14));
    });

    test('daily comes back tomorrow, even after a long gap', () {
      final next = nextOccurrence(
        _task(repeat: Repeat.daily),
        DateTime(2026, 10, 20, 22),
      )!;
      expect(next.scheduledStart, DateTime(2026, 10, 21));
    });

    test('weekdays skip the weekend', () {
      final next = nextOccurrence(
        _task(repeat: Repeat.weekdays, fromDone: true),
        DateTime(2026, 10, 9, 17), // Friday
      )!;
      expect(next.scheduledStart, DateTime(2026, 10, 12)); // Monday
    });
  });

  group('with a due date', () {
    test('due one period later, visible a couple of days before', () {
      final next = nextOccurrence(
        _task(due: DateTime(2026, 10, 9, 17)), // Friday 5pm
        DateTime(2026, 10, 9, 15),
      )!;
      expect(next.dueAt, DateTime(2026, 10, 16, 17));
      expect(next.scheduledStart, DateTime(2026, 10, 14));
    });

    test('finished late: skips missed dates instead of stacking them', () {
      final next = nextOccurrence(
        _task(due: DateTime(2026, 10, 2, 17)),
        DateTime(2026, 10, 13, 9),
      )!;
      expect(next.dueAt, DateTime(2026, 10, 16, 17));
    });

    test('from when finished keeps the time of day', () {
      final next = nextOccurrence(
        _task(due: DateTime(2026, 10, 9, 17), fromDone: true),
        DateTime(2026, 10, 11, 10),
      )!;
      expect(next.dueAt, DateTime(2026, 10, 18, 17));
    });

    test('daily stays out of the way until its day', () {
      final next = nextOccurrence(
        _task(repeat: Repeat.daily, due: DateTime(2026, 10, 9, 21)),
        DateTime(2026, 10, 9, 20),
      )!;
      expect(next.dueAt, DateTime(2026, 10, 10, 21));
      expect(next.scheduledStart, DateTime(2026, 10, 10));
    });
  });

  test('monthly clamps to the end of shorter months', () {
    expect(
      advance(DateTime(2026, 1, 31, 9), Repeat.monthly),
      DateTime(2026, 2, 28, 9),
    );
    expect(
      advance(DateTime(2026, 12, 15), Repeat.monthly),
      DateTime(2027, 1, 15),
    );
  });

  test('repeat settings survive a JSON round trip', () {
    final t = _task(repeat: Repeat.biweekly, fromDone: true);
    final back = Task.fromJson(t.toJson());
    expect(back.repeat, Repeat.biweekly);
    expect(back.repeatFromDone, isTrue);
    // Older data without the fields still loads.
    final old = t.toJson()
      ..remove('repeat')
      ..remove('repeatFromDone');
    expect(Task.fromJson(old).repeat, Repeat.none);
  });
}
