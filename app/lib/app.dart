import 'dart:math' as math;

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
import 'features/notes/note_editor_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/outside/device_bridge.dart';
import 'features/outside/desktop_hotkey.dart';
import 'features/outside/outside_bootstrap.dart';
import 'features/picker/dashboard_screen.dart';
import 'features/reminders/reminder_bootstrap.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/settings_button.dart';
import 'features/settings/settings_screen.dart';
import 'features/tasks/task_list_screen.dart';
import 'features/tasks/weekly_reset_screen.dart';
import 'features/picker/errand_run_screen.dart';
import 'data/models/template.dart';
import 'features/templates/template_editor_screen.dart';
import 'features/templates/templates_screen.dart';
import 'features/guide/guide_screen.dart';
import 'features/wrapup/wrapup_screen.dart';
import 'sync/sync_badge.dart';
import 'widgets/ui.dart';
import 'core/theme/ph.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon, this.iconOn);
  final String path;
  final String label;
  final IconData icon;

  /// The Fill weight, for the tab you're on.
  final IconData iconOn;
}

const _destinations = [
  _Dest('/', 'Today', Ph.sunHorizon, Ph.sunHorizonFill),
  _Dest('/tasks', 'Tasks', Ph.listBullets, Ph.listBulletsFill),
  _Dest('/notes', 'Notes', Ph.notePencil, Ph.notePencilFill),
  _Dest('/progress', 'Progress', Ph.shootingStar, Ph.shootingStarFill),
];

/// Every page sits on the sky.
Widget _sky(Widget child) => SkyBackground(child: child);

GoRouter buildRouter() => GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => _sky(
        AppShell(
          location: state.uri.path,
          from: state.uri.queryParameters['from'],
          child: child,
        ),
      ),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        GoRoute(path: '/tasks', builder: (_, _) => const TaskListScreen()),
        GoRoute(path: '/notes', builder: (_, _) => const NotesScreen()),
        GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
    GoRoute(
      path: '/focus/:id',
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return _sky(
          FocusScreen(
            taskId: state.pathParameters['id']!,
            minutes: int.tryParse(q['min'] ?? '') ?? 25,
            justFive: q['five'] == '1',
            panic: q['panic'] == '1',
          ),
        );
      },
    ),
    GoRoute(path: '/wrapup', builder: (_, _) => _sky(const WrapUpScreen())),
    GoRoute(path: '/guide', builder: (_, _) => _sky(const GuideScreen())),
    GoRoute(
      path: '/templates',
      builder: (_, _) => _sky(const TemplatesScreen()),
    ),
    GoRoute(path: '/reset', builder: (_, _) => _sky(const WeeklyResetScreen())),
    GoRoute(path: '/errands', builder: (_, _) => _sky(const ErrandRunScreen())),
    GoRoute(
      path: '/template/:id',
      builder: (_, state) => _sky(
        TemplateEditorScreen(
          templateId: state.pathParameters['id']!,
          kind:
              TemplateKind.values
                  .asNameMap()[state.uri.queryParameters['kind']] ??
              TemplateKind.task,
        ),
      ),
    ),
    // The iOS widget's + button (unstuck://app/add): Home, then Quick add.
    GoRoute(
      path: '/add',
      redirect: (_, _) {
        quickAddRequested.value = true;
        return '/';
      },
    ),
    GoRoute(
      path: '/note/:id',
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return _sky(
          NoteEditorScreen(
            noteId: state.pathParameters['id']!,
            workspace: Workspace.values.firstWhere(
              (w) => w.name == q['ws'],
              orElse: () => Workspace.personal,
            ),
            projectId: q['project'] ?? '',
            taskId: q['task'] ?? '',
            tag: q['tag'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/task/:id',
      builder: (_, state) => _sky(
        TaskEditorScreen(
          taskId: state.pathParameters['id']!,
          focusFirstStep: state.uri.queryParameters['focusFirstStep'] == '1',
          draft: state.extra is Task ? state.extra! as Task : null,
        ),
      ),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) => buildRouter());

class GumptionApp extends ConsumerWidget {
  const GumptionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(settingsProvider.select((s) => s.appearance));
    return MaterialApp.router(
      title: 'Gumption',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(lightSpec),
      darkTheme: buildTheme(darkSpec),
      themeMode: appearance.mode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => WebSafeArea(
        child: SyncBootstrap(
          child: ReminderBootstrap(
            child: OutsideBootstrap(
              child: DesktopHotkey(
                child: CelebrationOverlay(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tab bar on phones, a sidebar on wide screens. Both carry the Add
/// button. Also owns the keyboard shortcuts and Android back. Settings
/// lives in the shell too: the sidebar lists it, and on a phone each tab
/// has a gear at the top right; the tab bar stays, with no tab lit.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.location,
    this.from,
    required this.child,
  });
  final String location;

  /// On Settings: the tab it was opened from (see `goToSettings`).
  final String? from;
  final Widget child;

  bool get _onSettings => location.startsWith('/settings');

  /// The tab to light up; none on Settings.
  int get _index {
    if (_onSettings) return -1;
    final i = _destinations.indexWhere(
      (d) => d.path != '/' && location.startsWith(d.path),
    );
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    void go(int i) => context.go(_destinations[i].path);
    final onNotes = location.startsWith('/notes');
    // + adds what the tab is about: a note on Notes, otherwise a task (into
    // the project Tasks is showing).
    void add() => onNotes
        ? openNewNote(context, ref)
        : showQuickAdd(
            context,
            projectId: location.startsWith('/tasks')
                ? ref.read(taskProjectFilterProvider) ?? ''
                : '',
          );
    final addLabel = onNotes ? 'Add a note' : 'Add a task';

    final scaffold = wide
        ? Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Row(
                children: [
                  _Sidebar(
                    index: _index,
                    settings: _onSettings,
                    onSelect: go,
                    onAdd: add,
                    addLabel: addLabel,
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          )
        : Scaffold(
            backgroundColor: Colors.transparent,
            // The bar sits over the content; screens pad their bottom by
            // MediaQuery.padding, which then includes the bar.
            extendBody: true,
            bottomNavigationBar: _TabBar(
              index: _index,
              onSelect: go,
              onAdd: add,
              addLabel: addLabel,
            ),
            // Progress draws its night sky under the status bar itself.
            body: SafeArea(
              top: !location.startsWith('/progress'),
              bottom: false,
              child: child,
            ),
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
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            goToSettings(context),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            goToSettings(context),
      },
      // Tabs replace each other rather than stacking, so Android's back
      // button would otherwise close the app from any tab. Back goes Home
      // first (from Settings, back to the tab it was opened from), and only
      // exits from there.
      child: PopScope(
        canPop: location == '/',
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go(_onSettings ? settingsReturn(from) : '/');
        },
        child: Focus(autofocus: true, child: scaffold),
      ),
    );
  }
}

/// Four tabs hanging from a 2px rule, and the + square.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.index,
    required this.onSelect,
    required this.onAdd,
    required this.addLabel,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final narrow = MediaQuery.sizeOf(context).width < 380;
    // The bar's own text stays the designed size; a larger system font
    // would push the labels out of their tabs. Screen readers still get
    // the full label.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Container(
        decoration: BoxDecoration(
          color: s.bg,
          border: Border(top: BorderSide(color: s.line2, width: 2)),
        ),
        padding: EdgeInsets.fromLTRB(
          narrow ? 6 : 10,
          0,
          narrow ? 8 : 14,
          math.max(bottom, 12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, d) in _destinations.indexed) ...[
              Expanded(
                child: _Tab(
                  dest: d,
                  selected: i == index,
                  fontSize: narrow ? 11 : 12,
                  onTap: () => onSelect(i),
                ),
              ),
              SizedBox(width: narrow ? 2 : 4),
            ],
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _AddButton(
                onAdd: onAdd,
                label: addLabel,
                size: narrow ? 48 : 54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.dest,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });
  final _Dest dest;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    const radius = BorderRadius.vertical(bottom: Radius.circular(Radii.md));
    return Tooltip(
      message: dest.label,
      excludeFromSemantics: true,
      child: Semantics(
        selected: selected,
        button: true,
        label: dest.label,
        excludeSemantics: true,
        child: Transform.translate(
          // Tucks the tab under the bar's top rule.
          offset: const Offset(0, -2),
          child: Material(
            color: selected ? s.raised : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: selected
                  ? BorderSide(color: s.line2, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: SizedBox(
                height: 54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? dest.iconOn : dest.icon,
                      size: 20,
                      color: selected ? s.accentText : s.ink3,
                    ),
                    const SizedBox(height: Gap.s1),
                    Text(
                      dest.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: s.button(fontSize, selected ? s.ink : s.ink3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onAdd, required this.label, this.size = 54});
  final VoidCallback onAdd;
  final String label;
  final double size;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final edge = _down ? 1.0 : 4.0;
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        label: widget.label,
        excludeSemantics: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onAdd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: EdgeInsets.only(top: 4 - edge, bottom: edge),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: s.star,
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: [
                BoxShadow(color: s.starDeep, offset: Offset(0, edge)),
              ],
            ),
            child: Icon(Ph.plusBold, size: 24, color: s.onStar),
          ),
        ),
      ),
    );
  }
}

/// The 220px sidebar on Mac, iPad and wide windows.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.settings,
    required this.onSelect,
    required this.onAdd,
    required this.addLabel,
  });
  final int index;
  final bool settings;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    Widget item(String label, IconData icon, IconData iconOn, bool on, tap) =>
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.s2),
          child: Semantics(
            selected: on,
            button: true,
            child: Material(
              color: on ? s.raised : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(Radii.md),
                ),
                side: on
                    ? BorderSide(color: s.line2, width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(Radii.md),
                ),
                onTap: tap,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        on ? iconOn : icon,
                        size: 20,
                        color: on ? s.accentText : s.ink3,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: s.button(15, on ? s.ink : s.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: s.line2, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 16),
            child: Align(alignment: Alignment.centerLeft, child: Wordmark()),
          ),
          const SizedBox(height: Gap.s8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PrimaryButton(
              label: addLabel,
              icon: Ph.plusBold,
              height: 46,
              fontSize: 15,
              onPressed: onAdd,
            ),
          ),
          const SizedBox(height: Gap.s7),
          for (final (i, d) in _destinations.indexed)
            item(d.label, d.icon, d.iconOn, i == index, () => onSelect(i)),
          const Spacer(),
          item(
            'Settings',
            Ph.gearSix,
            Ph.gearSixFill,
            settings,
            () => goToSettings(context),
          ),
          const Align(alignment: Alignment.centerLeft, child: SyncBadge()),
        ],
      ),
    );
  }
}
