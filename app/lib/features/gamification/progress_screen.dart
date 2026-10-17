import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/task_chips.dart';
import 'achievements.dart';
import 'level_badge.dart';
import 'progress_controller.dart';
import 'xp_rules.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final p = ref.watch(progressProvider);
    final now = ref.read(clockProvider)();
    final streak = streakWithGrace(p.activeDays, now);

    final stats = [
      ('Started', '${p.started}', Icons.bolt),
      ('Finished', '${p.completed}', Icons.check_circle_outline),
      ('Frogs eaten', '${p.ughCompleted}', Icons.sentiment_very_dissatisfied),
      ('Focus time', formatMinutes(p.focusMinutes), Icons.timer_outlined),
      ('Day streak', '$streak', Icons.local_fire_department_outlined),
      ('Coins', '${p.coins}', Icons.toll_outlined),
    ];

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          Text(
            'Progress',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: s.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          const Panel(highlight: true, child: LevelBadge()),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 760
                  ? 6
                  : c.maxWidth > 420
                  ? 3
                  : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  for (final (label, value, icon) in stats)
                    Panel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(icon, color: s.secondary, size: 20),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: s.onSurface,
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(color: s.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Streaks include 2 grace days a week. Missing a day never resets you to zero.',
            style: TextStyle(color: s.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          SectionLabel(
            'Achievements · ${p.unlocked.length}/${achievements.length}',
          ),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 760
                  ? 3
                  : c.maxWidth > 480
                  ? 2
                  : 1;
              final width = (c.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final a in achievements)
                    SizedBox(
                      width: width,
                      child: _AchievementTile(
                        achievement: a,
                        unlockedAt: p.unlocked[a.id],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          if (p.recent.isNotEmpty) ...[
            const SectionLabel('Recent XP'),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final r in p.recent.take(15))
                    ListTile(
                      dense: true,
                      title: Text(
                        r.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: s.onSurface),
                      ),
                      subtitle: Text(
                        _ago(r.at, now),
                        style: TextStyle(color: s.muted),
                      ),
                      trailing: Text(
                        '+${r.amount}',
                        style: TextStyle(
                          color: s.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel('Ranks'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < ranks.length; i++)
                InfoChip(
                  icon: p.level >= i * 5 + 1
                      ? Icons.military_tech
                      : Icons.lock_outline,
                  label: '${ranks[i]} · Lv ${i * 5 + 1}',
                  color: p.level >= i * 5 + 1 ? s.primary : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, this.unlockedAt});
  final Achievement achievement;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final unlocked = unlockedAt != null;
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Panel(
        highlight: unlocked,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(
              unlocked ? achievement.icon : '🔒',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: s.onSurface,
                    ),
                  ),
                  Text(
                    achievement.description,
                    style: TextStyle(color: s.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ago(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
