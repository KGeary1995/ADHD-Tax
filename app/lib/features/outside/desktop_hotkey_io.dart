import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Mac and Windows apps, not tests (which run on the host OS).
bool get hotkeySupported =>
    (Platform.isMacOS || Platform.isWindows) &&
    !Platform.environment.containsKey('FLUTTER_TEST');

String get hotkeyLabel => Platform.isMacOS ? '⌃⇧Space' : 'Ctrl+Shift+Space';

final _hotKey = HotKey(
  key: PhysicalKeyboardKey.space,
  modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
);

/// Registers the system-wide shortcut. Brings the window forward, then
/// calls [onPressed]. Failures (another app owns the shortcut) are ignored:
/// the app works the same without it.
Future<void> registerHotkey(void Function() onPressed) async {
  if (!hotkeySupported) return;
  try {
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();
    await hotKeyManager.register(
      _hotKey,
      keyDownHandler: (_) async {
        try {
          if (await windowManager.isMinimized()) await windowManager.restore();
          await windowManager.show();
          await windowManager.focus();
        } on Object {
          // Still open Quick add in whatever window state we have.
        }
        onPressed();
      },
    );
  } on Object {
    // Shortcut unavailable; nothing else depends on it.
  }
}

Future<void> unregisterHotkey() async {
  if (!hotkeySupported) return;
  try {
    await hotKeyManager.unregisterAll();
  } on Object {
    // Already gone.
  }
}
