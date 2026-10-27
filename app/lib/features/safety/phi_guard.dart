/// Lightweight "this looks like someone's personal details" check for the
/// Work workspace (Settings → Sensitive info check; off unless turned on).
///
/// This is a nudge, not a compliance control: it catches the common slips
/// (birth dates, record or account numbers, "Mrs. Jones") so the user writes
/// initials or a reference number instead. Internal names keep "phi" from
/// when it was a patient-info guard. Pure Dart.
library;

class PhiHit {
  const PhiHit(this.kind, this.match);
  final String kind;
  final String match;
}

final _patterns = <String, RegExp>{
  'Date of birth': RegExp(
    r'\b(dob|d\.o\.b\.?|date of birth|birth ?date)\b',
    caseSensitive: false,
  ),
  'Social security number': RegExp(r'\b\d{3}[- ]\d{2}[- ]\d{4}\b'),
  'Record or account number': RegExp(
    r'\b(mrn|med(ical)? ?rec(ord)?|acct|account) ?(#|no\.?|number)?:? ?\d{4,}\b',
    caseSensitive: false,
  ),
  'Long ID number': RegExp(r'\b\d{7,}\b'),
  // "pt John Smith", "patient SMITH", "Mrs. O'Brien", "Mr McDonald".
  "Someone's name": RegExp(
    r"\b([Pp]t\.?|[Pp]atient|[Mm]rs?\.?|[Mm]s\.?)\s+[A-Z][A-Za-z'’-]+"
    r"(\s+[A-Z][A-Za-z'’-]+)?",
  ),
};

/// 3/14/1985, 3-14-85, 1985-03-14.
final _slashDate = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4}|\d{2})\b');
final _isoDate = RegExp(r'\b((?:19|20)\d{2})-(\d{2})-(\d{2})\b');

/// A date in an earlier year looks like a birth date; this year's or a
/// later one is more likely when something is due.
String? _birthDate(String text, DateTime now) {
  int fullYear(String y) {
    if (y.length == 4) return int.parse(y);
    final yy = int.parse(y);
    return yy > now.year % 100 ? 1900 + yy : 2000 + yy;
  }

  for (final m in _slashDate.allMatches(text)) {
    if (fullYear(m.group(3)!) < now.year) return m.group(0);
  }
  for (final m in _isoDate.allMatches(text)) {
    if (int.parse(m.group(1)!) < now.year) return m.group(0);
  }
  return null;
}

List<PhiHit> scanForPhi(String text, {DateTime? now}) {
  final hits = <PhiHit>[];
  for (final e in _patterns.entries) {
    final m = e.value.firstMatch(text);
    if (m != null) hits.add(PhiHit(e.key, m.group(0)!));
  }
  final born = _birthDate(text, now ?? DateTime.now());
  if (born != null) {
    hits.insert(hits.isEmpty ? 0 : 1, PhiHit('Birth date', born));
  }
  return hits;
}

const phiWarning =
    "Looks like someone's personal details. Consider initials or a "
    'reference number instead: task text syncs to your Google Drive, and '
    'to the AI helper if you turn it on.';
