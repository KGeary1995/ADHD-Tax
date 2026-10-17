import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';

/// Time-Timer style disc: a colored wedge that shrinks as time runs out.
/// Makes remaining time visible at a glance, which helps with time blindness.
class VisualTimer extends StatelessWidget {
  const VisualTimer({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 300,
    this.paused = false,
  });

  final Duration remaining;
  final Duration total;
  final double size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final fraction = total.inMilliseconds == 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final over = remaining.isNegative;
    final shown = over ? -remaining : remaining;
    final mm = shown.inMinutes.toString().padLeft(2, '0');
    final ss = (shown.inSeconds % 60).toString().padLeft(2, '0');

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DiscPainter(
          fraction: fraction,
          wedge: over ? s.warning : s.primary,
          track: s.surfaceAlt,
          tick: s.muted,
          glow: s.glow,
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: s.background.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(s.radius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${over ? '+' : ''}$mm:$ss',
                  style: TextStyle(
                    fontSize: size / 6.5,
                    fontWeight: FontWeight.w800,
                    color: s.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (paused || over)
                  Text(
                    paused ? 'paused' : 'over time — finish up',
                    style: TextStyle(color: s.muted, fontSize: 13),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter({
    required this.fraction,
    required this.wedge,
    required this.track,
    required this.tick,
    required this.glow,
  });

  final double fraction;
  final Color wedge;
  final Color track;
  final Color tick;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = track);

    final rect = Rect.fromCircle(center: c, radius: r * 0.9);
    final sweep = 2 * math.pi * fraction;
    if (glow && fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        true,
        Paint()
          ..color = wedge.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawArc(rect, -math.pi / 2, sweep, true, Paint()..color = wedge);

    // Minute ticks around the rim.
    final tickPaint = Paint()
      ..color = tick.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * r * 0.93, c + dir * r * 0.99, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_DiscPainter old) =>
      old.fraction != fraction || old.wedge != wedge || old.track != track;
}
