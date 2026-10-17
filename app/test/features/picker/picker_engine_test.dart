import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/picker/picker_engine.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 17, 14); // Afternoon, so no morning frog boost.

Task task(
  String id, {
  int est = 15,
  Priority priority = Priority.p3,
  bool out = false,
  DateTime? due,
  bool hard = false,
  int ugh = 0,
  Energy energy = Energy.medium,
  Workspace ws = Workspace.personal,
  TaskStatus status = TaskStatus.todo,
  bool chunkable = false,
  DateTime? created,
  DateTime? scheduled,
  int skipCount = 0,
  DateTime? lastSkipped,
}) => Task(
  id: id,
  title: 'Task $id',
  estimateMin: est,
  priority: priority,
  requiresLeavingHouse: out,
  dueAt: due,
  hardDeadline: hard,
  ugh: ugh,
  energy: energy,
  workspace: ws,
  status: status,
  chunkable: chunkable,
  scheduledStart: scheduled,
  skipCount: skipCount,
  lastSkippedAt: lastSkipped,
  createdAt: created ?? now,
  updatedAt: created ?? now,
);

PickerContext ctx({
  int min = 30,
  bool leave = false,
  Energy? energy,
  Set<Workspace> ws = const {Workspace.personal, Workspace.work},
  DateTime? at,
}) => PickerContext(
  availableMin: min,
  willingToLeave: leave,
  energy: energy,
  workspaces: ws,
  now: at ?? now,
);

void main() {
  const engine = PickerEngine();

  group('filtering', () {
    test('excludes tasks longer than the window', () {
      final r = engine.rank([
        task('a', est: 60),
        task('b', est: 20),
      ], ctx(min: 30));
      expect(r.map((s) => s.task.id), ['b']);
    });

    test('excludes out-of-house tasks unless willing to leave', () {
      final tasks = [task('a', out: true), task('b')];
      expect(engine.rank(tasks, ctx()).map((s) => s.task.id), ['b']);
      expect(engine.rank(tasks, ctx(leave: true)).length, 2);
    });

    test('excludes closed, waiting and future-scheduled tasks', () {
      final tasks = [
        task('done', status: TaskStatus.done),
        task('wait', status: TaskStatus.waiting),
        task('arch', status: TaskStatus.archived),
        task('later', scheduled: now.add(const Duration(hours: 2))),
        task('ok'),
      ];
      expect(engine.rank(tasks, ctx()).map((s) => s.task.id), ['ok']);
    });

    test('respects workspace selection', () {
      final tasks = [task('p'), task('w', ws: Workspace.work)];
      expect(
        engine.rank(tasks, ctx(ws: {Workspace.work})).map((s) => s.task.id),
        ['w'],
      );
    });

    test('offers chunkable long tasks as a chunk of the window', () {
      final r = engine.rank([
        task('big', est: 180, chunkable: true),
      ], ctx(min: 45));
      expect(r.single.isChunk, isTrue);
      expect(r.single.plannedMin, 45);
    });

    test('does not chunk into tiny windows', () {
      final r = engine.rank([
        task('big', est: 180, chunkable: true),
      ], ctx(min: 5));
      expect(r, isEmpty);
    });
  });

  group('scoring', () {
    test('higher priority wins all else equal', () {
      final r = engine.rank([
        task('lo', priority: Priority.p4),
        task('hi', priority: Priority.p1),
      ], ctx());
      expect(r.first.task.id, 'hi');
    });

    test('imminent due date beats higher priority with no deadline', () {
      final r = engine.rank([
        task('pri', priority: Priority.p2),
        task('due', due: now.add(const Duration(hours: 2))),
      ], ctx());
      expect(r.first.task.id, 'due');
      expect(r.first.reasons.first, contains('Due'));
    });

    test('hard deadlines ramp up earlier than soft ones', () {
      final due = now.add(const Duration(days: 2));
      final r = engine.rank([
        task('soft', due: due),
        task('hard', due: due, hard: true),
      ], ctx());
      expect(r.first.task.id, 'hard');
    });

    test('old tasks gain weight so avoided tasks resurface', () {
      final r = engine.rank([
        task('fresh'),
        task('stale', created: now.subtract(const Duration(days: 10))),
      ], ctx());
      expect(r.first.task.id, 'stale');
      expect(r.first.reasons.first, contains('10 days'));
    });

    test('fills the window: a 25 min task beats a 5 min task in 30 min', () {
      final r = engine.rank([
        task('tiny', est: 5),
        task('fit', est: 25),
      ], ctx());
      expect(r.first.task.id, 'fit');
    });

    test('low energy steers away from high-energy and dreaded tasks', () {
      final r = engine.rank([
        task('hard', energy: Energy.high, ugh: 3),
        task('easy', energy: Energy.low),
      ], ctx(energy: Energy.low));
      expect(r.first.task.id, 'easy');
    });

    test('morning boosts dreaded tasks (eat the frog)', () {
      final morning = DateTime(2026, 10, 17, 9);
      final tasks = [task('frog', ugh: 3), task('plain')];
      expect(engine.rank(tasks, ctx(at: morning)).first.task.id, 'frog');
      expect(
        engine.rank(tasks, ctx(at: morning)).first.reasons,
        contains('Good moment to eat the frog'),
      );
    });

    test('skip penalty decays so skipped tasks come back', () {
      final justSkipped = task(
        's',
        priority: Priority.p2,
        skipCount: 1,
        lastSkipped: now.subtract(const Duration(minutes: 5)),
      );
      final other = task('o');
      expect(engine.rank([justSkipped, other], ctx()).first.task.id, 'o');

      final dayLater = ctx(at: now.add(const Duration(hours: 25)));
      expect(engine.rank([justSkipped, other], dayLater).first.task.id, 's');
    });

    test('in-progress tasks get a nudge to finish', () {
      final r = engine.rank([
        task('new'),
        task('started', status: TaskStatus.doing),
      ], ctx());
      expect(r.first.task.id, 'started');
    });

    test('ranking is deterministic on ties (oldest first)', () {
      final a = task('a', created: now.subtract(const Duration(hours: 2)));
      final b = task('b', created: now.subtract(const Duration(hours: 1)));
      expect(engine.rank([b, a], ctx()).first.task.id, 'a');
    });
  });

  group('pick', () {
    test('respects exclusions (rerolls)', () {
      final tasks = [task('a', priority: Priority.p1), task('b')];
      final r = engine.pick(tasks, ctx(), exclude: {'a'});
      expect(r.suggestion!.task.id, 'b');
    });

    test('explains why nothing was picked', () {
      expect(engine.pick([], ctx()).noPickReason, NoPickReason.noOpenTasks);
      expect(
        engine.pick([task('a', est: 90)], ctx()).noPickReason,
        NoPickReason.nothingFitsTime,
      );
      expect(
        engine.pick([task('a', out: true)], ctx()).noPickReason,
        NoPickReason.allNeedLeaving,
      );
      expect(
        engine.pick([task('a')], ctx(), exclude: {'a'}).noPickReason,
        NoPickReason.allExcluded,
      );
    });

    test('pickTiny turns any task into 5 minutes and prefers easy ones', () {
      final s = engine.pickTiny([
        task('dread', est: 120, ugh: 3),
        task('small', est: 10),
      ], ctx(min: 5))!;
      expect(s.task.id, 'small');
      expect(s.plannedMin, 5);
    });
  });
}
