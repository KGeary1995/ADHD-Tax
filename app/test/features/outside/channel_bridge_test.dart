import 'package:adhd_tax/features/outside/device_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The native side as iOS behaves: a widget tap is held until Dart takes
/// it, and Dart is told with a 'pending' call.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('unstuck/android');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final waiting = <Map<String, String>>[];

  setUp(() {
    waiting.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'takeLaunchRequest') {
        return waiting.isEmpty ? null : waiting.removeAt(0);
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> nativeCalls(String method) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall(method)),
    (_) {},
  );

  test('a tap taken before anything listens is kept, not dropped', () async {
    final bridge = ChannelDeviceBridge();
    waiting.add({'type': 'route', 'route': '/focus/a?min=10'});
    await nativeCalls('pending');
    expect(waiting, isEmpty);

    final got = await bridge.requests.first;
    expect((got as OpenRoute).route, '/focus/a?min=10');
  });

  test('a tap while listening arrives at once', () async {
    final bridge = ChannelDeviceBridge();
    final got = <OutsideRequest>[];
    final sub = bridge.requests.listen(got.add);
    await pumpEventQueue();

    waiting.add({'type': 'route', 'route': '/wrapup'});
    await nativeCalls('pending');
    await pumpEventQueue();
    expect(got.map((r) => (r as OpenRoute).route), ['/wrapup']);
    await sub.cancel();
  });
}
