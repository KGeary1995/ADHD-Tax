import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_themes.dart';
import 'data/models/task.dart';
import 'features/capture/quick_add_sheet.dart';
import 'features/capture/task_editor_screen.dart';
import 'features/focus/focus_screen.dart';
import 'features/gamification/celebration_overlay.dart';
import 'features/gamification/level_badge.dart';
import 'features/gamification/progress_screen.dart';
import 'features/picker/dashboard_screen.dart';
import 'features/reminders/reminder_bootstrap.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/settings_screen.dart';
import 'features/tasks/task_list_screen.dart';
import 'sync/sync_badge.dart';
import 'widgets/backdrop.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Dest('/', 'Focus', Icons.bolt_outlined, Icons.bolt),
  _Dest('/tasks', 'Tasks', Icons.checklist_outlined, Icons.checklist),
  _Dest(
    '/progress',
    'Progress',
    Icons.emoji_events_outlined,
    Icons.emoji_events,
  ),
  _Dest('/settings', 'Settings', Icons.tune_outlined, Icons.tune),
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

class AdhdTaxApp extends ConsumerWidget {
  const AdhdTaxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(settingsProvider.select((s) => s.themeId));
    final spec = themeSpecById(themeId);
    return MaterialApp.router(
      title: 'ADHD Tax',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(spec),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ThemedBackdrop(
        child: SyncBootstrap(
          child: ReminderBootstrap(
            child: CelebrationOverlay(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// Navigation rail on wide screens, bottom bar on phones, plus the global
/// quick-add button and keyboard shortcuts.
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
    final s = context.spec;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    void go(int i) => context.go(_destinations[i].path);

    final fab = FloatingActionButton.extended(
      onPressed: () => showQuickAdd(context),
      icon: const Icon(Icons.add),
      label: const Text('Quick add'),
      tooltip: 'Quick add (Ctrl+N)',
    );

    final scaffold = Scaffold(
      floatingActionButton: fab,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: go,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: go,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            'ADHD',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: s.primary,
                            ),
                          ),
                          Text(
                            'TAX',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: s.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SyncBadge(),
                              SizedBox(height: 12),
                              LevelBadge(compact: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  VerticalDivider(
                    width: 1,
                    color: s.muted.withValues(alpha: 0.15),
                  ),
                  Expanded(child: child),
                ],
              )
            : child,
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            showQuickAdd(context),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            showQuickAdd(context),
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
