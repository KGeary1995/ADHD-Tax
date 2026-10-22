import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/picker/errand_run.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 21, 10);
  Task e(
    String id, {
    String place = '',
    int min = 15,
    Priority priority = Priority.p3,
    bool out = true,
    Workspace ws = Workspace.personal,
    DateTime? due,
  }) => Task(
    id: id,
    title: id,
    location: place,
    estimateMin: min,
    priority: priority,
    requiresLeavingHouse: out,
    workspace: ws,
    dueAt: due,
    createdAt: now,
    updatedAt: now,
  );
  ErrandRun? plan(List<Task> ts, int min) => planErrandRun(
    ts,
    availableMin: min,
    workspaces: {Workspace.personal, Workspace.work},
    now: now,
  );

  test('groups by place (however it was typed) and counts travel', () {
    final run = plan([
      e('Rx', place: 'Pharmacy', min: 10),
      e('Vitamins', place: 'pharmacy ', min: 5),
      e('Stamps', place: 'Post office', min: 10),
      e('Read', out: false),
    ], 60)!;
    expect(run.stops, hasLength(2));
    expect(run.tasks.map((t) => t.id).toSet(), {'Rx', 'Vitamins', 'Stamps'});
    expect(run.minutes, 10 + 5 + 10 + 2 * travelPerStop);
    expect(
      run.summary,
      anyOf('Pharmacy + Post office', 'Post office + Pharmacy'),
    );
  });

  test('keeps to the time available, most pressing stop first', () {
    final run = plan([
      e('Return parcel', place: 'Post office', min: 20),
      e('Refill', place: 'Pharmacy', min: 10, priority: Priority.p1),
      e('Groceries', place: 'Store', min: 30, due: now),
    ], 60)!;
    // Store (due now) and Pharmacy (critical) fit; the post office doesn't.
    expect(run.tasks.map((t) => t.id).toSet(), {'Groceries', 'Refill'});
    expect(run.minutes, lessThanOrEqualTo(60));
  });

  test('no run for fewer than two errands', () {
    expect(plan([e('One', place: 'Bank')], 60), isNull);
    expect(plan([e('Big', min: 50), e('Small', min: 5)], 30), isNull);
  });

  test('unnamed places read as a count', () {
    expect(plan([e('a'), e('b')], 60)!.summary, '2 errands');
    expect(
      plan([
        e('a', place: 'Bank'),
        e('b', place: 'Shop'),
        e('c', place: 'Gym'),
      ], 120)!.summary,
      endsWith('+ 1 more'),
    );
  });
}
