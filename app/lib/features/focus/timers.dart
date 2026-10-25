import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';

/// "24:51", or "+01:30" once over time.
String clockText(Duration remaining) {
  final over = remaining.isNegative;
  final shown = over ? -remaining : remaining;
  final mm = shown.inMinutes.toString().padLeft(2, '0');
  final ss = (shown.inSeconds % 60).toString().padLeft(2, '0');
  return '${over ? '+' : ''}$mm:$ss';
}

/// The line under the time.
String timerCaption(Duration remaining, Duration total, bool paused) => paused
    ? 'Paused'
    : remaining.isNegative
    ? 'Over time. Finish up'
    : 'left of ${total.inMinutes} min';

String _semantics(Duration remaining) {
  final over = remaining.isNegative;
  final shown = over ? -remaining : remaining;
  return over
      ? '${shown.inMinutes} minutes over time'
      : '${shown.inMinutes} minutes ${shown.inSeconds % 60} seconds left';
}

/// A star travelling round an orbit as the time goes, with the time in the
/// middle. Paused, the star dims. With Reduce Motion it moves once a
/// minute.
class OrbitTimer extends StatelessWidget {
  const OrbitTimer({
    super.key,
    required this.remaining,
    required this.total,
    this.radius = 140,
    this.paused = false,
  });

  final Duration remaining;
  final Duration total;
  final double radius;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    var elapsed = total - remaining;
    if (context.reduceMotion) elapsed = Duration(minutes: elapsed.inMinutes);
    final frac = total.inMilliseconds == 0
        ? 0.0
        : (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final big = radius >= 120 ? 64.0 : 52.0;
    return Semantics(
      label: _semantics(remaining),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: radius * 2,
        child: CustomPaint(
          painter: _OrbitPainter(
            frac: frac,
            ring: s.line2,
            dashes: s.line,
            star: s.star,
            glow: s.glow,
            dim: paused,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(clockText(remaining), style: s.timer(big)),
                  const SizedBox(height: Gap.s4),
                  Text(
                    timerCaption(remaining, total, paused),
                    style: s.caption(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.frac,
    required this.ring,
    required this.dashes,
    required this.star,
    required this.glow,
    required this.dim,
  });

  final double frac;
  final Color ring;
  final Color dashes;
  final Color star;
  final Color glow;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 0.5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // The dashed inner ring.
    final inner = r - 16;
    final dash = Paint()
      ..color = dashes
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final n = (2 * math.pi * inner / 7).floor();
    for (var i = 0; i < n; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: inner),
        i * 2 * math.pi / n,
        math.pi / n,
        false,
        dash,
      );
    }
    final a = frac * 2 * math.pi - math.pi / 2;
    final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
    final o = dim ? 0.35 : 1.0;
    canvas
      ..drawCircle(
        p,
        12,
        Paint()
          ..color = glow.withValues(alpha: glow.a * o)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      )
      ..drawCircle(p, 7, Paint()..color = star.withValues(alpha: o));
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.frac != frac ||
      old.dim != dim ||
      old.star != star ||
      old.ring != ring;
}

/// Big digits over a grid of blocks that fill as the minutes go.
class BlockTimer extends StatelessWidget {
  const BlockTimer({
    super.key,
    required this.remaining,
    required this.total,
    this.small = false,
    this.paused = false,
  });

  final Duration remaining;
  final Duration total;
  final bool small;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final minutes = math.max(1, total.inMinutes);
    // One block a minute up to half an hour; longer sessions share blocks
    // so the grid stays a few rows tall.
    final per = minutes <= 30 ? 1 : (minutes / 30).ceil();
    final blocks = (minutes / per).ceil();
    final elapsed = total - remaining;
    final filled = (elapsed.inSeconds / 60 / per).floor().clamp(0, blocks);
    final rows = (blocks / 5).ceil();
    final blockH = small ? 8.0 : (rows <= 5 ? 22.0 : 12.0);
    return Semantics(
      label: _semantics(remaining),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            clockText(remaining),
            style: s
                .timer(small ? 52 : 90, color: s.ink)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(timerCaption(remaining, total, paused), style: s.caption()),
          SizedBox(height: small ? 10 : 24),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  for (var col = 0; col < 5; col++) ...[
                    if (col > 0) const SizedBox(width: 5),
                    Expanded(
                      child: r * 5 + col >= blocks
                          ? const SizedBox.shrink()
                          : Container(
                              height: blockH,
                              decoration: BoxDecoration(
                                color: r * 5 + col < filled
                                    ? s.star
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: r * 5 + col < filled
                                      ? s.star
                                      : s.line2,
                                  width: 2,
                                ),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          if (!small) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                per == 1 ? 'One block a minute' : 'One block per $per minutes',
                style: TextStyle(fontSize: 12, color: s.ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
