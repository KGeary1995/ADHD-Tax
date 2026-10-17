import 'package:adhd_tax/core/hlc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 17, 12);

  test('send is strictly increasing even if the wall clock stalls', () {
    var c = const Hlc.zero('a');
    final seen = <Hlc>[];
    for (var i = 0; i < 5; i++) {
      c = c.send(t0);
      seen.add(c);
    }
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i] > seen[i - 1], isTrue);
    }
  });

  test('send survives the wall clock going backwards', () {
    final a = const Hlc.zero('a').send(t0);
    final b = a.send(t0.subtract(const Duration(minutes: 5)));
    expect(b > a, isTrue);
  });

  test('receive orders after the remote clock', () {
    final local = const Hlc.zero('a').send(t0);
    final remote = Hlc(t0.millisecondsSinceEpoch + 60000, 3, 'b');
    final merged = local.receive(remote, t0);
    expect(merged > remote, isTrue);
    expect(merged.node, 'a');
    expect(merged.send(t0) > remote, isTrue);
  });

  test('pack/parse round trip and packed order matches compareTo', () {
    final a = Hlc(t0.millisecondsSinceEpoch, 7, 'node-1');
    expect(Hlc.parse(a.pack()), a);
    final b = Hlc(t0.millisecondsSinceEpoch + 1, 0, 'node-0');
    expect(a.pack().compareTo(b.pack()), lessThan(0));
    expect(a.compareTo(b), lessThan(0));
  });

  test('node id breaks ties deterministically', () {
    final a = Hlc(1000, 0, 'a');
    final b = Hlc(1000, 0, 'b');
    expect(b > a, isTrue);
  });
}
