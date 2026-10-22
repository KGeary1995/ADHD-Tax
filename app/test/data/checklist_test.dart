import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/tasks/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 19, 9);
  Task task({String firstStep = '', String checklist = ''}) => Task(
    id: 't',
    title: 'Open the clinic',
    firstStep: firstStep,
    checklist: checklist,
    createdAt: now,
    updatedAt: now,
  );

  test('parse and encode round trip', () {
    const raw = '[x] Lights on\n[ ] Check fridge temp\n[ ] Boot the PCs';
    final items = parseChecklist(raw);
    expect(items, const [
      ChecklistItem('Lights on', done: true),
      ChecklistItem('Check fridge temp'),
      ChecklistItem('Boot the PCs'),
    ]);
    expect(encodeChecklist(items), raw);
  });

  test('plain lines, blank lines and capital X still read', () {
    expect(parseChecklist('Buy milk\n\n  [X] Bread  \n'), const [
      ChecklistItem('Buy milk'),
      ChecklistItem('Bread', done: true),
    ]);
    expect(parseChecklist(''), isEmpty);
  });

  test('item text never breaks the one-line-per-item format', () {
    expect(
      encodeChecklist(const [ChecklistItem('two\nlines')]),
      '[ ] two lines',
    );
    expect(encodeChecklist(const [ChecklistItem('  ')]), '');
  });

  test('the next unticked item is the step to show', () {
    var t = task(firstStep: 'Find keys', checklist: '[ ] Unlock\n[ ] Alarm');
    expect(t.nextStep, 'Unlock');
    expect(t.startLine, 'Unlock');
    t = t.toggleStep(0);
    expect(t.nextStep, 'Alarm');
    t = t.toggleStep(1);
    // All ticked: the title, not a stale first step.
    expect(t.nextStep, '');
    expect(t.startLine, 'Open the clinic');
    // Out of range is ignored.
    expect(t.toggleStep(9).checklist, t.checklist);
  });

  test('without a checklist the first step still works', () {
    expect(task(firstStep: ' Find keys ').startLine, 'Find keys');
    expect(task().startLine, 'Open the clinic');
  });

  test('the next copy of a repeating task starts unticked', () {
    final done = Task(
      id: 'r',
      title: 'Weekly reset',
      repeat: Repeat.weekly,
      checklist: '[x] Laundry\n[x] Groceries',
      createdAt: now,
      updatedAt: now,
    );
    final next = nextOccurrence(done, now)!;
    expect(next.checklist, '[ ] Laundry\n[ ] Groceries');
  });
}
