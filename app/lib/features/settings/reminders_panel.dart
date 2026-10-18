import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/backdrop.dart';
import '../reminders/reminders.dart';
import 'settings_controller.dart';

const _maxNudges = 6;

/// Settings → Reminders: focus timer alerts and check-in nudges.
class RemindersPanel extends ConsumerStatefulWidget {
  const RemindersPanel({super.key});

  @override
  ConsumerState<RemindersPanel> createState() => _RemindersPanelState();
}

class _RemindersPanelState extends ConsumerState<RemindersPanel> {
  late final AppLifecycleListener _lifecycle;
  bool? _granted;
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    _check();
    // Back from Android's settings screen: the answer may have changed.
    _lifecycle = AppLifecycleListener(onResume: _check);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final g = await ref.read(remindersProvider).permissionGranted();
    if (mounted) setState(() => _granted = g);
  }

  Future<void> _ask() async {
    final g = await ref.read(remindersProvider).requestPermission();
    if (mounted) {
      setState(() {
        _granted = g;
        _blocked = !g;
      });
    }
  }

  Future<void> _addTime(List<int> times) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 15, minute: 30),
      helpText: 'Nudge me at',
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    if (times.contains(m)) return;
    ref
        .read(settingsProvider.notifier)
        .update((x) => x.copyWith(nudgeTimes: [...times, m]..sort()));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final settings = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final supported = ref.watch(remindersProvider).supported;

    if (!supported) {
      return Panel(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Icon(Icons.notifications_off_outlined, color: s.muted),
          title: const Text('Reminders are set up in the Android app'),
          subtitle: const Text(
            'Timer alerts and check-in nudges come to your phone. Here, the '
            'focus timer stays on screen.',
          ),
        ),
      );
    }

    final times = settings.nudgeTimes;
    final loc = MaterialLocalizations.of(context);
    String label(int m) =>
        loc.formatTimeOfDay(TimeOfDay(hour: m ~/ 60, minute: m % 60));

    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_granted == false)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(s.radius / 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _blocked
                        ? 'Android didn\'t show the prompt. Turn them on in '
                              'Android Settings → Apps → ADHD Tax → '
                              'Notifications.'
                        : 'Notifications are off for ADHD Tax, so none of '
                              'these will reach you.',
                    style: TextStyle(color: s.onSurface),
                  ),
                  if (!_blocked) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _ask,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Allow notifications'),
                    ),
                  ],
                ],
              ),
            ),
          SwitchListTile(
            title: const Text('Focus timer alerts'),
            subtitle: const Text(
              'A countdown in your notifications while you focus, and an '
              "alert when time's up, even if you've switched apps.",
            ),
            value: settings.timerAlerts,
            onChanged: (v) => ctl.update((x) => x.copyWith(timerAlerts: v)),
          ),
          SwitchListTile(
            title: const Text('Check-in nudges'),
            subtitle: const Text(
              'A gentle "pick one thing?" at the times below. Skipped if '
              'you started or finished something in the last 90 minutes.',
            ),
            value: settings.nudges,
            onChanged: (v) => ctl.update((x) => x.copyWith(nudges: v)),
          ),
          if (settings.nudges) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in times)
                    InputChip(
                      label: Text(label(m)),
                      onDeleted: () => ctl.update(
                        (x) => x.copyWith(
                          nudgeTimes: [
                            for (final t in x.nudgeTimes)
                              if (t != m) t,
                          ],
                        ),
                      ),
                      deleteButtonTooltipMessage: 'Remove',
                    ),
                  if (times.length < _maxNudges)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add a time'),
                      onPressed: () => _addTime(times),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Weekdays only'),
              value: settings.nudgeWeekdaysOnly,
              onChanged: (v) =>
                  ctl.update((x) => x.copyWith(nudgeWeekdaysOnly: v)),
            ),
          ],
        ],
      ),
    );
  }
}
