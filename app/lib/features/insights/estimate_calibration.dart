/// Learns how long tasks really take compared with your estimates. Pure
/// Dart.
library;

import '../../data/models/task.dart';

/// "Tasks take you about 1.4× your guess."
class Calibration {
  const Calibration({this.factor = 1.0, this.samples = 0});

  /// Median of actual ÷ estimated time over recent timed tasks.
  final double factor;

  /// How many finished, timed tasks it's based on.
  final int samples;

  static const minSamples = 5;

  /// Enough data, and far enough from 1× to be worth acting on.
  bool get meaningful =>
      samples >= minSamples && (factor >= 1.15 || factor <= 0.85);

  /// What [estimateMin] probably means in real minutes.
  int realMinutes(int estimateMin) => meaningful
      ? (estimateMin * factor).round().clamp(1, 24 * 60)
      : estimateMin;
}

/// Per workspace, falling back to all tasks together when a workspace has
/// too few timed tasks of its own.
class Calibrations {
  const Calibrations({
    this.overall = const Calibration(),
    this.byWorkspace = const {},
  });

  final Calibration overall;
  final Map<Workspace, Calibration> byWorkspace;

  Calibration forWorkspace(Workspace w) {
    final own = byWorkspace[w];
    return own != null && own.samples >= Calibration.minSamples ? own : overall;
  }
}

/// How many of the most recent timed tasks to learn from, so it follows
/// you as you get better at estimating.
const calibrationWindow = 30;

Calibrations calibrate(Iterable<Task> tasks) {
  final timed = [
    for (final t in tasks)
      if (t.status == TaskStatus.done &&
          t.completedAt != null &&
          (t.actualMin ?? 0) > 0 &&
          t.estimateMin > 0)
        t,
  ]..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  Calibration of(Iterable<Task> ts) {
    final ratios = [
      for (final t in ts.take(calibrationWindow)) t.actualMin! / t.estimateMin,
    ]..sort();
    if (ratios.isEmpty) return const Calibration();
    final mid = ratios.length ~/ 2;
    final median = ratios.length.isOdd
        ? ratios[mid]
        : (ratios[mid - 1] + ratios[mid]) / 2;
    return Calibration(
      factor: median.clamp(0.5, 3.0).toDouble(),
      samples: ratios.length,
    );
  }

  return Calibrations(
    overall: of(timed),
    byWorkspace: {
      for (final w in Workspace.values)
        w: of(timed.where((t) => t.workspace == w)),
    },
  );
}
