import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/checklist.dart';
import '../../core/theme/ph.dart';

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
              icon: Icon(Ph.dotsSixVertical, color: s.ink3, size: 18),
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
          style: TextStyle(fontSize: 16, color: s.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: s.star, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            prefixIcon: Icon(Ph.plus, size: 20, color: s.ink3),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            suffixIcon: ListenableBuilder(
              listenable: _add,
              builder: (context, _) => _add.text.trim().isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Add step',
                      icon: const Icon(Ph.arrowElbowDownLeft),
                      onPressed: _addTyped,
                    ),
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
        Semantics(
          checked: item.done,
          button: true,
          label: item.text,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onToggle,
            radius: 22,
            child: SizedBox.square(
              dimension: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: item.done ? s.star : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: item.done ? s.star : s.ink3,
                      width: 2,
                    ),
                  ),
                  child: item.done
                      ? Icon(Ph.checkBold, size: 12, color: s.onStar)
                      : null,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onTapText ?? onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                item.text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: item.done ? s.ink3 : s.ink,
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  decorationColor: s.ink3,
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
