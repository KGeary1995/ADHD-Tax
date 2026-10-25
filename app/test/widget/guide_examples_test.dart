import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/features/guide/guide_screen.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'app_flow_test.dart' show pumpApp;

void main() {
  testWidgets('example tasks: try them from an empty Today, then remove '
      'only the examples', (tester) async {
    final c = await pumpApp(
      tester,
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 21, 10)),
      ],
    );
    expect(find.text('Your sky is clear.'), findsOneWidget);

    await tester.tap(find.text('Try with example tasks'));
    await tester.pumpAndSettle();
    expect(c.read(tasksProvider).length, greaterThan(5));
    expect(c.read(notesProvider), hasLength(2));
    expect(find.text('Your sky is clear.'), findsNothing);
    expect(find.textContaining('These are example tasks'), findsOneWidget);

    // Something of your own is kept when the examples go.
    c.read(tasksProvider.notifier).create(title: 'My real task');
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SideItem, 'Help'));
    await tester.pumpAndSettle();
    // The store listings' pages are one tap away (Apple asks for this).
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Support'), findsWidgets);
    await tester.tap(find.text('Remove example tasks'));
    await tester.pumpAndSettle();

    expect(c.read(tasksProvider).map((t) => t.title), ['My real task']);
    expect(c.read(notesProvider), isEmpty);
    expect(c.read(projectsProvider), isEmpty);
    expect(find.text('Try with example tasks'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('the guide fits a phone at text ×$scale and its links go '
        'to the real screens', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, size: const Size(360, 800));

      GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/guide');
      await tester.pumpAndSettle();
      expect(find.byType(GuideScreen), findsOneWidget);
      expect(find.text('Your first five minutes'), findsOneWidget);

      final list = find
          .descendant(
            of: find.byType(GuideScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Go to Notes'),
        300,
        scrollable: list,
      );
      // To the middle of the screen, clear of the edges.
      await Scrollable.ensureVisible(
        tester.element(find.text('Go to Notes')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Go to Notes'));
      await tester.pumpAndSettle();
      expect(find.byType(GuideScreen), findsNothing);
      expect(find.text('Notes'), findsWidgets);
    });
  }
}
