import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';
import 'data/storage/key_value_store.dart';
import 'features/motivation/quote_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final quotes = await rootBundle.loadString('assets/quotes/quotes.json');

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(PrefsStore(prefs)),
        quoteServiceProvider.overrideWithValue(
          QuoteService.fromJsonString(quotes),
        ),
      ],
      child: const AdhdTaxApp(),
    ),
  );
}
