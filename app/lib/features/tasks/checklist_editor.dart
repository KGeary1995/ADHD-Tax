import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/checklist.dart';

/// Edits a checklist string: tick, rename, remove, add. Pasting several
/// lines into "Add a step" adds one step per line.
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Add a step',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  final _add = TextEditingController();
  final _addFocus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  List<ChecklistItem> get _items => parseChecklist(widget.value);

  void _set(List<ChecklistItem> items) =>
      widget.onChanged(encodeChecklist(items));

  void _addTyped() {
    final lines = _add.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    if (lines.isEmpty) return;
    _set([..._items, ...parseChecklist(lines.join('\n'))]);
    _add.clear();
    _addFocus.requestFocus();
  }

  Future<void> _rename(int i) async {
    final items = _items;
    final c = TextEditingController(text: items[i].text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit step'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    items[i] = ChecklistItem(text.trim(), done: items[i].done);
    _set(items);
  }

  void _move(int i, int by) {
    final items = _items;
    final j = i + by;
    if (j < 0 || j >= items.length) return;
    final it = items.removeAt(i);
    items.insert(j, it);
    _set(items);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final items = _items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          ChecklistRow(
            item: items[i],
            onToggle: () {
              final next = [...items];
              next[i] = next[i].toggled();
              _set(next);
            },
            onTapText: () => _rename(i),
            trailing: PopupMenuButton<String>(
              useRootNavigator: true,
              tooltip: 'Step options',
              icon: Icon(Icons.more_vert_rounded, color: s.muted, size: 20),
              onSelected: (v) => switch (v) {
                'up' => _move(i, -1),
                'down' => _move(i, 1),
                'edit' => _rename(i),
                _ => _set([...items]..removeAt(i)),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (i > 0)
                  const PopupMenuItem(value: 'up', child: Text('Move up')),
                if (i < items.length - 1)
                  const PopupMenuItem(value: 'down', child: Text('Move down')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ),
        const SizedBox(height: 6),
        TextField(
          controller: _add,
          focusNode: _addFocus,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          // Multi-line so a pasted list keeps its line breaks; a line
          // break (pasted, or Enter on a keyboard) adds what's there.
          minLines: 1,
          maxLines: 4,
          onChanged: (v) {
            if (v.contains('\n')) _addTyped();
          },
          onSubmitted: (_) => _addTyped(),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.add_rounded),
            suffixIcon: IconButton(
              tooltip: 'Add step',
              icon: const Icon(Icons.keyboard_return_rounded),
              onPressed: _addTyped,
            ),
          ),
        ),
      ],
    );
  }
}

/// One checklist line: a box and its text. Used in the editor and on the
/// focus screen.
class ChecklistRow extends StatelessWidget {
  const ChecklistRow({
    super.key,
    required this.item,
    required this.onToggle,
    this.onTapText,
    this.trailing,
  });

  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback? onTapText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Row(
      children: [
        Checkbox(value: item.done, onChanged: (_) => onToggle()),
        Expanded(
          child: InkWell(
            onTap: onTapText ?? onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                item.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: item.done ? s.muted : s.onSurface,
                  decoration: item.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// "2 of 5" for a checklist, '' when there is none.
String stepsProgress(List<ChecklistItem> items) => items.isEmpty
    ? ''
    : '${items.where((i) => i.done).length} of ${items.length}';
