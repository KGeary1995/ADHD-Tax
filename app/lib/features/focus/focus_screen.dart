import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import '../gamification/progress_controller.dart';
import '../motivation/quote_rotator.dart';
import '../motivation/quote_service.dart';
import '../reminders/reminders.dart';
import '../settings/settings_controller.dart';
import '../tasks/checklist_editor.dart';
import '../tasks/tasks_controller.dart';
import 'company.dart';
import 'company_widgets.dart';
import 'visual_timer.dart';

/// The Start screen: only the first step, a visual timer, and a quote.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({
    super.key,
    required this.taskId,
    required this.minutes,
    this.justFive = false,
    this.panic = false,
  });

  final String taskId;
  final int minutes;
  final bool justFive;
  final bool panic;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  late Duration _target = Duration(minutes: widget.minutes);
  Duration _banked = Duration.zero;
  DateTime? _runningSince;
  Timer? _tick;
  bool _keptGoing = false;
  bool _prompted = false;
  bool _finished = false;

  DateTime _now() => ref.read(clockProvider)();

  // Read up front: dispose() can't use ref.
  late final Reminders _reminders;
  late final bool _alerts;
  late final AmbientPlayer _ambient;

  Duration get _elapsed => _runningSince == null
      ? _banked
      : _banked + _now().difference(_runningSince!);

  Duration get _remaining => _target - _elapsed;

  int get _minutesWorked => math.max(1, (_elapsed.inSeconds / 60).ceil());

  @override
  void initState() {
    super.initState();
    _reminders = ref.read(remindersProvider);
    _alerts = ref.read(settingsProvider).timerAlerts;
    _ambient = ref.read(ambientPlayerProvider);
    _runningSince = _now();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final task = ref.read(tasksProvider.notifier).byId(widget.taskId);
      if (task == null) return;
      ref.read(tasksProvider.notifier).markStarted(task.id);
      // XP for starting — the hard part — before any work is done.
      ref
          .read(progressProvider.notifier)
          .recordStart(task, panic: widget.panic);
      _syncNotification();
      _ambient.play(ref.read(companyProvider).sound);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ambient.stop();
    if (_alerts) _reminders.focusEnded();
    super.dispose();
  }

  /// Mirrors the timer in the notification shade, with a "time's up" alert
  /// that still arrives if you've switched to another app.
  void _syncNotification() {
    if (!_alerts || _finished) return;
    final task = ref.read(tasksProvider.notifier).byId(widget.taskId);
    if (task == null) return;
    if (_runningSince == null) {
      _reminders.focusPaused(title: task.startLine, left: _remaining);
    } else {
      _reminders.focusRunning(
        title: task.startLine,
        endsAt: DateTime.now().add(_remaining),
      );
    }
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    if (!_prompted && _remaining <= Duration.zero && _runningSince != null) {
      _prompted = true;
      SystemSound.play(SystemSoundType.alert);
      if (_alerts) {
        // Looking at the app: the dialog is the alert, so drop the
        // notification. In the background, the notification is how you
        // find out, so leave it.
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed
            ? _reminders.focusEnded()
            : _reminders.focusTimeUp();
      }
      _timeUp();
    }
  }

  void _togglePause() {
    setState(() {
      if (_runningSince == null) {
        _runningSince = _now();
        _ambient.resume();
      } else {
        _banked = _elapsed;
        _runningSince = null;
        _ambient.pause();
      }
    });
    _syncNotification();
  }

  void _addTime(int min) {
    setState(() {
      _target += Duration(minutes: min);
      if (_remaining > Duration.zero) _prompted = false;
    });
    _syncNotification();
  }

  Future<void> _openCompany() async {
    await showCompanySheet(context);
    if (!mounted) return;
    // Paused stays quiet until Resume.
    final sound = ref.read(companyProvider).sound;
    await _ambient.play(sound);
    if (_runningSince == null) await _ambient.pause();
  }

  Future<void> _timeUp() async {
    final task = ref.read(tasksProvider.notifier).byId(widget.taskId);
    if (task == null) return;
    final firstFive = widget.justFive && !_keptGoing;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(firstFive ? '5 minutes done!' : "Time's up"),
        content: Text(
          firstFive
              ? "You started. That was the hard part. Want to keep going while you're in it?"
              : 'Nice work. Finished, or want a little more time?',
        ),
        actions: firstFive
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'stop'),
                  child: const Text('Stop here — that counts'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'keep'),
                  child: const Text('Keep going'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'stop'),
                  child: const Text('Stop for now'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'more'),
                  child: const Text('+10 min'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'done'),
                  child: const Text('Done!'),
                ),
              ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'keep':
        setState(() {
          _keptGoing = true;
          final rest = math.max(10, task.estimateMin - 5);
          _target = _elapsed + Duration(minutes: rest);
          _prompted = false;
        });
        _syncNotification();
      case 'more':
        _addTime(10);
      case 'done':
        _complete();
      default:
        _stop();
    }
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    final tasks = ref.read(tasksProvider.notifier);
    final task = tasks.byId(widget.taskId);
    if (task == null) {
      _leave();
      return;
    }
    final worked = _minutesWorked;
    tasks.complete(task.id, minutesWorked: worked);
    ref
        .read(progressProvider.notifier)
        .recordCompletion(
          task,
          actualMin: (task.actualMin ?? 0) + worked,
          keptGoingAfterFive: _keptGoing,
        );
    _leave();
  }

  void _stop() {
    if (_finished) return;
    _finished = true;
    final tasks = ref.read(tasksProvider.notifier);
    final task = tasks.byId(widget.taskId);
    if (task != null && _elapsed.inSeconds >= 60) {
      final worked = _minutesWorked;
      tasks.pause(task.id, minutesWorked: worked);
      ref
          .read(progressProvider.notifier)
          .recordPartial(task, worked, keptGoingAfterFive: _keptGoing);
    }
    _leave();
  }

  void _leave() {
    _tick?.cancel();
    if (_alerts) _reminders.focusEnded();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _confirmStop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop this session?'),
        content: const Text(
          "Whatever you did still counts. The task stays on your list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (ok == true) _stop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final task = ref.watch(
      tasksProvider.select(
        (l) => l.where((t) => t.id == widget.taskId).firstOrNull,
      ),
    );
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('That task no longer exists.')),
      );
    }
    final paused = _runningSince == null;
    final company = ref.watch(companyProvider);
    final hasStep = task.nextStep.isNotEmpty;
    final steps = task.steps;
    final nextIndex = steps.indexWhere((i) => !i.done);
    final stepLabel = steps.isEmpty
        ? (hasStep ? 'First step' : 'Now')
        : nextIndex < 0
        ? 'All ${steps.length} steps ticked'
        : 'Step ${nextIndex + 1} of ${steps.length}';
    final session = widget.justFive && !_keptGoing
        ? 'Just 5 minutes'
        : '${task.workspace.label} · ${_target.inMinutes} min session';

    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _togglePause,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  final timerSize = math.min(
                    290.0,
                    math.min(c.maxWidth - 80, c.maxHeight * 0.38),
                  );
                  return CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: ContentWidth(
                          maxWidth: 560,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 6, 18, 0),
                                child: Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Stop',
                                      iconSize: 24,
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: _confirmStop,
                                    ),
                                    Expanded(
                                      child: Text(
                                        session,
                                        textAlign: TextAlign.right,
                                        style: s.mono(
                                          13,
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Company',
                                      isSelected: company.any,
                                      selectedIcon: Icon(
                                        Icons.headphones_rounded,
                                        color: s.primary,
                                      ),
                                      icon: const Icon(
                                        Icons.headphones_outlined,
                                      ),
                                      onPressed: _openCompany,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  18,
                                  28,
                                  0,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      stepLabel,
                                      style: s.mono(
                                        13,
                                        color: s.primary,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      task.startLine,
                                      textAlign: TextAlign.center,
                                      style: s.display(30),
                                    ),
                                    if (hasStep) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        task.title,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: s.muted,
                                        ),
                                      ),
                                    ],
                                    if (nextIndex >= 0) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          ref
                                              .read(tasksProvider.notifier)
                                              .toggleStep(task.id, nextIndex);
                                          // The shade shows the step too.
                                          _syncNotification();
                                        },
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text('Step done'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              VisualTimer(
                                remaining: _remaining,
                                total: _target,
                                size: timerSize,
                                paused: paused,
                              ),
                              const SizedBox(height: 34),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _RoundButton(
                                    tooltip: paused ? 'Resume' : 'Pause',
                                    onPressed: _togglePause,
                                    child: Icon(
                                      paused
                                          ? Icons.play_arrow_rounded
                                          : Icons.pause_rounded,
                                      size: 26,
                                    ),
                                  ),
                                  _RoundButton(
                                    tooltip: 'Add 5 minutes',
                                    onPressed: () => _addTime(5),
                                    child: Text(
                                      '+5',
                                      style: s.mono(
                                        15,
                                        color: s.onSurface,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _complete,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 64),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 30,
                                      ),
                                      textStyle: const TextStyle(
                                        fontFamily: Fonts.ui,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Done'),
                                  ),
                                ],
                              ),
                              if (company.buddy)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    22,
                                    24,
                                    0,
                                  ),
                                  child: BuddyLine(elapsed: _elapsed),
                                ),
                              if (steps.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    0,
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      title: Text(
                                        'Checklist · ${stepsProgress(steps)}',
                                      ),
                                      children: [
                                        for (var i = 0; i < steps.length; i++)
                                          ChecklistRow(
                                            item: steps[i],
                                            onToggle: () {
                                              ref
                                                  .read(tasksProvider.notifier)
                                                  .toggleStep(task.id, i);
                                              _syncNotification();
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (task.notes.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    0,
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      title: const Text('Notes'),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(task.notes),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 32),
                              const Spacer(),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(32, 0, 32, 32),
                                child: QuoteRotator(
                                  context: QuoteContext.focus,
                                  align: TextAlign.center,
                                  quiet: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: s.surface,
        shape: CircleBorder(
          side: s.isDark ? BorderSide(color: s.outline) : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 64,
            child: IconTheme(
              data: IconThemeData(color: s.onSurface),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
