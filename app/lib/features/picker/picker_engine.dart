/// "Pick for me": filters and scores open tasks against the user's current
/// situation and returns the single best one, with a human-readable reason.
///
/// Pure Dart so it can be unit-tested and reused by a future planner/backend.
library;

import 'dart:math' as math;

import '../../data/models/task.dart';
import '../insights/estimate_calibration.dart';

class PickerContext {
  const PickerContext({
    required this.availableMin,
    required this.willingToLeave,
    required this.now,
    this.energy,
    this.workspaces = const {Workspace.personal, Workspace.work},
    this.calibration = const Calibrations(),
  });

  final int availableMin;
  final bool willingToLeave;
  final DateTime now;

  /// Null means "didn't say" — energy is then ignored in scoring.
  final Energy? energy;
  final Set<Workspace> workspaces;

  /// How long tasks really take you, learned from timed sessions. Tasks
  /// are fitted to your time by their real length, not the estimate.
  final Calibrations calibration;

  int realMinutes(Task t) =>
      calibration.forWorkspace(t.workspace).realMinutes(t.estimateMin);
}

class PickerWeights {
  const PickerWeights({
    this.priority = 1.0,
    this.urgency = 4.0,
    this.staleness = 1.5,
    this.fit = 1.0,
    this.energy = 1.0,
    this.ugh = 1.0,
    this.skipPenalty = 1.5,
    this.inProgress = 0.75,
  });

  final double priority;
  final double urgency;
  final double staleness;
  final double fit;
  final double energy;
  final double ugh;
  final double skipPenalty;
  final double inProgress;
}

class Suggestion {
  const Suggestion({
    required this.task,
    required this.score,
    required this.plannedMin,
    required this.isChunk,
    required this.reasons,
  });

  final Task task;
  final double score;

  /// How long this session should be (the estimate, or a chunk of it).
  final int plannedMin;
  final bool isChunk;

  /// Most important first.
  final List<String> reasons;

  String get reasonLine => reasons.take(2).join(' · ');
}

/// Why nothing was suggested, so the UI can offer a useful next move.
enum NoPickReason {
  noOpenTasks,
  nothingFitsTime,
  allNeedLeaving,
  allExcluded,

  /// Every open task is set to come back later (snoozed, or the next copy
  /// of a repeating task): a bigger window wouldn't help.
  allLater,
}

class PickResult {
  const PickResult.found(Suggestion this.suggestion) : noPickReason = null;
  const PickResult.none(NoPickReason this.noPickReason) : suggestion = null;

  final Suggestion? suggestion;
  final NoPickReason? noPickReason;
}

class PickerEngine {
  const PickerEngine({this.weights = const PickerWeights()});

  final PickerWeights weights;

  /// Minimum window for offering a chunk of a long task.
  static const minChunkMin = 10;

  /// Every eligible task, best first.
  List<Suggestion> rank(
    Iterable<Task> tasks,
    PickerContext ctx, {
    Set<String> exclude = const {},
  }) {
    final out = <Suggestion>[];
    for (final t in tasks) {
      if (exclude.contains(t.id) || !_isCandidate(t, ctx)) continue;
      final fits = ctx.realMinutes(t) <= ctx.availableMin;
      final canChunk = t.chunkable && ctx.availableMin >= minChunkMin;
      if (!fits && !canChunk) continue;
      out.add(_score(t, ctx, isChunk: !fits));
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.task.createdAt.compareTo(b.task.createdAt);
    });
    return out;
  }

  PickResult pick(
    Iterable<Task> tasks,
    PickerContext ctx, {
    Set<String> exclude = const {},
  }) {
    final ranked = rank(tasks, ctx, exclude: exclude);
    if (ranked.isNotEmpty) return PickResult.found(ranked.first);
    return PickResult.none(_whyNothing(tasks, ctx, exclude));
  }

  /// Overwhelm mode: any task becomes "just 5 minutes on it". Favors small,
  /// low-dread tasks so the first win comes fast.
  Suggestion? pickTiny(Iterable<Task> tasks, PickerContext ctx) {
    Suggestion? best;
    double bestScore = double.negativeInfinity;
    for (final t in tasks) {
      if (!_isCandidate(t, ctx)) continue;
      final s = _score(t, ctx, isChunk: t.estimateMin > 5);
      final tinyScore = s.score - t.ugh * 1.5 - math.log(t.estimateMin) * 0.5;
      if (tinyScore > bestScore) {
        bestScore = tinyScore;
        best = Suggestion(
          task: t,
          score: tinyScore,
          plannedMin: 5,
          isChunk: t.estimateMin > 5,
          reasons: const ['Just 5 minutes. That is the whole job.'],
        );
      }
    }
    return best;
  }

  bool _isCandidate(Task t, PickerContext ctx) {
    if (!t.isOpen) return false;
    if (!ctx.workspaces.contains(t.workspace)) return false;
    if (t.requiresLeavingHouse && !ctx.willingToLeave) return false;
    final sched = t.scheduledStart;
    if (sched != null && sched.isAfter(ctx.now)) return false;
    return true;
  }

  NoPickReason _whyNothing(
    Iterable<Task> tasks,
    PickerContext ctx,
    Set<String> exclude,
  ) {
    final open = tasks
        .where((t) => t.isOpen && ctx.workspaces.contains(t.workspace))
        .toList();
    if (open.isEmpty) return NoPickReason.noOpenTasks;
    final ready = open.where((t) {
      final sched = t.scheduledStart;
      return sched == null || !sched.isAfter(ctx.now);
    }).toList();
    if (ready.isEmpty) return NoPickReason.allLater;
    final notExcluded = ready.where((t) => !exclude.contains(t.id)).toList();
    if (notExcluded.isEmpty) return NoPickReason.allExcluded;
    final stayIn = notExcluded.where((t) => !t.requiresLeavingHouse);
    if (!ctx.willingToLeave && stayIn.isEmpty) {
      return NoPickReason.allNeedLeaving;
    }
    return NoPickReason.nothingFitsTime;
  }

  Suggestion _score(Task t, PickerContext ctx, {required bool isChunk}) {
    final w = weights;
    final parts = <_Part>[];

    parts.add(
      _Part(
        w.priority * t.priority.weight,
        t.priority == Priority.p1
            ? 'Critical priority'
            : t.priority == Priority.p2
            ? 'High priority'
            : null,
      ),
    );

    final due = t.dueAt;
    if (due != null) {
      final hoursLeft = due.difference(ctx.now).inMinutes / 60.0;
      double u;
      String reason;
      if (hoursLeft <= 0) {
        u = t.hardDeadline ? 1.0 : 0.8;
        reason = 'Past due — clearing it will feel great';
      } else {
        // Hard deadlines start ramping earlier.
        final halfLife = t.hardDeadline ? 24.0 : 12.0;
        u = 1 / (1 + hoursLeft / halfLife);
        reason = 'Due ${_humanizeHours(hoursLeft)}';
      }
      parts.add(_Part(w.urgency * u, u > 0.25 ? reason : null));
    }

    final ageDays = ctx.now.difference(t.createdAt).inHours / 24.0;
    final stale = (ageDays / 14).clamp(0.0, 1.0);
    parts.add(
      _Part(
        w.staleness * stale,
        ageDays >= 5 ? 'Waiting ${ageDays.floor()} days for you' : null,
      ),
    );

    final real = ctx.realMinutes(t);
    if (real != t.estimateMin) {
      parts.add(_Part(0, 'Tasks like this usually take you ~$real min'));
    }

    final double fit;
    if (isChunk) {
      fit = 0.5;
    } else {
      fit = 0.3 + 0.7 * (real / math.max(ctx.availableMin, 1));
    }
    parts.add(
      _Part(
        w.fit * fit,
        isChunk
            ? 'A ${formatMinutes(ctx.availableMin)} chunk moves it forward'
            : 'Fits your ${formatMinutes(ctx.availableMin)}',
        always: true,
      ),
    );

    final e = ctx.energy;
    if (e != null) {
      final diff = t.energy.index - e.index;
      final double score = diff > 0
          ? -1.0 * diff
          : diff == 0
          ? 0.5
          : 0.25;
      parts.add(
        _Part(w.energy * score, diff == 0 ? 'Matches your energy' : null),
      );
    }

    if (t.ugh > 0) {
      double u = 0;
      String? reason;
      final fresh = ctx.now.hour < 12 || e == Energy.high;
      if (e == Energy.low) {
        u = -0.5 * t.ugh;
      } else if (fresh) {
        u = 0.4 * t.ugh;
        if (t.ugh >= 2) reason = 'Good moment to eat the frog';
      }
      parts.add(_Part(w.ugh * u, reason));
    }

    final skipped = t.lastSkippedAt;
    if (skipped != null && t.skipCount > 0) {
      final hoursSince = ctx.now.difference(skipped).inMinutes / 60.0;
      if (hoursSince < 24) {
        final decay = 1 - hoursSince / 24;
        parts.add(
          _Part(-w.skipPenalty * math.min(t.skipCount, 3) * decay, null),
        );
      }
    }

    if (t.status == TaskStatus.doing) {
      parts.add(_Part(w.inProgress, 'You already started this one'));
    }

    final score = parts.fold<double>(0, (s, p) => s + p.value);
    final reasoned = parts.where((p) => p.reason != null).toList()
      ..sort((a, b) {
        if (a.always != b.always) return a.always ? 1 : -1;
        return b.value.compareTo(a.value);
      });

    return Suggestion(
      task: t,
      score: score,
      plannedMin: isChunk ? ctx.availableMin : real,
      isChunk: isChunk,
      reasons: [for (final p in reasoned) p.reason!],
    );
  }
}

class _Part {
  const _Part(this.value, this.reason, {this.always = false});
  final double value;
  final String? reason;

  /// Generic reasons (like "fits your time") sort after specific ones.
  final bool always;
}

String _humanizeHours(double h) {
  if (h < 1) return 'within the hour';
  if (h < 24) return 'in ${h.round()} hours';
  final d = (h / 24).round();
  return d == 1 ? 'tomorrow' : 'in $d days';
}
