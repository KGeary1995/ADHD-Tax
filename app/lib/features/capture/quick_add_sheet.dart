import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../focus/focus_route.dart';
import '../picker/picker_controller.dart';
import '../safety/phi_warning.dart';
import '../tasks/tasks_controller.dart';

/// Five-second capture. Only the title is required.
Future<void> showQuickAdd(
  BuildContext context, {
  bool brainDump = false,
}) async {
  final startNow = await showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => QuickAddSheet(brainDump: brainDump),
  );
  if (startNow != null && context.mounted) {
    openFocus(context, startNow.id, minutes: startNow.estimateMin);
  }
}

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, this.brainDump = false});
  final bool brainDump;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _title = TextEditingController();
  late bool _brainDump = widget.brainDump;
  int _estimate = 15;
  Priority _priority = Priority.p3;
  bool _leave = false;
  int _ugh = 0;
  late Workspace _workspace;

  @override
  void initState() {
    super.initState();
    final ws = ref.read(pickerInputsProvider).workspaces;
    _workspace = ws.length == 1 ? ws.first : Workspace.personal;
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty;

  void _save({bool start = false}) {
    if (!_canSave) return;
    final tasks = ref.read(tasksProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (_brainDump) {
      final created = tasks.createMany(
        _title.text.split('\n'),
        workspace: _workspace,
      );
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Captured ${created.length} tasks. Your head is lighter now.',
          ),
        ),
      );
      return;
    }
    final t = tasks.create(
      title: _title.text,
      estimateMin: _estimate,
      priority: _priority,
      requiresLeavingHouse: _leave,
      ugh: _ugh,
      workspace: _workspace,
    );
    Navigator.pop(context, start ? t : null);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _brainDump ? 'Brain dump' : 'Quick add',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: s.onSurface,
                  ),
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('Brain dump'),
                  avatar: const Icon(Icons.psychology_alt_outlined, size: 18),
                  selected: _brainDump,
                  onSelected: (v) => setState(() => _brainDump = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: true,
              minLines: _brainDump ? 5 : 1,
              maxLines: _brainDump ? 12 : 1,
              textInputAction: _brainDump
                  ? TextInputAction.newline
                  : TextInputAction.done,
              onSubmitted: _brainDump ? null : (_) => _save(),
              decoration: InputDecoration(
                hintText: _brainDump
                    ? 'Everything in your head, one per line.\nDon\'t sort it. Just get it out.'
                    : 'What needs doing?',
              ),
            ),
            PhiWarning(text: _title.text, workspace: _workspace),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SegmentedButton<Workspace>(
                  showSelectedIcon: false,
                  segments: [
                    for (final w in Workspace.values)
                      ButtonSegment(value: w, label: Text(w.label)),
                  ],
                  selected: {_workspace},
                  onSelectionChanged: (v) =>
                      setState(() => _workspace = v.first),
                ),
              ],
            ),
            if (!_brainDump) ...[
              const SizedBox(height: 14),
              Text('How long?', style: TextStyle(color: s.muted, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in estimatePresets)
                    ChoiceChip(
                      label: Text(formatMinutes(m)),
                      selected: _estimate == m,
                      onSelected: (_) => setState(() => _estimate = m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in Priority.values)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: _priority == p,
                      onSelected: (_) => setState(() => _priority = p),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.directions_car_outlined, size: 18),
                    label: const Text('Need to leave the house'),
                    selected: _leave,
                    onSelected: (v) => setState(() => _leave = v),
                  ),
                  for (var i = 1; i < ughLabels.length; i++)
                    ChoiceChip(
                      label: Text(ughLabels[i]),
                      selected: _ugh == i,
                      onSelected: (v) => setState(() => _ugh = v ? i : 0),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (!_brainDump)
                  TextButton.icon(
                    onPressed: _canSave ? () => _save(start: true) : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Add & start now'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: Text(_brainDump ? 'Capture all' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
