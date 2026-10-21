/// When a repeating task comes back. Pure Dart.
library;

import 'package:uuid/uuid.dart';

import '../../data/models/task.dart';

/// The next copy of a repeating task that was just finished, or null if it
/// doesn't repeat.
///
/// Its id is derived from the finished task's id, so two devices finishing
/// the same task offline create the same next copy instead of two.
///
/// With a due date, the next copy is due one period later and stays out of
/// "Pick for me" until shortly before then ([leadDays]). Without one, it
/// simply stays hidden until the day it's next due to happen.
Task? nextOccurrence(Task done, DateTime finishedAt) {
  if (done.repeat == Repeat.none) return null;
  final r = done.repeat;
  final today = _day(finishedAt);

  DateTime? dueAt;
  DateTime showFrom;
  final due = done.dueAt;
  if (due != null) {
    var next = advance(
      done.repeatFromDone
          ? DateTime(today.year, today.month, today.day, due.hour, due.minute)
          : due,
      r,
    );
    // Finished late: skip the dates already missed rather than stacking up
    // overdue copies.
    while (!next.isAfter(finishedAt)) {
      next = advance(next, r);
    }
    dueAt = next;
    showFrom = _day(next).subtract(Duration(days: leadDays(r)));
  } else {
    final anchor = done.repeatFromDone
        ? today
        : _day(done.scheduledStart ?? done.createdAt);
    var next = advance(anchor, r);
    while (!next.isAfter(today)) {
      next = advance(next, r);
    }
    showFrom = next;
  }

  return Task.fromJson({
    ...done.toJson(),
    // Never change this seed (it predates the rename to Unstuck): devices on
    // older builds must derive the same id for the same finished task.
    'id': const Uuid().v5(Namespace.url.value, 'adhd-tax:repeat:${done.id}'),
    'status': TaskStatus.todo.name,
    'dueAt': dueAt?.toIso8601String(),
    'scheduledStart': showFrom.isAfter(finishedAt)
        ? showFrom.toIso8601String()
        : null,
    'createdAt': finishedAt.toIso8601String(),
    'updatedAt': finishedAt.toIso8601String(),
    'startedAt': null,
    'completedAt': null,
    'actualMin': null,
    'skipCount': 0,
    'lastSkippedAt': null,
    'waitingOn': '',
    'followUpAt': null,
    'reviewedAt': null,
    // The next round starts with every box unticked.
    'checklist': resetChecklist(done.checklist),
  });
}

/// One period after [d], keeping the time of day.
DateTime advance(DateTime d, Repeat r) {
  DateTime plusDays(int n) =>
      DateTime(d.year, d.month, d.day + n, d.hour, d.minute);
  switch (r) {
    case Repeat.none:
      return d;
    case Repeat.daily:
      return plusDays(1);
    case Repeat.weekdays:
      final n = switch (d.weekday) {
        DateTime.friday => 3,
        DateTime.saturday => 2,
        _ => 1,
      };
      return plusDays(n);
    case Repeat.weekly:
      return plusDays(7);
    case Repeat.biweekly:
      return plusDays(14);
    case Repeat.monthly:
      // Jan 31 → Feb 28, not Mar 3.
      final lastDay = DateTime(d.year, d.month + 2, 0).day;
      return DateTime(
        d.year,
        d.month + 1,
        d.day > lastDay ? lastDay : d.day,
        d.hour,
        d.minute,
      );
  }
}

/// How many days before its due date a repeating task shows up again.
int leadDays(Repeat r) => switch (r) {
  Repeat.none || Repeat.daily || Repeat.weekdays => 0,
  Repeat.weekly => 2,
  Repeat.biweekly => 4,
  Repeat.monthly => 7,
};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
