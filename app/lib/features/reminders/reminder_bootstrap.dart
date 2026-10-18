import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../gamification/progress_controller.dart';
import '../settings/settings_controller.dart';
import 'nudge_plan.dart';
import 'reminders.dart';

/// Keeps check-in nudges scheduled: on launch, whenever the app comes back
/// to the foreground, and when the settings or your activity change. Also
/// asks for notification permission once, on first launch.
class ReminderBootstrap extends ConsumerStatefulWidget {
  const ReminderBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ReminderBootstrap> createState() => _ReminderBootstrapState();
}

class _ReminderBootstrapState extends ConsumerState<ReminderBootstrap> {
  late final AppLifecycleListener _lifecycle;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reschedule);
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstRun());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _firstRun() async {
    final reminders = ref.read(remindersProvider);
    if (!reminders.supported || !mounted) return;
    final s = ref.read(settingsProvider);
    if (!s.askedForNotifications && (s.nudges || s.timerAlerts)) {
      ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(askedForNotifications: true));
      await reminders.requestPermission();
    }
    _reschedule();
  }

  void _reschedule() {
    // Settings edits and back-to-back events arrive in bursts.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final reminders = ref.read(remindersProvider);
      if (!reminders.supported) return;
      final s = ref.read(settingsProvider);
      reminders.scheduleNudges(
        s.nudges
            ? planNudges(
                times: s.nudgeTimes,
                weekdaysOnly: s.nudgeWeekdaysOnly,
                now: ref.read(clockProvider)(),
                lastActive: ref.read(progressProvider).lastActiveAt,
              )
            : const [],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select(
        (s) => (s.nudges, s.nudgeTimes.join(','), s.nudgeWeekdaysOnly),
      ),
      (_, _) => _reschedule(),
    );
    ref.listen(
      progressProvider.select((p) => p.lastActiveAt),
      (_, _) => _reschedule(),
    );
    return widget.child;
  }
}
