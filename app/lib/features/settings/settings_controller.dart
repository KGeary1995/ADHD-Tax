import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';

const _settingsKey = 'settings.v1';

enum CelebrationLevel {
  off('Off', 'No animation. Just the XP.'),
  subtle('Subtle', 'A small card, no confetti.'),
  normal('Normal', 'Stars and a summary card.'),
  party('Party', 'The whole sky lights up.');

  const CelebrationLevel(this.label, this.description);
  final String label;
  final String description;
}

class AppSettings {
  const AppSettings({
    this.appearance = Appearance.system,
    this.celebration = CelebrationLevel.normal,
    this.quoteSeconds = 20,
    this.phiGuard = true,
    this.timerAlerts = true,
    this.nudges = true,
    this.nudgeTimes = const [8 * 60 + 45, 13 * 60 + 15],
    this.nudgeWeekdaysOnly = false,
    this.askedForNotifications = false,
    this.wrapUp = true,
    this.wrapUpTime = 20 * 60 + 30,
    this.pinnedTaskId,
    this.pinnedDay,
    this.timerBlocks = false,
  });

  final Appearance appearance;
  final CelebrationLevel celebration;
  final int quoteSeconds;

  /// Warn when Work tasks look like they contain patient info.
  final bool phiGuard;

  /// Countdown in the notification shade and a "time's up" alert during
  /// focus sessions (Android).
  final bool timerAlerts;

  /// "Pick one thing?" prompts at [nudgeTimes] (Android).
  final bool nudges;

  /// Minutes after midnight, local time.
  final List<int> nudgeTimes;
  final bool nudgeWeekdaysOnly;

  /// Android's notification prompt has been shown once, on first launch.
  /// After that it's only shown when the user asks for it in Settings.
  final bool askedForNotifications;

  /// Evening "wrap up the day?" reminder (Android) at [wrapUpTime],
  /// minutes after midnight.
  final bool wrapUp;
  final int wrapUpTime;

  /// Tomorrow's first thing, chosen in the evening wrap-up: shown first on
  /// Home on [pinnedDay] (yyyy-mm-dd). Device-local, like all settings.
  final String? pinnedTaskId;
  final String? pinnedDay;

  /// The focus timer as one block a minute instead of a star on an orbit.
  final bool timerBlocks;

  AppSettings copyWith({
    Appearance? appearance,
    CelebrationLevel? celebration,
    int? quoteSeconds,
    bool? phiGuard,
    bool? timerAlerts,
    bool? nudges,
    List<int>? nudgeTimes,
    bool? nudgeWeekdaysOnly,
    bool? askedForNotifications,
    bool? wrapUp,
    int? wrapUpTime,
    bool? timerBlocks,
  }) => AppSettings(
    appearance: appearance ?? this.appearance,
    celebration: celebration ?? this.celebration,
    quoteSeconds: quoteSeconds ?? this.quoteSeconds,
    phiGuard: phiGuard ?? this.phiGuard,
    timerAlerts: timerAlerts ?? this.timerAlerts,
    nudges: nudges ?? this.nudges,
    nudgeTimes: nudgeTimes ?? this.nudgeTimes,
    nudgeWeekdaysOnly: nudgeWeekdaysOnly ?? this.nudgeWeekdaysOnly,
    askedForNotifications: askedForNotifications ?? this.askedForNotifications,
    wrapUp: wrapUp ?? this.wrapUp,
    wrapUpTime: wrapUpTime ?? this.wrapUpTime,
    pinnedTaskId: pinnedTaskId,
    pinnedDay: pinnedDay,
    timerBlocks: timerBlocks ?? this.timerBlocks,
  );

  /// Pins a task as tomorrow's first thing ([taskId] null clears it).
  AppSettings pinForTomorrow(String? taskId, DateTime now) => AppSettings(
    appearance: appearance,
    celebration: celebration,
    quoteSeconds: quoteSeconds,
    phiGuard: phiGuard,
    timerAlerts: timerAlerts,
    nudges: nudges,
    nudgeTimes: nudgeTimes,
    nudgeWeekdaysOnly: nudgeWeekdaysOnly,
    askedForNotifications: askedForNotifications,
    wrapUp: wrapUp,
    wrapUpTime: wrapUpTime,
    pinnedTaskId: taskId,
    pinnedDay: taskId == null
        ? null
        : dayKeyOf(DateTime(now.year, now.month, now.day + 1)),
    timerBlocks: timerBlocks,
  );

  /// The pinned task id, if it was pinned for [now]'s day.
  String? pinnedFor(DateTime now) =>
      pinnedDay == dayKeyOf(now) ? pinnedTaskId : null;

  Map<String, Object?> toJson() => {
    'appearance': appearance.name,
    'celebration': celebration.name,
    'quoteSeconds': quoteSeconds,
    'phiGuard': phiGuard,
    'timerAlerts': timerAlerts,
    'nudges': nudges,
    'nudgeTimes': nudgeTimes,
    'nudgeWeekdaysOnly': nudgeWeekdaysOnly,
    'askedForNotifications': askedForNotifications,
    'wrapUp': wrapUp,
    'wrapUpTime': wrapUpTime,
    'pinnedTaskId': pinnedTaskId,
    'pinnedDay': pinnedDay,
    'timerBlocks': timerBlocks,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    appearance: _appearanceFromJson(j),
    celebration:
        CelebrationLevel.values.asNameMap()[j['celebration']] ??
        CelebrationLevel.normal,
    quoteSeconds: j['quoteSeconds'] as int? ?? 20,
    phiGuard: j['phiGuard'] as bool? ?? true,
    timerAlerts: j['timerAlerts'] as bool? ?? true,
    nudges: j['nudges'] as bool? ?? true,
    nudgeTimes: j['nudgeTimes'] is List
        ? [
            for (final m in j['nudgeTimes'] as List)
              if (m is int && m >= 0 && m < 24 * 60) m,
          ]
        : const [8 * 60 + 45, 13 * 60 + 15],
    nudgeWeekdaysOnly: j['nudgeWeekdaysOnly'] as bool? ?? false,
    askedForNotifications: j['askedForNotifications'] as bool? ?? false,
    wrapUp: j['wrapUp'] as bool? ?? true,
    wrapUpTime: switch (j['wrapUpTime']) {
      final int m when m >= 0 && m < 24 * 60 => m,
      _ => 20 * 60 + 30,
    },
    pinnedTaskId: j['pinnedTaskId'] as String?,
    pinnedDay: j['pinnedDay'] as String?,
    timerBlocks: j['timerBlocks'] as bool? ?? false,
  );
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final raw = ref.read(keyValueStoreProvider).read(_settingsKey);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  void update(AppSettings Function(AppSettings) f) {
    state = f(state);
    ref
        .read(keyValueStoreProvider)
        .write(_settingsKey, jsonEncode(state.toJson()));
  }
}

/// Before the redesign there were nine themes and no appearance setting.
/// Keep people on the brightness they had chosen.
Appearance _appearanceFromJson(Map<String, Object?> j) {
  final saved = Appearance.values.asNameMap()[j['appearance']];
  if (saved != null) return saved;
  return switch (j['themeId']) {
    null => Appearance.system,
    'slate' || 'clinic_calm' || 'low_stim' => Appearance.light,
    _ => Appearance.dark,
  };
}

String dayKeyOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
