import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';

/// A thick ring that empties as time runs out, with the time in the
/// middle. Makes remaining time visible at a glance (time blindness).
class VisualTimer extends StatelessWidget {
  const VisualTimer({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 290,
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
    final caption = paused
        ? 'paused'
        : over
        ? 'over time. Finish up'
        : 'left of ${total.inMinutes} min';

    return Semantics(
      label: over
          ? '${shown.inMinutes} minutes over time'
          : '${shown.inMinutes} minutes ${shown.inSeconds % 60} seconds left',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: fraction,
            color: over ? s.warning : s.accent,
            track: s.isDark ? const Color(0xFF1C2326) : s.track,
            stroke: size * 0.055,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${over ? '+' : ''}$mm:$ss',
                      style: s
                          .mono(
                            size * 0.207,
                            color: s.onSurface,
                            weight: FontWeight.w500,
                          )
                          .copyWith(letterSpacing: -size * 0.007),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: TextStyle(color: s.muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2 - 1;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
