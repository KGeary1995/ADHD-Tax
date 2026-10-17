import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../sync/sync_controller.dart';
import '../../widgets/backdrop.dart';

/// Settings → Accounts & sync: one row per workspace.
class AccountsPanel extends ConsumerWidget {
  const AccountsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final configured = ref.watch(googleAuthProvider).isConfigured;
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!configured)
            ListTile(
              leading: Icon(Icons.cloud_off_outlined, color: s.muted),
              title: const Text('Google sync isn\'t set up in this build'),
              subtitle: const Text(
                'Tasks are saved on this device only. To sync between your '
                'phone and computer, follow "Set up Google sync" in the README.',
              ),
            )
          else ...[
            for (final ws in Workspace.values) _WorkspaceRow(workspace: ws),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Each workspace syncs to its own Google account through a '
                'hidden app folder in that account\'s Drive. The app can\'t '
                'see anything else in your Drive.',
                style: TextStyle(color: s.muted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceRow extends ConsumerWidget {
  const _WorkspaceRow({required this.workspace});
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final sync = ref.watch(syncProvider(workspace));
    final ctl = ref.read(syncProvider(workspace).notifier);
    final busy =
        sync.phase == SyncPhase.connecting || sync.phase == SyncPhase.syncing;

    final subtitle = switch (sync.phase) {
      SyncPhase.notConfigured || SyncPhase.disconnected =>
        workspace == Workspace.work
            ? 'Use your clinic\'s Google Workspace account. Your admin may '
                  'need to approve the app first.'
            : 'Use your personal Google account.',
      SyncPhase.connecting => 'Waiting for Google sign-in…',
      SyncPhase.syncing => '${sync.email} · syncing…',
      SyncPhase.synced => '${sync.email} · ${_lastSynced(sync.lastSyncedAt)}',
      SyncPhase.error => '${sync.email} · ${sync.message ?? 'sync failed'}',
      SyncPhase.needsReconnect =>
        '${sync.email} · ${sync.message ?? 'sign in again'}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: SyncIcon(sync: sync),
          title: Text('${workspace.label} workspace'),
          subtitle: Text(subtitle),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        if (workspace == Workspace.work &&
            sync.isConnected &&
            sync.looksLikePersonalAccount)
          _Warning(
            'This looks like a personal Gmail account. Work tasks should '
            'sync to your clinic account so they stay under its policies.',
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!sync.isConnected)
                FilledButton.icon(
                  onPressed: busy ? null : ctl.connect,
                  icon: const Icon(Icons.login),
                  label: const Text('Connect Google account'),
                )
              else ...[
                if (sync.phase == SyncPhase.needsReconnect)
                  FilledButton.icon(
                    onPressed: busy ? null : ctl.connect,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: busy ? null : ctl.syncNow,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _export(context, ref),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Back up to Drive'),
                ),
                TextButton(
                  onPressed: busy ? null : () => _disconnect(context, ref),
                  style: TextButton.styleFrom(foregroundColor: s.danger),
                  child: const Text('Disconnect'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final link = await ref
          .read(syncProvider(workspace).notifier)
          .exportBackup();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Backup saved to your Google Drive.'),
          action: link == null
              ? null
              : SnackBarAction(
                  label: 'Open',
                  onPressed: () => launchUrl(Uri.parse(link)),
                ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disconnect ${workspace.label}?'),
        content: const Text(
          'Syncing stops on this device. Your tasks stay here, and the copy '
          'in Google Drive stays for your other devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(syncProvider(workspace).notifier).disconnect();
    }
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Container(
      margin: const EdgeInsets.fromLTRB(72, 0, 16, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: s.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(s.radius / 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: s.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: s.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cloud icon reflecting one workspace's sync state.
class SyncIcon extends StatelessWidget {
  const SyncIcon({super.key, required this.sync, this.size = 24});
  final WorkspaceSync sync;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final (icon, color) = switch (sync.phase) {
      SyncPhase.notConfigured ||
      SyncPhase.disconnected => (Icons.cloud_off_outlined, s.muted),
      SyncPhase.connecting ||
      SyncPhase.syncing => (Icons.cloud_sync_outlined, s.secondary),
      SyncPhase.synced => (Icons.cloud_done_outlined, s.success),
      SyncPhase.error => (Icons.cloud_queue, s.warning),
      SyncPhase.needsReconnect => (Icons.cloud_off, s.danger),
    };
    return Icon(icon, color: color, size: size);
  }
}

String _lastSynced(DateTime? at) {
  if (at == null) return 'not synced yet';
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'synced just now';
  if (d.inMinutes < 60) return 'synced ${d.inMinutes}m ago';
  if (d.inHours < 24) return 'synced ${d.inHours}h ago';
  return 'synced ${d.inDays}d ago';
}
