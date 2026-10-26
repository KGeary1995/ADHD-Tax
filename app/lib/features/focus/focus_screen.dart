import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models/task.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import '../gamification/progress_controller.dart';
import '../reminders/reminders.dart';
import '../settings/settings_controller.dart';
import '../tasks/tasks_controller.dart';
import 'company.dart';
import 'company_widgets.dart';
import '../motivation/quote_rotator.dart';
import '../motivation/quote_service.dart';
import 'hold_me.dart';
import 'started_view.dart';
import 'timers.dart';
import '../../core/theme/ph.dart';

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

  /// "A new star." shows for the first moments, then the timer.
  bool _intro = true;
  int _startXp = 0;
  Timer? _introTimer;

  /// The checklist drawer at the bottom is open.
  bool _check = false;

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
      final started = ref
          .read(progressProvider.notifier)
          .recordStart(task, panic: widget.panic);
      final level = ref.read(settingsProvider).celebration;
      if (level == CelebrationLevel.off) {
        setState(() => _intro = false);
      } else {
        setState(() => _startXp = started.award.total);
        _introTimer = Timer(
          Duration(milliseconds: context.reduceMotion ? 1200 : 2600),
          _endIntro,
        );
      }
      _syncNotification();
      _ambient.play(ref.read(companyProvider).sound);
    });
  }

  void _endIntro() {
    _introTimer?.cancel();
    if (mounted && _intro) setState(() => _intro = false);
  }

  @override
  void dispose() {
    _introTimer?.cancel();
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
      builder: (ctx) => _FocusDialog(
        title: firstFive ? '5 minutes done.' : "Time's up.",
        body: firstFive
            ? "You started. That was the hard part. Keep going while you're "
                  'in it?'
            : 'Nice work. Finished, or want a little more?',
        children: firstFive
            ? [
                PrimaryButton(
                  label: 'Keep going',
                  onPressed: () => Navigator.pop(ctx, 'keep'),
                ),
                const SizedBox(height: Gap.s4),
                OutlineButton(
                  label: 'Stop here, that counts',
                  quiet: true,
                  fontSize: 15,
                  onPressed: () => Navigator.pop(ctx, 'stop'),
                ),
              ]
            : [
                PrimaryButton(
                  label: 'Finished',
                  onPressed: () => Navigator.pop(ctx, 'done'),
                ),
                const SizedBox(height: Gap.s4),
                Row(
                  children: [
                    Expanded(
                      child: OutlineButton(
                        label: '+10 min',
                        fontSize: 15,
                        onPressed: () => Navigator.pop(ctx, 'more'),
                      ),
                    ),
                    const SizedBox(width: Gap.s4),
                    Expanded(
                      child: OutlineButton(
                        label: 'Stop for now',
                        quiet: true,
                        fontSize: 15,
                        onPressed: () => Navigator.pop(ctx, 'stop'),
                      ),
                    ),
                  ],
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
          sessionMin: worked,
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
      builder: (ctx) => _FocusDialog(
        title: 'Stop this session?',
        body: 'Whatever you did still counts. The task stays on your list.',
        children: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Keep going',
                  fontSize: 16,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: Gap.s4),
              Expanded(
                child: OutlineButton(
                  label: 'Stop',
                  quiet: true,
                  fontSize: 16,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok == true) _stop();
  }

  Future<void> _holdMe(Task task) => showAppSheet<void>(
    context: context,
    builder: (ctx) {
      final s = ctx.spec;
      final message = holdMeMessage(task, _target.inMinutes);
      return SafeArea(
        child: SingleChildScrollView(
          padding: sheetPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(
                'Hold me to it',
                subtitle:
                    "Send a friend what you're starting. Saying it out loud "
                    'helps.',
              ),
              const SizedBox(height: Gap.s6),
              Panel(
                color: Colors.transparent,
                borderColor: s.line2,
                padding: const EdgeInsets.all(16),
                child: Text(
                  '“$message”',
                  style: TextStyle(fontSize: 15, height: 1.45, color: s.ink),
                ),
              ),
              const SizedBox(height: Gap.s6),
              Builder(
                builder: (bctx) => PrimaryButton(
                  label: 'Share',
                  icon: Ph.shareFat,
                  onPressed: () {
                    final box = bctx.findRenderObject() as RenderBox?;
                    ref.read(shareTextProvider)(
                      message,
                      box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    );
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _toggleStep(Task task, int i) {
    ref.read(tasksProvider.notifier).toggleStep(task.id, i);
    // The shade shows the step too.
    _syncNotification();
  }

  /// The checklist (and notes) in a sheet, on a small phone.
  Future<void> _checklistSheet() => showAppSheet<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final task = ref
            .watch(tasksProvider)
            .where((t) => t.id == widget.taskId)
            .firstOrNull;
        if (task == null) return const SizedBox.shrink();
        return SafeArea(
          child: SingleChildScrollView(
            padding: sheetPadding,
            child: _ChecklistBody(
              task: task,
              onToggle: (i) => _toggleStep(task, i),
            ),
          ),
        );
      },
    ),
  );

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
        backgroundColor: Colors.transparent,
        appBar: AppBar(),
        body: const Center(child: Text('That task no longer exists.')),
      );
    }
    final paused = _runningSince == null;
    final company = ref.watch(companyProvider);
    final blocks = ref.watch(settingsProvider.select((x) => x.timerBlocks));
    final steps = task.steps;
    final nextIndex = steps.indexWhere((i) => !i.done);
    final stepLabel = steps.isEmpty
        ? (task.nextStep.isNotEmpty ? 'FIRST STEP' : 'NOW')
        : nextIndex < 0
        ? 'ALL ${steps.length} STEPS TICKED'
        : 'STEP ${nextIndex + 1} OF ${steps.length}';
    final session = widget.justFive && !_keptGoing
        ? 'Just 5 minutes'
        : '${_target.inMinutes}-minute session';
    final hasDrawer = steps.isNotEmpty || task.notes.trim().isNotEmpty;

    Widget focus(BoxConstraints c) {
      final small = c.maxHeight < 700 || c.maxWidth < 380;
      // The open checklist takes the timer's room: small digits instead.
      final compactTimer = _check && !small;
      final radius = small ? 82.0 : math.min(140.0, (c.maxWidth - 60) / 2);
      final ctl = small ? 52.0 : 60.0;
      final Widget timer = compactTimer
          ? Column(
              children: [
                Text(clockText(_remaining), style: s.timer(56)),
                const SizedBox(height: Gap.s3),
                Text(
                  timerCaption(_remaining, _target, paused),
                  style: s.caption(),
                ),
              ],
            )
          : blocks
          ? BlockTimer(
              remaining: _remaining,
              total: _target,
              small: small,
              paused: paused,
            )
          : OrbitTimer(
              remaining: _remaining,
              total: _target,
              radius: radius,
              paused: paused,
            );
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Stop',
                  icon: Icon(Ph.x, size: 22, color: s.ink2),
                  onPressed: _confirmStop,
                ),
                Expanded(
                  child: Text(
                    small ? session : '${task.workspace.label} · $session',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: s.ink3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Hold me to it',
                  icon: Icon(Ph.handHeart, size: 21, color: s.ink2),
                  onPressed: () => _holdMe(task),
                ),
                IconButton(
                  tooltip: 'Company',
                  icon: Icon(
                    company.any ? Ph.headphonesFill : Ph.headphones,
                    size: 21,
                    color: company.any ? s.accentText : s.ink2,
                  ),
                  onPressed: _openCompany,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                SizedBox(height: small ? 10 : 16),
                Text(stepLabel, style: s.overline(color: s.accentText)),
                const SizedBox(height: Gap.s4),
                Text(
                  task.startLine,
                  textAlign: TextAlign.center,
                  style: s.display(small ? 22 : 26),
                ),
                if (task.startLine != task.title) ...[
                  const SizedBox(height: Gap.s3),
                  Text(
                    task.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: s.ink2),
                  ),
                ],
                if (nextIndex >= 0) ...[
                  SizedBox(height: small ? 10 : 12),
                  _StepDoneButton(
                    onPressed: () {
                      _toggleStep(task, nextIndex);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Step done.')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: small ? 14 : 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s7),
            child: Stack(
              alignment: Alignment.center,
              children: [
                timer,
                if (company.buddy && !blocks && !compactTimer)
                  IgnorePointer(
                    child: _BuddyStar(radius: radius - 16, elapsed: _elapsed),
                  ),
              ],
            ),
          ),
          SizedBox(height: small ? 12 : 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SquareControl(
                tooltip: paused ? 'Resume' : 'Pause',
                size: ctl,
                onPressed: _togglePause,
                child: Icon(paused ? Ph.play : Ph.pause, size: 22),
              ),
              const SizedBox(width: Gap.s5),
              _SquareControl(
                tooltip: 'Add 5 minutes',
                size: ctl,
                onPressed: () => _addTime(5),
                child: Text('+5', style: s.button(15, s.ink)),
              ),
              const SizedBox(width: Gap.s5),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: PrimaryButton(
                  label: 'Done',
                  icon: Ph.checkBold,
                  height: ctl,
                  expand: false,
                  onPressed: _complete,
                ),
              ),
            ],
          ),
          if (company.buddy)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: BuddyLine(elapsed: _elapsed),
            ),
          // A dry line to keep you company; left out when space is short.
          if (!small && !(_check && hasDrawer))
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
              child: QuoteRotator(
                context: QuoteContext.focus,
                footnote: true,
                align: TextAlign.center,
              ),
            ),
          const Spacer(),
          if (hasDrawer)
            _ChecklistDrawer(
              task: task,
              open: _check && !small,
              onTap: small
                  ? _checklistSheet
                  : () => setState(() => _check = !_check),
              onToggle: (i) => _toggleStep(task, i),
            ),
          const SizedBox(height: Gap.s6),
        ],
      );
    }

    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _intro ? _endIntro() : _confirmStop();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _togglePause,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: AnimatedSwitcher(
                duration: Duration(
                  milliseconds: context.reduceMotion ? 0 : 500,
                ),
                child: _intro
                    ? GestureDetector(
                        key: const ValueKey('started'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _endIntro,
                        child: StartedView(
                          xp: _startXp,
                          next: task.nextStep,
                          rings:
                              ref.read(settingsProvider).celebration !=
                              CelebrationLevel.subtle,
                        ),
                      )
                    : LayoutBuilder(
                        key: const ValueKey('focus'),
                        builder: (context, c) => CustomScrollView(
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: ContentWidth(
                                maxWidth: 560,
                                child: focus(c),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stop, time's up: a confirmation with a title, a line, and buttons.
class _FocusDialog extends StatelessWidget {
  const _FocusDialog({
    required this.title,
    required this.body,
    required this.children,
  });
  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: s.display(24)),
              const SizedBox(height: Gap.s3),
              Text(
                body,
                style: TextStyle(fontSize: 15, height: 1.45, color: s.ink2),
              ),
              const SizedBox(height: Gap.s7),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDoneButton extends StatelessWidget {
  const _StepDoneButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(color: s.line2, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(
          fontFamily: Fonts.ui,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: const Icon(Ph.check, size: 16),
      label: const Text('Step done'),
    );
  }
}

/// Pause and +5: ink-outlined squares.
class _SquareControl extends StatelessWidget {
  const _SquareControl({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    required this.size,
  });
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: BorderSide(color: s.ink, width: 2),
    );
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: IconTheme(
              data: IconThemeData(color: s.ink),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Checklist · 2 of 4": pinned at the bottom, opens upward.
class _ChecklistDrawer extends StatelessWidget {
  const _ChecklistDrawer({
    required this.task,
    required this.open,
    required this.onTap,
    required this.onToggle,
  });
  final Task task;
  final bool open;
  final VoidCallback onTap;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final steps = task.steps;
    final label = steps.isEmpty
        ? 'Notes'
        : 'Checklist · ${steps.where((i) => i.done).length + (steps.any((i) => !i.done) ? 1 : 0)} of ${steps.length}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gap.s7),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: s.line, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: s.ink,
                        ),
                      ),
                    ),
                    Icon(
                      open ? Ph.caretDown : Ph.caretUp,
                      size: 18,
                      color: s.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: _ChecklistBody(task: task, onToggle: onToggle),
            ),
        ],
      ),
    );
  }
}

class _ChecklistBody extends StatelessWidget {
  const _ChecklistBody({required this.task, required this.onToggle});
  final Task task;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final steps = task.steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          InkWell(
            onTap: () => onToggle(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  _MiniCheck(done: steps[i].done),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[i].text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: steps[i].done ? s.ink3 : s.ink,
                        decoration: steps[i].done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: s.ink3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (task.notes.trim().isNotEmpty) ...[
          if (steps.isNotEmpty) const SizedBox(height: 12),
          Text(
            task.notes.trim(),
            style: TextStyle(fontSize: 15, height: 1.45, color: s.ink2),
          ),
        ],
      ],
    );
  }
}

class _MiniCheck extends StatelessWidget {
  const _MiniCheck({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Semantics(
      checked: done,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: done ? s.star : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: done ? s.star : s.ink3, width: 2),
        ),
        child: done ? Icon(Ph.checkBold, size: 12, color: s.onStar) : null,
      ),
    );
  }
}

/// The buddy: a second, smaller star on the inner ring, keeping its own
/// pace.
class _BuddyStar extends StatelessWidget {
  const _BuddyStar({required this.radius, required this.elapsed});
  final double radius;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final secs = context.reduceMotion
        ? elapsed.inMinutes * 60
        : elapsed.inSeconds;
    // Once round every 17 minutes, starting opposite yours.
    final a = math.pi / 2 + secs / (17 * 60) * 2 * math.pi;
    return SizedBox.square(
      dimension: radius * 2 + 10,
      child: Align(
        alignment: Alignment(math.cos(a), math.sin(a)),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s.ink2,
            boxShadow: [BoxShadow(color: s.ink3, blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}
