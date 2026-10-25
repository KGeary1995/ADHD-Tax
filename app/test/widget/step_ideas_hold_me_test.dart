import 'package:adhd_tax/app.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/features/focus/company.dart';
import 'package:adhd_tax/features/focus/hold_me.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pastStarted, pumpApp;
import 'reset_errands_company_ai_test.dart' show FakeAmbient, frames;

const _phone = Size(360, 800);

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('without an AI key: first-step ideas and Suggest steps '
        '(text ×$scale)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = await pumpApp(tester, size: _phone);
      final t = c
          .read(tasksProvider.notifier)
          .create(title: 'Call the dentist');
      c.read(routerProvider).go('/task/${t.id}');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Ideas show while the first step is empty; one tap fills it in.
      final idea = find.text('+ Find the number and put it on screen');
      expect(idea, findsOneWidget);
      await tester.tap(idea);
      await tester.pump();
      expect(idea, findsNothing);

      final suggest = find.text('Suggest steps');
      await tester.ensureVisible(suggest);
      await tester.pumpAndSettle();
      await tester.tap(suggest);
      await tester.pumpAndSettle();
      expect(find.text('Write down what you need from the call'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Hold me to it shares a message; a Work task stays private', (
    tester,
  ) async {
    final sent = <String>[];
    final c = await pumpApp(
      tester,
      size: _phone,
      overrides: [
        ambientPlayerProvider.overrideWithValue(FakeAmbient()),
        shareTextProvider.overrideWithValue((text, _) async => sent.add(text)),
      ],
    );
    final tasks = c.read(tasksProvider.notifier);
    final mine = tasks.create(title: 'Clean the bathroom');
    final job = tasks.create(
      title: 'Follow up on the audit',
      workspace: Workspace.work,
    );

    for (final t in [mine, job]) {
      c.read(routerProvider).push('/focus/${t.id}?min=25');
      await tester.pump();
      await pastStarted(tester);
      await tester.tap(find.byTooltip('Hold me to it'));
      await frames(tester);
      // A sheet shows the message first; Share sends it.
      await tester.tap(find.text('Share'));
      await frames(tester);
      c.read(routerProvider).go('/');
      await frames(tester);
    }

    expect(sent[0], contains('"Clean the bathroom"'));
    expect(sent[0], contains('25 min'));
    expect(sent[1], contains('a work task'));
    expect(sent[1], isNot(contains('audit')));
  });
}
