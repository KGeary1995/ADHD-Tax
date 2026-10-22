import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';
import 'data/storage/key_value_store.dart';
import 'features/motivation/quote_service.dart';
import 'startup_error.dart';

void main() {
  runZonedGuarded(_start, (error, stack) {
    // Anything that escapes before the first frame would otherwise leave a
    // black screen; show it instead.
    if (!_started) runApp(StartupErrorApp(error: error, stack: stack));
  });
}

bool _started = false;

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A widget that throws while building shows its error in place, instead
  // of an empty box in release builds. Self-contained, since it may replace
  // the whole app.
  ErrorWidget.builder = (details) => BuildErrorPanel(details: details);
  LicenseRegistry.addLicense(_fontLicenses);

  try {
    final prefs = await SharedPreferences.getInstance();
    final quotes = await rootBundle.loadString('assets/quotes/quotes.json');
    _started = true;
    runApp(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(PrefsStore(prefs)),
          quoteServiceProvider.overrideWithValue(
            QuoteService.fromJsonString(quotes),
          ),
        ],
        child: const GumptionApp(),
      ),
    );
  } on Object catch (error, stack) {
    runApp(StartupErrorApp(error: error, stack: stack, onRetry: _start));
  }
}

Stream<LicenseEntry> _fontLicenses() async* {
  for (final (package, file) in [
    ('Bricolage Grotesque', 'OFL-BricolageGrotesque.txt'),
    ('Geist', 'OFL-Geist.txt'),
    ('Geist Mono', 'OFL-GeistMono.txt'),
  ]) {
    final text = await rootBundle.loadString('assets/fonts/$file');
    yield LicenseEntryWithLineBreaks([package], text);
  }
}
