import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../safety/phi_warning.dart';
import 'tasks_controller.dart';

/// A waiting task whose check-back date has come.
bool followUpDue(Task t, DateTime now) =>
    t.status == TaskStatus.waiting &&
    t.followUpAt != null &&
    !t.followUpAt!.isAfter(now);

enum _CheckBack {
  tomorrow('Tomorrow'),
  threeDays('In 3 days'),
  nextWeek('Next week'),
  pick('Pick a date'),
  none('No reminder');

  const _CheckBack(this.label);
  final String label;
}

/// 9 am, [days] from today.
DateTime _morning(DateTime now, int days) =>
    DateTime(now.year, now.month, now.day + days, 9);

/// "Waiting on someone": who it's waiting for and when to check back.
/// Used both to park a task and for "Still waiting" on a due follow-up.
Future<void> showWaitingSheet(BuildContext context, Task task) =>
    showAppSheet<void>(
      context: context,
      builder: (_) => _WaitingSheet(task: task),
    );

class _WaitingSheet extends ConsumerStatefulWidget {
  const _WaitingSheet({required this.task});
  final Task task;

  @override
  ConsumerState<_WaitingSheet> createState() => _WaitingSheetState();
}

class _WaitingSheetState extends ConsumerState<_WaitingSheet> {
  late final _who = TextEditingController(text: widget.task.waitingOn)
    ..addListener(() => setState(() {}));
  var _when = _CheckBack.threeDays;
  DateTime? _picked;

  @override
  void dispose() {
    _who.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final d = await showDatePicker(
      context: context,
      initialDate: _morning(now, 1),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _when = _CheckBack.pick;
        _picked = DateTime(d.year, d.month, d.day, 9);
      });
    }
  }

  DateTime? _followUp(DateTime now) => switch (_when) {
    _CheckBack.tomorrow => _morning(now, 1),
    _CheckBack.threeDays => _morning(now, 3),
    _CheckBack.nextWeek => _morning(now, 7),
    _CheckBack.pick => _picked,
    _CheckBack.none => null,
  };

  void _save() {
    final now = ref.read(clockProvider)();
    final at = _followUp(now);
    ref
        .read(tasksProvider.notifier)
        .setWaiting(widget.task.id, waitingOn: _who.text, followUpAt: at);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          at == null
              ? 'Parked under "Waiting on someone".'
              : "Parked. I'll remind you to check back ${formatDue(at, now)}.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final now = ref.read(clockProvider)();
    final at = _followUp(now);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: sheetPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle('Waiting on someone', subtitle: widget.task.title),
              const SizedBox(height: Gap.s6),
              TextField(
                controller: _who,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Who or what? e.g. Quote from the plumber',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    borderSide: BorderSide(color: s.star, width: 2),
                  ),
                ),
              ),
              PhiWarning(text: _who.text, workspace: widget.task.workspace),
              const SizedBox(height: Gap.s7),
              const OptionLabel('Check back'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _CheckBack.values)
                    Pill(
                      label: c == _CheckBack.pick && _picked != null
                          ? formatDate(_picked!)
                          : c.label,
                      selected: _when == c,
                      onTap: c == _CheckBack.pick
                          ? _pickDate
                          : () => setState(() => _when = c),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                at == null
                    ? 'It waits in your list until you move it back.'
                    : 'It comes back to the top of Tasks '
                          '${formatDue(at, now)}, with a reminder on your phone.',
                style: s.caption(),
              ),
              const SizedBox(height: Gap.s8),
              PrimaryButton(
                label: 'Save',
                onPressed: _when == _CheckBack.pick && _picked == null
                    ? null
                    : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
