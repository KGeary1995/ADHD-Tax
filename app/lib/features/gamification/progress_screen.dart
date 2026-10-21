import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../../data/models/task.dart';
import '../insights/estimate_calibration.dart';
import '../picker/picker_controller.dart';
import 'achievements.dart';
import 'progress_controller.dart';
import 'reward_shop.dart';
import 'xp_rules.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final p = ref.watch(progressProvider);
    final now = ref.read(clockProvider)();
    final streak = streakWithGrace(p.activeDays, now);
    final level = p.level;
    final toNext = xpForLevel(level + 1) - p.xp;
    final motion = context.reduceMotion ? 0 : 800;

    final stats = [
      ('${p.started}', 'Tasks started'),
      ('${p.completed}', 'Finished'),
      (shortMinutes(p.focusMinutes), 'Focused'),
      (streak == 1 ? '1 day' : '$streak days', 'Streak'),
      ('${p.ughCompleted}', 'Dreaded ones done'),
      ('${p.coins}', 'Coins'),
    ];
    final sorted = [
      ...achievements.where((a) => p.unlocked.containsKey(a.id)),
      ...achievements.where((a) => !p.unlocked.containsKey(a.id)),
    ];

    final levelPanel = Panel(
      radius: 26,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text('Level $level', style: s.display(44))),
              Text(
                rankForLevel(level),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: s.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label: 'XP to the next level',
            value: '${(levelProgress(p.xp) * 100).round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: levelProgress(p.xp)),
                duration: Duration(milliseconds: motion),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text('${p.xp} XP', style: s.mono(13)),
              Text('$toNext to level ${level + 1}', style: s.mono(13)),
            ],
          ),
        ],
      ),
    );
    final statBlock = Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth > 520 ? 3 : 2;
          final w = (c.maxWidth - (cols - 1) * 20) / cols;
          return Wrap(
            spacing: 20,
            children: [
              for (final (value, label) in stats)
                Container(
                  width: w,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: s.hairline)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: s.display(30, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(fontSize: 14, color: s.muted),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
    final streakNote = Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Text(
        'Streaks have 2 grace days a week. Missing a day never sends '
        'you back to zero.',
        style: TextStyle(color: s.muted, fontSize: 13, height: 1.4),
      ),
    );
    final achievementList = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: 'Achievements',
              children: [
                TextSpan(
                  text: '  ${p.unlocked.length} of ${achievements.length}',
                  style: TextStyle(color: s.faint, fontWeight: FontWeight.w400),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: s.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          // Two columns when there's room, so the list isn't a long scroll.
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 600 ? 2 : 1;
              final w = (c.maxWidth - (cols - 1) * 24) / cols;
              final lastRow = (sorted.length - 1) ~/ cols;
              return Wrap(
                spacing: 24,
                children: [
                  for (final (i, a) in sorted.indexed)
                    SizedBox(
                      width: w,
                      child: _AchievementRow(
                        achievement: a,
                        unlocked: p.unlocked.containsKey(a.id),
                        last: i ~/ cols == lastRow,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
    final recentXp = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Recent XP'),
          for (final r in p.recent.take(15))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: s.hairline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: s.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _ago(r.at, now),
                          style: TextStyle(fontSize: 13, color: s.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${r.amount}',
                    style: s.mono(
                      15,
                      color: s.primary,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    const header = Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: PageHeader('Progress'),
    );

    return LayoutBuilder(
      builder: (context, c) {
        // A computer: where you stand on the left, what to spend and
        // what you've earned lately on the right.
        if (c.maxWidth >= 1000) {
          return ContentWidth(
            maxWidth: 1180,
            child: ListView(
              padding: EdgeInsets.fromLTRB(22, 28, 22, navClearance(context)),
              children: [
                header,
                const SizedBox(height: 22),
                ResponsiveColumns(
                  sideWidth: 400,
                  main: [
                    levelPanel,
                    statBlock,
                    streakNote,
                    const SizedBox(height: 26),
                    achievementList,
                  ],
                  side: [
                    const RewardShop(),
                    const SizedBox(height: 16),
                    const _EstimatesCard(),
                    if (p.recent.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      recentXp,
                    ],
                  ],
                ),
              ],
            ),
          );
        }
        return ContentWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(14, 24, 14, navClearance(context)),
            children: [
              header,
              const SizedBox(height: 22),
              levelPanel,
              statBlock,
              streakNote,
              const SizedBox(height: 22),
              const RewardShop(),
              const SizedBox(height: 16),
              const _EstimatesCard(),
              const SizedBox(height: 26),
              achievementList,
              if (p.recent.isNotEmpty) ...[
                const SizedBox(height: 26),
                recentXp,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.achievement,
    required this.unlocked,
    required this.last,
  });
  final Achievement achievement;
  final bool unlocked;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: s.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: unlocked
                ? BoxDecoration(color: s.accent, shape: BoxShape.circle)
                : BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: s.outline, width: 1.5),
                  ),
            child: unlocked
                ? Text(achievement.icon, style: const TextStyle(fontSize: 20))
                : Icon(Icons.lock_outline_rounded, size: 18, color: s.faint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: unlocked ? s.onSurface : s.text2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: unlocked ? s.muted : s.faint,
                  ),
                ),
              ],
            ),
          ),
        ],
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

/// "Tasks take you about 1.4× your guess": what the picker has learned.
class _EstimatesCard extends ConsumerWidget {
  const _EstimatesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final c = ref.watch(calibrationProvider);
    String line(Calibration k) {
      if (!k.meaningful) return 'about what you guess';
      return k.factor > 1
          ? 'about ${k.factor.toStringAsFixed(1)}× your guess'
          : 'about ${(k.factor * 100).round()}% of your guess';
    }

    final String body;
    final rows = <(String, String)>[];
    if (c.overall.samples < Calibration.minSamples) {
      final left = Calibration.minSamples - c.overall.samples;
      body =
          'Finish $left more ${left == 1 ? 'task' : 'tasks'} with the focus '
          'timer and Unstuck learns how long things really take you, then '
          'picks tasks that truly fit your time.';
    } else {
      body =
          'From your last ${c.overall.samples} timed tasks. The picker uses '
          'this to fit tasks to your time.';
      for (final w in Workspace.values) {
        final k = c.byWorkspace[w];
        if (k != null && k.samples >= Calibration.minSamples) {
          rows.add((w.label, line(k)));
        }
      }
      // One workspace alone just repeats the headline.
      if (rows.length < 2) rows.clear();
    }
    return Panel(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How long things really take',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: s.onSurface,
            ),
          ),
          if (c.overall.samples >= Calibration.minSamples) ...[
            const SizedBox(height: 10),
            Text(
              'Tasks take you ${line(c.overall)}',
              style: s.display(24, weight: FontWeight.w600),
            ),
            for (final (label, text) in rows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('$label: $text', style: s.mono(13, color: s.text2)),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(fontSize: 13, color: s.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
