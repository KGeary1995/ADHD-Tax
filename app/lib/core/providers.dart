import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage/key_value_store.dart';
import '../features/motivation/quote_service.dart';

/// Overridden in main() with the initialized store.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError(),
);

/// Overridden in main() once the bundled quotes are loaded.
final quoteServiceProvider = Provider<QuoteService>((ref) => QuoteService([]));

/// Injectable clock so time-dependent logic is testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
