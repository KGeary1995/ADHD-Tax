import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task.dart';
import '../gamification/progress_controller.dart';
import 'tasks_controller.dart';

/// List actions that change a task in one tap, each with an Undo, since a
/// mis-tap is easy and shouldn't cost anything.
///
/// Everything needed for the undo is captured up front: the tile that
/// triggered it is usually gone (moved to another section) by the time
/// Undo is tapped.

/// Done without a focus session, e.g. something already handled. Still
/// earns XP, and a repeating task gets its next copy.
void markDoneWithUndo(BuildContext context, WidgetRef ref, Task t) {
  final tasks = ref.read(tasksProvider.notifier);
  final progress = ref.read(progressProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final dates = MaterialLocalizations.of(context);

  final next = tasks.complete(t.id, minutesWorked: 0);
  final celebration = progress.recordCompletion(t, actualMin: null);
  final when = next?.dueAt ?? next?.scheduledStart;
  _undoBar(
    messenger,
    when == null
        ? 'Done: ${t.title}'
        : 'Done: ${t.title} · next one ${dates.formatMediumDate(when)}',
    () {
      tasks.restore(t);
      if (next != null) tasks.delete(next.id);
      progress.revoke(celebration);
    },
  );
}

void archiveWithUndo(BuildContext context, WidgetRef ref, Task t) {
  final tasks = ref.read(tasksProvider.notifier);
  tasks.setStatus(t.id, TaskStatus.archived);
  _undoBar(
    ScaffoldMessenger.of(context),
    'Archived: ${t.title}',
    () => tasks.restore(t),
  );
}

void deleteWithUndo(BuildContext context, WidgetRef ref, Task t) {
  final tasks = ref.read(tasksProvider.notifier);
  tasks.delete(t.id);
  _undoBar(
    ScaffoldMessenger.of(context),
    'Deleted: ${t.title}',
    () => tasks.restore(t),
  );
}

void _undoBar(
  ScaffoldMessengerState messenger,
  String message,
  VoidCallback undo,
) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'Undo', onPressed: undo),
      ),
    );
}
