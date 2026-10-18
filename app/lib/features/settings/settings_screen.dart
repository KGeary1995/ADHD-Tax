import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/task_chips.dart';
import '../gamification/progress_controller.dart';
import 'accounts_panel.dart';
import 'reminders_panel.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final settings = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final groups = <String, List<ThemeSpec>>{};
    for (final t in themeSpecs) {
      (groups[t.group] ??= []).add(t);
    }

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: s.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          for (final g in groups.entries) ...[
            SectionLabel('${g.key} themes'),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 760
                    ? 3
                    : c.maxWidth > 460
                    ? 2
                    : 1;
                final w = (c.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final t in g.value)
                      SizedBox(
                        width: w,
                        child: _ThemeCard(
                          spec: t,
                          selected: settings.themeId == t.id,
                          onTap: () =>
                              ctl.update((x) => x.copyWith(themeId: t.id)),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
          const SectionLabel('Reminders'),
          const RemindersPanel(),
          const SizedBox(height: 20),
          const SectionLabel('Celebrations'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: RadioGroup<CelebrationLevel>(
              groupValue: settings.celebration,
              onChanged: (v) {
                if (v != null) ctl.update((x) => x.copyWith(celebration: v));
              },
              child: Column(
                children: [
                  for (final c in CelebrationLevel.values)
                    RadioListTile<CelebrationLevel>(
                      value: c,
                      title: Text(c.label),
                      subtitle: Text(c.description),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Motivation'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rotate quotes every ${settings.quoteSeconds} seconds',
                  style: TextStyle(color: s.onSurface),
                ),
                Slider(
                  min: 8,
                  max: 60,
                  divisions: 13,
                  value: settings.quoteSeconds.toDouble(),
                  label: '${settings.quoteSeconds}s',
                  onChanged: (v) =>
                      ctl.update((x) => x.copyWith(quoteSeconds: v.round())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Work safety'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SwitchListTile(
              title: const Text('Patient-info guard'),
              subtitle: const Text(
                'Warn when a Work task looks like it contains PHI (DOB, MRN, '
                'patient names). Use initials or ticket numbers instead.',
              ),
              value: settings.phiGuard,
              onChanged: (v) => ctl.update((x) => x.copyWith(phiGuard: v)),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Accounts & sync'),
          const AccountsPanel(),
          const SizedBox(height: 20),
          const SectionLabel('Data'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.restart_alt, color: s.danger),
                  title: const Text('Reset XP and achievements'),
                  subtitle: const Text('Applies on all your synced devices.'),
                  onTap: () async {
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
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });
  final ThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = context.spec;
    final t = spec;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(current.radius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(current.radius),
            gradient: LinearGradient(
              colors: [t.background, t.backgroundEnd ?? t.surfaceAlt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: selected
                  ? current.primary
                  : current.muted.withValues(alpha: 0.3),
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected && t.glow
                ? [
                    BoxShadow(
                      color: t.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final c in [
                    t.primary,
                    t.secondary,
                    t.surface,
                    t.onSurface,
                  ])
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.muted.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle, color: t.primary),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t.name,
                style: TextStyle(
                  color: t.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  fontFamily: t.fontFamily,
                  fontFamilyFallback: t.fontFamilyFallback,
                ),
              ),
              const SizedBox(height: 2),
              Text(t.tagline, style: TextStyle(color: t.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
