import 'package:flutter/material.dart';

import 'device_workspaces.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../sync/sync_controller.dart';
import '../../widgets/ui.dart';
import '../../core/theme/ph.dart';

/// Settings → Sync: one row per workspace.
class AccountsPanel extends ConsumerWidget {
  const AccountsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final services = ref.watch(availableSyncServicesProvider);
    if (services.isEmpty) {
      return const Group(
        label: 'Sync',
        children: [
          GroupRow(
            title: 'Sync isn\'t set up in this build',
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
            for (final ws in ref.watch(deviceWorkspacesProvider).shown)
              _WorkspaceRow(workspace: ws),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Text(
            services.length > 1
                ? 'Each workspace syncs to the place you choose. Gumption '
                      'only uses its own folder there: hidden in Google '
                      'Drive and iCloud, and Apps/Gumption in OneDrive. It '
                      'can\'t see anything else.'
                : switch (services.single) {
                    SyncService.google =>
                      'Each workspace syncs to its own Google account, in a '
                          'hidden app folder in that account\'s Drive. '
                          'Gumption can\'t see anything else in your Drive.',
                    SyncService.onedrive =>
                      'Each workspace syncs to its own Microsoft account, in '
                          'the Apps/Gumption folder of its OneDrive. Gumption '
                          'can\'t see anything else in your OneDrive.',
                    SyncService.icloud =>
                      'Each workspace syncs through iCloud, in a hidden '
                          'folder only Gumption uses.',
                  },
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
    final services = ref.watch(availableSyncServicesProvider);
    final service = ctl.service;
    // With more than one service on offer, say which one this row uses.
    final account = sync.isICloud || services.length < 2
        ? sync.accountLabel
        : '${service.storeName} · ${sync.accountLabel}';

    final subtitle = switch (sync.phase) {
      SyncPhase.notConfigured ||
      SyncPhase.disconnected => _notConnected(services),
      SyncPhase.connecting => 'Waiting for ${service.signInName} sign-in…',
      SyncPhase.syncing => '$account · syncing…',
      SyncPhase.synced => '$account · ${_lastSynced(sync.lastSyncedAt)}',
      SyncPhase.error => '$account · ${sync.message ?? 'sync failed'}',
      SyncPhase.needsReconnect =>
        '$account · ${sync.message ?? 'sign in again'}',
    };
    final personalOnWork =
        workspace == Workspace.work &&
        sync.isConnected &&
        sync.looksLikePersonalAccount;
    final workOnICloud =
        workspace == Workspace.work && sync.isConnected && sync.isICloud;

    final Widget trailing;
    if (sync.phase == SyncPhase.connecting) {
      // The Google page can be closed without finishing; never leave the
      // row spinning with no way out.
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          TextButton(onPressed: ctl.cancelConnect, child: const Text('Cancel')),
        ],
      );
    } else if (busy) {
      trailing = const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (!sync.isConnected || sync.phase == SyncPhase.needsReconnect) {
      trailing = FilledButton(
        onPressed: () =>
            sync.isConnected ? ctl.connect() : _chooseAndConnect(context, ref),
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
            useRootNavigator: true,
            tooltip: 'Sync options',
            icon: Icon(Ph.dotsThree, color: s.muted),
            onSelected: (v) => switch (v) {
              'sync' => ctl.syncNow(),
              'backup' => _export(context, ref),
              _ => _disconnect(context, ref),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'sync', child: Text('Sync now')),
              if (!sync.isICloud)
                PopupMenuItem(
                  value: 'backup',
                  child: Text(
                    service == SyncService.onedrive
                        ? 'Back up to OneDrive'
                        : 'Back up to Drive',
                  ),
                ),
              const PopupMenuItem(
                value: 'disconnect',
                child: Text('Disconnect'),
              ),
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
              'This looks like a personal account. If your workplace has its '
              'own Google or Microsoft account, Work tasks belong there, '
              'under its policies.',
              style: TextStyle(color: s.warning, fontSize: 13, height: 1.35),
            ),
          ),
        if (workOnICloud)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Work tasks sync to your personal iCloud. If your workplace has '
              'rules about where work data goes, use its Google or Microsoft '
              'account.',
              style: TextStyle(color: s.ink2, fontSize: 13, height: 1.35),
            ),
          ),
      ],
    );
  }

  String _notConnected(List<SyncService> services) {
    if (services.length == 1 && services.single == SyncService.google) {
      return workspace == Workspace.work
          ? 'Not connected. Use the Google account you use for work. A '
                'company account may need its admin to allow the app.'
          : 'Not connected. Use your personal Google account.';
    }
    final names = [
      for (final s in services)
        switch (s) {
          SyncService.icloud => 'iCloud',
          SyncService.google => 'a Google account',
          SyncService.onedrive => 'a Microsoft account',
        },
    ];
    final list = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}';
    return 'Not connected. Sync with $list.';
  }

  /// First connection: where should this workspace sync? Only the services
  /// this device has are offered; with just one, it goes straight there.
  Future<void> _chooseAndConnect(BuildContext context, WidgetRef ref) async {
    final ctl = ref.read(syncProvider(workspace).notifier);
    final services = ref.read(availableSyncServicesProvider);
    if (services.length == 1) return ctl.connect(via: services.single);
    final pick = await showAppSheet<SyncService>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: sheetPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(
                'Sync ${workspace.label} with…',
                subtitle:
                    'Use the same choice on every device you want this '
                    'workspace on.',
              ),
              for (final service in services) ...[
                SizedBox(height: service == services.first ? Gap.s7 : Gap.s4),
                switch (service) {
                  SyncService.icloud => SheetChoice(
                    title: 'iCloud',
                    subtitle:
                        'iPhone, iPad and Mac only. Uses the Apple ID this '
                        'device is signed in to; nothing to sign in to.',
                    onTap: () => Navigator.pop(ctx, SyncService.icloud),
                  ),
                  SyncService.google => SheetChoice(
                    title: 'Google account',
                    subtitle:
                        'Any device, including Android, Windows and the '
                        'web. Signs in to Google.',
                    onTap: () => Navigator.pop(ctx, SyncService.google),
                  ),
                  SyncService.onedrive => SheetChoice(
                    title: 'Microsoft account (OneDrive)',
                    subtitle:
                        'Any device, including the web. A personal account '
                        'or one from work or school. Signs in to Microsoft.',
                    onTap: () => Navigator.pop(ctx, SyncService.onedrive),
                  ),
                },
              ],
            ],
          ),
        ),
      ),
    );
    if (pick != null) await ctl.connect(via: pick);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final link = await ref
          .read(syncProvider(workspace).notifier)
          .exportBackup();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref.read(syncProvider(workspace).notifier).service ==
                    SyncService.onedrive
                ? 'Backup saved to OneDrive, in Apps/Gumption/Backups.'
                : 'Backup saved to your Google Drive.',
          ),
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
        content: Text(
          'Syncing stops on this device. Your tasks stay here, and the copy '
          'in ${ref.read(syncProvider(workspace).notifier).service.storeName} '
          'stays for your other devices.',
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
      SyncPhase.disconnected => (Ph.cloudSlash, s.muted),
      SyncPhase.connecting || SyncPhase.syncing => (Ph.cloudArrowUp, s.muted),
      SyncPhase.synced => (Ph.cloudCheck, s.primary),
      SyncPhase.error => (Ph.cloud, s.warning),
      SyncPhase.needsReconnect => (Ph.cloudSlash, s.danger),
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
