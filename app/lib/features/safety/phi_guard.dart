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
  'Birth date': RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-](19\d{2}|200\d)\b'),
  'Social security number': RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
  'Record or account number': RegExp(
    r'\b(mrn|med(ical)? ?rec(ord)?|acct|account) ?(#|no\.?|number)?:? ?\d{4,}\b',
    caseSensitive: false,
  ),
  'Long ID number': RegExp(r'\b\d{7,}\b'),
  // "pt John Smith", "patient Mary Jones", "Mrs. Lopez".
  "Someone's name": RegExp(
    r'\b([Pp]t\.?|[Pp]atient|[Mm]rs?\.|[Mm]s\.)\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)?\b',
  ),
};

List<PhiHit> scanForPhi(String text) {
  final hits = <PhiHit>[];
  for (final e in _patterns.entries) {
    final m = e.value.firstMatch(text);
    if (m != null) hits.add(PhiHit(e.key, m.group(0)!));
  }
  return hits;
}

const phiWarning =
    "Looks like someone's personal details. Consider initials or a "
    'reference number instead: task text syncs to your Google Drive, and '
    'to the AI helper if you turn it on.';
