import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'desktop_hotkey_stub.dart'
    if (dart.library.io) 'desktop_hotkey_io.dart'
    as impl;
import 'device_bridge.dart';

export 'desktop_hotkey_stub.dart'
    if (dart.library.io) 'desktop_hotkey_io.dart'
    show hotkeyLabel, hotkeySupported;

/// "Quick add from anywhere" on Mac and Windows. Device-local, on by
/// default.
final hotkeyEnabledProvider = NotifierProvider<HotkeyEnabled, bool>(
  HotkeyEnabled.new,
);

class HotkeyEnabled extends Notifier<bool> {
  static const _key = 'hotkey.enabled';

  @override
  bool build() => ref.read(keyValueStoreProvider).read(_key) != 'false';

  void set(bool on) {
    ref.read(keyValueStoreProvider).write(_key, '$on');
    state = on;
  }
}

/// Keeps the system-wide Quick add shortcut registered while enabled.
class DesktopHotkey extends ConsumerStatefulWidget {
  const DesktopHotkey({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DesktopHotkey> createState() => _DesktopHotkeyState();
}

class _DesktopHotkeyState extends ConsumerState<DesktopHotkey> {
  @override
  void initState() {
    super.initState();
    _apply(ref.read(hotkeyEnabledProvider));
  }

  void _apply(bool on) => on
      ? impl.registerHotkey(() => quickAddRequested.value = true)
      : impl.unregisterHotkey();

  @override
  void dispose() {
    impl.unregisterHotkey();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(hotkeyEnabledProvider, (_, on) => _apply(on));
    return widget.child;
  }
}
