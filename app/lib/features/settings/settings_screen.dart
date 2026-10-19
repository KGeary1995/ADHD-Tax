import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import '../gamification/progress_controller.dart';
import '../../sync/replicas_controller.dart';
import 'accounts_panel.dart';
import 'backup_group.dart';
import 'device_workspaces.dart';
import 'reminders_panel.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final settings = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    const gap = SizedBox(height: 22);

    return ContentWidth(
      child: ListView(
        padding: EdgeInsets.fromLTRB(14, 24, 14, navClearance(context)),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: PageHeader('Settings'),
          ),
          gap,
          const FieldLabel('Appearance', inset: 8),
          Segmented<Appearance>(
            values: Appearance.values,
            selected: settings.appearance,
            labelOf: (a) => a.label,
            onSelected: (a) => ctl.update((x) => x.copyWith(appearance: a)),
          ),
          gap,
          const _ShowOnDevice(),
          gap,
          const RemindersPanel(),
          gap,
          const AccountsPanel(),
          gap,
          Group(
            label: 'Feel',
            children: [
              GroupRow(
                title: 'Celebrations',
                trailing: _Value(settings.celebration.label),
                onTap: () => _pickCelebration(context, ref),
              ),
              GroupRow(
                title: 'Quotes',
                trailing: _Value('every ${settings.quoteSeconds} s'),
                onTap: () => _pickQuoteSpeed(context, ref),
              ),
              SwitchRow(
                title: 'Patient-info guard',
                subtitle: 'Warn on Work tasks that look like PHI',
                value: settings.phiGuard,
                onChanged: (v) => ctl.update((x) => x.copyWith(phiGuard: v)),
              ),
            ],
          ),
          gap,
          const BackupGroup(),
          gap,
          Group(
            label: 'Data',
            children: [
              GroupRow(
                title: 'Reset XP and achievements',
                subtitle: 'Your tasks stay. Applies on all synced devices.',
                trailing: Icon(Icons.restart_alt_rounded, color: s.danger),
                onTap: () => _reset(context, ref),
              ),
              GroupRow(
                title: 'Licenses',
                trailing: Icon(Icons.chevron_right_rounded, color: s.faint),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Unstuck',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Show on this device": both workspaces, or one, e.g. a second copy of
/// Unstuck in an Android work profile that should only hold Work.
class _ShowOnDevice extends ConsumerWidget {
  const _ShowOnDevice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final device = ref.watch(deviceWorkspacesProvider);
    final replicas = ref.watch(replicasProvider);
    // What the current choice hides, so nobody thinks it was deleted.
    var tasks = 0, notes = 0;
    for (final (ws, r) in replicas.entries) {
      if (device.shown.contains(ws)) continue;
      tasks += r
          .collection(collTasks)
          .values
          .where((x) => !x.isDeleted && x.values['status'] != 'done')
          .length;
      notes += r.collection(collNotes).values.where((x) => !x.isDeleted).length;
    }
    String count(int n, String what) => '$n $what${n == 1 ? '' : 's'}';
    final hidden = [
      if (tasks > 0) count(tasks, 'open task'),
      if (notes > 0) count(notes, 'note'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Show on this device', inset: 8),
        Segmented<DeviceWorkspaces>(
          values: DeviceWorkspaces.values,
          selected: device,
          labelOf: (d) => d.label,
          onSelected: ref.read(deviceWorkspacesProvider.notifier).set,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Text(
            [
              device.single
                  ? 'Only ${device.primary.label} tasks and notes appear '
                        'here, and new ones go to ${device.primary.label}.'
                  : 'Use Personal or Work if this copy of Unstuck is for '
                        'one side only, like a second copy in an Android '
                        'work profile.',
              if (hidden.isNotEmpty)
                '${hidden.join(' and ')} from the other side '
                    '${tasks + notes == 1 ? 'is' : 'are'} hidden on this '
                    'device, not deleted.',
            ].join(' '),
            style: TextStyle(fontSize: 13, color: s.muted, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: TextStyle(fontSize: 15, color: s.muted)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, size: 20, color: s.faint),
      ],
    );
  }
}

Future<void> _pickCelebration(
  BuildContext context,
  WidgetRef ref,
) => showModalBottomSheet<void>(
  context: context,
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final s = ctx.spec;
      final current = ref.watch(settingsProvider).celebration;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Celebrations', style: s.display(26)),
              const SizedBox(height: 14),
              for (final c in CelebrationLevel.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    radius: 18,
                    color: c == current
                        ? s.accent
                        : (s.isDark ? s.background : s.surface),
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .update((x) => x.copyWith(celebration: c));
                      Navigator.pop(ctx);
                    },
                    child: Semantics(
                      selected: c == current,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c == current ? s.onAccent : s.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: c == current ? s.onAccentMuted : s.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  ),
);

Future<void> _pickQuoteSpeed(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final s = ctx.spec;
          final secs = ref.watch(settingsProvider).quoteSeconds;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quotes', style: s.display(26)),
                  const SizedBox(height: 6),
                  Text(
                    'A new one every $secs seconds',
                    style: TextStyle(color: s.muted),
                  ),
                  Slider(
                    min: 8,
                    max: 60,
                    divisions: 13,
                    value: secs.toDouble(),
                    label: '${secs}s',
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .update((x) => x.copyWith(quoteSeconds: v.round())),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

Future<void> _reset(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset progress?'),
      content: const Text(
        'Your tasks stay. XP, level, coins and achievements go back to zero.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Reset'),
        ),
      ],
    ),
  );
  if (ok == true) ref.read(progressProvider.notifier).reset();
}
