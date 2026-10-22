import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shown instead of a blank screen when the app fails to start. Deliberately
/// plain: no theme engine, providers or plugins, so it can't fail the same
/// way the app did.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.error,
    this.stack,
    this.onRetry,
  });

  final Object error;
  final StackTrace? stack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C9CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: StartupErrorView(error: error, stack: stack, onRetry: onRetry),
    );
  }
}

class StartupErrorView extends StatelessWidget {
  const StartupErrorView({
    super.key,
    required this.error,
    this.stack,
    this.onRetry,
  });

  final Object error;
  final StackTrace? stack;
  final VoidCallback? onRetry;

  String get details => '$error\n\n${stack ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong starting Gumption',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your tasks are safe. Tap "Copy details" and send them to '
              'whoever is helping you fix the app.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: details)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy details'),
                ),
                const SizedBox(width: 12),
                if (onRetry != null)
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              details,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces a widget that failed to build. Needs no Material ancestors, so
/// it works even when the failure is at the root of the app.
class BuildErrorPanel extends StatelessWidget {
  const BuildErrorPanel({super.key, required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF2A1215),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Gumption hit an error drawing this screen:\n\n'
            '${details.exceptionAsString()}\n\n${details.stack ?? ''}',
            style: const TextStyle(color: Color(0xFFFFD7D7), fontSize: 12),
          ),
        ),
      ),
    );
  }
}
