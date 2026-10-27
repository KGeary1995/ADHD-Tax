// Fixes from the third code audit, in the pure-Dart logic.
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/capture/quick_parse.dart';
import 'package:adhd_tax/features/gamification/xp_rules.dart';
import 'package:adhd_tax/features/picker/picker_engine.dart';
import 'package:adhd_tax/features/safety/phi_guard.dart';
import 'package:adhd_tax/features/tasks/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task({
  Repeat repeat = Repeat.monthly,
  DateTime? due,
  DateTime? created,
  DateTime? scheduled,
  DateTime? repeatFrom,
  int repeatDay = 0,
}) {
  final c = created ?? DateTime(2026, 10, 1, 9);
  return Task(
    id: 'bills',
    title: 'Pay bills',
    createdAt: c,
    updatedAt: c,
    repeat: repeat,
    dueAt: due,
    scheduledStart: scheduled,
    repeatFrom: repeatFrom,
    repeatDay: repeatDay,
    status: TaskStatus.doing,
  );
}

void main() {
  group('repeating tasks', () {
    test('monthly on the 31st comes back on the 31st after February', () {
      var t = _task(due: DateTime(2027, 1, 31, 17));
      final dues = <String>[];
      for (var i = 0; i < 3; i++) {
        final next = nextOccurrence(t, t.dueAt!)!;
        dues.add('${next.dueAt!.month}/${next.dueAt!.day}');
        t = next;
      }
      expect(dues, ['2/28', '3/31', '4/30']);
    });

    test('a due date moved to another day starts a new series day', () {
      // Was the 31st, now edited to the 15th: the 15th from here on.
      final t = _task(due: DateTime(2027, 3, 15, 17), repeatDay: 31);
      final next = nextOccurrence(t, t.dueAt!)!;
      expect(next.dueAt, DateTime(2027, 4, 15, 17));
    });

    test('Start clearing the schedule date does not move the next copy', () {
      // A weekly copy made on a Thursday (finished late) for Monday 26 Oct,
      // started on that Monday: scheduledStart is cleared by Start.
      final t = _task(
        repeat: Repeat.weekly,
        created: DateTime(2026, 10, 22, 9),
        repeatFrom: DateTime(2026, 10, 26),
      );
      final next = nextOccurrence(t, DateTime(2026, 10, 26, 12))!;
      expect(next.scheduledStart, DateTime(2026, 11, 2));
      expect(next.repeatFrom, DateTime(2026, 11, 2));
    });
  });

  group('quick add', () {
    final now = DateTime(2026, 10, 27, 10); // Tuesday 10:00
    QuickParse p(String s) => parseQuickAdd(s, now);

    test('a guessed hour follows tonight or the evening', () {
      expect(p('Pizza tonight at 8').dueAt, DateTime(2026, 10, 27, 20));
      expect(p('Gym tomorrow evening at 7').dueAt, DateTime(2026, 10, 28, 19));
      expect(p('Run tomorrow morning at 5').dueAt, DateTime(2026, 10, 28, 5));
    });

    test('"at 5:30" is pm like "at 5"; two digits are read as written', () {
      expect(p('Call mom at 5:30').dueAt, DateTime(2026, 10, 27, 17, 30));
      expect(p('Call mom at 5').dueAt, DateTime(2026, 10, 27, 17));
      expect(p('Alarm 05:30').dueAt, DateTime(2026, 10, 28, 5, 30));
    });

    test('ordinary titles stay titles', () {
      final houses = p('Look at 3 houses');
      expect(houses.dueAt, isNull);
      expect(houses.title, 'Look at 3 houses');
      final milk = p('Buy 1/2 gallon milk');
      expect(milk.dueAt, isNull);
      expect(milk.title, 'Buy 1/2 gallon milk');
      // Still a date with "by" in front, or on its own at the end.
      expect(p('Report by 1/2').dueAt, DateTime(2027, 1, 2, 17));
      expect(p('Dentist 11/14').dueAt, DateTime(2026, 11, 14, 17));
    });

    test('dates that don\'t exist aren\'t picked up', () {
      expect(p('Feb 30 thing').dueAt, isNull);
      expect(p('4/31 thing').dueAt, isNull);
      expect(p('jan 45 thing').dueAt, isNull);
      // Feb 29 means the next year that has one.
      expect(p('Party Feb 29').dueAt, DateTime(2028, 2, 29, 17));
    });

    test('this weekend on a Sunday is today', () {
      final sunday = DateTime(2026, 11, 1, 10);
      expect(
        parseQuickAdd('Clean garage this weekend', sunday).dueAt,
        DateTime(2026, 11, 1, 17),
      );
    });
  });

  test('every task parked for later says so, not "nothing fits"', () {
    final now = DateTime(2026, 10, 17, 14);
    final later = Task(
      id: 'a',
      title: 'Later',
      createdAt: now,
      updatedAt: now,
      scheduledStart: now.add(const Duration(hours: 3)),
    );
    final r = const PickerEngine().pick([
      later,
    ], PickerContext(availableMin: 30, willingToLeave: true, now: now));
    expect(r.noPickReason, NoPickReason.allLater);
  });

  test('the old-task bonus counts calendar days across the clock change', () {
    // Spring forward (US): Mar 8 2026. Created a week before, at 9:00.
    expect(
      calendarDaysBetween(DateTime(2026, 3, 3, 9), DateTime(2026, 3, 10, 8)),
      7,
    );
  });

  test('the sensitive-info check catches more of the obvious slips', () {
    final now = DateTime(2026, 10, 27);
    List<String> kinds(String s) =>
        scanForPhi(s, now: now).map((h) => h.kind).toList();
    expect(kinds('Born 3/14/2012'), contains('Birth date'));
    expect(kinds('Born 3/14/85'), contains('Birth date'));
    expect(kinds('Born 1985-03-14'), contains('Birth date'));
    expect(kinds('Due 3/14/2027'), isNot(contains('Birth date')));
    expect(kinds('Call Mrs. McDonald'), contains("Someone's name"));
    expect(kinds("Call Mrs. O'Brien"), contains("Someone's name"));
    expect(kinds('Call Mr Smith'), contains("Someone's name"));
    expect(kinds('patient SMITH'), contains("Someone's name"));
    expect(kinds('SSN 123 45 6789'), contains('Social security number'));
  });

  test(
    'an empty checklist box is skipped, so ticks land on the right item',
    () {
      final items = parseChecklist('[ ]\n[ ] Call\n[ ] Email');
      expect(items.map((i) => i.text), ['Call', 'Email']);
      expect(parseChecklist(encodeChecklist(items)), items);
    },
  );

  test('whole numbers written as 15.0 still read', () {
    final t = Task.fromJson({
      'id': 'x',
      'title': 'x',
      'createdAt': '2026-10-01T09:00:00.000',
      'updatedAt': '2026-10-01T09:00:00.000',
      'estimateMin': 15.0,
      'ugh': 2.0,
      'skipCount': 1.0,
      'actualMin': 30.0,
    });
    expect([t.estimateMin, t.ugh, t.skipCount, t.actualMin], [15, 2, 1, 30]);
  });
}
