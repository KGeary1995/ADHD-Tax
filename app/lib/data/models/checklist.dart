/// A task's checklist, stored as one string so it syncs as a single field
/// (a list field would be re-stamped on every save; see docs/DECISIONS.md).
///
/// One item per line: `[ ] Call the office` or `[x] Find the form`. Lines
/// without a box (pasted text, older edits) count as open items. Pure Dart.
library;

class ChecklistItem {
  const ChecklistItem(this.text, {this.done = false});

  final String text;
  final bool done;

  ChecklistItem toggled() => ChecklistItem(text, done: !done);

  @override
  bool operator ==(Object other) =>
      other is ChecklistItem && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);

  @override
  String toString() => '${done ? '[x]' : '[ ]'} $text';
}

final _box = RegExp(r'^\[( |x|X)\]\s*');

/// A box with nothing after it (`[ ]`) is skipped, as [encodeChecklist]
/// skips it, so an item's index means the same in both.
List<ChecklistItem> parseChecklist(String raw) => [
  for (final line in raw.split('\n'))
    if (line.trim().isNotEmpty)
      ?switch (_box.firstMatch(line.trim())) {
        final m? when line.trim().substring(m.end).trim().isEmpty => null,
        final m? => ChecklistItem(
          line.trim().substring(m.end).trim(),
          done: m.group(1) != ' ',
        ),
        null => ChecklistItem(line.trim()),
      },
];

String encodeChecklist(Iterable<ChecklistItem> items) => [
  for (final i in items)
    if (i.text.trim().isNotEmpty)
      '${i.done ? '[x]' : '[ ]'} ${i.text.replaceAll('\n', ' ').trim()}',
].join('\n');

/// The same checklist with every box unticked, for the next copy of a
/// repeating task.
String resetChecklist(String raw) => encodeChecklist([
  for (final i in parseChecklist(raw)) ChecklistItem(i.text),
]);
