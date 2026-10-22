import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../gamification/progress_controller.dart';
import '../settings/device_workspaces.dart';
import 'tasks_controller.dart';
import 'weekly_reset.dart';

/// When this device last finished a weekly reset. Device-local.
final lastResetProvider = NotifierProvider<LastResetController, DateTime?>(
  LastResetController.new,
);

class LastResetController extends Notifier<DateTime?> {
  static const _key = 'reset.lastAt';

  @override
  DateTime? build() =>
      DateTime.tryParse(ref.read(keyValueStoreProvider).read(_key) ?? '');

  void done(DateTime at) {
    ref.read(keyValueStoreProvider).write(_key, at.toIso8601String());
    state = at;
  }
}

/// XP for getting through the weekly reset.
const resetXp = 20;

enum _Choice { keep, shrink, snooze, drop }

/// One stale task at a time: keep it, make it smaller, snooze it, or let
/// it go. No wrong answers and nothing shouted about.
class WeeklyResetScreen extends ConsumerStatefulWidget {
  const WeeklyResetScreen({super.key});

  @override
  ConsumerState<WeeklyResetScreen> createState() => _WeeklyResetScreenState();
}

class _WeeklyResetScreenState extends ConsumerState<WeeklyResetScreen> {
  // Snapshot: deciding about one task mustn't reshuffle the rest.
  late final List<Task> _queue;
  var _pos = 0;
  final _history = <(Task, _Choice, int)>[];
  bool _finished = false;

  DateTime _now() => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    _queue = staleTasks(ref.read(tasksProvider), _now());
  }

  void _choose(Task t, _Choice c) {
    final tasks = ref.read(tasksProvider.notifier);
    final now = _now();
    // Finished or deleted meanwhile (e.g. on another device): leave it.
    final fresh = tasks.byId(t.id);
    if (fresh != null && fresh.isOpen) {
      switch (c) {
        case _Choice.keep:
          tasks.save(fresh.copyWith(reviewedAt: now));
        case _Choice.shrink:
          tasks.save(fresh.copyWith(reviewedAt: now));
          context.push('/task/${t.id}?focusFirstStep=1');
        case _Choice.snooze:
          tasks.save(
            fresh.copyWith(
              reviewedAt: now,
              scheduledStart: now.add(const Duration(days: 7)),
            ),
          );
        case _Choice.drop:
          tasks.save(
            fresh.copyWith(status: TaskStatus.archived, reviewedAt: now),
          );
      }
      _history.add((fresh, c, _pos));
    }
    setState(() => _pos++);
    if (_pos >= _queue.length) _finish();
  }

  void _undo() {
    if (_history.isEmpty || _finished) return;
    final (before, _, pos) = _history.removeLast();
    ref.read(tasksProvider.notifier).restore(before);
    setState(() => _pos = pos);
  }

  void _finish() {
    _finished = true;
    ref.read(lastResetProvider.notifier).done(_now());
    ref
        .read(progressProvider.notifier)
        .recordBonus(
          'Weekly reset',
          resetXp,
          ref.read(deviceWorkspacesProvider).primary,
        );
  }

  int _count(_Choice c) => _history.where((h) => h.$2 == c).length;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final current = _finished || _pos >= _queue.length ? null : _queue[_pos];

    final Widget body;
    if (_queue.isEmpty) {
      body = _Message(
        title: 'Nothing has been sitting.',
        text:
            'Every open task has been added or looked at in the last week. '
            'Nice.',
      );
    } else if (current == null) {
      body = _Message(
        title: 'All sorted.',
        text: [
          if (_count(_Choice.keep) > 0) '${_count(_Choice.keep)} kept',
          if (_count(_Choice.shrink) > 0)
            '${_count(_Choice.shrink)} made smaller',
          if (_count(_Choice.snooze) > 0)
            '${_count(_Choice.snooze)} snoozed a week',
          if (_count(_Choice.drop) > 0) '${_count(_Choice.drop)} let go',
        ].join(' · '),
        footer: '+$resetXp XP for doing the reset.',
      );
    } else {
      final t = current;
      final now = _now();
      final age = now.difference(t.reviewedAt ?? t.createdAt).inDays;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_pos + 1} of ${_queue.length}',
            style: s.mono(13, color: s.primary, weight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Panel(
            radius: 24,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: s.display(28)),
                const SizedBox(height: 8),
                TaskMeta(task: t, now: now),
                const SizedBox(height: 6),
                Text(
                  t.reviewedAt == null
                      ? 'Added $age days ago.'
                      : 'Kept $age days ago.',
                  style: TextStyle(fontSize: 14, color: s.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Does it still matter?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: s.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          for (final (c, icon, label, help) in [
            (
              _Choice.keep,
              Icons.check_rounded,
              'Keep it',
              'Still matters. Leave it on the list.',
            ),
            (
              _Choice.shrink,
              Icons.compress_rounded,
              'Make it smaller',
              'Give it a first step you could do in 2 minutes.',
            ),
            (
              _Choice.snooze,
              Icons.snooze_rounded,
              'Not this week',
              'Hide it for 7 days.',
            ),
            (
              _Choice.drop,
              Icons.waving_hand_outlined,
              'Let it go',
              "Archive it. Deciding not to do something counts as done.",
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onTap: () => _choose(t, c),
                child: Row(
                  children: [
                    Icon(icon, color: s.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: s.onSurface,
                            ),
                          ),
                          Text(
                            help,
                            style: TextStyle(fontSize: 13, color: s.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly reset'),
        actions: [
          if (_history.isNotEmpty && !_finished)
            TextButton(onPressed: _undo, child: const Text('Back')),
        ],
      ),
      body: ContentWidth(
        maxWidth: 560,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 22,
            8,
            narrow ? 16 : 22,
            40,
          ),
          children: [body],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.text, this.footer});
  final String title;
  final String text;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Panel(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: s.display(28)),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: s.text2, height: 1.4)),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Text(footer!, style: s.mono(13, color: s.primary)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
