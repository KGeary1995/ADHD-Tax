import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../settings/settings_controller.dart';
import 'quote_service.dart';

/// Crossfades through context-appropriate quotes. Tap to skip ahead.
class QuoteRotator extends ConsumerStatefulWidget {
  const QuoteRotator({
    super.key,
    this.context = QuoteContext.dashboard,
    this.large = false,
    this.align = TextAlign.start,
  });

  final QuoteContext context;
  final bool large;
  final TextAlign align;

  @override
  ConsumerState<QuoteRotator> createState() => _QuoteRotatorState();
}

class _QuoteRotatorState extends ConsumerState<QuoteRotator> {
  late Quote _quote;
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _quote = ref.read(quoteServiceProvider).next(widget.context);
  }

  @override
  void didUpdateWidget(QuoteRotator old) {
    super.didUpdateWidget(old);
    if (old.context != widget.context) _advance();
  }

  void _schedule(int seconds) {
    if (seconds == _seconds && _timer != null) return;
    _seconds = seconds;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => _advance());
  }

  void _advance() {
    if (!mounted) return;
    setState(
      () => _quote = ref.read(quoteServiceProvider).next(widget.context),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedule(ref.watch(settingsProvider.select((s) => s.quoteSeconds)));
    final s = context.spec;
    final crossAxis = widget.align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _advance,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: s.reduceMotion ? 0 : 600),
        child: Column(
          key: ValueKey(_quote.text),
          crossAxisAlignment: crossAxis,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '“${_quote.text}”',
              textAlign: widget.align,
              style: TextStyle(
                fontSize: widget.large ? 22 : 17,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: s.onSurface,
                shadows: s.glow
                    ? [
                        Shadow(
                          color: s.primary.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
            if (_quote.author != null) ...[
              const SizedBox(height: 6),
              Text(
                '— ${_quote.author}',
                textAlign: widget.align,
                style: TextStyle(fontSize: 13, color: s.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
