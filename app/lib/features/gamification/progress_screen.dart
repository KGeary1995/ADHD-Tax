import 'dart:math' as math;

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
import 'constellation.dart';
import 'progress_controller.dart';
import '../settings/settings_button.dart';
import 'reward_shop.dart';
import 'xp_rules.dart';
import '../../core/theme/ph.dart';

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
      ('${p.started}', 'Started'),
      ('${p.completed}', 'Finished'),
      (shortMinutes(p.focusMinutes), 'Focused'),
      ('$streak', 'Day streak'),
      ('${p.ughCompleted}', 'Dreaded, done'),
      ('${p.coins}', 'Coins'),
    ];
    final sorted = [
      ...achievements.where((a) => p.unlocked.containsKey(a.id)),
      ...achievements.where((a) => !p.unlocked.containsKey(a.id)),
    ];

    Widget heading(String text, [String? note]) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(text, style: s.display(19))),
        if (note != null) Text(note, style: s.caption(color: s.ink2)),
      ],
    );

    final levelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Level $level ',
                  children: [
                    TextSpan(
                      text: rankForLevel(level),
                      style: s.display(
                        15,
                        weight: FontWeight.w500,
                        color: s.ink2,
                      ),
                    ),
                  ],
                ),
                style: s.display(26),
              ),
            ),
            Text('$toNext XP to go', style: s.caption(color: s.ink2)),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'XP to the next level',
          value: '${(levelProgress(p.xp) * 100).round()}%',
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: levelProgress(p.xp)),
            duration: Duration(milliseconds: motion),
            builder: (_, v, _) => Row(
              children: [
                Expanded(
                  flex: math.max(1, (v * 1000).round()),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.star,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: math.max(1, ((1 - v) * 1000).round()),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: s.line2, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.s8),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 12.0;
            final w = (c.maxWidth - 2 * gap) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: Gap.s7,
              children: [
                for (final (value, label) in stats)
                  SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(value, maxLines: 1, style: s.stat()),
                        ),
                        const SizedBox(height: Gap.s3),
                        Text(
                          label,
                          style: TextStyle(fontSize: 12, color: s.ink2),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Gap.s5),
        Text(
          '2 grace days a week. Streaks never fall back to zero.',
          style: s.caption(),
        ),
      ],
    );

    final achievementGrid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Achievements',
          '${p.unlocked.length} of ${achievements.length}',
        ),
        const SizedBox(height: Gap.s6),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 520 ? 6 : 4;
            const gap = 10.0;
            final w = (c.maxWidth - (cols - 1) * gap) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: Gap.s6,
              children: [
                for (final a in sorted)
                  SizedBox(
                    width: w,
                    child: _AchievementTile(
                      achievement: a,
                      unlocked: p.unlocked.containsKey(a.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );

    final recentXp = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Recent XP'),
        const SizedBox(height: Gap.s4),
        for (final (i, r) in p.recent.take(15).indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: i == math.min(14, p.recent.length - 1)
                  ? null
                  : Border(bottom: BorderSide(color: s.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: r.label,
                      children: [
                        TextSpan(
                          text: '  ${_ago(r.at, now)}',
                          style: TextStyle(color: s.ink3),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: s.ink,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.s4),
                Text(
                  '+${r.amount}',
                  style: s
                      .mono(15, color: s.accentText)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        final top = MediaQuery.paddingOf(context).top;
        final side = wide ? 36.0 : Gap.listSide;
        // Your sky: always night, edge to edge, under the status bar.
        final hero = Theme(
          data: buildTheme(nightSpec),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0A0F1F),
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF17203F), Color(0xFF0A0F1F)],
                stops: [0, 0.7],
              ),
            ),
            padding: EdgeInsets.fromLTRB(side, top + 18, side, 26),
            child: ContentWidth(
              maxWidth: 1120,
              child: Builder(
                builder: (context) => Constellation(
                  startsByDay: p.startsByDay,
                  now: now,
                  trailing: hasSettingsButton(context)
                      ? const SettingsButton()
                      : null,
                ),
              ),
            ),
          ),
        );
        final body = wide
            ? ResponsiveColumns(
                sideWidth: 400,
                gap: 48,
                main: [
                  levelBlock,
                  const SizedBox(height: Gap.s9),
                  achievementGrid,
                  if (p.recent.isNotEmpty) ...[
                    const SizedBox(height: Gap.s9),
                    recentXp,
                  ],
                ],
                side: const [
                  RewardShop(),
                  SizedBox(height: Gap.s9),
                  _EstimatesCard(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  levelBlock,
                  const SizedBox(height: Gap.s9),
                  const RewardShop(),
                  const SizedBox(height: Gap.s9),
                  const _EstimatesCard(),
                  const SizedBox(height: Gap.s9),
                  achievementGrid,
                  if (p.recent.isNotEmpty) ...[
                    const SizedBox(height: Gap.s9),
                    recentXp,
                  ],
                ],
              );
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: ListView(
            padding: EdgeInsets.only(bottom: navClearance(context)),
            children: [
              hero,
              Padding(
                padding: EdgeInsets.fromLTRB(side, Gap.s8, side, 0),
                child: ContentWidth(maxWidth: 1120, child: body),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// An achievement: a gold tile when earned, a dashed lock when not. Tap
/// for what it's for.
class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});
  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Semantics(
      button: true,
      label:
          '${achievement.title}. ${unlocked ? 'Unlocked' : 'Locked'}. '
          '${achievement.description}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => ConfirmDialog(
            title: achievement.title,
            body: achievement.description,
            cancel: unlocked ? 'Unlocked' : 'Not yet',
            confirm: 'OK',
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: unlocked
                  ? BoxDecoration(
                      color: s.star,
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              child: unlocked
                  ? Text(achievement.icon, style: const TextStyle(fontSize: 26))
                  : CustomPaint(
                      painter: _DashedSquare(s.line2),
                      child: SizedBox.square(
                        dimension: 56,
                        child: Icon(Ph.lock, size: 22, color: s.ink3),
                      ),
                    ),
            ),
            const SizedBox(height: Gap.s3),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: unlocked ? s.ink : s.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedSquare extends CustomPainter {
  _DashedSquare(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(16),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSquare old) => old.color != color;
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
          'timer and Gumption learns how long things really take you, then '
          'picks tasks that truly fit your time.';
    } else {
      body =
          'From your last ${c.overall.samples} timed tasks. The pick uses '
          'this to fit your time.';
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
      color: Colors.transparent,
      borderColor: s.line2,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How long things really take',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: s.ink2,
            ),
          ),
          if (c.overall.samples >= Calibration.minSamples) ...[
            const SizedBox(height: Gap.s3),
            Text(_capital(line(c.overall)), style: s.display(22)),
            for (final (label, text) in rows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('$label: $text', style: s.mono(13, color: s.text2)),
              ),
          ],
          const SizedBox(height: Gap.s1),
          Text(body, style: s.caption()),
        ],
      ),
    );
  }
}

String _capital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
