import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';

/// "A new star.": the moment you press Start. The star ignites, two rings
/// spread from it, and the words rise. Focus follows by itself.
class StartedView extends StatefulWidget {
  const StartedView({
    super.key,
    required this.xp,
    required this.next,
    this.rings = true,
  });

  /// XP for starting.
  final int xp;

  /// The step you're about to do.
  final String next;

  /// Off for the Subtle celebration level.
  final bool rings;

  @override
  State<StartedView> createState() => _StartedViewState();
}

class _StartedViewState extends State<StartedView>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0..1 progress of a part that starts at [startMs] and lasts [ms].
  double _part(int startMs, int ms) =>
      ((_c.value * 2200 - startMs) / ms).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Ignite: 0 → 1.35 → 1 over 900 ms.
        final ig = _part(0, 900);
        final scale = ig < 0.4
            ? Curves.easeOut.transform(ig / 0.4) * 1.35
            : 1.35 - 0.35 * Curves.easeInOut.transform((ig - 0.4) / 0.6);
        final starOpacity = (ig / 0.4).clamp(0.0, 1.0);
        Widget ring(int startMs, double width) {
          final p = Curves.easeOut.transform(_part(startMs, 1600));
          if (p <= 0 || p >= 1) return const SizedBox.shrink();
          return Transform.scale(
            scale: 0.2 + 3.0 * p,
            child: Opacity(
              opacity: 0.9 * (1 - p),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: s.star, width: width),
                ),
              ),
            ),
          );
        }

        Widget rise(int startMs, Widget child) {
          final p = Curves.easeOut.transform(_part(startMs, 700));
          return Opacity(
            opacity: p,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - p)),
              child: child,
            ),
          );
        }

        return Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.s8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (widget.rings) ...[ring(200, 1.5), ring(550, 1)],
                          Opacity(
                            opacity: starOpacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: s.star,
                                  boxShadow: [
                                    BoxShadow(
                                      color: s.glow,
                                      blurRadius: 40,
                                      spreadRadius: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.s5),
                    rise(
                      500,
                      Text(
                        'A new star.',
                        textAlign: TextAlign.center,
                        style: s.display(40),
                      ),
                    ),
                    const SizedBox(height: Gap.s1),
                    rise(
                      700,
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '+${widget.xp} XP',
                              style: TextStyle(
                                color: s.accentText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(
                              text: ' · Starting was the hard part.',
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: s.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.next.isNotEmpty)
              Positioned(
                left: 30,
                right: 30,
                bottom: 100,
                child: rise(
                  950,
                  Text(
                    'Next: ${widget.next}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: s.ink3),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
