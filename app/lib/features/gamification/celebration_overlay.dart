import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/backdrop.dart';
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
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Panel(
          highlight: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${event.award.total} XP',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: s.primary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(color: s.onSurface, fontSize: 14),
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
                      color: s.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
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
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 440),
          child: Panel(
            highlight: true,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.leveledUp ? '🆙' : '🎉',
                  style: const TextStyle(fontSize: 52),
                ),
                const SizedBox(height: 8),
                Text(
                  event.leveledUp
                      ? 'Level ${event.levelAfter}! ${rankForLevel(event.levelAfter)}'
                      : cheer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: s.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.taskTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: s.muted),
                ),
                const SizedBox(height: 18),
                for (final l in event.award.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.label,
                            style: TextStyle(color: s.onSurface),
                          ),
                        ),
                        Text(
                          '+${l.amount}',
                          style: TextStyle(
                            color: s.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(
                          color: s.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '+${event.award.total} XP · +${event.award.coins} 🪙',
                      style: TextStyle(
                        color: s.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                for (final a in event.achievements) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: s.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(s.radius),
                    ),
                    child: Row(
                      children: [
                        Text(a.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Achievement: ${a.title}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: s.onSurface,
                                ),
                              ),
                              Text(
                                a.description,
                                style: TextStyle(color: s.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const QuoteRotator(
                  context: QuoteContext.celebration,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onClose,
                    child: const Text('Keep the streak going'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
