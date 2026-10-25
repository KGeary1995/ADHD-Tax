import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/links.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import '../gamification/progress_controller.dart';
import '../../sync/replicas_controller.dart';
import '../ai/ai_settings_group.dart';
import '../guide/examples.dart';
import '../outside/desktop_hotkey.dart';
import 'accounts_panel.dart';
import 'backup_group.dart';
import 'device_workspaces.dart';
import 'reminders_panel.dart';
import 'settings_controller.dart';
import '../../core/theme/ph.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // The open section on a computer.
  var _section = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final settings = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    const gap = SizedBox(height: Gap.s9);

    final appearance = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Appearance'),
        Segmented<Appearance>(
          values: Appearance.values,
          selected: settings.appearance,
          labelOf: (a) => a.label,
          onSelected: (a) => ctl.update((x) => x.copyWith(appearance: a)),
        ),
      ],
    );
    final feel = Group(
      label: 'Feel',
      children: [
        GroupRow(
          title: 'Celebrations',
          leading: const Icon(Ph.confetti),
          trailing: RowValue(settings.celebration.label),
          onTap: () => _pickCelebration(context, ref),
        ),
        GroupRow(
          title: 'Focus timer',
          leading: const Icon(Ph.timer),
          trailing: RowValue(settings.timerBlocks ? 'Blocks' : 'Orbit'),
          onTap: () => _pickTimer(context, ref),
        ),
        GroupRow(
          title: 'Quotes',
          leading: const Icon(Ph.quotes),
          trailing: RowValue('Every ${settings.quoteSeconds} s'),
          onTap: () => _pickQuoteSpeed(context, ref),
        ),
        SwitchRow(
          leading: const Icon(Ph.shieldCheck),
          title: 'Patient-info guard',
          subtitle: 'Warn on Work tasks that look like PHI',
          value: settings.phiGuard,
          onChanged: (v) => ctl.update((x) => x.copyWith(phiGuard: v)),
        ),
      ],
    );
    final reuse = Group(
      label: 'Reuse',
      children: [
        if (hotkeySupported)
          SwitchRow(
            leading: const Icon(Ph.keyboard),
            title: 'Quick add from anywhere',
            subtitle: 'Press $hotkeyLabel in any app',
            value: ref.watch(hotkeyEnabledProvider),
            onChanged: ref.read(hotkeyEnabledProvider.notifier).set,
          ),
        GroupRow(
          title: 'Templates',
          leading: const Icon(Ph.copySimple),
          subtitle: 'Checklists and notes you use again and again',
          trailing: Icon(Ph.caretRight, size: 16, color: s.ink3),
          onTap: () => context.push('/templates'),
        ),
      ],
    );
    final data = Group(
      label: 'Data',
      children: [
        GroupRow(
          title: 'Reset XP and achievements',
          leading: Icon(Ph.arrowCounterClockwise, color: s.danger),
          subtitle: 'Your tasks stay. Applies on all synced devices.',
          onTap: () => _reset(context, ref),
        ),
        GroupRow(
          title: 'Licenses',
          leading: const Icon(Ph.textAlignLeft),
          trailing: Icon(Ph.caretRight, size: 16, color: s.ink3),
          onTap: () =>
              showLicensePage(context: context, applicationName: 'Gumption'),
        ),
      ],
    );

    final examples = ref.watch(examplesShowingProvider);
    final help = Group(
      label: 'Help',
      children: [
        GroupRow(
          title: 'How Gumption works',
          leading: const Icon(Ph.question),
          subtitle: 'A short tour of every feature',
          trailing: Icon(Ph.caretRight, size: 16, color: s.ink3),
          onTap: () => context.push('/guide'),
        ),
        GroupRow(
          title: examples ? 'Remove example tasks' : 'Try with example tasks',
          subtitle: examples
              ? 'Takes away only the examples'
              : 'See the app full before adding your own',
          leading: Icon(examples ? Ph.trash : Ph.flask),
          onTap: () {
            final ctl = ref.read(examplesProvider.notifier);
            examples ? ctl.remove() : ctl.add();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  examples
                      ? 'Example tasks removed.'
                      : 'Added example tasks. Have a look at Today.',
                ),
              ),
            );
          },
        ),
        GroupRow(
          title: 'Support',
          leading: const Icon(Ph.lifebuoy),
          subtitle: 'Questions, or something not working',
          trailing: Icon(Ph.arrowUpRight, size: 16, color: s.ink3),
          onTap: () => launchUrl(Uri.parse(Links.support)),
        ),
        GroupRow(
          title: 'Privacy policy',
          leading: const Icon(Ph.lock),
          subtitle: 'No ads, no tracking, no server',
          trailing: Icon(Ph.arrowUpRight, size: 16, color: s.ink3),
          onTap: () => launchUrl(Uri.parse(Links.privacy)),
        ),
      ],
    );

    // A computer: a list of sections on the left, the open one on the
    // right, like the system settings on a Mac.
    final sections = <(IconData, String, String, List<Widget>)>[
      (
        Ph.palette,
        'Look and feel',
        'Light or dark, celebrations, quotes and the patient-info guard.',
        [appearance, gap, feel],
      ),
      (
        Ph.devices,
        'This device',
        'Which side this copy of Gumption shows.',
        [const _ShowOnDevice()],
      ),
      (
        Ph.bellSimple,
        'Reminders',
        'Timer alerts and check-in nudges.',
        [const RemindersPanel()],
      ),
      (
        Ph.cloud,
        'Sync',
        'Google accounts for Personal and Work.',
        [const AccountsPanel()],
      ),
      (
        Ph.lightning,
        'Shortcuts and templates',
        'Quick add from anywhere, and things you reuse.',
        [reuse],
      ),
      (
        Ph.sparkle,
        'AI helper',
        'Break tasks into steps with your own Anthropic key.',
        [const AiSettingsGroup()],
      ),
      (
        Ph.floppyDisk,
        'Backup',
        'Save everything to one file, or restore from one.',
        [const BackupGroup()],
      ),
      (
        Ph.question,
        'Help',
        'A tour of the app, and example tasks to try it with.',
        [help],
      ),
      (Ph.slidersHorizontal, 'Data', 'Reset progress, and licenses.', [data]),
    ];

    return SidebarLayout(
      maxWidth: 1100,
      sidebar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 22),
            child: PageHeader('Settings'),
          ),
          for (final (i, (icon, label, _, _)) in sections.indexed)
            SideItem(
              label: label,
              icon: icon,
              selected: _section == i,
              onTap: () => setState(() => _section = i),
            ),
        ],
      ),
      builder: (context, wide) {
        if (wide) {
          final (_, title, about, content) = sections[_section];
          return ListView(
            padding: EdgeInsets.fromLTRB(8, 40, 22, navClearance(context)),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(title, style: s.display(32)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
                child: Text(
                  about,
                  style: TextStyle(fontSize: 15, color: s.muted, height: 1.4),
                ),
              ),
              ...content,
            ],
          );
        }
        // A phone: reached from the gear on Progress, with a way back.
        return ListView(
          padding: EdgeInsets.fromLTRB(
            Gap.listSide,
            4,
            Gap.listSide,
            MediaQuery.paddingOf(context).bottom + 40,
          ),
          children: [
            Row(
              children: [
                Transform.translate(
                  offset: const Offset(-12, 0),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: Icon(Ph.caretLeft, color: s.ink),
                    onPressed: () => context.go('/progress'),
                  ),
                ),
                Text('Settings', style: s.display(20)),
              ],
            ),
            const SizedBox(height: Gap.s4),
            appearance,
            gap,
            const _ShowOnDevice(),
            gap,
            const RemindersPanel(),
            gap,
            const AccountsPanel(),
            gap,
            feel,
            gap,
            reuse,
            gap,
            const AiSettingsGroup(),
            gap,
            const BackupGroup(),
            gap,
            help,
            gap,
            data,
          ],
        );
      },
    );
  }
}

/// "Show on this device": both workspaces, or one, e.g. a second copy of
/// Gumption in an Android work profile that should only hold Work.
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
        const FieldLabel('This device shows'),
        Segmented<DeviceWorkspaces>(
          values: DeviceWorkspaces.values,
          selected: device,
          labelOf: (d) => d.label,
          onSelected: ref.read(deviceWorkspacesProvider.notifier).set,
        ),
        Padding(
          padding: const EdgeInsets.only(top: Gap.s4),
          child: Text(
            [
              device.single
                  ? 'Only ${device.primary.label} tasks and notes appear '
                        'here, and new ones go to ${device.primary.label}.'
                  : 'Use Personal or Work if this copy of Gumption is for '
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

Future<void> _pickCelebration(BuildContext context, WidgetRef ref) =>
    showAppSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final s = ctx.spec;
          final current = ref.watch(settingsProvider).celebration;
          return SafeArea(
            child: SingleChildScrollView(
              padding: sheetPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetTitle(
                    'Celebrations',
                    subtitle: 'Reduce Motion on your phone always wins.',
                  ),
                  const SizedBox(height: Gap.s6),
                  for (final c in CelebrationLevel.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.s4),
                      child: Panel(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        color: c == current ? s.starSoft : Colors.transparent,
                        borderColor: c == current ? s.star : s.line2,
                        onTap: () {
                          ref
                              .read(settingsProvider.notifier)
                              .update((x) => x.copyWith(celebration: c));
                          Navigator.pop(ctx);
                        },
                        child: Semantics(
                          selected: c == current,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.label,
                                      style: s.body(weight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: Gap.s1),
                                    Text(
                                      c.description,
                                      style: s.caption(color: s.ink2),
                                    ),
                                  ],
                                ),
                              ),
                              if (c == current)
                                Icon(Ph.starFourFill, size: 16, color: s.star),
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

Future<void> _pickTimer(BuildContext context, WidgetRef ref) =>
    showAppSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final blocks = ref.watch(settingsProvider).timerBlocks;
          void set(bool v) => ref
              .read(settingsProvider.notifier)
              .update((x) => x.copyWith(timerBlocks: v));
          return SafeArea(
            child: Padding(
              padding: sheetPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetTitle(
                    'Focus timer',
                    subtitle:
                        'A star travelling round an orbit, or one block a '
                        'minute.',
                  ),
                  const SizedBox(height: Gap.s7),
                  OptionRow(
                    children: [
                      OptionButton(
                        label: 'Orbit',
                        selected: !blocks,
                        onTap: () => set(false),
                      ),
                      OptionButton(
                        label: 'Blocks',
                        selected: blocks,
                        onTap: () => set(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.s8),
                  PrimaryButton(
                    label: 'Done',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

Future<void> _pickQuoteSpeed(BuildContext context, WidgetRef ref) =>
    showAppSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final secs = ref.watch(settingsProvider).quoteSeconds;
          return SafeArea(
            child: Padding(
              padding: sheetPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetTitle(
                    'Quotes',
                    subtitle: 'A new one every $secs seconds',
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
    builder: (ctx) => const ConfirmDialog(
      title: 'Reset progress?',
      body:
          'Your tasks stay. XP, level, coins and achievements go back to zero.',
      confirm: 'Reset',
      danger: true,
    ),
  );
  if (ok == true) ref.read(progressProvider.notifier).reset();
}
