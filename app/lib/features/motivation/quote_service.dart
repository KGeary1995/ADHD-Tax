/// Context-aware motivational quote rotation. Pure Dart.
library;

import 'dart:convert';
import 'dart:math' as math;

enum QuoteCategory { starting, dread, compassion, momentum, humor }

class Quote {
  const Quote(this.text, this.category, {this.author});

  final String text;
  final String? author;
  final QuoteCategory category;

  factory Quote.fromJson(Map<String, Object?> j) => Quote(
    j['text'] as String,
    QuoteCategory.values.asNameMap()[j['category']] ?? QuoteCategory.starting,
    author: j['author'] as String?,
  );
}

/// Where the quote is shown; drives which categories are favored.
enum QuoteContext { dashboard, dreadTask, afterSkip, focus, celebration }

const _mix = <QuoteContext, Map<QuoteCategory, int>>{
  QuoteContext.dashboard: {
    QuoteCategory.starting: 4,
    QuoteCategory.humor: 4,
    QuoteCategory.compassion: 2,
    QuoteCategory.dread: 1,
  },
  QuoteContext.dreadTask: {
    QuoteCategory.dread: 6,
    QuoteCategory.starting: 2,
    QuoteCategory.humor: 1,
  },
  QuoteContext.afterSkip: {
    QuoteCategory.compassion: 5,
    QuoteCategory.starting: 2,
    QuoteCategory.humor: 1,
  },
  QuoteContext.focus: {QuoteCategory.momentum: 4, QuoteCategory.humor: 2},
  QuoteContext.celebration: {
    QuoteCategory.momentum: 3,
    QuoteCategory.humor: 2,
    QuoteCategory.compassion: 1,
  },
};

class QuoteService {
  QuoteService(List<Quote> quotes, {math.Random? random})
    : _random = random ?? math.Random(),
      _byCategory = {
        for (final c in QuoteCategory.values)
          c: quotes.where((q) => q.category == c).toList(),
      };

  factory QuoteService.fromJsonString(String json, {math.Random? random}) {
    final list = (jsonDecode(json) as List<Object?>)
        .map((e) => Quote.fromJson(e as Map<String, Object?>))
        .toList();
    return QuoteService(list, random: random);
  }

  final math.Random _random;
  final Map<QuoteCategory, List<Quote>> _byCategory;

  /// Shuffle-bag per category: no repeats until the category is exhausted.
  final Map<QuoteCategory, List<Quote>> _bags = {};
  Quote? _last;

  bool get isEmpty => _byCategory.values.every((l) => l.isEmpty);

  Quote next(QuoteContext context) {
    if (isEmpty) return const Quote('One small step.', QuoteCategory.starting);
    final category = _pickCategory(context);
    var bag = _bags[category];
    if (bag == null || bag.isEmpty) {
      bag = List.of(_byCategory[category]!)..shuffle(_random);
      // Avoid showing the same quote twice in a row across a refill.
      if (bag.length > 1 && identical(bag.last, _last)) {
        bag.insert(0, bag.removeLast());
      }
      _bags[category] = bag;
    }
    return _last = bag.removeLast();
  }

  QuoteCategory _pickCategory(QuoteContext context) {
    final weights = {
      for (final e in _mix[context]!.entries)
        if (_byCategory[e.key]!.isNotEmpty) e.key: e.value,
    };
    if (weights.isEmpty) {
      return _byCategory.entries.firstWhere((e) => e.value.isNotEmpty).key;
    }
    final total = weights.values.fold(0, (a, b) => a + b);
    var roll = _random.nextInt(total);
    for (final e in weights.entries) {
      if (roll < e.value) return e.key;
      roll -= e.value;
    }
    return weights.keys.first;
  }
}
