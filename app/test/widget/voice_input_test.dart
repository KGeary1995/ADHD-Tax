// The mic button with a stand-in for the platform's speech recognizer.

import 'package:adhd_tax/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'app_flow_test.dart' show pumpApp;

class FakeSpeech extends SpeechToTextPlatform {
  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async => true;

  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async => onStatus?.call('notListening');

  @override
  Future<void> cancel() async => onStatus?.call('notListening');
}

void main() {
  testWidgets('a mic button opened after the first one still hears that '
      'listening ended', (tester) async {
    final original = SpeechToTextPlatform.instance;
    final speech = FakeSpeech();
    SpeechToTextPlatform.instance = speech;
    addTearDown(() => SpeechToTextPlatform.instance = original);

    Future<void> dictateInNewNote() async {
      final c = await pumpApp(tester);
      c.read(routerProvider).go('/note/new');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Say it').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stop listening'), findsOneWidget);
      speech.onStatus?.call('notListening'); // the recognizer stopped
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stop listening'), findsNothing);
    }

    await dictateInNewNote();
    await tester.pumpWidget(const SizedBox());
    await dictateInNewNote();
  });
}
