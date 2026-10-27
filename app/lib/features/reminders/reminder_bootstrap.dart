import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart' show openFromOutside, routerProvider;
import '../../core/providers.dart';
import '../../data/models/task.dart';
import '../gamification/progress_controller.dart';
import '../settings/settings_controller.dart';
import '../tasks/tasks_controller.dart';
import 'nudge_plan.dart';
import 'reminders.dart';

/// Keeps notifications scheduled (check-in nudges, follow-ups on waiting
/// tasks, the evening wrap-up): on launch, whenever the app comes back to
/// the foreground, and when settings, tasks or your activity change. Opens
/// the right screen when one is tapped. Also asks for notification
/// permission once, on first launch.
class ReminderBootstrap extends ConsumerStatefulWidget {
  const ReminderBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ReminderBootstrap> createState() => _ReminderBootstrapState();
}

class _ReminderBootstrapState extends ConsumerState<ReminderBootstrap> {
  late final AppLifecycleListener _lifecycle;
  Timer? _debounce;
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reschedule);
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstRun());
    _taps = ref.read(remindersProvider).opened.listen(_open);
  }

  void _open(String route) {
    if (!mounted) return;
    openFromOutside(ref.read(routerProvider), route);
  }

  @override
  void dispose() {
    _taps?.cancel();
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
      final now = ref.read(clockProvider)();
      reminders.scheduleNudges([
        if (s.nudges)
          ...planNudges(
            times: s.nudgeTimes,
            weekdaysOnly: s.nudgeWeekdaysOnly,
            now: now,
            lastActive: ref.read(progressProvider).lastActiveAt,
          ),
        ...planFollowUps(ref.read(tasksProvider), now),
        if (s.wrapUp) ...planWrapUps(time: s.wrapUpTime, now: now),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select(
        (s) => (
          s.nudges,
          s.nudgeTimes.join(','),
          s.nudgeWeekdaysOnly,
          s.wrapUp,
          s.wrapUpTime,
        ),
      ),
      (_, _) => _reschedule(),
    );
    ref.listen(
      progressProvider.select((p) => p.lastActiveAt),
      (_, _) => _reschedule(),
    );
    ref.listen(
      tasksProvider.select(
        (ts) => [
          for (final t in ts)
            if (t.status == TaskStatus.waiting && t.followUpAt != null)
              '${t.id}@${t.followUpAt}',
        ].join(','),
      ),
      (_, _) => _reschedule(),
    );
    return widget.child;
  }
}
