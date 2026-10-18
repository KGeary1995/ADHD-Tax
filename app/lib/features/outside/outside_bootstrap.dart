import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart' show routerProvider;
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../capture/quick_add_sheet.dart';
import '../picker/picker_controller.dart';
import '../picker/picker_engine.dart';
import 'android_bridge.dart';

/// Acts on shares and widget taps, and keeps the home-screen widget
/// showing the current pick.
class OutsideBootstrap extends ConsumerStatefulWidget {
  const OutsideBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<OutsideBootstrap> createState() => _OutsideBootstrapState();
}

class _OutsideBootstrapState extends ConsumerState<OutsideBootstrap> {
  StreamSubscription<OutsideRequest>? _sub;
  Timer? _debounce;
  String? _lastWidget;

  @override
  void initState() {
    super.initState();
    // After the first frame, so the router's navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sub = ref.read(androidBridgeProvider).requests.listen(_handle);
      _pushWidget();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _handle(OutsideRequest r) {
    final router = ref.read(routerProvider);
    final nav = router.routerDelegate.navigatorKey.currentContext;
    switch (r) {
      case SharedText():
        if (nav == null) return;
        final t = taskFromShare(r);
        showQuickAdd(nav, initialTitle: t.title, initialNotes: t.notes);
      case OpenRoute(route: '/add'):
        if (nav != null) showQuickAdd(nav);
      case OpenRoute(:final route) when route.startsWith('/focus/'):
        router.push(route);
      case OpenRoute(:final route):
        router.go(route);
    }
  }

  /// The widget mirrors Home's teal card.
  void _pushWidget() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final result = ref.read(pickResultProvider);
      final s = result.suggestion;
      final data = s == null
          ? {
              'empty': result.noPickReason == NoPickReason.noOpenTasks
                  ? 'Your list is empty. Tap + to add something.'
                  : 'Nothing fits right now. Open Unstuck to change your situation.',
            }
          : {
              ..._cardData(s),
              // The large widget's "Next up": two more that fit now.
              for (final (i, alt)
                  in ref
                      .read(nextUpProvider)
                      .where((x) => x.task.id != s.task.id)
                      .take(2)
                      .indexed)
                ..._altData(i + 1, alt),
            };
      final key = data.toString();
      if (key == _lastWidget) return;
      _lastWidget = key;
      ref.read(androidBridgeProvider).updateWidget(data);
    });
  }

  Map<String, String> _altData(int n, Suggestion s) => {
    'alt${n}Title': s.task.title,
    'alt${n}Meta': taskFacts(
      s.task,
      plannedMin: s.isChunk ? s.plannedMin : null,
    ).take(3).join(' · '),
    'alt${n}Route': _focusRoute(s),
  };

  String _focusRoute(Suggestion s) => Uri(
    path: '/focus/${s.task.id}',
    queryParameters: {'min': '${s.plannedMin}'},
  ).toString();

  Map<String, String> _cardData(Suggestion s) {
    final t = s.task;
    final time = s.isChunk
        ? '${s.plannedMin} of ${t.estimateMin} min'
        : formatMinutes(s.plannedMin);
    final due = t.dueAt == null
        ? ''
        : ' · due ${formatDue(t.dueAt!, DateTime.now())}';
    return {
      'title': t.title,
      'step': t.firstStep.trim().isEmpty ? '' : 'First: ${t.firstStep.trim()}',
      'meta': '${t.workspace.label} · $time$due',
      'startRoute': _focusRoute(s),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pickResultProvider, (_, _) => _pushWidget());
    ref.listen(nextUpProvider, (_, _) => _pushWidget());
    return widget.child;
  }
}
