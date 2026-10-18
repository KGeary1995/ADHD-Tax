import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../focus/focus_route.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../picker/picker_controller.dart';
import '../safety/phi_warning.dart';
import '../tasks/tasks_controller.dart';
import 'voice_input.dart';

/// Five-second capture. Only the title is required.
Future<void> showQuickAdd(
  BuildContext context, {
  bool brainDump = false,
  String initialTitle = '',
  String initialNotes = '',
}) async {
  final startNow = await showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => QuickAddSheet(
      brainDump: brainDump,
      initialTitle: initialTitle,
      initialNotes: initialNotes,
    ),
  );
  if (startNow != null && context.mounted) {
    openFocus(context, startNow.id, minutes: startNow.estimateMin);
  }
}

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.brainDump = false,
    this.initialTitle = '',
    this.initialNotes = '',
  });
  final bool brainDump;

  /// Prefilled, e.g. from text shared from another app.
  final String initialTitle;
  final String initialNotes;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late String _notes = widget.initialNotes;
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
      notes: _notes,
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
      notes: _notes,
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
    final side = narrow ? 18.0 : 22.0;
    // Sits on top of the keyboard when it's open, above the system
    // navigation bar when it isn't.
    final bottom = MediaQuery.viewInsetsOf(context).bottom > 0
        ? MediaQuery.viewInsetsOf(context).bottom
        : MediaQuery.viewPaddingOf(context).bottom;

    Widget section(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [FieldLabel(label), child],
      ),
    );

    final link = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(
        fontFamily: Fonts.ui,
        fontSize: 14,
        fontWeight: FontWeight.w500,
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
              padding: EdgeInsets.fromLTRB(side, 0, side, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        _brainDump ? 'Brain dump' : 'Add a task',
                        style: s.display(26),
                      ),
                      Wrap(
                        children: [
                          TextButton(
                            style: link,
                            onPressed: () =>
                                setState(() => _brainDump = !_brainDump),
                            child: Text(_brainDump ? 'One task' : 'Brain dump'),
                          ),
                          if (!_brainDump)
                            Tooltip(
                              message:
                                  'First step, due date, notes, energy and '
                                  'more',
                              child: TextButton(
                                style: link,
                                onPressed: _openFullForm,
                                child: const Text('Full form'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _title,
                    autofocus: true,
                    minLines: _brainDump ? 5 : 1,
                    maxLines: _brainDump ? 12 : 1,
                    style: TextStyle(fontSize: 17, color: s.onSurface),
                    textInputAction: _brainDump
                        ? TextInputAction.newline
                        : TextInputAction.done,
                    onSubmitted: _brainDump ? null : (_) => _save(),
                    decoration: InputDecoration(
                      hintText: _brainDump
                          ? 'Everything in your head, one per line.\nDon\'t sort it. Just get it out.'
                          : 'What needs doing?',
                      suffixIcon: VoiceButton(
                        controller: _title,
                        newLine: _brainDump,
                      ),
                    ),
                  ),
                  if (_notes.isNotEmpty && !_brainDump)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.notes_rounded, size: 16, color: s.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Note: $_notes',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: s.muted),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove note',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: () => setState(() => _notes = ''),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  PhiWarning(
                    text: '${_title.text}\n$_notes',
                    workspace: _workspace,
                  ),
                  if (!_brainDump) ...[
                    section(
                      'How long?',
                      ChoiceGroup(
                        values: estimatePresets,
                        selected: _estimate,
                        mono: true,
                        labelOf: shortMinutes,
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
                  ],
                  const SizedBox(height: 18),
                  // Where it goes and whether it's an errand: two yes/no
                  // facts, kept apart from the dread scale above.
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 220,
                        child: Segmented<Workspace>(
                          values: Workspace.values,
                          selected: _workspace,
                          inset: s.isDark,
                          labelOf: (w) => w.label,
                          onSelected: (w) => setState(() => _workspace = w),
                        ),
                      ),
                      if (!_brainDump)
                        Pill(
                          label: 'Leave the house',
                          icon: Icons.directions_car_outlined,
                          selected: _leave,
                          onTap: () => setState(() => _leave = !_leave),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Pinned below the scrolling fields so the buttons stay visible
          // however long the form gets.
          Padding(
            padding: EdgeInsets.fromLTRB(side, 12, side, 16),
            child: Row(
              children: [
                if (!_brainDump) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _canSave ? () => _save(start: true) : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      child: const Text('Add & start'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
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
