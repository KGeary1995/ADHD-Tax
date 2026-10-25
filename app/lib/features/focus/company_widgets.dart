import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../widgets/ui.dart';
import 'company.dart';

/// Focus → headphones: background sound and the buddy.
Future<void> showCompanySheet(BuildContext context) => showAppSheet<void>(
  context: context,
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final c = ref.watch(companyProvider);
      final ctl = ref.read(companyProvider.notifier);
      return SafeArea(
        child: SingleChildScrollView(
          padding: sheetPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(
                'Company while you work',
                subtitle: "Starting is easier when you're not alone.",
              ),
              const SizedBox(height: Gap.s7),
              const OptionLabel('Background sound'),
              OptionRow(
                children: [
                  for (final x in FocusSound.values)
                    OptionButton(
                      label: x.label,
                      selected: c.sound == x,
                      onTap: () => ctl.setSound(x),
                    ),
                ],
              ),
              const SizedBox(height: Gap.s5),
              SwitchRow(
                title: 'Work alongside a buddy',
                subtitle:
                    'A second star orbits with yours, like someone at the '
                    'next desk.',
                value: c.buddy,
                onChanged: ctl.setBuddy,
              ),
              const SizedBox(height: Gap.s6),
              PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
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
