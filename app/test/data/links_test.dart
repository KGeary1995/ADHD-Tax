import 'package:adhd_tax/data/models/links.dart';
import 'package:adhd_tax/data/models/note.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 23, 9);

  Task task(
    String id,
    String title, {
    Workspace workspace = Workspace.personal,
    TaskStatus status = TaskStatus.todo,
    String tags = '',
    String projectId = '',
    DateTime? dueAt,
  }) => Task(
    id: id,
    title: title,
    workspace: workspace,
    status: status,
    tags: tags,
    projectId: projectId,
    dueAt: dueAt,
    createdAt: now,
    updatedAt: now,
  );

  Note note(
    String id, {
    String title = '',
    String body = '',
    Workspace workspace = Workspace.personal,
    DateTime? updatedAt,
  }) => Note(
    id: id,
    title: title,
    body: body,
    workspace: workspace,
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );

  test('finds [[links]] once each, ignoring case and broken brackets', () {
    expect(
      wikiLinksIn(
        'Call [[Renew license]] then [[renew  LICENSE]] and [[Gift ideas]].\n'
        'Not [[this\nline]], not [[]], not [[open',
      ),
      ['Renew license', 'Gift ideas'],
    );
    expect(withoutLinkBrackets('See [[ Gift ideas ]]'), 'See Gift ideas');
  });

  test('a note heading shows links as plain names', () {
    final n = note('n', body: '[[Renew license]] notes\n[[Car]] stuff');
    expect(n.heading, 'Renew license notes');
    expect(n.preview, 'Car stuff');
  });

  test(
    'a link prefers an unfinished task, then a finished one, then a note',
    () {
      final tasks = [
        task('done', 'Water plants', status: TaskStatus.done),
        task('open', 'water plants'),
        task('work', 'Gift ideas', workspace: Workspace.work),
      ];
      final notes = [note('n1', title: 'Gift ideas')];
      LinkTarget r(String name) => resolveLink(
        name,
        workspace: Workspace.personal,
        tasks: tasks,
        notes: notes,
      );
      expect((r('Water Plants') as TaskLink).task.id, 'open');
      // The Work task with the same name is never reached from Personal.
      expect((r('gift ideas') as NoteLink).note.id, 'n1');
      expect(r('Nothing here'), isA<MissingLink>());
      expect(
        (resolveLink(
          'Water plants',
          workspace: Workspace.personal,
          tasks: [tasks.first],
          notes: const [],
        ) as TaskLink).task.id,
        'done',
      );
    },
  );

  test('backlinks: notes in the same workspace that link to a name', () {
    final notes = [
      note('a', body: 'See [[Renew license]]', updatedAt: now),
      note(
        'b',
        title: 'Plan [[renew license]]',
        updatedAt: now.add(const Duration(hours: 1)),
      ),
      note('c', body: 'Renew license, no link'),
      note('d', body: '[[Renew license]]', workspace: Workspace.work),
    ];
    expect(
      notesLinkingTo(
        'Renew License',
        workspace: Workspace.personal,
        notes: notes,
      ).map((n) => n.id),
      ['b', 'a'],
    );
    expect(
      notesLinkingTo(
        'Renew license',
        workspace: Workspace.personal,
        notes: notes,
        excludeNoteId: 'a',
      ).map((n) => n.id),
      ['b'],
    );
  });

  test('related tasks share a tag or the project, most in common first', () {
    final me = task(
      'me',
      'Draft cheat sheet',
      tags: 'training,phones',
      projectId: 'p',
    );
    final all = [
      me,
      task('one-tag', 'Shadow Monday', tags: 'training'),
      task('two-tags', 'Call scripts', tags: 'phones,training'),
      task('project', 'Book the room', projectId: 'p'),
      task('soon', 'Quiz', tags: 'training', dueAt: now),
      task('done', 'Old', tags: 'training', status: TaskStatus.done),
      task('other', 'Unrelated', tags: 'car'),
      task('work', 'Elsewhere', tags: 'training', workspace: Workspace.work),
    ];
    expect(relatedTasks(me, all).map((t) => t.id), [
      'two-tags',
      'soon',
      'one-tag',
      'project',
    ]);
    expect(relatedTasks(me, all, limit: 1).map((t) => t.id), ['two-tags']);
  });

  test('typing [[ is spotted and completed in place', () {
    const text = 'Call [[ren and more';
    expect(openLinkAt(text, 10), (query: 'ren', start: 5));
    // Names can have spaces, so it stays open to the end of the line.
    expect(openLinkAt(text, text.length)?.query, 'ren and more');
    expect(openLinkAt('[[ren\nx', 7), isNull);
    expect(openLinkAt('[[done]] x', 10), isNull);
    final done = completeLink(text, 10, 'Renew license');
    expect(done.text, 'Call [[Renew license]] and more');
    expect(done.cursor, 'Call [[Renew license]]'.length);
    // Closing brackets already typed are reused.
    expect(completeLink('[[re]]', 4, 'Renew').text, '[[Renew]]');
  });
}
