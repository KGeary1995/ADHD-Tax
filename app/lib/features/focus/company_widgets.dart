import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import 'company.dart';

/// Focus → headphones: background sound and the buddy.
Future<void> showCompanySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final s = ctx.spec;
          final c = ref.watch(companyProvider);
          final ctl = ref.read(companyProvider.notifier);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Company while you work', style: s.display(24)),
                  const SizedBox(height: 6),
                  Text(
                    'Starting is easier when you\'re not alone. Pick a '
                    'background sound, a buddy, or both.',
                    style: TextStyle(color: s.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel('Background sound'),
                  ChoiceGroup<FocusSound>(
                    values: FocusSound.values,
                    selected: c.sound,
                    labelOf: (x) => x.label,
                    onSelected: ctl.setSound,
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Work alongside a buddy'),
                    subtitle: const Text(
                      'A quiet line under the timer, like someone at the '
                      'next desk getting on with their own list.',
                    ),
                    value: c.buddy,
                    onChanged: ctl.setBuddy,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

/// "Your buddy · Answering emails", changing every few minutes.
class BuddyLine extends StatelessWidget {
  const BuddyLine({super.key, required this.elapsed});
  final Duration elapsed;

  /// How long the buddy sticks with one thing.
  static const every = Duration(minutes: 4);

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final i = elapsed.inSeconds ~/ every.inSeconds;
    final line = buddyLines[i % buddyLines.length];
    final motion = !context.reduceMotion;
    return Semantics(
      label: 'Your buddy is working too: $line',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Breathing(animate: motion, color: s.primary),
          const SizedBox(width: 10),
          Flexible(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: motion ? 400 : 0),
              child: Text(
                'Your buddy · $line',
                key: ValueKey(line),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: s.text2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small dot that slowly grows and shrinks, like someone breathing.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.animate, required this.color});
  final bool animate;
  final Color color;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Container(
      width: 10 + 4 * _c.value,
      height: 10 + 4 * _c.value,
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.5 + 0.5 * _c.value),
        shape: BoxShape.circle,
      ),
    ),
  );
}
