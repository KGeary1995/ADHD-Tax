import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
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
      return const Group(
        label: 'Reminders',
        children: [
          GroupRow(
            title: 'Reminders come to the Android app',
            subtitle:
                'Timer alerts and check-in nudges go to your phone. Here, '
                'the focus timer stays on screen.',
          ),
        ],
      );
    }

    final times = settings.nudgeTimes;
    final loc = MaterialLocalizations.of(context);
    String label(int m) =>
        loc.formatTimeOfDay(TimeOfDay(hour: m ~/ 60, minute: m % 60));

    return Group(
      label: 'Reminders',
      children: [
        if (_granted == false)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 20,
                      color: s.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _blocked
                            ? 'Android didn\'t show the prompt. Turn them on '
                                  'in Android Settings → Apps → Unstuck → '
                                  'Notifications.'
                            : 'Notifications are off for Unstuck, so none '
                                  'of these will reach you.',
                        style: TextStyle(color: s.text2, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (!_blocked) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _ask,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Allow notifications'),
                  ),
                ],
              ],
            ),
          ),
        SwitchRow(
          title: 'Focus timer alerts',
          subtitle: 'Countdown and a "time\'s up" alert',
          value: settings.timerAlerts,
          onChanged: (v) => ctl.update((x) => x.copyWith(timerAlerts: v)),
        ),
        SwitchRow(
          title: 'Check-in nudges',
          subtitle: settings.nudges && times.isNotEmpty
              ? times.map(label).join(' · ')
              : 'A gentle "pick one thing?" during the day',
          subtitleMono: settings.nudges && times.isNotEmpty,
          value: settings.nudges,
          onChanged: (v) => ctl.update((x) => x.copyWith(nudges: v)),
        ),
        if (settings.nudges) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skipped if you started something in the last 90 minutes.',
                  style: TextStyle(fontSize: 13, color: s.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in times)
                      _TimePill(
                        label: label(m),
                        onRemove: () => ctl.update(
                          (x) => x.copyWith(
                            nudgeTimes: [
                              for (final t in x.nudgeTimes)
                                if (t != m) t,
                            ],
                          ),
                        ),
                      ),
                    if (times.length < _maxNudges)
                      Pill(
                        label: 'Add a time',
                        icon: Icons.add_rounded,
                        selected: false,
                        onTap: () => _addTime(times),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SwitchRow(
            title: 'Weekdays only',
            value: settings.nudgeWeekdaysOnly,
            onChanged: (v) =>
                ctl.update((x) => x.copyWith(nudgeWeekdaysOnly: v)),
          ),
        ],
        SwitchRow(
          title: 'Evening wrap-up',
          subtitle: settings.wrapUp
              ? label(settings.wrapUpTime)
              : "Today's wins and tomorrow's first thing",
          subtitleMono: settings.wrapUp,
          value: settings.wrapUp,
          onChanged: (v) => ctl.update((x) => x.copyWith(wrapUp: v)),
        ),
        if (settings.wrapUp)
          GroupRow(
            title: 'Wrap-up time',
            trailing: Text(
              label(settings.wrapUpTime),
              style: s.mono(14, color: s.primary),
            ),
            onTap: () async {
              final t = settings.wrapUpTime;
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: t ~/ 60, minute: t % 60),
                helpText: 'Wrap up the day at',
              );
              if (picked != null) {
                ctl.update(
                  (x) =>
                      x.copyWith(wrapUpTime: picked.hour * 60 + picked.minute),
                );
              }
            },
          ),
      ],
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 14),
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: s.outline)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: s.mono(14, color: s.text2)),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
