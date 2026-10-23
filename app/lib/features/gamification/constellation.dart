import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import 'progress_stats.dart';

/// Every task you started in the last [weeks] weeks, drawn as a star.
/// Days in a row join up into constellations; a missed day just leaves
/// a gap, never a mark against you.
class Constellation extends StatelessWidget {
  const Constellation({
    super.key,
    required this.startsByDay,
    required this.now,
    this.weeks = 12,
  });

  final Map<String, int> startsByDay;
  final DateTime now;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final today = DateTime(now.year, now.month, now.day);
    // Calendar weeks from Monday, so each week keeps its shape as the days
    // go by; the last one is this week, up to today.
    final firstMonday = today.subtract(
      Duration(days: today.weekday - 1 + (weeks - 1) * 7),
    );
    final counts = [
      for (var w = 0; w < weeks; w++)
        [
          for (var d = 0; d < 7; d++)
            switch (firstMonday.add(Duration(days: w * 7 + d))) {
              final day when day.isAfter(today) => -1,
              final day => startsByDay[dayKey(day)] ?? 0,
            },
        ],
    ];
    final total = counts
        .expand((w) => w)
        .where((n) => n > 0)
        .fold(0, (a, b) => a + b);
    final ink = s.isDark ? s.onSurface : s.onInk;

    return Panel(
      radius: 22,
      color: s.isDark ? null : s.ink,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Your sky', style: s.display(22, color: ink)),
              Text(
                '$total ${total == 1 ? 'start' : 'starts'} · $weeks weeks',
                style: s.mono(12, color: ink.withValues(alpha: 0.7)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 520 ? 6 : 4;
              final rows = (weeks / cols).ceil();
              return Semantics(
                container: true,
                image: true,
                label:
                    '$total ${total == 1 ? 'task' : 'tasks'} started in the '
                    'last $weeks weeks',
                child: SizedBox(
                  height: rows * 64.0,
                  child: CustomPaint(
                    painter: _SkyPainter(
                      weeks: counts,
                      cols: cols,
                      star: s.accent,
                      ink: ink,
                      firstWeek:
                          firstMonday.millisecondsSinceEpoch ~/ 86400000 ~/ 7,
                    ),
                    child: total == 0
                        ? Center(
                            child: Text(
                              'Start a task and your first star appears here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ink.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Every start is a star. Each week makes its own constellation.',
            style: TextStyle(color: ink.withValues(alpha: 0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.weeks,
    required this.cols,
    required this.star,
    required this.ink,
    required this.firstWeek,
  });

  /// Starts per day, a list of 7 per week, oldest week first. -1 is a day
  /// still to come this week.
  final List<List<int>> weeks;
  final int cols;
  final Color star;
  final Color ink;

  /// Week number of the first week, so every week gets the same shape
  /// each time it's drawn.
  final int firstWeek;

  /// 0..1, the same every time for the same [n].
  static double _rand(int n) {
    var x = (n * 0x45d9f3b) & 0x7fffffff;
    x = ((x >> 16) ^ x) * 0x45d9f3b & 0x7fffffff;
    x = (x >> 16) ^ x;
    return (x & 0xffff) / 0xffff;
  }

  /// Most stars drawn for one day; busier days get a bigger main star.
  static const _perDay = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = (weeks.length / cols).ceil();
    final cw = size.width / cols;
    final ch = size.height / rows;

    // Faint dust so even an empty sky reads as sky.
    final dust = Paint()..color = ink.withValues(alpha: 0.12);
    for (var i = 0; i < 70; i++) {
      canvas.drawCircle(
        Offset(size.width * _rand(i * 7 + 1), size.height * _rand(i * 13 + 5)),
        0.8,
        dust,
      );
    }

    final line = Paint()
      ..color = ink.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final dot = Paint();

    for (var w = 0; w < weeks.length; w++) {
      final wk = firstWeek + w;
      final centre = Offset(
        cw * (w % cols + 0.5) + (_rand(wk * 5) - 0.5) * cw * 0.15,
        ch * (w ~/ cols + 0.5) + (_rand(wk * 11) - 0.5) * ch * 0.15,
      );
      // The week's seven places along an open arc, turned and stretched a
      // little differently each week, so each reads as its own shape.
      final turn = _rand(wk) * math.pi * 2;
      final places = [
        for (var d = 0; d < 7; d++)
          () {
            final a = turn + d / 7 * math.pi * 1.6;
            final r = 0.55 + 0.45 * _rand(wk * 7 + d);
            return centre +
                Offset(
                  math.cos(a) * cw * 0.36 * r,
                  math.sin(a) * ch * 0.36 * r,
                );
          }(),
      ];
      final days = weeks[w];
      // Older weeks fade a little; this week is brightest.
      final alpha = 1 - (weeks.length - 1 - w) / weeks.length * 0.5;

      for (var d = 1; d < 7; d++) {
        if (days[d - 1] > 0 && days[d] > 0) {
          canvas.drawLine(places[d - 1], places[d], line);
        }
      }
      for (var d = 0; d < 7; d++) {
        final n = days[d];
        if (n <= 0) continue;
        final seed = (wk * 7 + d) * 31;
        for (var i = 0; i < math.min(n, _perDay); i++) {
          final p = i == 0
              ? places[d]
              : places[d] +
                    Offset(
                      (_rand(seed + i) - 0.5) * 12,
                      (_rand(seed + i + 9) - 0.5) * 12,
                    );
          final r = i == 0
              ? 2.0 + math.min(n, 6) * 0.3
              : 0.9 + _rand(seed + i + 3) * 0.6;
          glow.color = star.withValues(alpha: 0.35 * alpha);
          canvas.drawCircle(p, r * 2.2, glow);
          dot.color = star.withValues(alpha: alpha);
          canvas.drawCircle(p, r, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.firstWeek != firstWeek ||
      old.cols != cols ||
      old.star != star ||
      old.ink != ink ||
      old.weeks.expand((w) => w).join(',') != weeks.expand((w) => w).join(',');
}
