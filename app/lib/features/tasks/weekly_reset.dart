/// The weekly reset: which tasks have been sitting long enough to ask
/// about, and when to offer the reset. Pure Dart.
library;

import '../../data/models/task.dart';

/// A task untouched for this long gets asked about.
const staleAfter = Duration(days: 7);

/// Open tasks nobody has decided about for a week, oldest first.
///
/// Leaves out what's already moving or parked on purpose: in progress,
/// waiting on someone, snoozed until later, and repeating tasks (each copy
/// is new by design).
List<Task> staleTasks(Iterable<Task> tasks, DateTime now) {
  final cutoff = now.subtract(staleAfter);
  return [
    for (final t in tasks)
      if ((t.status == TaskStatus.todo || t.status == TaskStatus.inbox) &&
          t.repeat == Repeat.none &&
          (t.scheduledStart == null || !t.scheduledStart!.isAfter(now)) &&
          (t.reviewedAt ?? t.createdAt).isBefore(cutoff))
        t,
  ]..sort(
    (a, b) =>
        (a.reviewedAt ?? a.createdAt).compareTo(b.reviewedAt ?? b.createdAt),
  );
}

/// Whether Home should offer the reset. Weekends, once a week; on a
/// weekday only when it's been two weeks and the pile is getting big.
bool resetDue({
  required int staleCount,
  required DateTime? lastReset,
  required DateTime now,
}) {
  if (staleCount == 0) return false;
  final since = lastReset == null ? null : now.difference(lastReset);
  final weekend =
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (weekend) return since == null || since >= const Duration(days: 6);
  return staleCount >= 5 &&
      (since == null || since >= const Duration(days: 14));
}
