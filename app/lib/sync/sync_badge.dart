import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/task.dart';
import '../features/settings/accounts_panel.dart';
import 'sync_controller.dart';

/// Compact sync status for the app chrome; tap to open Settings. Shows the
/// most urgent state across both workspaces.
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  static const _urgency = [
    SyncPhase.needsReconnect,
    SyncPhase.error,
    SyncPhase.connecting,
    SyncPhase.syncing,
    SyncPhase.synced,
    SyncPhase.disconnected,
    SyncPhase.notConfigured,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [
      for (final ws in Workspace.values) ref.watch(syncProvider(ws)),
    ];
    final connected = all.where((s) => s.isConnected).toList();
    final shown = (connected.isEmpty ? all : connected).reduce(
      (a, b) => _urgency.indexOf(a.phase) <= _urgency.indexOf(b.phase) ? a : b,
    );
    final tip = [
      for (final (i, ws) in Workspace.values.indexed)
        '${ws.label}: ${all[i].isConnected ? '${all[i].email} (${all[i].phase.name})' : 'not syncing'}',
    ].join('\n');
    return IconButton(
      tooltip: tip,
      onPressed: () => context.go('/settings'),
      icon: SyncIcon(sync: shown),
    );
  }
}

/// A sync icon on Home only when a workspace needs attention (failed, or
/// signed out by Google). Quiet otherwise.
class SyncAlert extends ConsumerWidget {
  const SyncAlert({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final troubled =
        [for (final ws in Workspace.values) ref.watch(syncProvider(ws))].where(
          (s) =>
              s.phase == SyncPhase.error || s.phase == SyncPhase.needsReconnect,
        );
    if (troubled.isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Sync needs attention',
      onPressed: () => context.go('/settings'),
      icon: SyncIcon(sync: troubled.first, size: 22),
    );
  }
}

/// Keeps both workspaces' sync running for the app's lifetime and syncs
/// when the app comes back to the foreground.
class SyncBootstrap extends ConsumerStatefulWidget {
  const SyncBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SyncBootstrap> createState() => _SyncBootstrapState();
}

class _SyncBootstrapState extends ConsumerState<SyncBootstrap> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        for (final ws in Workspace.values) {
          ref.read(syncProvider(ws).notifier).syncNow();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final ws in Workspace.values) {
      ref.watch(syncProvider(ws));
    }
    return widget.child;
  }
}
