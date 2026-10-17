import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/core/theme/app_themes.dart';
import 'package:adhd_tax/data/storage/key_value_store.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/motivation/quote_service.dart';
import 'package:adhd_tax/features/settings/settings_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _quotes = [
  Quote('Start small.', QuoteCategory.starting),
  Quote('Keep going.', QuoteCategory.momentum),
  Quote('Be kind to yourself.', QuoteCategory.compassion),
  Quote('Do the scary one.', QuoteCategory.dread),
  Quote('Plot twist: you do it.', QuoteCategory.humor),
];

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryStore()),
      quoteServiceProvider.overrideWithValue(QuoteService(_quotes)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AdhdTaxApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('capture → pick → start → finish → celebrate', (tester) async {
    final c = await pumpApp(tester);

    expect(find.text('Your list is empty.'), findsOneWidget);
    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Call insurance about claim',
    );
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // The dashboard picks the only task.
    expect(find.text('Your next task'.toUpperCase()), findsOneWidget);
    expect(find.text('Call insurance about claim'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // Focus screen, with XP awarded just for starting.
    expect(find.text('Done!'), findsOneWidget);
    expect(find.textContaining('+10 XP'), findsOneWidget);
    expect(find.textContaining('First Spark'), findsOneWidget);
    expect(c.read(progressProvider).started, 1);

    await tester.tap(find.text('Done!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Keep the streak going'), findsOneWidget);
    expect(find.textContaining('First Win'), findsWidgets);
    await tester.tap(find.text('Keep the streak going'));
    await tester.pumpAndSettle();

    final p = c.read(progressProvider);
    expect(p.completed, 1);
    expect(p.unlocked.keys, containsAll(['first_spark', 'first_win']));
    expect(c.read(tasksProvider).single.actualMin, 1);
    expect(find.text('Your list is empty.'), findsOneWidget);
  });

  testWidgets('"Not this one" twice asks you to commit', (tester) async {
    final c = await pumpApp(tester);
    final tasks = c.read(tasksProvider.notifier);
    tasks.create(title: 'A');
    tasks.create(title: 'B');
    tasks.create(title: 'C');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not this one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not this one'));
    await tester.pumpAndSettle();

    expect(find.text('Pick one of these and commit.'), findsOneWidget);
    for (final t in ['A', 'B', 'C']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('every theme renders the dashboard on a phone', (tester) async {
    final c = await pumpApp(tester, size: const Size(400, 860));
    c.read(tasksProvider.notifier).create(title: 'Dreaded thing', ugh: 3);
    for (final spec in themeSpecs) {
      c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(themeId: spec.id));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: spec.id);
      expect(find.text('Dreaded thing'), findsOneWidget, reason: spec.id);
    }
  });

  testWidgets('PHI guard warns on Work tasks only', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Quick add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Call pt John Smith');
    await tester.pump();
    expect(find.textContaining('Looks like patient info'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Work'),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Looks like patient info'), findsOneWidget);
  });
}
