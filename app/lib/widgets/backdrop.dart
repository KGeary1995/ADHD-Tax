import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_themes.dart';

/// Paints the theme's background (gradient, synthwave grid, scanlines).
class ThemedBackdrop extends StatelessWidget {
  const ThemedBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final end = s.backgroundEnd;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.background,
        gradient: end == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [s.background, end],
              ),
      ),
      child: switch (s.backdrop) {
        BackdropStyle.grid => CustomPaint(
          painter: _GridPainter(s.primary, s.secondary),
          child: child,
        ),
        BackdropStyle.scanlines => CustomPaint(
          foregroundPainter: _ScanlinePainter(s.primary),
          child: child,
        ),
        _ => child,
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.a, this.b);
  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.62;
    final paint = Paint()
      ..strokeWidth = 1
      ..color = a.withValues(alpha: 0.10);
    // Perspective floor lines converging on the horizon.
    final cx = size.width / 2;
    for (var i = -12; i <= 12; i++) {
      canvas.drawLine(
        Offset(cx + i * 18, horizon),
        Offset(cx + i * size.width / 6, size.height),
        paint,
      );
    }
    var y = horizon;
    var step = 6.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += step;
      step *= 1.25;
    }
    // Horizon glow.
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          b.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, horizon - 80, size.width, 160));
    canvas.drawRect(Rect.fromLTWH(0, horizon - 80, size.width, 160), glow);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.a != a || old.b != b;
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter(this.c);
  final Color c;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = c.withValues(alpha: 0.025);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => old.c != c;
}

/// The app's card surface: plain, neon-glow, or frosted glass per theme.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlight = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Accent border/glow, for the hero card.
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final radius = BorderRadius.circular(s.radius);
    final borderColor = highlight
        ? s.primary.withValues(alpha: 0.7)
        : s.muted.withValues(alpha: s.glass ? 0.25 : 0.15);
    final decoration = BoxDecoration(
      color: s.surface,
      borderRadius: radius,
      border: Border.all(color: borderColor, width: highlight ? 1.5 : 1),
      boxShadow: [
        if (s.glow && highlight)
          BoxShadow(
            color: s.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        if (!s.glow && s.brightness == Brightness.light)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
      ],
    );

    Widget content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (s.glass) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(decoration: decoration, child: content),
        ),
      );
      return content;
    }
    return DecoratedBox(decoration: decoration, child: content);
  }
}
