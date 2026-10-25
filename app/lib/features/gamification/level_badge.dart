import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import 'progress_controller.dart';
import 'xp_rules.dart';
import '../../core/theme/ph.dart';

/// "✦ Level 6 · 13 days": level and streak. Opens Progress. [compact]
/// leaves out the streak.
class LevelPill extends ConsumerWidget {
  const LevelPill({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final p = ref.watch(progressProvider);
    final now = ref.read(clockProvider)();
    final streak = streakWithGrace(p.activeDays, now);
    return Semantics(
      label:
          'Level ${p.level}${streak > 0 ? ', $streak-day streak' : ''}. '
          'Open progress',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => context.go('/progress'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Ph.starFourFill, size: 13, color: s.star),
                const SizedBox(width: Gap.s3),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: 'Level ${p.level}',
                      children: [
                        if (streak > 0 && !compact) ...[
                          TextSpan(
                            text: ' · ',
                            style: TextStyle(color: s.ink3),
                          ),
                          TextSpan(
                            text: '$streak ${streak == 1 ? 'day' : 'days'}',
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: s.button(14, s.ink2),
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
