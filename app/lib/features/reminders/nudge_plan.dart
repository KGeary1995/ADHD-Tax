/// When check-in nudges go off. Pure Dart.
library;

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
