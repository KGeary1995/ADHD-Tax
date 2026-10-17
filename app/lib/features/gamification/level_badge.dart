import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import 'progress_controller.dart';
import 'xp_rules.dart';

/// Level, rank, XP bar and streak — the always-visible progress summary.
class LevelBadge extends ConsumerWidget {
  const LevelBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final p = ref.watch(progressProvider);
    final now = ref.read(clockProvider)();
    final level = p.level;
    final streak = streakWithGrace(p.activeDays, now);
    final toNext = xpForLevel(level + 1) - p.xp;

    final ring = SizedBox(
      width: compact ? 40 : 56,
      height: compact ? 40 : 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: levelProgress(p.xp)),
            duration: Duration(milliseconds: s.reduceMotion ? 0 : 800),
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: compact ? 4 : 5,
              backgroundColor: s.muted.withValues(alpha: 0.2),
              color: s.primary,
            ),
          ),
          Text(
            '$level',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 15 : 20,
              color: s.onSurface,
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return Tooltip(
        message: 'Level $level ${rankForLevel(level)} · $toNext XP to next',
        child: ring,
      );
    }

    return Row(
      children: [
        ring,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Level $level · ${rankForLevel(level)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: s.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${p.xp} XP · $toNext to next level',
                style: TextStyle(color: s.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        _Stat(icon: '🔥', value: '$streak', label: 'streak'),
        const SizedBox(width: 12),
        _Stat(icon: '🪙', value: '${p.coins}', label: 'coins'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Column(
      children: [
        Text(
          '$icon $value',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: s.onSurface,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: s.muted)),
      ],
    );
  }
}
