import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';
import 'reminders.dart';

const _focusId = 1;
const _timesUpId = 2;

/// Nudges use ids from here up, so they can be replaced as a set.
const _firstNudgeId = 100;

/// iOS keeps at most 64 pending notifications per app; leave room for the
/// focus timer's "time's up".
const _iosMaxNudges = 60;

const _darwinQuiet = DarwinNotificationDetails(
  presentAlert: true,
  presentBanner: true,
  presentList: true,
  presentSound: false,
);

const _darwinAlert = DarwinNotificationDetails(
  presentAlert: true,
  presentBanner: true,
  presentList: true,
  presentSound: true,
  interruptionLevel: InterruptionLevel.active,
);

const _focusChannel = AndroidNotificationDetails(
  'focus',
  'Focus timer',
  channelDescription: 'The countdown while a focus session is running.',
  importance: Importance.low,
  priority: Priority.low,
  playSound: false,
  enableVibration: false,
);

const _timesUpChannel = AndroidNotificationDetails(
  'times_up',
  "Time's up",
  channelDescription: 'When a focus session reaches the end of its time.',
  importance: Importance.high,
  priority: Priority.high,
  category: AndroidNotificationCategory.alarm,
  visibility: NotificationVisibility.public,
);

const _nudgeChannel = AndroidNotificationDetails(
  'nudges',
  'Check-in nudges',
  channelDescription: 'Gentle prompts to pick one thing, at times you set.',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  category: AndroidNotificationCategory.reminder,
);

/// Real notifications on Android, iPhone and iPad. Android also gets an
/// ongoing countdown while you focus; iOS has no such notification, so it
/// only gets the "time's up" alert.
class DeviceReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _opened = StreamController<String>.broadcast();
  Future<void>? _init;

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_focus'),
        // Asked for in requestPermission, at a moment that makes sense.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final route = r.payload;
        if (route != null && route.startsWith('/')) _opened.add(route);
      },
    );
  }

  @override
  Stream<String> get opened async* {
    await _android();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final route = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        route != null &&
        route.startsWith('/')) {
      yield route;
    }
    yield* _opened.stream;
  }

  Future<AndroidFlutterLocalNotificationsPlugin?> _android() async {
    await (_init ??= _initialize());
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  @override
  bool get supported => true;

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> permissionGranted() async {
    final android = await _android();
    if (isIOSDevice) {
      return (await _ios?.checkPermissions())?.isEnabled ?? false;
    }
    return await android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    final android = await _android();
    if (isIOSDevice) {
      return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Exact when Android allows it, otherwise as close as it will.
  Future<AndroidScheduleMode> _mode() async =>
      !isIOSDevice &&
          (await (await _android())?.canScheduleExactNotifications() ?? false)
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  @override
  Future<void> focusRunning({
    required String title,
    required DateTime endsAt,
  }) async {
    await _android();
    if (!isIOSDevice) {
      await _plugin.show(
        id: _focusId,
        title: title,
        body: 'Focus session running',
        notificationDetails: NotificationDetails(
          android: _ongoing(
            when: endsAt.millisecondsSinceEpoch,
            countdown: true,
          ),
        ),
      );
    }
    await _plugin.cancel(id: _timesUpId);
    if (!endsAt.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _timesUpId,
      title: "Time's up",
      body: '$title\nFinished, or want a little more time?',
      scheduledDate: tz.TZDateTime.from(endsAt, tz.UTC),
      notificationDetails: const NotificationDetails(
        android: _timesUpChannel,
        iOS: _darwinAlert,
      ),
      androidScheduleMode: await _mode(),
    );
  }

  @override
  Future<void> focusPaused({
    required String title,
    required Duration left,
  }) async {
    await _android();
    await _plugin.cancel(id: _timesUpId);
    if (isIOSDevice) return;
    final min = (left.inSeconds / 60).ceil().clamp(0, 24 * 60);
    await _plugin.show(
      id: _focusId,
      title: title,
      body: 'Paused · $min min left',
      notificationDetails: NotificationDetails(android: _ongoing()),
    );
  }

  @override
  Future<void> focusTimeUp() async {
    await _android();
    await _plugin.cancel(id: _focusId);
  }

  @override
  Future<void> focusEnded() async {
    await _android();
    await _plugin.cancel(id: _focusId);
    await _plugin.cancel(id: _timesUpId);
  }

  @override
  Future<void> scheduleNudges(List<Nudge> nudges) async {
    await _android();
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= _firstNudgeId) await _plugin.cancel(id: p.id);
    }
    final now = DateTime.now();
    final upcoming = [
      for (final n in nudges)
        if (n.at.isAfter(now)) n,
    ]..sort((a, b) => a.at.compareTo(b.at));
    // iOS drops anything past its limit, so keep the soonest; the rest are
    // scheduled when the app next opens.
    final keep = isIOSDevice ? upcoming.take(_iosMaxNudges) : upcoming;
    var id = _firstNudgeId;
    for (final n in keep) {
      await _plugin.zonedSchedule(
        id: id++,
        title: n.title,
        body: n.message,
        payload: n.route,
        // An absolute instant, worked out in local time by the caller, so
        // daylight-saving changes need no time zone database here.
        scheduledDate: tz.TZDateTime.from(n.at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: _nudgeChannel,
          iOS: _darwinQuiet,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

AndroidNotificationDetails _ongoing({int? when, bool countdown = false}) =>
    AndroidNotificationDetails(
      _focusChannel.channelId,
      _focusChannel.channelName,
      channelDescription: _focusChannel.channelDescription,
      importance: _focusChannel.importance,
      priority: _focusChannel.priority,
      playSound: false,
      enableVibration: false,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      showWhen: when != null,
      when: when,
      usesChronometer: countdown,
      chronometerCountDown: countdown,
      category: AndroidNotificationCategory.progress,
    );
