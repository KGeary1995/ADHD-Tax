import 'dart:io';
import 'dart:math' as math;

import 'package:adhd_tax/features/motivation/quote_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bundled = File('assets/quotes/quotes.json').readAsStringSync();

  test('bundled quotes cover every category', () {
    final svc = QuoteService.fromJsonString(bundled, random: math.Random(1));
    final seen = <QuoteCategory>{};
    for (var i = 0; i < 400; i++) {
      for (final c in QuoteContext.values) {
        seen.add(svc.next(c).category);
      }
    }
    expect(seen, QuoteCategory.values.toSet());
  });

  test('dread context mostly serves dread quotes', () {
    final svc = QuoteService.fromJsonString(bundled, random: math.Random(2));
    final cats = [
      for (var i = 0; i < 200; i++) svc.next(QuoteContext.dreadTask).category,
    ];
    final dread = cats.where((c) => c == QuoteCategory.dread).length;
    expect(dread / cats.length, greaterThan(0.5));
  });

  test('no immediate repeats', () {
    final svc = QuoteService.fromJsonString(bundled, random: math.Random(3));
    var last = svc.next(QuoteContext.focus);
    for (var i = 0; i < 300; i++) {
      final q = svc.next(QuoteContext.focus);
      expect(q.text, isNot(last.text));
      last = q;
    }
  });

  test('empty service still returns something', () {
    expect(QuoteService([]).next(QuoteContext.dashboard).text, isNotEmpty);
  });
}
