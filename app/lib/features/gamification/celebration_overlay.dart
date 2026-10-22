import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import '../motivation/quote_rotator.dart';
import '../motivation/quote_service.dart';
import '../settings/settings_controller.dart';
import 'progress_controller.dart';
import 'xp_rules.dart';

const _cheers = [
  'You did the thing!',
  'Task: obliterated.',
  'Look at you go.',
  'That one is DONE.',
  'Brain: 0. You: 1.',
  'Another one bites the dust.',
  'Future you says thanks.',
];

/// Sits above the whole app and plays queued celebrations: a toast for
/// starts, a card with confetti for finishes, level-ups and achievements.
class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));
  CelebrationEvent? _current;
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
    setState(() => _current = e);
    if (e.isBig) {
      if (level.index >= CelebrationLevel.normal.index) _playConfetti();
      if (level != CelebrationLevel.off) HapticFeedback.mediumImpact();
      if (level == CelebrationLevel.off) {
        _toastTimer = Timer(const Duration(seconds: 3), _dismiss);
      }
    } else {
      _toastTimer = Timer(const Duration(milliseconds: 2600), _dismiss);
    }
  }

  void _dismiss() {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() => _current = null);
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
          // A finish shouldn't wait behind a "you started" toast.
          if (cur != null && !cur.isBig && q.length > 1) {
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
    final showCard = e != null && e.isBig && level != CelebrationLevel.off;
    final showToast = e != null && !showCard;

    return Stack(
      children: [
        widget.child,
        if (showCard)
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismiss,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: _CelebrationCard(event: e, onClose: _dismiss),
                ),
              ),
            ),
          ),
        if (showToast)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 0,
            right: 0,
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
                emissionFrequency: level == CelebrationLevel.party
                    ? 0.08
                    : 0.04,
                numberOfParticles: level == CelebrationLevel.party ? 40 : 18,
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

class _XpToast extends StatelessWidget {
  const _XpToast({required this.event});
  final CelebrationEvent event;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final label = switch (event.kind) {
      CelebrationKind.started => 'Started! That was the hard part.',
      CelebrationKind.partial => 'Progress counts.',
      CelebrationKind.completed => 'Done!',
    };
    final extras = [
      if (event.leveledUp)
        'Level ${event.levelAfter} · ${rankForLevel(event.levelAfter)}',
      for (final a in event.achievements) '${a.icon} ${a.title}',
    ];
    // Inverted, like a snackbar: reads as a passing note, not a card.
    final bg = s.isDark ? const Color(0xFFF2F5F4) : s.ink;
    final fg = s.isDark ? s.background : s.onInk;
    final xp = s.isDark ? const Color(0xFF0B7563) : s.accent;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${event.award.total} XP',
                  style: s.mono(16, color: xp, weight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            for (final x in extras)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  x,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
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

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.event, required this.onClose});
  final CelebrationEvent event;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final cheer = event.kind == CelebrationKind.completed
        ? _cheers[event.taskTitle.hashCode.abs() % _cheers.length]
        : 'Progress is progress.';
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {}, // Don't dismiss when tapping the card itself.
        child: Container(
          margin: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 440),
          child: Panel(
            radius: 30,
            color: s.isDark ? s.surface : s.background,
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The teal header carries the number: what you earned.
                  Container(
                    color: s.accent,
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.leveledUp
                              ? 'Level ${event.levelAfter} · '
                                    '${rankForLevel(event.levelAfter)}'
                              : '+${event.award.total} XP',
                          style: s.mono(
                            14,
                            color: s.onAccentMuted,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          event.leveledUp
                              ? 'Level ${event.levelAfter}!'
                              : cheer,
                          style: s.display(32, color: s.onAccent),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.taskTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: s.onAccentMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final l in event.award.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: s.text2,
                                    ),
                                  ),
                                ),
                                Text(
                                  '+${l.amount}',
                                  style: s.mono(15, color: s.onSurface),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: s.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '+${event.award.total} XP · '
                              '+${event.award.coins} coins',
                              style: s.mono(
                                15,
                                color: s.primary,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        for (final a in event.achievements) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: s.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  a.icon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Achievement: ${a.title}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: s.onSurface,
                                      ),
                                    ),
                                    Text(
                                      a.description,
                                      style: TextStyle(
                                        color: s.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 22),
                        const QuoteRotator(
                          context: QuoteContext.celebration,
                          align: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: onClose,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 56),
                          ),
                          child: const Text('Keep the streak going'),
                        ),
                      ],
                    ),
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
