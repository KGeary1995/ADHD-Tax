import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/core/theme/app_themes.dart';
import 'package:adhd_tax/data/storage/key_value_store.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/picker/dashboard_screen.dart';
import 'package:adhd_tax/features/picker/picker_controller.dart';
import 'package:adhd_tax/features/motivation/quote_service.dart';
import 'package:adhd_tax/features/settings/settings_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryStore()),
      quoteServiceProvider.overrideWithValue(QuoteService(_quotes)),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GumptionApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Past the focus screen's "A new star." moment, to the timer. The timer
/// ticks every second, so this pumps fixed steps, never pumpAndSettle.
Future<void> pastStarted(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

/// Settings: on a phone it's the gear on Progress.
Future<void> openSettings(WidgetTester tester) async {
  if (find.byTooltip('Settings').evaluate().isEmpty) {
    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('capture → pick → start → finish → celebrate', (tester) async {
    final c = await pumpApp(tester);

    expect(find.text('Your sky is clear.'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.text('Add a task'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Call insurance about claim',
    );
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // The dashboard picks the only task.
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Call insurance about claim'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // "A new star.", with XP awarded just for starting.
    expect(find.text('A new star.'), findsOneWidget);
    expect(find.textContaining('+10 XP'), findsOneWidget);
    expect(c.read(progressProvider).started, 1);

    // Then the timer, and the start's achievement as a note.
    await pastStarted(tester);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('First Spark'), findsOneWidget);

    await tester.tap(find.text('Done'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Finished.'), findsOneWidget);
    await tester.tap(find.text('Nice'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ACHIEVEMENT UNLOCKED'), findsOneWidget);
    expect(find.text('First Win'), findsOneWidget);
    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();

    final p = c.read(progressProvider);
    expect(p.completed, 1);
    expect(p.unlocked.keys, containsAll(['first_spark', 'first_win']));
    expect(c.read(tasksProvider).single.actualMin, 1);
    expect(find.text('Your sky is clear.'), findsOneWidget);
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

    expect(find.text('Pick one of these three'), findsOneWidget);
    for (final t in ['A', 'B', 'C']) {
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(t)),
        findsOneWidget,
      );
    }
    // Choosing one makes it today's pick, and that's decided.
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('B')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pick one of these three'), findsNothing);
    expect(c.read(pickResultProvider).suggestion?.task.title, 'B');
  });

  testWidgets('light and dark both render the dashboard on a phone', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: const Size(360, 800));
    c.read(tasksProvider.notifier).create(title: 'Dreaded thing', ugh: 3);
    for (final a in Appearance.values) {
      c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(appearance: a));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: a.name);
      expect(find.text('Dreaded thing'), findsOneWidget, reason: a.name);
    }
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });

  test('old theme choices map onto light or dark', () {
    Appearance from(Map<String, Object?> j) =>
        AppSettings.fromJson(j).appearance;
    expect(from({}), Appearance.system);
    expect(from({'themeId': 'slate'}), Appearance.light);
    expect(from({'themeId': 'graphite'}), Appearance.dark);
    expect(from({'themeId': 'neon_grid'}), Appearance.dark);
    expect(from({'themeId': 'slate', 'appearance': 'dark'}), Appearance.dark);
    final round = AppSettings.fromJson(
      const AppSettings(appearance: Appearance.light).toJson(),
    );
    expect(round.appearance, Appearance.light);
  });

  testWidgets('PHI guard warns on Work tasks only', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Add a task').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Call pt John Smith');
    await tester.pump();
    expect(find.textContaining('Looks like patient info'), findsNothing);

    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Work')),
    );
    await tester.pump();
    expect(find.textContaining('Looks like patient info'), findsOneWidget);
  });
}
