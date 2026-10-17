/// Achievement definitions and the stats they are evaluated against. Pure Dart.
library;

import 'progress_stats.dart';
import 'xp_rules.dart';

export 'progress_stats.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.test,
  });

  final String id;
  final String title;
  final String description;

  /// Emoji, so achievements render the same on every platform and theme.
  final String icon;
  final bool Function(ProgressStats s, AchievementEvent e) test;
}

/// What just happened, so time-of-day achievements only fire on a finish.
class AchievementEvent {
  const AchievementEvent(this.now, {this.justCompleted = false});
  final DateTime now;
  final bool justCompleted;
}

final achievements = <Achievement>[
  Achievement(
    id: 'first_spark',
    title: 'First Spark',
    description: 'Start your first task.',
    icon: '⚡',
    test: (s, _) => s.started >= 1,
  ),
  Achievement(
    id: 'first_win',
    title: 'First Win',
    description: 'Finish your first task.',
    icon: '🏁',
    test: (s, _) => s.completed >= 1,
  ),
  Achievement(
    id: 'frog_curious',
    title: 'Frog Curious',
    description: 'Finish a task you rated "Ugh" or worse.',
    icon: '🐸',
    test: (s, _) => s.ughCompleted >= 1,
  ),
  Achievement(
    id: 'frog_eater',
    title: 'Frog Eater',
    description: 'Finish 10 tasks you were dreading.',
    icon: '👑',
    test: (s, _) => s.ughCompleted >= 10,
  ),
  Achievement(
    id: 'errand_runner',
    title: 'Errand Runner',
    description: 'Finish 3 out-of-the-house tasks in one day.',
    icon: '🚗',
    test: (s, e) => (s.errandsByDay[dayKey(e.now)] ?? 0) >= 3,
  ),
  Achievement(
    id: 'time_lord',
    title: 'Time Lord',
    description: 'Finish 10 tasks within 10% of your estimate.',
    icon: '⏱️',
    test: (s, _) => s.accurateEstimates >= 10,
  ),
  Achievement(
    id: 'archaeologist',
    title: 'Archaeologist',
    description: 'Clear a task that sat for a week or more.',
    icon: '🦴',
    test: (s, _) => s.oldTasksCleared >= 1,
  ),
  Achievement(
    id: 'momentum',
    title: 'Momentum',
    description: 'Commit to "just 5 minutes" and keep going.',
    icon: '🚀',
    test: (s, _) => s.justFiveKeptGoing >= 1,
  ),
  Achievement(
    id: 'brave',
    title: 'Brave Little Toaster',
    description: 'Use the overwhelm button and start anyway.',
    icon: '🫶',
    test: (s, _) => s.panicStarts >= 1,
  ),
  Achievement(
    id: 'deep_work',
    title: 'Deep Work',
    description: 'Log 10 hours of focus time.',
    icon: '🧠',
    test: (s, _) => s.focusMinutes >= 600,
  ),
  Achievement(
    id: 'ten_down',
    title: 'Ten Down',
    description: 'Finish 10 tasks.',
    icon: '🔟',
    test: (s, _) => s.completed >= 10,
  ),
  Achievement(
    id: 'centurion',
    title: 'Centurion',
    description: 'Finish 100 tasks.',
    icon: '💯',
    test: (s, _) => s.completed >= 100,
  ),
  Achievement(
    id: 'streak_7',
    title: 'Week Warrior',
    description: 'Keep a 7-day streak (grace days included).',
    icon: '🔥',
    test: (s, e) => streakWithGrace(s.activeDays, e.now) >= 7,
  ),
  Achievement(
    id: 'streak_30',
    title: 'Unstoppable',
    description: 'Keep a 30-day streak.',
    icon: '🌋',
    test: (s, e) => streakWithGrace(s.activeDays, e.now) >= 30,
  ),
  Achievement(
    id: 'level_5',
    title: 'Starter Rank',
    description: 'Reach level 5.',
    icon: '⭐',
    test: (s, _) => s.level >= 5,
  ),
  Achievement(
    id: 'level_10',
    title: 'Double Digits',
    description: 'Reach level 10.',
    icon: '🌟',
    test: (s, _) => s.level >= 10,
  ),
  Achievement(
    id: 'early_bird',
    title: 'Early Bird',
    description: 'Finish a task before 8 AM.',
    icon: '🌅',
    test: (s, e) => e.justCompleted && e.now.hour < 8,
  ),
  Achievement(
    id: 'night_owl',
    title: 'Night Owl',
    description: 'Finish a task after 10 PM.',
    icon: '🦉',
    test: (s, e) => e.justCompleted && e.now.hour >= 22,
  ),
];

/// Achievements newly satisfied by [s] that weren't already unlocked.
List<Achievement> newlyUnlocked(ProgressStats s, AchievementEvent e) => [
  for (final a in achievements)
    if (!s.unlocked.containsKey(a.id) && a.test(s, e)) a,
];
