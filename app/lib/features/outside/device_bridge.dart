import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reminders/platform_stub.dart'
    if (dart.library.io) '../reminders/platform_io.dart';

/// Something from outside the app: text shared to it, a widget tap, or the
/// browser coming back from a Microsoft sign-in (Android).
sealed class OutsideRequest {
  const OutsideRequest();

  static OutsideRequest? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return switch (raw['type']) {
      'share' => SharedText(
        text: '${raw['text'] ?? ''}',
        subject: '${raw['subject'] ?? ''}',
      ),
      'route' => OpenRoute('${raw['route'] ?? '/'}'),
      'auth' => switch (Uri.tryParse('${raw['url']}')) {
        final url? => AuthRedirect(url),
        null => null,
      },
      _ => null,
    };
  }
}

class SharedText extends OutsideRequest {
  const SharedText({required this.text, this.subject = ''});
  final String text;
  final String subject;
}

class OpenRoute extends OutsideRequest {
  const OpenRoute(this.route);
  final String route;
}

/// `gumption://auth?code=…`: hand it to the sign-in that's waiting.
class AuthRedirect extends OutsideRequest {
  const AuthRedirect(this.url);
  final Uri url;
}

/// The native side of the phone apps: MainActivity / PickWidget on
/// Android, AppDelegate / the widget and share extensions on iOS. Desktop
/// and web get [NoDeviceBridge].
abstract class DeviceBridge {
  /// Requests: the one that launched the app first, then any that arrive
  /// while it runs.
  Stream<OutsideRequest> get requests;

  /// Asks again for anything waiting, e.g. text the iOS share extension
  /// queued while the app was in the background.
  Future<void> poll();

  /// Redraws the home-screen widget with [data] (all strings).
  Future<void> updateWidget(Map<String, String> data);
}

class NoDeviceBridge implements DeviceBridge {
  const NoDeviceBridge();
  @override
  Stream<OutsideRequest> get requests => const Stream.empty();
  @override
  Future<void> poll() async {}
  @override
  Future<void> updateWidget(Map<String, String> data) async {}
}

class ChannelDeviceBridge implements DeviceBridge {
  ChannelDeviceBridge() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        // Android: the request itself.
        case 'request':
          final r = OutsideRequest.fromMap(call.arguments);
          if (r != null) _deliver(r);
        // iOS: a widget tap is waiting; take it.
        case 'pending':
          await poll();
      }
    });
  }

  static const _channel = MethodChannel('unstuck/android');
  final _incoming = StreamController<OutsideRequest>.broadcast();

  /// Requests that arrived before anything listened to [requests] (a
  /// broadcast stream would drop them), e.g. an iOS widget tap during
  /// startup.
  final _held = <OutsideRequest>[];

  void _deliver(OutsideRequest r) =>
      _incoming.hasListener ? _incoming.add(r) : _held.add(r);

  Future<OutsideRequest?> _take() async {
    try {
      return OutsideRequest.fromMap(
        await _channel.invokeMethod<Object?>('takeLaunchRequest'),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Stream<OutsideRequest> get requests async* {
    final first = await _take();
    if (first != null) yield first;
    while (_held.isNotEmpty) {
      yield _held.removeAt(0);
    }
    yield* _incoming.stream;
  }

  @override
  Future<void> poll() async {
    final r = await _take();
    if (r != null) _deliver(r);
  }

  @override
  Future<void> updateWidget(Map<String, String> data) async {
    try {
      await _channel.invokeMethod<void>('updateWidget', data);
    } on PlatformException {
      // The widget is a nice-to-have; never let it break the app.
    } on MissingPluginException {
      // Same.
    }
  }
}

final deviceBridgeProvider = Provider<DeviceBridge>(
  (ref) => isAndroidDevice || isIOSDevice
      ? ChannelDeviceBridge()
      : const NoDeviceBridge(),
);

/// Set by the `/add` route; OutsideBootstrap opens Quick add when it sees
/// it. iOS widget links now arrive through the channel, but `/add` stays a
/// redirect so an `/add` that reaches the router another way still works.
final quickAddRequested = ValueNotifier<bool>(false);

/// Splits shared text into a task title and notes: the subject or first
/// line becomes the title, the rest goes to notes. Pure.
({String title, String notes}) taskFromShare(SharedText s) {
  final text = s.text.trim();
  final subject = s.subject.trim();
  if (subject.isNotEmpty) return (title: subject, notes: text);
  final lines = text.split('\n');
  final first = lines.first.trim();
  if (first.length <= 120) {
    return (title: first, notes: lines.skip(1).join('\n').trim());
  }
  return (title: '${first.substring(0, 80).trimRight()}…', notes: text);
}
