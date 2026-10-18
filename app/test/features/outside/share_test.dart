import 'package:adhd_tax/features/outside/android_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subject becomes the title, text the notes', () {
    final t = taskFromShare(
      const SharedText(
        text: 'https://example.com/form',
        subject: 'Renew registration',
      ),
    );
    expect(t.title, 'Renew registration');
    expect(t.notes, 'https://example.com/form');
  });

  test('first line is the title, the rest notes', () {
    final t = taskFromShare(
      const SharedText(text: 'Call IT about printer\nTicket 4411\nAfter 2pm'),
    );
    expect(t.title, 'Call IT about printer');
    expect(t.notes, 'Ticket 4411\nAfter 2pm');
  });

  test(
    'a long paragraph is shortened for the title and kept whole in notes',
    () {
      final long = 'word ' * 40;
      final t = taskFromShare(SharedText(text: long));
      expect(t.title.length, lessThanOrEqualTo(81));
      expect(t.title.endsWith('…'), isTrue);
      expect(t.notes, long.trim());
    },
  );

  test('requests from the native side', () {
    expect(
      OutsideRequest.fromMap({'type': 'route', 'route': '/add'}),
      isA<OpenRoute>(),
    );
    expect(
      OutsideRequest.fromMap({'type': 'share', 'text': 'x'}),
      isA<SharedText>(),
    );
    expect(OutsideRequest.fromMap({'type': 'nope'}), isNull);
    expect(OutsideRequest.fromMap(null), isNull);
  });
}
