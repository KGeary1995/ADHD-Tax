/// Errand runs: when you can go out, batch the errands that fit into one
/// trip, grouped by place. Pure Dart.
library;

import '../../data/models/task.dart';

/// Rough travel time added for each separate place.
const travelPerStop = 10;

class ErrandStop {
  const ErrandStop(this.place, this.tasks);

  /// The task's location, or '' when none was given.
  final String place;
  final List<Task> tasks;

  int get minutes => tasks.fold(0, (m, t) => m + t.estimateMin);
}

class ErrandRun {
  const ErrandRun(this.stops);
  final List<ErrandStop> stops;

  List<Task> get tasks => [for (final s in stops) ...s.tasks];

  /// Task time plus travel between places.
  int get minutes =>
      stops.fold(0, (m, s) => m + s.minutes) + stops.length * travelPerStop;

  /// "Pharmacy + Post office", "Pharmacy + 2 more", or "3 errands" when
  /// no places were given.
  String get summary {
    final named = [
      for (final s in stops)
        if (s.place.isNotEmpty) s.place,
    ];
    if (named.isEmpty) return '${tasks.length} errands';
    final shown = named.take(2).toList();
    final others =
        tasks.length -
        stops
            .where((s) => shown.contains(s.place))
            .fold(0, (n, s) => n + s.tasks.length);
    return [shown.join(' + '), if (others > 0) '+ $others more'].join(' ');
  }
}

/// The best run that fits in [availableMin] (2 hours or more counts as
/// "plenty"), or null when fewer than two errands would go together.
ErrandRun? planErrandRun(
  Iterable<Task> tasks, {
  required int availableMin,
  required Set<Workspace> workspaces,
  required DateTime now,
}) {
  final errands = [
    for (final t in tasks)
      if (t.requiresLeavingHouse &&
          (t.status == TaskStatus.todo || t.status == TaskStatus.inbox) &&
          workspaces.contains(t.workspace) &&
          (t.scheduledStart == null || !t.scheduledStart!.isAfter(now)))
        t,
  ];
  if (errands.length < 2) return null;

  // Same place, however it was typed.
  final byPlace = <String, List<Task>>{};
  final names = <String, String>{};
  for (final t in errands) {
    final key = t.location.trim().toLowerCase();
    (byPlace[key] ??= []).add(t);
    names.putIfAbsent(key, () => t.location.trim());
  }
  final stops = [
    for (final e in byPlace.entries)
      ErrandStop(
        names[e.key]!,
        e.value..sort((a, b) => _urgency(b, now).compareTo(_urgency(a, now))),
      ),
  ]..sort((a, b) => _stopUrgency(b, now).compareTo(_stopUrgency(a, now)));

  final budget = availableMin >= 120 ? 240 : availableMin;
  final chosen = <ErrandStop>[];
  var used = 0;
  for (final stop in stops) {
    final fitting = <Task>[];
    var stopMin = travelPerStop;
    for (final t in stop.tasks) {
      if (used + stopMin + t.estimateMin <= budget) {
        fitting.add(t);
        stopMin += t.estimateMin;
      }
    }
    if (fitting.isEmpty) continue;
    chosen.add(ErrandStop(stop.place, fitting));
    used += stopMin;
  }
  final run = ErrandRun(chosen);
  return run.tasks.length >= 2 ? run : null;
}

/// Higher is more pressing: priority, then a due date coming up.
double _urgency(Task t, DateTime now) {
  var u = t.priority.weight;
  if (t.dueAt != null) {
    final days = t.dueAt!.difference(now).inHours / 24;
    u += days <= 0 ? 4 : (days < 7 ? (7 - days) / 2 : 0);
  }
  return u;
}

double _stopUrgency(ErrandStop s, DateTime now) =>
    s.tasks.map((t) => _urgency(t, now)).reduce((a, b) => a > b ? a : b) +
    s.tasks.length * 0.5;
