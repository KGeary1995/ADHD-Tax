import 'package:flutter/material.dart';

import '../core/theme/app_themes.dart';
import '../data/models/task.dart';

/// One quiet line of task facts: "Due 5 pm · 1h · Critical · Work".
/// A due date leads, in amber; everything else is muted.
class TaskMeta extends StatelessWidget {
  const TaskMeta({
    super.key,
    required this.task,
    this.plannedMin,
    this.now,
    this.extra,
  });

  final Task task;

  /// Shown instead of the estimate when the picker offers a chunk.
  final int? plannedMin;
  final DateTime? now;

  /// Appended at the end, e.g. "sitting for 9 days".
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final t = task;
    final due = t.dueAt == null
        ? null
        : '${t.hardDeadline ? 'Hard deadline' : 'Due'} '
              '${formatDue(t.dueAt!, now ?? DateTime.now())}';
    final parts = taskFacts(t, plannedMin: plannedMin);
    if (extra != null) parts.add(extra!);
    return Text.rich(
      TextSpan(
        children: [
          if (due != null)
            TextSpan(
              text: parts.isEmpty ? due : '$due · ',
              style: TextStyle(color: s.warning, fontWeight: FontWeight.w600),
            ),
          TextSpan(text: parts.join(' · ')),
        ],
      ),
      style: TextStyle(fontSize: 13, color: s.muted, height: 1.35),
    );
  }
}

/// The facts [TaskMeta] lists after the due date.
List<String> taskFacts(Task t, {int? plannedMin}) => [
  if (t.status == TaskStatus.waiting && t.waitingOn.isNotEmpty)
    'Waiting on ${t.waitingOn}',
  if (t.status == TaskStatus.waiting && t.followUpAt != null)
    'Check back ${formatDue(t.followUpAt!, DateTime.now())}',
  plannedMin != null && plannedMin != t.estimateMin
      ? '${formatMinutes(plannedMin)} of ${formatMinutes(t.estimateMin)}'
      : formatMinutes(t.estimateMin),
  if (t.steps.isNotEmpty)
    '${t.steps.where((i) => i.done).length}/${t.steps.length} steps',
  if (t.priority.index <= Priority.p2.index) t.priority.label,
  if (t.ugh >= 2) ughLabels[t.ugh],
  if (t.requiresLeavingHouse)
    t.location.isEmpty ? 'Out of the house' : 'Out: ${t.location}',
  if (t.workspace == Workspace.work) 'Work',
  if (t.repeat != Repeat.none) t.repeat.short,
  for (final tag in t.tagList) '#$tag',
  if (t.isOpen &&
      t.scheduledStart != null &&
      t.scheduledStart!.isAfter(DateTime.now()))
    'From ${formatDate(t.scheduledStart!)}',
];

/// "5 pm" today, "tomorrow 9 am", otherwise "Oct 21".
String formatDue(DateTime d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final hasTime = d.hour != 0 || d.minute != 0;
  if (day == today) return hasTime ? formatClock(d) : 'today';
  if (day == today.add(const Duration(days: 1))) {
    return hasTime ? 'tomorrow ${formatClock(d)}' : 'tomorrow';
  }
  return formatDate(d);
}

/// "5 pm", "9:30 am".
String formatClock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
  return '$h$m ${d.hour < 12 ? 'am' : 'pm'}';
}

String formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

/// Short estimate for pills and mono text: "15m", "1h", "1h 30m".
String shortMinutes(int min) {
  if (min < 60) return '${min}m';
  final h = min ~/ 60;
  final m = min % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
