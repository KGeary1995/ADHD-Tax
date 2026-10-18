import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/safe_area/web_safe_area.dart';
import 'core/theme/app_themes.dart';
import 'data/models/task.dart';
import 'features/capture/quick_add_sheet.dart';
import 'features/capture/task_editor_screen.dart';
import 'features/focus/focus_screen.dart';
import 'features/gamification/celebration_overlay.dart';
import 'features/gamification/progress_screen.dart';
import 'features/picker/dashboard_screen.dart';
import 'features/reminders/reminder_bootstrap.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/settings_screen.dart';
import 'features/tasks/task_list_screen.dart';
import 'sync/sync_badge.dart';
import 'widgets/ui.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _destinations = [
  _Dest('/', 'Today', Icons.adjust_rounded),
  _Dest('/tasks', 'Tasks', Icons.format_list_bulleted_rounded),
  _Dest('/progress', 'Progress', Icons.bar_chart_rounded),
  _Dest('/settings', 'Settings', Icons.tune_rounded),
];

GoRouter buildRouter() => GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        GoRoute(path: '/tasks', builder: (_, _) => const TaskListScreen()),
        GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
    GoRoute(
      path: '/focus/:id',
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return FocusScreen(
          taskId: state.pathParameters['id']!,
          minutes: int.tryParse(q['min'] ?? '') ?? 25,
          justFive: q['five'] == '1',
          panic: q['panic'] == '1',
        );
      },
    ),
    GoRoute(
      path: '/task/:id',
      builder: (_, state) => TaskEditorScreen(
        taskId: state.pathParameters['id']!,
        focusFirstStep: state.uri.queryParameters['focusFirstStep'] == '1',
        draft: state.extra is Task ? state.extra! as Task : null,
      ),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) => buildRouter());

class UnstuckApp extends ConsumerWidget {
  const UnstuckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(settingsProvider.select((s) => s.appearance));
    return MaterialApp.router(
      title: 'Unstuck',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(lightSpec),
      darkTheme: buildTheme(darkSpec),
      themeMode: appearance.mode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => WebSafeArea(
        child: SyncBootstrap(
          child: ReminderBootstrap(
            child: CelebrationOverlay(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// A floating pill nav on phones, a slim rail on wide screens. Both carry
/// the Add button. Also owns the keyboard shortcuts and Android back.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  int get _index {
    final i = _destinations.indexWhere(
      (d) => d.path != '/' && location.startsWith(d.path),
    );
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    void go(int i) => context.go(_destinations[i].path);
    void add() => showQuickAdd(context);

    final scaffold = wide
        ? Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _Rail(index: _index, onSelect: go, onAdd: add),
                  const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              ),
            ),
          )
        : Scaffold(
            // The nav floats over the content; screens pad their bottom by
            // MediaQuery.padding, which then includes the nav.
            extendBody: true,
            bottomNavigationBar: _PillNav(
              index: _index,
              onSelect: go,
              onAdd: add,
            ),
            body: SafeArea(bottom: false, child: child),
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): add,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): add,
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            go(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            go(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            go(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
            go(3),
      },
      // Tabs replace each other rather than stacking, so Android's back
      // button would otherwise close the app from any tab. Back goes Home
      // first, and only exits from there.
      child: PopScope(
        canPop: location == '/',
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/');
        },
        child: Focus(autofocus: true, child: scaffold),
      ),
    );
  }
}

class _PillNav extends StatelessWidget {
  const _PillNav({
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottom > 0 ? bottom : 16),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            height: 66,
            padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
            decoration: ShapeDecoration(
              color: s.nav,
              shape: StadiumBorder(side: BorderSide(color: s.navBorder)),
              shadows: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (i, d) in _destinations.indexed)
                  IconButton(
                    tooltip: d.label,
                    isSelected: i == index,
                    onPressed: () => onSelect(i),
                    iconSize: 25,
                    constraints: const BoxConstraints.tightFor(
                      width: 52,
                      height: 52,
                    ),
                    color: s.navIcon,
                    selectedIcon: Icon(d.icon, color: s.navIconActive),
                    icon: Icon(d.icon),
                  ),
                _AddButton(onAdd: onAdd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Tooltip(
      message: 'Add a task',
      child: Material(
        color: s.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onAdd,
          child: SizedBox.square(
            dimension: 50,
            child: Icon(Icons.add_rounded, size: 28, color: s.onAccent),
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Tooltip(message: 'Unstuck', child: UnstuckMark(size: 28)),
          const SizedBox(height: 28),
          _AddButton(onAdd: onAdd),
          const SizedBox(height: 20),
          for (final (i, d) in _destinations.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(i),
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: Container(
                    width: 76,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 30,
                          decoration: ShapeDecoration(
                            color: i == index ? s.surface : null,
                            shape: const StadiumBorder(),
                          ),
                          child: Icon(
                            d.icon,
                            size: 22,
                            color: i == index ? s.onSurface : s.faint,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == index
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == index ? s.onSurface : s.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          const SyncBadge(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
