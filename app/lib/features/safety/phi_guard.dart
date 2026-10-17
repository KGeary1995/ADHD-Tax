/// Lightweight "this looks like patient info" check for the Work workspace.
///
/// This is a nudge, not a compliance control: it catches the common slips
/// (DOBs, MRNs, "pt Jane Doe") so the user writes initials or a ticket number
/// instead. Pure Dart.
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
  'Birth-year date': RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-](19\d{2}|200\d)\b'),
  'SSN': RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
  'MRN / account number': RegExp(
    r'\b(mrn|med(ical)? ?rec(ord)?|acct|account) ?(#|no\.?|number)?:? ?\d{4,}\b',
    caseSensitive: false,
  ),
  'Long ID number': RegExp(r'\b\d{7,}\b'),
  // "pt John Smith", "patient Mary Jones", "Mrs. Lopez".
  'Patient name': RegExp(
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
    'Looks like patient info. Use initials or a ticket number instead — '
    'task text syncs to Google Drive and to AI features if you turn them on.';
