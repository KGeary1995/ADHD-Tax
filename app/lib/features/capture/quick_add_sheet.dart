import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../focus/focus_route.dart';
import '../../widgets/task_chips.dart';
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

  /// Carries what's been entered so far into the full editor.
  void _openFullForm() {
    final now = ref.read(clockProvider)();
    final draft = Task(
      id: '',
      title: _title.text.trim(),
      estimateMin: _estimate,
      priority: _priority,
      requiresLeavingHouse: _leave,
      ugh: _ugh,
      workspace: _workspace,
      createdAt: now,
      updatedAt: now,
    );
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/task/new', extra: draft);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final side = narrow ? 16.0 : 20.0;
    // Sits on top of the keyboard when it's open, above the system
    // navigation bar when it isn't.
    final bottom = MediaQuery.viewInsetsOf(context).bottom > 0
        ? MediaQuery.viewInsetsOf(context).bottom
        : MediaQuery.viewPaddingOf(context).bottom;

    Widget section(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionLabel(label), child],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(side, 20, side, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _brainDump ? 'Brain dump' : 'Quick add',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Brain dump'),
                        avatar: const Icon(
                          Icons.psychology_alt_outlined,
                          size: 18,
                        ),
                        selected: _brainDump,
                        onSelected: (v) => setState(() => _brainDump = v),
                      ),
                      if (!_brainDump)
                        ActionChip(
                          label: const Text('Full task form'),
                          avatar: const Icon(Icons.open_in_full, size: 18),
                          tooltip:
                              'First step, due date, notes, energy and more',
                          onPressed: _openFullForm,
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
                  section(
                    'Workspace',
                    ChoiceGroup(
                      values: Workspace.values,
                      selected: _workspace,
                      labelOf: (w) => w.label,
                      onSelected: (w) => setState(() => _workspace = w),
                    ),
                  ),
                  if (!_brainDump) ...[
                    section(
                      'How long?',
                      ChoiceGroup(
                        values: estimatePresets,
                        selected: _estimate,
                        labelOf: formatMinutes,
                        onSelected: (m) => setState(() => _estimate = m),
                      ),
                    ),
                    section(
                      'Priority',
                      ChoiceGroup(
                        values: Priority.values,
                        selected: _priority,
                        labelOf: (p) => p.label,
                        onSelected: (p) => setState(() => _priority = p),
                      ),
                    ),
                    section(
                      'How much do you dread it?',
                      ChoiceGroup(
                        values: [for (var i = 0; i < ughLabels.length; i++) i],
                        selected: _ugh,
                        labelOf: (i) => ughLabels[i],
                        onSelected: (i) => setState(() => _ugh = i),
                      ),
                    ),
                    section(
                      'Errand',
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.directions_car_outlined),
                        title: const Text('Need to leave the house'),
                        value: _leave,
                        onChanged: (v) => setState(() => _leave = v),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Pinned below the scrolling fields so the buttons stay visible
          // however long the form gets.
          Padding(
            padding: EdgeInsets.fromLTRB(side, 8, side, 16),
            child: Row(
              children: [
                if (!_brainDump) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canSave ? () => _save(start: true) : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(narrow ? 'Add & start' : 'Add & start now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: Text(_brainDump ? 'Capture all' : 'Add'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
