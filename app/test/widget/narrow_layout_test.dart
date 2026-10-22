import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/capture/quick_add_sheet.dart';
import 'package:adhd_tax/data/models/template.dart';
import 'package:adhd_tax/features/gamification/rewards_controller.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/picker/picker_controller.dart';
import 'package:adhd_tax/features/templates/templates_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(360, 800);

final _editorScroll = find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<ProviderContainer> _pumpPhone(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  // Evening, so Home's line also carries the "Wrap up" link (the widest
  // case; it overflowed once and only showed after 5 pm).
  return pumpApp(
    tester,
    size: _phone,
    overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 18, 21)),
    ],
  );
}

void main() {
  for (final scale in [1.0, 1.3]) {
    group('phone width, text ×$scale', () {
      testWidgets('quick add: labelled sections, nothing overflows', (
        tester,
      ) async {
        await _pumpPhone(tester, scale);
        showQuickAdd(tester.element(find.byType(Scaffold).first));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // A phone starts with just a length and Personal/Work.
        for (final label in ['How long?', 'Personal', 'Work']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text('Priority'), findsNothing);
        await tester.ensureVisible(find.text('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('More options'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['Priority', 'How much do you dread it?']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        // A yes/no toggle of its own, outside the dread levels' group.
        final errand = find.widgetWithText(Pill, 'Leave the house');
        expect(errand, findsOneWidget);
        expect(
          find.ancestor(of: errand, matching: find.byType(ChoiceGroup<int>)),
          findsNothing,
        );
      });

      testWidgets('quick add: buttons stay above the keyboard', (tester) async {
        await _pumpPhone(tester, scale);
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        addTearDown(tester.view.resetViewInsets);
        showQuickAdd(tester.element(find.byType(Scaffold).first));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final keyboardTop = _phone.height - 320;
        for (final label in ['Add', 'Add & start']) {
          final button = find.text(label);
          expect(button, findsOneWidget, reason: label);
          expect(
            tester.getRect(button).bottom,
            lessThanOrEqualTo(keyboardTop),
            reason: label,
          );
        }
      });

      testWidgets('new task editor: nothing overflows', (tester) async {
        final c = await _pumpPhone(tester, scale);
        c.read(routerProvider).go('/task/new');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Pick a date'),
          200,
          scrollable: _editorScroll,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('existing task editor: nothing overflows', (tester) async {
        final c = await _pumpPhone(tester, scale);
        final tasks = c.read(tasksProvider.notifier);
        final t = tasks.create(title: 'Renew license');
        tasks.save(t.copyWith(dueAt: DateTime(2030, 9, 30, 17)));
        c.read(routerProvider).go('/task/${t.id}');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Status'),
          200,
          scrollable: _editorScroll,
        );
        expect(find.text('Clear'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('notes, a note, and the board: nothing overflows', (
        tester,
      ) async {
        final c = await _pumpPhone(tester, scale);
        final project = c
            .read(projectsProvider.notifier)
            .create('Front desk training', Workspace.work);
        final t = c
            .read(tasksProvider.notifier)
            .create(
              title: 'Write the phone triage cheat sheet for new hires',
              workspace: Workspace.work,
              projectId: project.id,
            );
        final n = c
            .read(notesProvider.notifier)
            .create(
              workspace: Workspace.work,
              title: 'Ideas for the onboarding checklist',
              body: 'Shadow a full Monday #onboarding #training #front-desk',
              projectId: project.id,
              taskId: t.id,
            );
        for (final path in ['/notes', '/note/${n.id}', '/tasks']) {
          c.read(routerProvider).go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: path);
        }
        await tester.tap(find.byIcon(Icons.filter_list_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'filter sheet');
        await tester.tap(find.text('Board'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'board');
        // Five tabs and + in the floating bar.
        for (final tab in ['Today', 'Tasks', 'Notes', 'Progress', 'Settings']) {
          expect(find.byTooltip(tab), findsOneWidget, reason: tab);
        }
      });

      testWidgets('weekly reset, errand run, company sheet, AI settings: '
          'nothing overflows', (tester) async {
        final c = await _pumpPhone(tester, scale);
        final now = DateTime(2026, 10, 18, 21);
        final tasks = c.read(tasksProvider.notifier);
        for (final (title, place) in [
          ('Return the library books that are overdue', 'Central library'),
          ('Pick up the prescription refill', 'Pharmacy on Main Street'),
        ]) {
          tasks.save(
            Task(
              id: '',
              title: title,
              requiresLeavingHouse: true,
              location: place,
              priority: Priority.p2,
              dueAt: now.add(const Duration(days: 1)),
              createdAt: now.subtract(const Duration(days: 20)),
              updatedAt: now.subtract(const Duration(days: 20)),
            ),
          );
        }
        c.read(pickerInputsProvider.notifier).setWillingToLeave(true);
        c.read(pickerInputsProvider.notifier).setTime(120);
        for (final path in ['/', '/reset', '/errands']) {
          c.read(routerProvider).go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: path);
        }
        c.read(routerProvider).go('/settings');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Anthropic API key'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull, reason: 'AI settings');

        final t = c.read(tasksProvider).first;
        c.read(routerProvider).push('/focus/${t.id}?min=15');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byTooltip('Company'));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Company while you work'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'company sheet');
      });

      testWidgets('checklists, focus, reward shop, templates and typed '
          'extras: nothing overflows', (tester) async {
        final c = await _pumpPhone(tester, scale);
        final t = c
            .read(tasksProvider.notifier)
            .create(
              title: 'Get the front desk ready for the Monday rush',
              checklist:
                  '[x] Lights, computers and equipment on\n'
                  '[ ] Look over the schedule for gaps and double-books\n'
                  '[ ] Restock the front desk',
              tags: 'opening,front-desk',
            );
        c
            .read(rewardsProvider.notifier)
            .create('A long walk somewhere new with a fancy coffee', 120);
        c
            .read(templatesProvider.notifier)
            .save(exampleTemplates(DateTime(2026, 10, 18)).first);
        for (final path in [
          '/task/${t.id}',
          '/progress',
          '/templates',
          '/template/new?kind=task',
          '/template/new?kind=note',
          '/',
        ]) {
          c.read(routerProvider).go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: path);
        }
        c.read(routerProvider).go('/progress');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Redeem'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull, reason: 'shop');

        c.read(routerProvider).go('/');
        await tester.pumpAndSettle();
        showQuickAdd(tester.element(find.byType(Scaffold).first));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'Call the billing office back tomorrow 2:30pm 45 min '
          '#insurance #follow-up urgent',
        );
        await tester.pump();
        expect(find.text('45 min'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'typed extras');
        Navigator.of(tester.element(find.text('45 min'))).pop();
        await tester.pumpAndSettle();

        c.read(routerProvider).push('/focus/${t.id}?min=15');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Step 2 of 3'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'focus');
      });
    });
  }

  testWidgets('Android back from a tab goes Home instead of exiting', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _phone);
    final router = c.read(routerProvider);
    String where() => router.routerDelegate.currentConfiguration.uri.path;

    await tester.tap(find.byTooltip('Tasks'));
    await tester.pumpAndSettle();
    expect(where(), '/tasks');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(where(), '/');
  });

  testWidgets('Full task form carries over what Quick add had', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    final router = c.read(routerProvider);
    showQuickAdd(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Renew license');
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical'));
    await tester.pump();
    await tester.tap(find.text('Full form'));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Renew license'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(Pill, 'Critical'),
      300,
      scrollable: _editorScroll,
    );
    expect(
      tester.widget<Pill>(find.widgetWithText(Pill, 'Critical')).selected,
      isTrue,
    );

    // Back returns to where Quick add was opened, without saving.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(c.read(tasksProvider), isEmpty);
  });
}
