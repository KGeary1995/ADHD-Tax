import 'package:adhd_tax/features/safety/phi_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> kinds(String s) => scanForPhi(s).map((h) => h.kind).toList();

  test('flags common PHI slips', () {
    expect(kinds('Call pt John Smith re: refill'), contains("Someone's name"));
    expect(
      kinds('Patient Maria Lopez needs callback'),
      contains("Someone's name"),
    );
    expect(kinds('Verify DOB for insurance'), contains('Date of birth'));
    expect(kinds('Born 04/12/1961, check coverage'), contains('Birth date'));
    expect(kinds('MRN 4481920 chart review'), isNotEmpty);
    expect(kinds('SSN 123-45-6789'), contains('Social security number'));
  });

  test('leaves ordinary work tasks alone', () {
    expect(scanForPhi('Order more OCT paper'), isEmpty);
    expect(scanForPhi('Staff huddle agenda for 10/20/2026'), isEmpty);
    expect(
      scanForPhi('Follow up with Dr. Patel on schedule template'),
      isEmpty,
    );
    expect(scanForPhi('Call Optos rep about service contract'), isEmpty);
  });
}
