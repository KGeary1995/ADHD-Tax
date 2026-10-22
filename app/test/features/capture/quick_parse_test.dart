import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/capture/quick_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Monday 19 Oct 2026, 10:00.
  final now = DateTime(2026, 10, 19, 10);
  QuickParse p(String s, {Set<String> ignore = const {}}) =>
      parseQuickAdd(s, now, ignore: ignore);

  test('the example from the app: date, time, length, tag', () {
    final r = p('Call insurance tomorrow 2pm 15 min #billing');
    expect(r.title, 'Call insurance');
    expect(r.dueAt, DateTime(2026, 10, 20, 14));
    expect(r.estimateMin, 15);
    expect(r.tags, ['billing']);
    expect(r.bits.map((b) => b.label), [
      '15 min',
      'Due tomorrow 2 pm',
      '#billing',
    ]);
  });

  test('plain text stays plain', () {
    for (final s in [
      'Read 1984',
      'Sat down with the budget',
      'Fix the sun shade',
      'Email Pat about room 5',
      'Mon-Fri schedule review',
      'Call mom!',
    ]) {
      final r = p(s);
      expect(r.title, s, reason: s);
      expect(r.bits, isEmpty, reason: s);
    }
  });

  test('times', () {
    expect(
      p('Meds at 9').dueAt,
      DateTime(2026, 10, 19, 9).add(
        const Duration(days: 1), // 9 am already passed today
      ),
    );
    expect(p('Pick up kids at 3').dueAt, DateTime(2026, 10, 19, 15));
    expect(p('Huddle 13:30').dueAt, DateTime(2026, 10, 19, 13, 30));
    expect(p('Lunch at noon').dueAt, DateTime(2026, 10, 19, 12));
    expect(p('Call 4:15 pm').dueAt, DateTime(2026, 10, 19, 16, 15));
    expect(p('Call 12am').dueAt, DateTime(2026, 10, 20, 0));
  });

  test('days', () {
    expect(p('Pay rent by friday').dueAt, DateTime(2026, 10, 23, 17));
    expect(p('Pay rent by friday').title, 'Pay rent');
    expect(p('Groceries on sat').dueAt, DateTime(2026, 10, 24, 17));
    // Today is Monday: "monday" is today, "next monday" a week out.
    expect(p('Report monday').dueAt, DateTime(2026, 10, 19, 17));
    expect(p('Report next monday').dueAt, DateTime(2026, 10, 26, 17));
    expect(p('Laundry tonight').dueAt, DateTime(2026, 10, 19, 20));
    expect(p('Gym tomorrow morning').dueAt, DateTime(2026, 10, 20, 9));
    expect(p('Renew in 2 weeks').dueAt, DateTime(2026, 11, 2, 17));
    expect(p('Plan next week').dueAt, DateTime(2026, 10, 26, 17));
    expect(p('Clean garage this weekend').dueAt, DateTime(2026, 10, 24, 17));
    expect(p('Taxes due 4/15').dueAt, DateTime(2027, 4, 15, 17));
    expect(p('Party Nov 3rd 7pm').dueAt, DateTime(2026, 11, 3, 19));
    expect(p('Party 3 nov').dueAt, DateTime(2026, 11, 3, 17));
    expect(p('Send recap eod').dueAt, DateTime(2026, 10, 19, 17));
  });

  test('lengths', () {
    expect(p('Stretch 5m').estimateMin, 5);
    expect(p('Deep clean for 1.5 hours').estimateMin, 90);
    expect(p('Deep clean 1h 30m').estimateMin, 90);
    expect(p('Walk half an hour').estimateMin, 30);
    expect(p('Walk for an hour').title, 'Walk');
    expect(p('Walk for an hour').estimateMin, 60);
  });

  test('priority and workspace', () {
    expect(p('Refill rx urgent').priority, Priority.p1);
    expect(p('Refill rx !!').priority, Priority.p2);
    expect(p('Refill rx !!!').priority, Priority.p1);
    expect(p('Clean desk someday').priority, Priority.p4);
    expect(p('Clean desk low priority').title, 'Clean desk');
    final w = p('Order lens wipes #work #supplies');
    expect(w.workspace, Workspace.work);
    expect(w.tags, ['supplies']);
    expect(w.title, 'Order lens wipes');
  });

  test('ignoring a chip puts the words back in the title', () {
    final r = p('Call insurance tomorrow 2pm', ignore: {qkDue});
    expect(r.title, 'Call insurance tomorrow 2pm');
    expect(r.dueAt, isNull);
    final t = p('Book #travel flights', ignore: {qkTag('travel')});
    expect(t.title, 'Book #travel flights');
    expect(t.tags, isEmpty);
  });

  test('only extras typed: the text stays as the title', () {
    expect(p('tomorrow').title, 'tomorrow');
  });
}
