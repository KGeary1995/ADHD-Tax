import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/task.dart';

/// "Hold me to it": tells a friend you've started, through whatever app
/// the user picks in the share sheet. No server and no account; the
/// friend just gets a message.
String holdMeMessage(Task task, int minutes) {
  // A Work task's title can name people or cases, so it never leaves in a
  // message: the friend only hears that it's work.
  final what = task.workspace == Workspace.work
      ? 'a work task'
      : '"${task.title.trim()}"';
  return "I'm starting $what now, for $minutes min. "
      'Check on me when the time is up?';
}

/// Opens the share sheet. [origin] anchors the popover on iPad and Mac.
typedef ShareText = Future<void> Function(String text, Rect? origin);

final shareTextProvider = Provider<ShareText>(
  (_) =>
      (text, origin) => SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      ),
);
