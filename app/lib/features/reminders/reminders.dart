import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_reminders.dart';
import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

/// One scheduled notification: a check-in nudge, a follow-up on a waiting
/// task, or the evening wrap-up. Tapping it opens [route].
class Nudge {
  const Nudge(this.at, this.message, {this.title = 'Gumption', this.route});
  final DateTime at;
  final String message;
  final String title;
  final String? route;
}

/// What the app needs from system notifications. Android, iPhone and iPad
/// get the real thing; desktop and web keep the timer on screen and do
/// nothing here.
abstract class Reminders {
  bool get supported;

  Future<bool> permissionGranted();

  /// Shows Android's "Allow notifications?" prompt (if it still can).
  Future<bool> requestPermission();

  /// A countdown in the notification shade, plus a "time's up" alert at
  /// [endsAt] that arrives even if the app is in the background.
  Future<void> focusRunning({required String title, required DateTime endsAt});

  Future<void> focusPaused({required String title, required Duration left});

  /// The timer ran out while the app was open: drop the countdown, keep
  /// any alert that already appeared.
  Future<void> focusTimeUp();

  /// Session over: remove the countdown and any pending alert.
  Future<void> focusEnded();

  /// Replaces all previously scheduled nudges.
  Future<void> scheduleNudges(List<Nudge> nudges);

  /// Routes from tapped notifications, including the one that launched the
  /// app (delivered once, after the first listen).
  Stream<String> get opened;
}

class NoReminders implements Reminders {
  const NoReminders();
  @override
  bool get supported => false;
  @override
  Future<bool> permissionGranted() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> focusRunning({
    required String title,
    required DateTime endsAt,
  }) async {}
  @override
  Future<void> focusPaused({
    required String title,
    required Duration left,
  }) async {}
  @override
  Future<void> focusTimeUp() async {}
  @override
  Future<void> focusEnded() async {}
  @override
  Future<void> scheduleNudges(List<Nudge> nudges) async {}
  @override
  Stream<String> get opened => const Stream.empty();
}

final remindersProvider = Provider<Reminders>(
  (ref) =>
      isAndroidDevice || isIOSDevice ? DeviceReminders() : const NoReminders(),
);
