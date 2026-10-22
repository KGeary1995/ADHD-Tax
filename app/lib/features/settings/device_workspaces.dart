import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/task.dart';

const _key = 'device.workspaces';

/// Which workspaces this install shows: both, or just one (e.g. a second
/// copy of Gumption in an Android work profile that should only hold Work).
/// Device-local and never synced. Hidden data isn't deleted; it just stays
/// out of every list, the picker, widgets and reminders.
enum DeviceWorkspaces {
  both('Both', [Workspace.personal, Workspace.work]),
  personal('Personal', [Workspace.personal]),
  work('Work', [Workspace.work]);

  const DeviceWorkspaces(this.label, this.shown);
  final String label;
  final List<Workspace> shown;

  bool get single => shown.length == 1;

  /// The workspace new things go into by default.
  Workspace get primary => shown.first;
}

final deviceWorkspacesProvider =
    NotifierProvider<DeviceWorkspacesController, DeviceWorkspaces>(
      DeviceWorkspacesController.new,
    );

class DeviceWorkspacesController extends Notifier<DeviceWorkspaces> {
  @override
  DeviceWorkspaces build() {
    final saved = ref.read(keyValueStoreProvider).read(_key);
    return DeviceWorkspaces.values.firstWhere(
      (d) => d.name == saved,
      orElse: () => DeviceWorkspaces.both,
    );
  }

  void set(DeviceWorkspaces d) {
    ref.read(keyValueStoreProvider).write(_key, d.name);
    state = d;
  }
}
