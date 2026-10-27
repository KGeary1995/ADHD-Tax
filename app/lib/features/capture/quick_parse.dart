/// Reads the extras out of a one-line task: "Call insurance tomorrow 2pm
/// 15 min #billing !!" → title "Call insurance", due tomorrow at 2 pm,
/// 15 minutes, tag billing, High priority.
///
/// Offline and rule-based (no AI). Anything it picks up is shown as a chip
/// in Quick add, and tapping a chip puts those words back in the title, so
/// a wrong guess costs one tap. Pure Dart.
library;

import '../../data/models/task.dart';

/// One thing understood, for the preview chips. [key] is what to pass in
/// `ignore` to leave it in the title instead.
class QuickBit {
  const QuickBit(this.key, this.label);
  final String key;
  final String label;

  @override
  String toString() => '$key: $label';
}

class QuickParse {
  const QuickParse({
    required this.title,
    this.dueAt,
    this.estimateMin,
    this.priority,
    this.workspace,
    this.tags = const [],
    this.bits = const [],
  });

  /// What's left once the understood words are taken out.
  final String title;
  final DateTime? dueAt;
  final int? estimateMin;
  final Priority? priority;
  final Workspace? workspace;
  final List<String> tags;
  final List<QuickBit> bits;

  bool get understoodAnything => bits.isNotEmpty;
}

/// Keys for [parseQuickAdd]'s `ignore`.
const qkDue = 'due';
const qkLength = 'length';
const qkPriority = 'priority';
const qkWorkspace = 'workspace';
String qkTag(String tag) => 'tag:$tag';

RegExp _re(String p) => RegExp(p, caseSensitive: false);

const _pre = r'(?:(?:due|by|on|for)\s+)?';
const _partOfDay = r'(?:\s+(morning|afternoon|evening|night))?';

const _weekdays = {
  'monday': 1,
  'mon': 1,
  'tuesday': 2,
  'tues': 2,
  'tue': 2,
  'wednesday': 3,
  'weds': 3,
  'wed': 3,
  'thursday': 4,
  'thurs': 4,
  'thur': 4,
  'thu': 4,
  'friday': 5,
  'fri': 5,
  'saturday': 6,
  'sat': 6,
  'sunday': 7,
  'sun': 7,
};

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};
const _monthNames =
    'january|february|march|april|may|june|july|august|september|october|'
    'november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec';

/// Words that may follow a bare "at 5" and still leave it a time.
const _whenWords =
    'today|tonight|tomorrow|tmrw|tmr|on|next|this|in|by|due|for|every|'
    'morning|afternoon|evening|night|weekend|eod|end|'
    'monday|mon|tuesday|tues|tue|wednesday|weds|wed|thursday|thurs|thur|thu|'
    'friday|fri|saturday|sat|sunday|sun|$_monthNames';

const _numberWords = {
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
};

QuickParse parseQuickAdd(
  String text,
  DateTime now, {
  Set<String> ignore = const {},
}) {
  var rest = ' $text ';
  final bits = <QuickBit>[];

  /// Finds the first match [accept] allows, blanks it out of [rest], and
  /// returns it.
  RegExpMatch? take(RegExp re, [bool Function(RegExpMatch m)? accept]) {
    for (final m in re.allMatches(rest)) {
      if (accept != null && !accept(m)) continue;
      rest = '${rest.substring(0, m.start)} ${rest.substring(m.end)}';
      return m;
    }
    return null;
  }

  // --- #tags, and #work / #personal for the workspace ----------------------
  final tags = <String>[];
  Workspace? workspace;
  for (final m in _re(r'(?<![\w#])#([a-z][\w-]*)').allMatches(rest).toList()) {
    final tag = m.group(1)!.toLowerCase();
    final ws = Workspace.values.asNameMap()[tag];
    if (ws != null && !ignore.contains(qkWorkspace) && workspace == null) {
      workspace = ws;
    } else if (ws == null && !ignore.contains(qkTag(tag))) {
      if (!tags.contains(tag)) tags.add(tag);
    } else {
      continue;
    }
    rest = rest.replaceFirst(
      _re('(?<![\\w#])#${RegExp.escape(tag)}(?![\\w-])'),
      ' ',
    );
  }

  // --- How long ------------------------------------------------------------
  int? estimate;
  if (!ignore.contains(qkLength)) {
    final hm = take(
      _re(
        r'(?<![\w.])(?:for\s+)?(\d{1,2})\s*h(?:ours?|rs?)?\s*(?:and\s+)?'
        r'(\d{1,2})\s*m(?:in(?:ute)?s?)?\b',
      ),
    );
    if (hm != null) {
      estimate = int.parse(hm.group(1)!) * 60 + int.parse(hm.group(2)!);
    } else if (take(_re(r'\b(?:for\s+)?(?:half\s+an?\s+hour|half\s+hour)\b'))
        case _?) {
      estimate = 30;
    } else if (take(_re(r'\b(?:for\s+)?an\s+hour\b')) case _?) {
      estimate = 60;
    } else if (take(
          _re(
            r'(?<![\w.:/])(?:for\s+)?(\d+(?:\.\d+)?)\s*'
            r'(minutes?|mins?|m|hours?|hrs?|h)\b',
          ),
        )
        case final m?) {
      final n = double.parse(m.group(1)!);
      estimate = (m.group(2)!.toLowerCase().startsWith('h') ? n * 60 : n)
          .round();
    }
    if (estimate != null) {
      estimate = estimate.clamp(1, 24 * 60);
      bits.add(QuickBit(qkLength, formatMinutes(estimate)));
    }
  }

  // --- When ----------------------------------------------------------------
  DateTime? day;
  int? hour;
  var minute = 0;
  int? defaultHour;
  // The hour came without am/pm and was guessed: "at 5" is 5 pm.
  var guessed = false;
  if (!ignore.contains(qkDue)) {
    // Times first, so "at 2" isn't read as a date.
    if (take(
          _re(
            r'(?<![\w:])(?:at\s+|@\s*)?(\d{1,2})(?::([0-5]\d))?\s*'
            r'(a\.?m\.?|p\.?m\.?)(?![\w])',
          ),
          (m) => (int.tryParse(m.group(1)!) ?? 0).between(1, 12),
        )
        case final m?) {
      final h = int.parse(m.group(1)!) % 12;
      hour = m.group(3)!.toLowerCase().startsWith('p') ? h + 12 : h;
      minute = int.tryParse(m.group(2) ?? '') ?? 0;
    } else if (take(
          _re(r'(?<![\w:/])(?:at\s+|@\s*)?([01]?\d|2[0-3]):([0-5]\d)(?![\w:])'),
        )
        case final m?) {
      hour = int.parse(m.group(1)!);
      minute = int.parse(m.group(2)!);
      // "at 5:30" means 5:30 pm, like "at 5". Written with two digits
      // ("05:30", "17:30") it's read as it is.
      if (m.group(1)!.length == 1) {
        guessed = true;
        if (hour.between(1, 6)) hour += 12;
      }
    } else if (take(_re(r'\b(?:at\s+)?(noon|midday)\b')) case _?) {
      hour = 12;
    } else if (take(
          // Only with nothing after it but a date or time word: "Look at 3
          // houses" isn't due at 3.
          _re(
            r'(?<![\w])(?:at|@)\s*(\d{1,2})(?![\w:/%.])'
            '(?=\\s*(?:\$|[,.;!?#]|(?:$_whenWords)\\b))',
          ),
          (m) => (int.tryParse(m.group(1)!) ?? 0).between(1, 12),
        )
        case final m?) {
      // "at 5" means 5 pm; "at 9" means 9 am.
      final h = int.parse(m.group(1)!);
      hour = h <= 6 ? h + 12 : h;
      guessed = true;
    }

    final relative = take(
      _re(
        '(?<![\\w])$_pre(today|tonight|tomorrow|tmrw|tmr|eod|end of day)'
        '$_partOfDay\\b',
      ),
    );
    if (relative != null) {
      final w = relative.group(1)!.toLowerCase();
      day = _addDays(
        now,
        w.startsWith('tm') || w.startsWith('tomorrow') ? 1 : 0,
      );
      defaultHour = switch (w) {
        'tonight' => 20,
        _ => _partHour(relative.group(2)),
      };
    } else if (take(
          _re(
            '(?<![\\w])$_pre(next\\s+|this\\s+)?'
            '(${_weekdays.keys.join('|')})$_partOfDay\\b',
          ),
          // "sat" and "sun" are also plain words: abbreviations need
          // "on", "by", "next"... in front.
          (m) =>
              m.group(2)!.length >= 6 ||
              !m
                  .group(0)!
                  .trim()
                  .toLowerCase()
                  .startsWith(m.group(2)!.toLowerCase()),
        )
        case final m?) {
      final target = _weekdays[m.group(2)!.toLowerCase()]!;
      final next = m.group(1)?.trim().toLowerCase() == 'next';
      var ahead = (target - now.weekday) % 7;
      if (ahead == 0 && next) ahead = 7;
      day = _addDays(now, ahead);
      defaultHour = _partHour(m.group(3));
    } else if (take(_re(r'\bnext\s+week\b')) case _?) {
      day = _addDays(now, 8 - now.weekday);
    } else if (take(_re(r'\b(?:this\s+|on\s+the\s+)?weekend\b')) case _?) {
      // On a Sunday, this weekend is today.
      day = _addDays(now, now.weekday == DateTime.sunday ? 0 : 6 - now.weekday);
    } else if (take(
          _re(
            r'\bin\s+(\d+|a|an|one|two|three|four|five|six|seven)\s+(days?|weeks?)\b',
          ),
        )
        case final m?) {
      final n =
          int.tryParse(m.group(1)!) ?? _numberWords[m.group(1)!.toLowerCase()]!;
      final days = m.group(2)!.toLowerCase().startsWith('w') ? n * 7 : n;
      day = _addDays(now, days.clamp(0, 3650));
    } else if (take(
          _re(
            '(?<![\\w])$_pre($_monthNames)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b',
          ),
          (m) => _validDate(
            _months[m.group(1)!.toLowerCase().substring(0, 3)]!,
            int.parse(m.group(2)!),
          ),
        )
        case final m?) {
      day = _dateIn(
        now,
        _months[m.group(1)!.toLowerCase().substring(0, 3)]!,
        int.parse(m.group(2)!),
      );
    } else if (take(
          _re('(?<![\\w])$_pre(\\d{1,2})(?:st|nd|rd|th)?\\s+($_monthNames)\\b'),
          (m) => _validDate(
            _months[m.group(2)!.toLowerCase().substring(0, 3)]!,
            int.parse(m.group(1)!),
          ),
        )
        case final m?) {
      day = _dateIn(
        now,
        _months[m.group(2)!.toLowerCase().substring(0, 3)]!,
        int.parse(m.group(1)!),
      );
    } else if (take(
          _re(
            r'(?<![\w/])'
            '$_pre'
            r'(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?(?![\w/])',
          ),
          (m) =>
              _validDate(int.parse(m.group(1)!), int.parse(m.group(2)!)) &&
              !_looksLikeFraction(m, rest),
        )
        case final m?) {
      final y = m.group(3);
      day = y == null
          ? _dateIn(now, int.parse(m.group(1)!), int.parse(m.group(2)!))
          : DateTime(
              y.length == 2 ? 2000 + int.parse(y) : int.parse(y),
              int.parse(m.group(1)!),
              int.parse(m.group(2)!),
            );
    }
  }

  // A guessed hour follows the part of the day: "tonight at 8" is 8 pm,
  // "tomorrow morning at 5" is 5 am.
  if (hour != null && guessed && defaultHour != null) {
    if (defaultHour >= 12 && hour < 12) hour += 12;
    if (defaultHour < 12 && hour >= 12) hour -= 12;
  }

  DateTime? dueAt;
  if (day != null) {
    dueAt = DateTime(
      day.year,
      day.month,
      day.day,
      hour ?? defaultHour ?? 17,
      hour == null ? 0 : minute,
    );
  } else if (hour != null) {
    dueAt = DateTime(now.year, now.month, now.day, hour, minute);
    // A time that's already gone today means tomorrow.
    if (!dueAt.isAfter(now)) {
      dueAt = DateTime(now.year, now.month, now.day + 1, hour, minute);
    }
  }
  if (dueAt != null) bits.add(QuickBit(qkDue, _dueLabel(dueAt, now)));

  // --- Priority ------------------------------------------------------------
  Priority? priority;
  if (!ignore.contains(qkPriority)) {
    if (take(_re(r'(?<![\w!])(!{2,3}|![1-4])(?![\w!])')) case final m?) {
      final t = m.group(1)!;
      priority = switch (t) {
        '!!!' || '!1' => Priority.p1,
        '!!' || '!2' => Priority.p2,
        '!3' => Priority.p3,
        _ => Priority.p4,
      };
    } else if (take(_re(r'\b(urgent|asap)\b')) case _?) {
      priority = Priority.p1;
    } else if (take(_re(r'\b(high|low)\s+priority\b')) case final m?) {
      priority = m.group(1)!.toLowerCase() == 'high'
          ? Priority.p2
          : Priority.p4;
    } else if (take(_re(r'\bsomeday\b')) case _?) {
      priority = Priority.p4;
    }
    if (priority != null) bits.add(QuickBit(qkPriority, priority.label));
  }

  if (workspace != null) bits.add(QuickBit(qkWorkspace, workspace.label));
  for (final t in tags) {
    bits.add(QuickBit(qkTag(t), '#$t'));
  }

  var title = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Words left dangling by what was taken out: "Pay rent by" → "Pay rent".
  final dangling = _re(
    r'^(?:at|on|by|due|for|in|from|@|-|,)\s+|\s+(?:at|on|by|due|for|in|from|@|-|,)$|[\s,;-]+$',
  );
  for (var prev = ''; prev != title;) {
    prev = title;
    title = title.replaceAll(dangling, '').trim();
  }
  // Only extras typed ("tomorrow 2pm"): keep what was typed as the title.
  if (title.isEmpty) title = text.trim();

  return QuickParse(
    title: title,
    dueAt: dueAt,
    estimateMin: estimate,
    priority: priority,
    workspace: workspace,
    tags: tags,
    bits: bits,
  );
}

extension on int {
  bool between(int lo, int hi) => this >= lo && this <= hi;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Midnight [n] calendar days after [d]'s date. Adding `Duration(days: n)`
/// to a local midnight lands on 23:00 of the day before when the clocks
/// go back in between.
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int? _partHour(String? part) => switch (part?.toLowerCase()) {
  'morning' => 9,
  'afternoon' => 14,
  'evening' => 18,
  'night' => 20,
  _ => null,
};

/// A day that exists in that month in some year: Feb 29 does, Feb 30 and
/// Apr 31 don't.
bool _validDate(int month, int day) =>
    month >= 1 &&
    month <= 12 &&
    day >= 1 &&
    day <= DateTime(2024, month + 1, 0).day; // 2024 is a leap year

/// "1/2 gallon": a small fraction with a word after it, not Jan 2. A date
/// written that way has "on", "by"… in front, or a year.
bool _looksLikeFraction(RegExpMatch m, String text) {
  if (m.group(3) != null) return false;
  if (RegExp(r'^\s*[a-z]', caseSensitive: false).hasMatch(m.group(0)!)) {
    return false; // "by 1/2"
  }
  final a = int.parse(m.group(1)!);
  final b = int.parse(m.group(2)!);
  if (a >= b || !const {2, 3, 4, 8}.contains(b)) return false;
  return RegExp(
    r'^\s*[a-z]',
    caseSensitive: false,
  ).hasMatch(text.substring(m.end));
}

/// The next [month]/[day] from today: a date already past this year means
/// next year, and Feb 29 the next year that has one.
DateTime _dateIn(DateTime now, int month, int day) {
  DateTime inYear(int y) {
    while (DateTime(y, month, day).day != day) {
      y++;
    }
    return DateTime(y, month, day);
  }

  final d = inYear(now.year);
  return d.isBefore(_day(now)) ? inYear(d.year + 1) : d;
}

String _dueLabel(DateTime d, DateTime now) {
  final today = _day(now);
  final day = _day(d);
  // Rounded: across a clock change two midnights are 23 or 25 hours apart.
  final diff = (day.difference(today).inHours / 24).round();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
  final clock = '$h$m ${d.hour < 12 ? 'am' : 'pm'}';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  final when = switch (diff) {
    0 => 'today',
    1 => 'tomorrow',
    > 1 && < 7 => days[d.weekday - 1],
    _ => '${months[d.month - 1]} ${d.day}',
  };
  return 'Due $when $clock';
}
