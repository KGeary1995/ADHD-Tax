import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import '../settings/settings_controller.dart';
import 'achievements.dart';
import 'progress_controller.dart';
import 'xp_rules.dart';

/// One screen of a celebration.
sealed class _Step {
  const _Step();
}

class _FinishedStep extends _Step {
  const _FinishedStep();
}

class _LevelStep extends _Step {
  const _LevelStep();
}

class _AchievementStep extends _Step {
  const _AchievementStep(this.achievement);
  final Achievement achievement;
}

/// Sits above the whole app and plays queued celebrations. A finish gets
/// "Finished." with its stars, then "Level 7." if it was a level, then a
/// card for each achievement. Starts are celebrated on the focus screen
/// ("A new star."); with celebrations Off, everything is a toast.
class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));
  CelebrationEvent? _current;
  List<_Step> _steps = const [];

  /// False while a start's note waits for its moment.
  bool _shown = false;
  Timer? _toastTimer;
  Timer? _confettiCleanup;
  bool _confettiMounted = false;

  @override
  void dispose() {
    _confetti.dispose();
    _toastTimer?.cancel();
    _confettiCleanup?.cancel();
    super.dispose();
  }

  void _playConfetti() {
    setState(() => _confettiMounted = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    // The package animates until every particle leaves the screen, and its
    // stop() can't clear stragglers. Unmounting disposes its ticker so a
    // stray particle can't keep the app redrawing.
    _confettiCleanup?.cancel();
    _confettiCleanup = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _confettiMounted = false);
    });
  }

  void _showNext(List<CelebrationEvent> queue) {
    if (_current != null || queue.isEmpty) return;
    final e = queue.first;
    final level = ref.read(settingsProvider).celebration;
    // The focus screen celebrates a start itself ("A new star."). An
    // achievement or level earned by starting waits until that moment has
    // passed, then shows as a note.
    if (e.kind == CelebrationKind.started && level != CelebrationLevel.off) {
      if (!e.leveledUp && e.achievements.isEmpty) {
        ref.read(celebrationQueueProvider.notifier).pop();
        return;
      }
      _current = e;
      _steps = const [];
      _toastTimer = Timer(const Duration(milliseconds: 3000), () {
        if (!mounted) return;
        setState(() => _shown = true);
        _toastTimer = Timer(const Duration(seconds: 3), _dismiss);
      });
      return;
    }
    final steps = level == CelebrationLevel.off || !e.isBig
        ? const <_Step>[]
        : [
            if (e.kind == CelebrationKind.completed) const _FinishedStep(),
            if (e.leveledUp) const _LevelStep(),
            for (final a in e.achievements) _AchievementStep(a),
          ];
    setState(() {
      _current = e;
      _steps = steps;
      _shown = true;
    });
    if (steps.isNotEmpty) {
      if (level == CelebrationLevel.party) _playConfetti();
      HapticFeedback.mediumImpact();
    } else {
      _toastTimer = Timer(const Duration(seconds: 3), _dismiss);
    }
  }

  /// On to the next screen of this celebration, or done.
  void _advance() {
    if (_steps.length > 1) {
      setState(() => _steps = _steps.sublist(1));
    } else {
      _dismiss();
    }
  }

  void _dismiss() {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _current = null;
      _steps = const [];
      _shown = false;
    });
    ref.read(celebrationQueueProvider.notifier).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(celebrationQueueProvider, (_, q) {
      // Defer to after the current frame, and make sure one is coming.
      WidgetsBinding.instance
        ..addPostFrameCallback((_) {
          if (!mounted) return;
          final cur = _current;
          // A finish shouldn't wait behind a toast.
          if (cur != null && _steps.isEmpty && q.length > 1) {
            _toastTimer?.cancel();
            _dismiss();
          } else {
            _showNext(ref.read(celebrationQueueProvider));
          }
        })
        ..ensureVisualUpdate();
    });
    final level = ref.watch(settingsProvider).celebration;
    final s = context.spec;
    final e = _current;
    final step = _steps.firstOrNull;
    // Subtle and Reduce Motion: the same screens, without the show.
    final animate = level != CelebrationLevel.subtle && !context.reduceMotion;

    return Stack(
      children: [
        widget.child,
        if (e != null && step != null)
          Positioned.fill(
            child: switch (step) {
              _FinishedStep() => _FullScreen(
                key: ValueKey('finished-${e.eventId}'),
                button: 'Nice',
                onDone: _advance,
                child: _Finished(event: e, animate: animate),
              ),
              _LevelStep() => _FullScreen(
                key: ValueKey('level-${e.eventId}'),
                button: 'Keep going',
                onDone: _advance,
                child: _LevelUp(level: e.levelAfter, animate: animate),
              ),
              _AchievementStep(:final achievement) => _AchievementCard(
                key: ValueKey('a-${achievement.id}'),
                achievement: achievement,
                onDone: _advance,
              ),
            },
          ),
        if (e != null && step == null && _shown)
          Positioned(
            left: 16,
            right: 16,
            bottom: 108,
            child: IgnorePointer(
              child: Center(child: _XpToast(event: e)),
            ),
          ),
        if (_confettiMounted)
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.08,
                numberOfParticles: 40,
                maxBlastForce: 30,
                minBlastForce: 10,
                gravity: 0.25,
                colors: s.confettiColors,
              ),
            ),
          ),
      ],
    );
  }
}

/// "+10 XP · Done: Laundry": a passing note in inverse colours.
class _XpToast extends StatelessWidget {
  const _XpToast({required this.event});
  final CelebrationEvent event;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final label = switch (event.kind) {
      CelebrationKind.started => 'Started. That was the hard part.',
      CelebrationKind.partial => 'Progress counts.',
      CelebrationKind.completed => 'Done: ${event.taskTitle}',
    };
    final extras = [
      if (event.leveledUp)
        'Level ${event.levelAfter} · ${rankForLevel(event.levelAfter)}',
      for (final a in event.achievements) '${a.icon} ${a.title}',
    ];
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: s.toastBg,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '+${event.award.total} XP',
                    style: TextStyle(
                      color: s.toastAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: ' · $label'),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: s.toastInk,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final x in extras)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  x,
                  style: TextStyle(
                    color: s.toastInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A celebration that takes the screen: the sky, the content in the
/// middle, one button at the bottom.
class _FullScreen extends StatelessWidget {
  const _FullScreen({
    super.key,
    required this.child,
    required this.button,
    required this.onDone,
  });
  final Widget child;
  final String button;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SkyBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.sizeOf(context).height * 0.6,
                        ),
                        child: Center(child: child),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.s6),
                  PrimaryButton(label: button, height: 58, onPressed: onDone),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Finished.": five stars light up one after another into this week's
/// shape, then what you earned.
class _Finished extends StatefulWidget {
  const _Finished({required this.event, required this.animate});
  final CelebrationEvent event;
  final bool animate;

  @override
  State<_Finished> createState() => _FinishedState();
}

class _FinishedState extends State<_Finished>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final e = widget.event;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final ms = _c.value * 1800;
        final text = Curves.easeOut.transform(((ms - 1100) / 500).clamp(0, 1));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: 245,
                height: 120,
                child: CustomPaint(
                  painter: _MiniSkyPainter(
                    ms: ms,
                    star: s.star,
                    glow: s.glow,
                    line: s.star.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.s8),
            Opacity(
              opacity: text,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Finished.',
                    textAlign: TextAlign.center,
                    style: s.display(40),
                  ),
                  const SizedBox(height: Gap.s3),
                  Text(
                    e.taskTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: s.ink2),
                  ),
                  const SizedBox(height: Gap.s8),
                  Panel(
                    color: Colors.transparent,
                    borderColor: s.line2,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        for (final l in e.award.lines)
                          _AwardRow(label: l.label, value: '+${l.amount}'),
                        _AwardRow(
                          label: 'Total',
                          value:
                              '+${e.award.total} XP · +${e.award.coins} coins',
                          total: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.s6),
                  Text(
                    "This week's constellation just got a new star.",
                    textAlign: TextAlign.center,
                    style: s.caption(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({
    required this.label,
    required this.value,
    this.total = false,
  });
  final String label;
  final String value;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final weight = total ? FontWeight.w800 : FontWeight.w600;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        border: total ? null : Border(bottom: BorderSide(color: s.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: weight, color: s.ink),
            ),
          ),
          const SizedBox(width: Gap.s4),
          Text(
            value,
            style: s
                .mono(14, color: total ? s.accentText : s.ink2)
                .copyWith(fontWeight: weight),
          ),
        ],
      ),
    );
  }
}

class _MiniSkyPainter extends CustomPainter {
  _MiniSkyPainter({
    required this.ms,
    required this.star,
    required this.glow,
    required this.line,
  });
  final double ms;
  final Color star;
  final Color glow;
  final Color line;

  static const _points = [
    Offset(20, 90),
    Offset(70, 40),
    Offset(120, 70),
    Offset(170, 30),
    Offset(225, 95),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    double lit(int i) {
      final at = i == _points.length - 1 ? 900.0 : 100.0 * i;
      return Curves.easeOutBack.transform(((ms - at) / 500).clamp(0.0, 1.0));
    }

    final lines = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var i = 1; i < _points.length; i++) {
      final l = math.min(lit(i - 1), lit(i)).clamp(0.0, 1.0);
      if (l <= 0) continue;
      canvas.drawLine(
        _points[i - 1],
        Offset.lerp(_points[i - 1], _points[i], l)!,
        lines,
      );
    }
    for (var i = 0; i < _points.length; i++) {
      final l = lit(i);
      if (l <= 0) continue;
      final last = i == _points.length - 1;
      final r = (last ? 8.0 : 3.0) * l;
      canvas
        ..drawCircle(
          _points[i],
          r * 2.4,
          Paint()
            ..color = glow
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, last ? 12 : 4),
        )
        ..drawCircle(
          _points[i],
          r,
          Paint()..color = last ? const Color(0xFFFFE2A0) : star,
        );
    }
  }

  @override
  bool shouldRepaint(_MiniSkyPainter old) => old.ms != ms || old.star != star;
}

/// "7 · LEVEL UP · Level 7.": bursts and a ring around the new number.
class _LevelUp extends StatefulWidget {
  const _LevelUp({required this.level, required this.animate});
  final int level;
  final bool animate;

  @override
  State<_LevelUp> createState() => _LevelUpState();
}

class _LevelUpState extends State<_LevelUp>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final ms = _c.value * 2000;
        final pop = ((ms) / 700).clamp(0.0, 1.0);
        final scale = pop < 0.6
            ? 0.6 + 0.46 * Curves.easeOut.transform(pop / 0.6)
            : 1.06 - 0.06 * ((pop - 0.6) / 0.4);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 320,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.animate)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BurstPainter(ms: ms, color: s.star),
                      ),
                    ),
                  Opacity(
                    opacity: pop.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: widget.animate ? scale : 1,
                      child: Text(
                        '${widget.level}',
                        style: TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 120,
                          fontWeight: FontWeight.w300,
                          height: 1,
                          letterSpacing: -6,
                          color: s.star,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.s7),
            Text('LEVEL UP', style: s.overline(color: s.accentText)),
            const SizedBox(height: Gap.s4),
            Text(
              'Level ${widget.level}.',
              textAlign: TextAlign.center,
              style: s.display(34),
            ),
            const SizedBox(height: Gap.s4),
            Text(
              "You're a ${rankForLevel(widget.level)} now. Today's "
              'forecast: a 100% chance of getting one thing done. Called it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.45, color: s.ink2),
            ),
          ],
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.ms, required this.color});
  final double ms;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // A ring opening out over 1.8 s.
    final ring = (ms / 1800).clamp(0.0, 1.0);
    if (ring < 1) {
      canvas.drawCircle(
        c,
        30 + 120 * Curves.easeOut.transform(ring),
        Paint()
          ..color = color.withValues(alpha: 0.6 * (1 - ring))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    // 14 bursts flying out over 1.4 s.
    for (var i = 0; i < 14; i++) {
      final delay = 200 + (i % 3) * 80;
      final p = ((ms - delay) / 1400).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final e = Curves.easeOut.transform(p);
      final a = i / 14 * 2 * math.pi;
      final o = p < 0.25 ? p / 0.25 : 1 - (p - 0.25) / 0.75;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * 150 * e,
        (i % 3 == 0 ? 3.5 : 2) * (0.3 + 0.7 * e),
        Paint()..color = color.withValues(alpha: o),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.ms != ms;
}

/// "Achievement unlocked": a card over the page.
class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    super.key,
    required this.achievement,
    required this.onDone,
  });
  final Achievement achievement;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Material(
      color: s.scrim,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(22),
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              color: s.sheet,
              borderRadius: BorderRadius.circular(Radii.xl),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.star,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: s.glow, blurRadius: 22)],
                      ),
                      child: Text(
                        achievement.icon,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.s7),
                  Text(
                    'ACHIEVEMENT UNLOCKED',
                    textAlign: TextAlign.center,
                    style: s.overline(color: s.accentText),
                  ),
                  const SizedBox(height: Gap.s3),
                  Text(
                    achievement.title,
                    textAlign: TextAlign.center,
                    style: s.display(26),
                  ),
                  const SizedBox(height: Gap.s3),
                  Text(
                    achievement.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4, color: s.ink2),
                  ),
                  const SizedBox(height: Gap.s7),
                  PrimaryButton(label: 'Nice', onPressed: onDone),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
