import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/features/capture/quick_add_sheet.dart';
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

        for (final label in [
          'How long?',
          'Priority',
          'How much do you dread it?',
          'Personal',
          'Work',
        ]) {
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
    await tester.tap(find.text('Critical'));
    await tester.pump();
    await tester.tap(find.text('Full form'));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Renew license'), findsOneWidget);
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
