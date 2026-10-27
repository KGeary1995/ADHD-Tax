import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart' show openFromOutside, routerProvider;
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../core/providers.dart';
import '../../microsoft/microsoft_auth.dart' show authRedirects;
import '../capture/quick_add_sheet.dart';
import '../gamification/progress_controller.dart';
import '../gamification/xp_rules.dart';
import '../picker/picker_controller.dart';
import '../picker/picker_engine.dart';
import 'device_bridge.dart';

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
  late final AppLifecycleListener _lifecycle;
  Timer? _pickerRefresh;
  Timer? _dayPart;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(deviceBridgeProvider).poll();
        // Time passed while the app was away; see pickerTickProvider.
        ref.invalidate(pickerTickProvider);
        ref.invalidate(dayPartProvider);
      },
    );
    ref.listenManual(
      dayPartProvider,
      (_, now) => _scheduleDayPart(now),
      fireImmediately: true,
    );
    ref.listenManual(
      pickerTickProvider,
      (_, tick) => _schedulePickerRefresh(tick.now, tick.next),
      fireImmediately: true,
    );
    quickAddRequested.addListener(_quickAddFromRoute);
    // After the first frame, so the router's navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sub = ref.read(deviceBridgeProvider).requests.listen(_handle);
      _pushWidget();
      _quickAddFromRoute();
    });
  }

  void _quickAddFromRoute() {
    if (!quickAddRequested.value || !mounted) return;
    final nav = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (nav == null) return;
    quickAddRequested.value = false;
    showQuickAdd(nav);
  }

  /// Looks at the picks again when time makes a task eligible (see
  /// [pickerTickProvider]).
  void _schedulePickerRefresh(DateTime now, DateTime next) {
    _pickerRefresh?.cancel();
    _pickerRefresh = Timer(
      next.difference(now) + const Duration(milliseconds: 500),
      () {
        if (mounted) ref.invalidate(pickerTickProvider);
      },
    );
  }

  /// Moves Home on to the next part of the day ([dayPartProvider]).
  void _scheduleDayPart(DateTime now) {
    _dayPart?.cancel();
    _dayPart = Timer(
      nextDayPart(now).difference(now) + const Duration(milliseconds: 500),
      () {
        if (mounted) ref.invalidate(dayPartProvider);
      },
    );
  }

  @override
  void dispose() {
    _pickerRefresh?.cancel();
    _dayPart?.cancel();
    _lifecycle.dispose();
    quickAddRequested.removeListener(_quickAddFromRoute);
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
      case OpenRoute(:final route):
        openFromOutside(router, route);
      case AuthRedirect(:final url):
        // Nobody waiting (the app restarted mid sign-in): nothing to do.
        authRedirects.add(url);
    }
  }

  /// The widget mirrors Today's pick. `meta`/`step` are what widgets drawn
  /// by builds before 1.1 read; the rest is the 1.1 layout's.
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
                  : 'Nothing fits right now. Open Gumption to change your situation.',
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
      final streak = streakWithGrace(
        ref.read(progressProvider).activeDays,
        ref.read(clockProvider)(),
      );
      if (streak > 0) {
        data['streak'] = '$streak ${streak == 1 ? 'day' : 'days'}';
      }
      final key = data.toString();
      if (key == _lastWidget) return;
      _lastWidget = key;
      ref.read(deviceBridgeProvider).updateWidget(data);
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

  /// [justFive] is the "Just 5 minutes" start: five minutes with the
  /// Keep going / Stop here ending, as from Today.
  String _focusRoute(Suggestion s, {bool justFive = false}) => Uri(
    path: '/focus/${s.task.id}',
    queryParameters: {
      'min': justFive ? '5' : '${s.plannedMin}',
      if (justFive) 'five': '1',
    },
  ).toString();

  Map<String, String> _cardData(Suggestion s) {
    final t = s.task;
    final time = s.isChunk
        ? '${s.plannedMin} of ${t.estimateMin} min'
        : formatMinutes(s.plannedMin);
    final due = t.dueAt == null
        ? ''
        : ' · due ${formatDue(t.dueAt!, DateTime.now())}';
    // The step you're on and the one after it, like Today's card.
    final steps = t.steps;
    final current = steps.indexWhere((i) => !i.done);
    final lines = steps.isEmpty
        ? [if (t.nextStep.isNotEmpty) t.nextStep]
        : [
            for (final i in steps.skip(current < 0 ? steps.length : current))
              if (!i.done) i.text,
          ];
    return {
      'title': t.title,
      'step': t.nextStep.isEmpty ? '' : 'First: ${t.nextStep}',
      'meta': '${t.workspace.label} · $time$due',
      'startRoute': _focusRoute(s),
      'header': steps.isEmpty || current < 0
          ? t.workspace.label
          : '${t.workspace.label} · Step ${current + 1} of ${steps.length}',
      'work': t.workspace == Workspace.work ? '1' : '0',
      'length': time,
      if (lines.isNotEmpty) 'line1': lines[0],
      if (lines.length > 1) 'line2': lines[1],
      'fiveRoute': _focusRoute(s, justFive: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pickResultProvider, (_, _) => _pushWidget());
    ref.listen(nextUpProvider, (_, _) => _pushWidget());
    return widget.child;
  }
}
