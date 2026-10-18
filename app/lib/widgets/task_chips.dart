import 'package:flutter/material.dart';

import '../core/theme/app_themes.dart';
import '../data/models/task.dart';

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final c = color ?? s.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(s.radius / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact metadata row for a task: time, priority, home/out, dread.
class TaskChips extends StatelessWidget {
  const TaskChips({super.key, required this.task, this.plannedMin});

  final Task task;

  /// Shown instead of the estimate when the picker offers a chunk.
  final int? plannedMin;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final t = task;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        InfoChip(
          icon: Icons.timer_outlined,
          label: plannedMin != null && plannedMin != t.estimateMin
              ? '${formatMinutes(plannedMin!)} of ${formatMinutes(t.estimateMin)}'
              : formatMinutes(t.estimateMin),
        ),
        if (t.priority.index <= Priority.p2.index)
          InfoChip(
            icon: Icons.flag_outlined,
            label: t.priority.label,
            color: t.priority == Priority.p1 ? s.danger : s.warning,
          ),
        if (t.requiresLeavingHouse)
          InfoChip(
            icon: Icons.directions_car_outlined,
            label: t.location.isEmpty ? 'Out' : t.location,
            color: s.secondary,
          ),
        if (t.ugh > 0)
          InfoChip(
            icon: Icons.sentiment_dissatisfied_outlined,
            label: ughLabels[t.ugh],
            color: s.warning,
          ),
        if (t.workspace == Workspace.work)
          InfoChip(icon: Icons.work_outline, label: 'Work', color: s.primary),
        if (t.dueAt != null)
          InfoChip(
            icon: Icons.event_outlined,
            label: _due(t.dueAt!, t.hardDeadline),
            color: t.hardDeadline ? s.danger : null,
          ),
        if (t.repeat != Repeat.none)
          InfoChip(icon: Icons.repeat, label: t.repeat.short),
        if (t.isOpen &&
            t.scheduledStart != null &&
            t.scheduledStart!.isAfter(DateTime.now()))
          InfoChip(
            icon: Icons.schedule,
            label: 'From ${_date(t.scheduledStart!)}',
          ),
      ],
    );
  }
}

String _due(DateTime d, bool hard) {
  return '${hard ? 'Hard: ' : ''}${_date(d)}';
}

String _date(DateTime d) {
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

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
        color: context.spec.muted,
      ),
    ),
  );
}

/// Pick exactly one of a few options. Chips wrap onto the next line on a
/// narrow phone instead of squeezing their labels like a SegmentedButton.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in values)
        ChoiceChip(
          label: Text(labelOf(v)),
          selected: v == selected,
          // Tapping the selected chip keeps it selected.
          onSelected: (_) => onSelected(v),
        ),
    ],
  );
}

/// Centers content with a max width so desktop layouts stay readable.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1180});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
