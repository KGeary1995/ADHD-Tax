import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/ui.dart';
import '../settings/device_workspaces.dart';
import 'ai_settings.dart';

/// Settings → AI helper: the API key and the Work switch.
class AiSettingsGroup extends ConsumerWidget {
  const AiSettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final ai = ref.watch(aiSettingsProvider);
    final showsWork = ref
        .watch(deviceWorkspacesProvider)
        .shown
        .contains(Workspace.work);
    return Group(
      label: 'AI helper',
      children: [
        GroupRow(
          title: 'Anthropic API key',
          subtitle: ai.hasKey
              ? 'Saved on this device only'
              : 'Optional. Lets "Break it down" turn a task into steps.',
          trailing: Icon(Icons.chevron_right_rounded, color: s.faint),
          onTap: () => _editKey(context, ref, ai.hasKey),
        ),
        if (showsWork)
          SwitchRow(
            title: 'Use on Work tasks',
            subtitle: 'Off: Work tasks are never sent to Claude',
            value: ai.allowWork,
            onChanged: (on) async {
              if (on && !await _confirmWork(context)) return;
              ref.read(aiSettingsProvider.notifier).setAllowWork(on);
            },
          ),
      ],
    );
  }

  Future<void> _editKey(BuildContext context, WidgetRef ref, bool has) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anthropic API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '"Break it down" sends a task\'s title and notes to Claude '
              'with your own key, and you pay Anthropic for what you use '
              '(a fraction of a cent per task). The key stays on this '
              'device.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: has ? 'New key' : 'Key',
                hintText: 'sk-ant-…',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://console.anthropic.com/settings/keys'),
              ),
              child: const Text('Get a key at console.anthropic.com'),
            ),
          ],
        ),
        actions: [
          if (has)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Remove key'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result.isNotEmpty && result.trim().isEmpty) return;
    await ref.read(aiSettingsProvider.notifier).setKey(result);
  }

  Future<bool> _confirmWork(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Use the AI helper on Work tasks?'),
          content: const Text(
            'The task\'s title and notes go to Anthropic. Keep patient '
            'names, dates of birth and record numbers out of them. Tasks '
            'that look like they contain patient details are never sent. '
            'Check that your clinic allows this first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      ) ??
      false;
}
