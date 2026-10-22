import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/note.dart' show parseTags;
import '../../data/models/task.dart';
import '../../data/models/template.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import '../safety/phi_warning.dart';
import '../settings/device_workspaces.dart';
import '../tasks/checklist_editor.dart';
import 'templates_controller.dart';

/// Edits a template. `templateId == 'new'` makes one of [kind].
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({
    super.key,
    required this.templateId,
    this.kind = TemplateKind.task,
  });

  final String templateId;
  final TemplateKind kind;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late Template _t;
  late final bool _isNew;
  late final _name = TextEditingController(text: _t.name);
  late final _title = TextEditingController(text: _t.title);
  late final _body = TextEditingController(text: _t.body);
  late final _tags = TextEditingController(
    text: _t.tags
        .split(',')
        .where((x) => x.isNotEmpty)
        .map((x) => '#$x')
        .join(' '),
  );

  @override
  void initState() {
    super.initState();
    final existing = ref
        .read(templatesProvider.notifier)
        .byId(widget.templateId);
    _isNew = existing == null;
    _t =
        existing ??
        Template(
          id: '',
          kind: widget.kind,
          name: '',
          workspace: ref.read(deviceWorkspacesProvider).primary,
          createdAt: ref.read(clockProvider)(),
        );
    for (final c in [_name, _title, _body]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _title, _body, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    ref
        .read(templatesProvider.notifier)
        .save(
          _t.copyWith(
            name: _name.text.trim(),
            title: _title.text.trim(),
            body: _body.text,
            tags: parseTags(_tags.text.split(RegExp(r'[\s,]+')).join(','))
                .join(','),
          ),
        );
    context.canPop() ? context.pop() : context.go('/templates');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final isTask = _t.kind == TemplateKind.task;

    Widget field(String label, Widget child, {String? help}) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          child,
          if (help != null) ...[
            const SizedBox(height: 4),
            Text(
              help,
              style: TextStyle(color: s.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New template' : 'Edit template'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 12 : 20,
            8,
            narrow ? 12 : 20,
            48,
          ),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isNew)
                    field(
                      'Makes a',
                      ChoiceGroup(
                        values: TemplateKind.values,
                        selected: _t.kind,
                        labelOf: (k) => k.label,
                        onSelected: (k) =>
                            setState(() => _t = _t.copyWith(kind: k)),
                      ),
                    ),
                  field(
                    'Template name',
                    TextField(
                      controller: _name,
                      autofocus: _isNew,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isTask
                            ? 'e.g. Opening checklist'
                            : 'e.g. Huddle notes',
                      ),
                    ),
                  ),
                  if (!ref.watch(deviceWorkspacesProvider).single)
                    field(
                      'Workspace',
                      ChoiceGroup(
                        values: Workspace.values,
                        selected: _t.workspace,
                        labelOf: (w) => w.label,
                        onSelected: (w) =>
                            setState(() => _t = _t.copyWith(workspace: w)),
                      ),
                    ),
                  field(
                    isTask ? 'Task title' : 'Note title',
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isTask ? 'Same as the name' : 'Huddle {date}',
                      ),
                    ),
                    help: '{date} becomes the day you use it, e.g. "Oct 19".',
                  ),
                  if (isTask) ...[
                    field(
                      'Checklist',
                      ChecklistEditor(
                        value: _t.checklist,
                        onChanged: (v) =>
                            setState(() => _t = _t.copyWith(checklist: v)),
                      ),
                    ),
                    field(
                      'Estimate',
                      ChoiceGroup(
                        values: {...estimatePresets, _t.estimateMin}.toList()
                          ..sort(),
                        selected: _t.estimateMin,
                        mono: true,
                        labelOf: shortMinutes,
                        onSelected: (m) =>
                            setState(() => _t = _t.copyWith(estimateMin: m)),
                      ),
                    ),
                    field(
                      'Tags',
                      TextField(
                        controller: _tags,
                        decoration: const InputDecoration(
                          hintText: '#opening #frontdesk',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                      ),
                    ),
                  ] else
                    field(
                      'Note',
                      TextField(
                        controller: _body,
                        minLines: 6,
                        maxLines: 16,
                        decoration: const InputDecoration(
                          hintText: 'Headings and prompts to fill in',
                        ),
                      ),
                    ),
                  PhiWarning(
                    text:
                        '${_name.text}\n${_title.text}\n${_t.checklist}\n'
                        '${_body.text}',
                    workspace: _t.workspace,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
