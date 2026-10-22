import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import 'progress_controller.dart';
import 'xp_rules.dart';

/// "LV 4 · 6 DAYS": level and streak in one outlined pill. Opens Progress.
class LevelPill extends ConsumerWidget {
  const LevelPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final p = ref.watch(progressProvider);
    final now = ref.read(clockProvider)();
    final streak = streakWithGrace(p.activeDays, now);
    final text = streak > 0
        ? 'LV ${p.level} · $streak ${streak == 1 ? 'DAY' : 'DAYS'}'
        : 'LV ${p.level}';
    return Semantics(
      label:
          'Level ${p.level}${streak > 0 ? ', $streak-day streak' : ''}. '
          'Open progress',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: s.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => context.go('/progress'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: s.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: s.mono(13, color: s.text2, weight: FontWeight.w500),
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
