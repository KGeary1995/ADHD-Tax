import 'package:adhd_tax/data/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 17, 9, 30);

  test('JSON round trip preserves every field', () {
    final t = Task(
      id: 'abc',
      title: 'Renew license',
      notes: 'bring photo',
      firstStep: 'Find the form',
      estimateMin: 45,
      requiresLeavingHouse: true,
      location: 'DMV',
      priority: Priority.p1,
      dueAt: now.add(const Duration(days: 3)),
      hardDeadline: true,
      ugh: 3,
      energy: Energy.high,
      workspace: Workspace.work,
      status: TaskStatus.doing,
      chunkable: true,
      scheduledStart: now,
      createdAt: now,
      updatedAt: now,
      startedAt: now,
      actualMin: 12,
      skipCount: 2,
      lastSkippedAt: now,
      projectId: 'p1',
    );
    expect(Task.fromJson(t.toJson()), t);
    // Older builds never wrote it.
    expect(Task.fromJson(t.toJson()..remove('projectId')).projectId, '');
  });

  test('unknown enum values fall back to defaults', () {
    final t = Task.fromJson({
      'id': 'a',
      'title': 'x',
      'priority': 'p9',
      'status': 'weird',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
    expect(t.priority, Priority.p3);
    expect(t.status, TaskStatus.todo);
  });

  test('copyWith can clear nullable fields', () {
    final t = Task(
      id: 'a',
      title: 'x',
      createdAt: now,
      updatedAt: now,
      dueAt: now,
    );
    expect(t.copyWith(dueAt: null).dueAt, isNull);
    expect(t.copyWith(title: 'y').dueAt, now);
  });

  test('startLine prefers the first step', () {
    final t = Task(id: 'a', title: 'Taxes', createdAt: now, updatedAt: now);
    expect(t.startLine, 'Taxes');
    expect(t.copyWith(firstStep: 'Open TurboTax').startLine, 'Open TurboTax');
  });

  test('formatMinutes', () {
    expect(formatMinutes(15), '15 min');
    expect(formatMinutes(60), '1h');
    expect(formatMinutes(90), '1h 30m');
  });
}
