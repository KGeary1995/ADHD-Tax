import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/insights/estimate_calibration.dart';
import 'package:adhd_tax/features/picker/picker_engine.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 17, 14);

Task timed(
  String id,
  int est,
  int actual, {
  Workspace ws = Workspace.personal,
  int ago = 1,
}) => Task(
  id: id,
  title: 'T$id',
  estimateMin: est,
  actualMin: actual,
  workspace: ws,
  status: TaskStatus.done,
  createdAt: now.subtract(Duration(days: ago + 1)),
  updatedAt: now,
  completedAt: now.subtract(Duration(days: ago)),
);

void main() {
  test('needs five timed tasks before it says anything', () {
    final c = calibrate([for (var i = 0; i < 4; i++) timed('$i', 10, 30)]);
    expect(c.overall.samples, 4);
    expect(c.overall.meaningful, isFalse);
    expect(c.overall.realMinutes(10), 10);
  });

  test('median of actual ÷ estimate, ignoring untimed and open tasks', () {
    final c = calibrate([
      timed('a', 10, 15),
      timed('b', 10, 20),
      timed('c', 10, 14),
      timed('d', 20, 30),
      timed('e', 10, 100), // one outlier doesn't swing the median
      Task(
        id: 'x',
        title: 'untimed',
        createdAt: now,
        updatedAt: now,
        status: TaskStatus.done,
        completedAt: now,
      ),
      Task(
        id: 'y',
        title: 'open',
        createdAt: now,
        updatedAt: now,
        actualMin: 90,
      ),
    ]);
    expect(c.overall.samples, 5);
    expect(c.overall.factor, 1.5);
    expect(c.overall.realMinutes(30), 45);
  });

  test('close to 1× is treated as accurate', () {
    final c = calibrate([for (var i = 0; i < 6; i++) timed('$i', 20, 22)]);
    expect(c.overall.meaningful, isFalse);
    expect(c.overall.realMinutes(20), 20);
  });

  test('per workspace when it has enough data, else overall', () {
    final c = calibrate([
      for (var i = 0; i < 5; i++) timed('w$i', 10, 30, ws: Workspace.work),
      for (var i = 0; i < 3; i++) timed('p$i', 10, 10),
    ]);
    expect(c.forWorkspace(Workspace.work).factor, 3.0);
    expect(identical(c.forWorkspace(Workspace.personal), c.overall), isTrue);
  });

  test('the picker fits tasks by how long they really take', () {
    final c = calibrate([for (var i = 0; i < 5; i++) timed('$i', 10, 20)]);
    final open = Task(
      id: 'o',
      title: 'Write report',
      estimateMin: 20,
      createdAt: now,
      updatedAt: now,
    );
    const engine = PickerEngine();
    final naive = engine.pick([
      open,
    ], PickerContext(availableMin: 30, willingToLeave: false, now: now));
    expect(naive.suggestion?.task.id, 'o');
    final real = engine.pick(
      [open],
      PickerContext(
        availableMin: 30,
        willingToLeave: false,
        now: now,
        calibration: c,
      ),
    );
    expect(real.suggestion, isNull, reason: '20 min really takes ~40');
    final roomy = engine.pick(
      [open],
      PickerContext(
        availableMin: 45,
        willingToLeave: false,
        now: now,
        calibration: c,
      ),
    );
    expect(roomy.suggestion?.plannedMin, 40);
    expect(
      roomy.suggestion?.reasons,
      contains('Tasks like this usually take you ~40 min'),
    );
  });
}
