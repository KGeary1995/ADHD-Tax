/// Hybrid logical clock: wall-clock milliseconds plus a counter and node id.
///
/// Gives every write a timestamp that is unique across devices and orders
/// causally even when device clocks disagree a little. Packed form sorts
/// lexicographically, so comparing two packed strings compares the clocks.
/// Pure Dart.
library;

import 'dart:math' as math;

class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.node);

  /// The zero clock for [node].
  const Hlc.zero(this.node) : millis = 0, counter = 0;

  final int millis;
  final int counter;
  final String node;

  static const _maxCounter = 0xFFFF;

  /// Next timestamp for a local event.
  Hlc send(DateTime now) {
    final wall = now.millisecondsSinceEpoch;
    if (wall > millis) return Hlc(wall, 0, node);
    return _bump(millis, counter);
  }

  /// How far ahead of this device's clock another device's may be before
  /// it stops pulling ours along.
  static const maxDrift = Duration(minutes: 10);

  /// Advance past a timestamp seen from another node, so later local writes
  /// sort after everything already merged. A remote clock far ahead of ours
  /// (a device whose date was set into the future) is only followed up to
  /// [maxDrift], so it can't pin every device's clock to that date.
  Hlc receive(Hlc remote, DateTime now) {
    final wall = now.millisecondsSinceEpoch;
    final limit = wall + maxDrift.inMilliseconds;
    final r = remote.millis > limit ? Hlc(limit, 0, remote.node) : remote;
    final m = math.max(wall, math.max(millis, r.millis));
    if (m == wall && m > millis && m > r.millis) return Hlc(m, 0, node);
    final c = m == millis && m == r.millis
        ? math.max(counter, r.counter)
        : m == millis
        ? counter
        : r.counter;
    return _bump(m, c);
  }

  Hlc _bump(int m, int c) =>
      c >= _maxCounter ? Hlc(m + 1, 0, node) : Hlc(m, c + 1, node);

  /// `<base36 millis, 10 chars>-<hex counter, 4 chars>-<node>`.
  String pack() =>
      '${millis.toRadixString(36).padLeft(10, '0')}-'
      '${counter.toRadixString(16).padLeft(4, '0')}-$node';

  /// Throws [FormatException] for a string that isn't a packed clock.
  static Hlc parse(String s) {
    final first = s.indexOf('-');
    final second = first < 0 ? -1 : s.indexOf('-', first + 1);
    if (second < 0) throw FormatException('Not a clock', s);
    return Hlc(
      int.parse(s.substring(0, first), radix: 36),
      int.parse(s.substring(first + 1, second), radix: 16),
      s.substring(second + 1),
    );
  }

  @override
  int compareTo(Hlc other) => pack().compareTo(other.pack());

  bool operator >(Hlc other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.node == node;

  @override
  int get hashCode => Object.hash(millis, counter, node);

  @override
  String toString() => pack();
}
