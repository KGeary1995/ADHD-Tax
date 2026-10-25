import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/data/models/template.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/gamification/progress_event.dart';
import 'package:adhd_tax/features/gamification/rewards_controller.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/features/tasks/checklist_editor.dart';
import 'package:adhd_tax/features/templates/templates_controller.dart';
import 'package:adhd_tax/sync/replicas_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pastStarted, pumpApp;

const _phone = Size(390, 844);

// Monday morning.
final _now = DateTime(2026, 10, 19, 10);

Future<void> tab(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip(name));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.dragUntilVisible(
    f,
    find.byType(Scrollable).first,
    const Offset(0, -250),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('checklist: add steps in the editor, the next one shows on '
      'Home and in focus, and ticking it moves on', (tester) async {
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => _now)],
    );
    final t = c.read(tasksProvider.notifier).create(title: 'Open the clinic');
    c.read(routerProvider).push('/task/${t.id}');
    await tester.pumpAndSettle();

    final add = find
        .descendant(
          of: find.byType(ChecklistEditor),
          matching: find.byType(TextField),
        )
        .last;
    await scrollTo(tester, add);
    await tester.enterText(add, 'Unlock doors');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // Pasting several lines adds one step each.
    await tester.enterText(add, 'Lights on\nBoot the PCs');
    await tester.pumpAndSettle();
    expect(find.text('Boot the PCs'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      c.read(tasksProvider.notifier).byId(t.id)!.checklist,
      '[ ] Unlock doors\n[ ] Lights on\n[ ] Boot the PCs',
    );

    // Home's card leads with the next step.
    c.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1 of 3'), findsOneWidget);

    c.read(routerProvider).push('/focus/${t.id}?min=15');
    await pastStarted(tester);
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('Unlock doors'), findsOneWidget);
    await tester.tap(find.text('Step done'));
    await tester.pump();
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('Lights on'), findsOneWidget);
    expect(c.read(tasksProvider.notifier).byId(t.id)!.steps.first.done, true);
  });

  testWidgets('reward shop: add an idea, redeem it, undo', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    // 30 coins from earlier work.
    c
        .read(replicasProvider.notifier)
        .write(
          Workspace.personal,
          (r, now) => r.put(
            collEvents,
            'earned',
            ProgressEvent(
              id: 'earned',
              at: DateTime(2026, 10, 1),
              kind: ProgressKind.completed,
              label: 'Earlier',
              xp: 300,
              coins: 30,
            ).toJson(),
            now,
          ),
          events: true,
        );
    await tab(tester, 'Progress');
    final idea = find.text('Fancy coffee out · 25');
    await scrollTo(tester, idea);
    await tester.tap(idea);
    await tester.pumpAndSettle();
    expect(c.read(rewardsProvider).single.cost, 25);

    // The cheaper idea pills are gone; the reward row has Redeem.
    await tester.ensureVisible(find.text('Redeem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();
    expect(c.read(progressProvider).coins, 5);
    expect(find.text('Enjoy it.'), findsOneWidget);
    expect(
      find.textContaining('Fancy coffee out. You earned it'),
      findsOneWidget,
    );
    expect(find.textContaining('Last treat: Fancy coffee out'), findsOneWidget);
    expect(c.read(redemptionsProvider), hasLength(1));
    // Spending doesn't show as XP or affect level.
    expect(c.read(progressProvider).xp, 300);

    // Can't afford it twice.
    expect(find.text('20 to go'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.read(progressProvider).coins, 30);
  });

  testWidgets('quick add reads "tomorrow 2pm 15 min #billing"; a tapped '
      'chip goes back into the title', (tester) async {
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => _now)],
    );
    await tester.tap(find.byTooltip('Add a task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Call insurance tomorrow 2pm 15 min #billing !!',
    );
    await tester.pump();
    expect(find.text('Due tomorrow 2 pm'), findsOneWidget);
    expect(find.text('#billing'), findsOneWidget);
    expect(find.textContaining('Saving as "Call insurance"'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final t = c.read(tasksProvider).single;
    expect(t.title, 'Call insurance');
    expect(t.dueAt, DateTime(2026, 10, 20, 14));
    expect(t.estimateMin, 15);
    expect(t.priority, Priority.p2);
    expect(t.tagList, ['billing']);

    await tester.tap(find.byTooltip('Add a task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lunch at noon');
    await tester.pump();
    await tester.tap(find.text('Due today 12 pm'));
    await tester.pump();
    expect(find.text('Due today 12 pm'), findsNothing);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final lunch = c.read(tasksProvider).firstWhere((x) => x.id != t.id);
    expect(lunch.title, 'Lunch at noon');
    expect(lunch.dueAt, isNull);
  });

  testWidgets('a #tag naming a project files the task there', (tester) async {
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => _now)],
    );
    final p = c
        .read(projectsProvider.notifier)
        .create('Move house', Workspace.personal);
    await tester.tap(find.byTooltip('Add a task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Book movers #move-house',
    );
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final t = c.read(tasksProvider).single;
    expect(t.title, 'Book movers');
    expect(t.projectId, p.id);
    expect(t.tags, '');
  });

  testWidgets('templates: add an example, use it for a task and a note, and '
      'save a task as a template', (tester) async {
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [clockProvider.overrideWithValue(() => _now)],
    );
    c.read(routerProvider).push('/templates');
    await tester.pumpAndSettle();
    expect(find.text('START FROM AN EXAMPLE'), findsOneWidget);
    await tester.tap(find.text('Add').first); // Opening checklist
    await tester.pumpAndSettle();
    expect(find.text('START FROM AN EXAMPLE'), findsNothing);
    expect(c.read(templatesProvider).single.stepCount, 5);

    // Use it: the editor opens with everything filled in, unsaved.
    await tester.tap(find.text('Opening checklist'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Unlock the doors'), findsOneWidget);
    expect(c.read(tasksProvider), isEmpty);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final opened = c.read(tasksProvider).single;
    expect(opened.title, 'Open up');
    expect(opened.workspace, Workspace.work);
    expect(opened.steps, hasLength(5));

    // A note template, used from the Notes tab.
    c
        .read(templatesProvider.notifier)
        .save(
          Template(
            id: '',
            kind: TemplateKind.note,
            name: 'Huddle notes',
            title: 'Huddle {date}',
            body: 'Staffing:',
            createdAt: _now,
          ),
        );
    c.read(routerProvider).go('/notes');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From a template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Huddle notes'));
    await tester.pumpAndSettle();
    expect(find.text('Huddle Oct 19'), findsOneWidget);
    expect(c.read(notesProvider).single.body, 'Staffing:');

    // Save a task as a template from its editor.
    c.read(routerProvider).go('/');
    final t = c
        .read(tasksProvider.notifier)
        .create(title: 'Weekly invoices', checklist: '[x] Export\n[ ] Send');
    c.read(routerProvider).push('/task/${t.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save as template'));
    await tester.pumpAndSettle();
    final saved = c
        .read(templatesProvider)
        .firstWhere((x) => x.name == 'Weekly invoices');
    expect(saved.checklist, '[ ] Export\n[ ] Send');
  });
}
