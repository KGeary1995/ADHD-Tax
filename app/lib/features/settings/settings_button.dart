import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_themes.dart';
import '../../core/theme/ph.dart';
import '../../widgets/ui.dart';

/// The tabs Settings can return to. Anything else goes back to Today.
const _tabs = {'/', '/tasks', '/notes', '/progress'};

/// Where Settings' back goes: the tab it was opened from (`?from=`).
String settingsReturn(String? from) => _tabs.contains(from) ? from! : '/';

/// Opens Settings from whichever tab you're on, so its back (and Android's
/// back) returns there rather than to a fixed tab.
void goToSettings(BuildContext context) {
  final here = GoRouter.of(context)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
  context.go(
    _tabs.contains(here)
        ? Uri(path: '/settings', queryParameters: {'from': here}).toString()
        : '/settings',
  );
}

/// Whether this layout shows [SettingsButton] (phones; not with the sidebar).
bool hasSettingsButton(BuildContext context) =>
    MediaQuery.sizeOf(context).width < wideBreakpoint;

/// The gear at the top right of each tab on a phone. Wide layouts list
/// Settings in the sidebar instead, so it's hidden there.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.quiet = false});

  /// Today: a plain icon, no square, to keep that screen calm.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    if (!hasSettingsButton(context)) return const SizedBox.shrink();
    if (!quiet) {
      return SquareIconButton(
        icon: Ph.gearSix,
        tooltip: 'Settings',
        onPressed: () => goToSettings(context),
      );
    }
    final s = context.spec;
    return IconButton(
      tooltip: 'Settings',
      constraints: const BoxConstraints.tightFor(width: 40, height: 42),
      padding: EdgeInsets.zero,
      icon: Icon(Ph.gearSix, size: 20, color: s.ink2),
      onPressed: () => goToSettings(context),
    );
  }
}
