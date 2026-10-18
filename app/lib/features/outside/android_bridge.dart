import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reminders/platform_stub.dart'
    if (dart.library.io) '../reminders/platform_io.dart';

/// Something from outside the app: text shared to it, or a widget tap.
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

/// The Android side of the app (MainActivity / PickWidget). Everywhere
/// else it does nothing.
abstract class AndroidBridge {
  /// Requests: the one that launched the app first, then any that arrive
  /// while it runs.
  Stream<OutsideRequest> get requests;

  /// Redraws the home-screen widget with [data] (all strings).
  Future<void> updateWidget(Map<String, String> data);
}

class NoAndroidBridge implements AndroidBridge {
  const NoAndroidBridge();
  @override
  Stream<OutsideRequest> get requests => const Stream.empty();
  @override
  Future<void> updateWidget(Map<String, String> data) async {}
}

class ChannelAndroidBridge implements AndroidBridge {
  ChannelAndroidBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'request') {
        final r = OutsideRequest.fromMap(call.arguments);
        if (r != null) _incoming.add(r);
      }
    });
  }

  static const _channel = MethodChannel('unstuck/android');
  final _incoming = StreamController<OutsideRequest>.broadcast();

  @override
  Stream<OutsideRequest> get requests async* {
    try {
      final first = OutsideRequest.fromMap(
        await _channel.invokeMethod<Object?>('takeLaunchRequest'),
      );
      if (first != null) yield first;
    } on PlatformException {
      // Older native side: nothing to hand over.
    }
    yield* _incoming.stream;
  }

  @override
  Future<void> updateWidget(Map<String, String> data) async {
    try {
      await _channel.invokeMethod<void>('updateWidget', data);
    } on PlatformException {
      // The widget is a nice-to-have; never let it break the app.
    }
  }
}

final androidBridgeProvider = Provider<AndroidBridge>(
  (ref) => isAndroidDevice ? ChannelAndroidBridge() : const NoAndroidBridge(),
);

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
