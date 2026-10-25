import 'package:adhd_tax/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show pumpApp;

const _phone = Size(390, 844);
const _small = Size(360, 800);

void main() {
  const tabs = {
    'Today': '/',
    'Tasks': '/tasks',
    'Notes': '/notes',
    'Progress': '/progress',
  };

  for (final MapEntry(key: tab, value: path) in tabs.entries) {
    testWidgets('on a phone, $tab has a gear to Settings, and back returns '
        'to $tab', (tester) async {
      final c = await pumpApp(tester, size: _phone);
      final router = c.read(routerProvider);
      String where() => router.routerDelegate.currentConfiguration.uri.path;

      await tester.tap(find.byTooltip(tab));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(where(), '/settings');
      expect(find.text('Settings'), findsOneWidget);
      // The tab bar stays, so any tab is one tap away.
      for (final t in tabs.keys) {
        expect(find.byTooltip(t), findsOneWidget);
      }

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(where(), path);

      // Android back does the same.
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(where(), path);
    });
  }

  testWidgets('from Settings, a tab goes straight there', (tester) async {
    final c = await pumpApp(tester, size: _phone);
    final router = c.read(routerProvider);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notes'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/notes');
  });

  testWidgets('the gear fits every tab at 360 wide with big text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, size: _small);
    for (final tab in tabs.keys) {
      await tester.tap(find.byTooltip(tab));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Settings'), findsOneWidget, reason: tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('wide layouts keep Settings in the sidebar, with no gears', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });
}
