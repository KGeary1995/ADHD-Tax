import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../sync/sync_controller.dart';
import '../../widgets/ui.dart';

/// Settings → Sync: one row per workspace.
class AccountsPanel extends ConsumerWidget {
  const AccountsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final configured = ref.watch(googleAuthProvider).isConfigured;
    if (!configured) {
      return const Group(
        label: 'Sync',
        children: [
          GroupRow(
            title: 'Google sync isn\'t set up in this build',
            subtitle:
                'Tasks are saved on this device only, so save a backup '
                'file below now and then. To sync your phone and computer, '
                'follow "Set up Google sync" in the README.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Group(
          label: 'Sync',
          children: [
            for (final ws in Workspace.values) _WorkspaceRow(workspace: ws),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Text(
            'Each workspace syncs to its own Google account, in a hidden '
            'app folder in that account\'s Drive. Unstuck can\'t see '
            'anything else in your Drive.',
            style: TextStyle(color: s.muted, fontSize: 12, height: 1.4),
          ),
        ),
      ],
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
            ? 'Not connected. Use your clinic\'s Google Workspace account; '
                  'your admin may need to approve the app.'
            : 'Not connected. Use your personal Google account.',
      SyncPhase.connecting => 'Waiting for Google sign-in…',
      SyncPhase.syncing => '${sync.email} · syncing…',
      SyncPhase.synced => '${sync.email} · ${_lastSynced(sync.lastSyncedAt)}',
      SyncPhase.error => '${sync.email} · ${sync.message ?? 'sync failed'}',
      SyncPhase.needsReconnect =>
        '${sync.email} · ${sync.message ?? 'sign in again'}',
    };
    final personalOnWork =
        workspace == Workspace.work &&
        sync.isConnected &&
        sync.looksLikePersonalAccount;

    final Widget trailing;
    if (busy) {
      trailing = const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (!sync.isConnected || sync.phase == SyncPhase.needsReconnect) {
      trailing = FilledButton(
        onPressed: ctl.connect,
        style: FilledButton.styleFrom(
          backgroundColor: s.onSurface,
          foregroundColor: s.background,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(
            fontFamily: Fonts.ui,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(sync.isConnected ? 'Reconnect' : 'Connect'),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SyncIcon(sync: sync, size: 20),
          PopupMenuButton<String>(
            tooltip: 'Sync options',
            icon: Icon(Icons.more_horiz_rounded, color: s.muted),
            onSelected: (v) => switch (v) {
              'sync' => ctl.syncNow(),
              'backup' => _export(context, ref),
              _ => _disconnect(context, ref),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'sync', child: Text('Sync now')),
              PopupMenuItem(value: 'backup', child: Text('Back up to Drive')),
              PopupMenuItem(value: 'disconnect', child: Text('Disconnect')),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupRow(
          title: workspace.label,
          subtitle: subtitle,
          trailing: trailing,
        ),
        if (personalOnWork)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'This looks like a personal Gmail account. Work tasks should '
              'sync to your clinic account so they stay under its policies.',
              style: TextStyle(color: s.warning, fontSize: 13, height: 1.35),
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
      SyncPhase.syncing => (Icons.cloud_sync_outlined, s.muted),
      SyncPhase.synced => (Icons.cloud_done_outlined, s.primary),
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
