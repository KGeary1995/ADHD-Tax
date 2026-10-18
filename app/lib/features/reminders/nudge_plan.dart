/// When check-in nudges go off. Pure Dart.
library;

import '../../data/models/task.dart';
import 'reminders.dart';

/// Rotated so the same words don't become wallpaper.
const nudgeMessages = [
  "Got 20 minutes? Let's pick one thing.",
  "One small thing? Tap and I'll choose it for you.",
  'Head full? Dump it here, then pick one.',
  'Starting is the hard part. Want a 5-minute one?',
  "Quick check-in: what's one thing you could start?",
];

/// How far ahead nudges are scheduled. They're re-planned every time the
/// app opens, so this only matters if it isn't opened for weeks.
const nudgeDays = 14;

/// Nudges at [times] (minutes after midnight, local time) for the coming
/// [days], skipping weekends if [weekdaysOnly].
///
/// None go off within [quiet] after [lastActive]: right after you started
/// or finished something, a "pick one thing?" is just noise.
List<Nudge> planNudges({
  required List<int> times,
  required bool weekdaysOnly,
  required DateTime now,
  DateTime? lastActive,
  int days = nudgeDays,
  Duration quiet = const Duration(minutes: 90),
}) {
  final sorted = [...times]..sort();
  final out = <Nudge>[];
  for (var d = 0; d < days; d++) {
    final day = DateTime(now.year, now.month, now.day + d);
    if (weekdaysOnly && day.weekday >= DateTime.saturday) continue;
    for (final m in sorted) {
      final at = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
      if (!at.isAfter(now)) continue;
      if (lastActive != null &&
          !at.isBefore(lastActive) &&
          at.isBefore(lastActive.add(quiet))) {
        continue;
      }
      out.add(Nudge(at, nudgeMessages[out.length % nudgeMessages.length]));
    }
  }
  return out;
}

/// One reminder per waiting task with a check-back date still ahead.
List<Nudge> planFollowUps(Iterable<Task> tasks, DateTime now) {
  final due = [
    for (final t in tasks)
      if (t.status == TaskStatus.waiting &&
          t.followUpAt != null &&
          t.followUpAt!.isAfter(now))
        t,
  ]..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));
  return [
    for (final t in due.take(30))
      Nudge(
        t.followUpAt!,
        t.waitingOn.isEmpty
            ? '${t.title}: any news?'
            : '${t.title}: any news from ${t.waitingOn}?',
        title: 'Time to check back',
        route: '/tasks',
      ),
  ];
}

/// "Wrap up the day?" at [time] (minutes after midnight) for the coming
/// [days].
List<Nudge> planWrapUps({
  required int time,
  required DateTime now,
  int days = nudgeDays,
}) => [
  for (var d = 0; d < days; d++)
    if (DateTime(now.year, now.month, now.day + d, time ~/ 60, time % 60)
        case final at when at.isAfter(now))
      Nudge(
        at,
        "3 minutes: today's wins, the leftovers, and tomorrow's first thing.",
        title: 'Wrap up the day?',
        route: '/wrapup',
      ),
];
