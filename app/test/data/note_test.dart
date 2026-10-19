import 'package:adhd_tax/data/models/note.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 19, 9);

  Note note({
    String title = '',
    String body = '',
    List<String> tags = const [],
  }) => Note(
    id: 'n',
    title: title,
    body: body,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );

  test('JSON round trip, and old records load with defaults', () {
    final n = Note(
      id: 'n1',
      workspace: Workspace.work,
      title: 'Vendor call',
      body: 'Ask about the lens cleaner order',
      pinned: true,
      projectId: 'p',
      taskId: 't',
      tags: ['vendors', 'orders'],
      createdAt: now,
      updatedAt: now,
    );
    final back = Note.fromJson(n.toJson());
    expect(back.toJson(), n.toJson());
    // Tags are stored as one string so the replica sees unchanged values
    // as unchanged.
    expect(n.toJson()['tags'], 'vendors,orders');

    final old = Note.fromJson({'id': 'x', 'body': 'hi'});
    expect(old.workspace, Workspace.personal);
    expect(old.tags, isEmpty);
    expect(old.projectId, '');
  });

  test('heading falls back to the first line; preview skips it', () {
    final n = note(
      body: '\n  Call the bank \nfee was charged twice\nask for refund',
    );
    expect(n.heading, 'Call the bank');
    expect(n.preview, 'fee was charged twice · ask for refund');
    expect(note().heading, 'Untitled note');
    expect(note(title: 'T', body: 'a\nb').preview, 'a · b');
  });

  test('tags: chips plus #hashtags, normalized and de-duplicated', () {
    expect(parseTags(' Billing, #Insurance,billing ,, Front Desk'), [
      'billing',
      'insurance',
      'front-desk',
    ]);
    final n = note(
      title: 'Payroll #admin',
      body: 'Due friday #Admin #q4-planning\nnot a tag: #2 or a#b',
      tags: ['money'],
    );
    expect(n.allTags, ['admin', 'money', 'q4-planning']);
  });

  test('search matches title, body and tags', () {
    final n = note(title: 'Rota', body: 'swap shifts', tags: ['staffing']);
    expect(n.matches('rota'), isTrue);
    expect(n.matches('SHIFTS'), isTrue);
    expect(n.matches('#staff'), isTrue);
    expect(n.matches('payroll'), isFalse);
    expect(n.matches('  '), isTrue);
  });

  test('task lines drop list markers and blank lines', () {
    expect(
      taskLinesOf(
        '- Call IT\n\n* Order toner\n1. Email Dana\n[ ] Book room\n'
        '[x] Already done\n   plain line  ',
      ),
      [
        'Call IT',
        'Order toner',
        'Email Dana',
        'Book room',
        'Already done',
        'plain line',
      ],
    );
  });
}
