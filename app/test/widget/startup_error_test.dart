import 'package:adhd_tax/startup_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup failure shows the error, copy and retry', (
    tester,
  ) async {
    var retried = false;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      StartupErrorApp(
        error: StateError('prefs unavailable'),
        stack: StackTrace.current,
        onRetry: () => retried = true,
      ),
    );

    expect(find.text('Something went wrong starting ADHD Tax'), findsOneWidget);
    expect(find.textContaining('prefs unavailable'), findsOneWidget);

    await tester.tap(find.text('Copy details'));
    expect(copied, contains('prefs unavailable'));

    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('build errors render even with no MaterialApp above', (
    tester,
  ) async {
    await tester.pumpWidget(
      BuildErrorPanel(
        details: FlutterErrorDetails(exception: Exception('boom at root')),
      ),
    );
    expect(find.textContaining('boom at root'), findsOneWidget);
  });
}
