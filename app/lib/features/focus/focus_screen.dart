import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/task_chips.dart';
import '../gamification/progress_controller.dart';
import '../motivation/quote_rotator.dart';
import '../motivation/quote_service.dart';
import '../tasks/tasks_controller.dart';
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

  Duration get _elapsed => _runningSince == null
      ? _banked
      : _banked + _now().difference(_runningSince!);

  Duration get _remaining => _target - _elapsed;

  int get _minutesWorked => math.max(1, (_elapsed.inSeconds / 60).ceil());

  @override
  void initState() {
    super.initState();
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
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    if (!_prompted && _remaining <= Duration.zero && _runningSince != null) {
      _prompted = true;
      SystemSound.play(SystemSoundType.alert);
      _timeUp();
    }
  }

  void _togglePause() {
    setState(() {
      if (_runningSince == null) {
        _runningSince = _now();
      } else {
        _banked = _elapsed;
        _runningSince = null;
      }
    });
  }

  void _addTime(int min) => setState(() {
    _target += Duration(minutes: min);
    if (_remaining > Duration.zero) _prompted = false;
  });

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
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: Text('That task no longer exists.')),
      );
    }
    final paused = _runningSince == null;
    final hasStep = task.firstStep.trim().isNotEmpty;

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
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                tooltip: 'Stop',
                icon: const Icon(Icons.close),
                onPressed: _confirmStop,
              ),
              title: Text(
                widget.justFive && !_keptGoing ? 'Just 5 minutes' : 'Focus',
                style: TextStyle(color: s.muted, fontSize: 16),
              ),
              centerTitle: true,
            ),
            body: LayoutBuilder(
              builder: (context, c) {
                final timerSize = math.min(
                  320.0,
                  math.min(c.maxWidth - 48, c.maxHeight * 0.42),
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: ContentWidth(
                    maxWidth: 640,
                    child: Column(
                      children: [
                        Text(
                          hasStep ? 'FIRST STEP' : 'NOW',
                          style: TextStyle(
                            letterSpacing: 2,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: s.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.startLine,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: s.onSurface,
                          ),
                        ),
                        if (hasStep) ...[
                          const SizedBox(height: 6),
                          Text(
                            task.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: s.muted),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Center(child: TaskChips(task: task)),
                        const SizedBox(height: 24),
                        VisualTimer(
                          remaining: _remaining,
                          total: _target,
                          size: timerSize,
                          paused: paused,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _togglePause,
                              icon: Icon(
                                paused ? Icons.play_arrow : Icons.pause,
                              ),
                              label: Text(paused ? 'Resume' : 'Pause'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _addTime(5),
                              icon: const Icon(Icons.add),
                              label: const Text('5 min'),
                            ),
                            FilledButton.icon(
                              onPressed: _complete,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text(
                                'Done!',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        const QuoteRotator(
                          context: QuoteContext.focus,
                          align: TextAlign.center,
                        ),
                        if (task.notes.trim().isNotEmpty) ...[
                          const SizedBox(height: 24),
                          ExpansionTile(
                            title: const Text('Notes'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(task.notes),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
