import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_themes.dart';
import '../core/theme/ph.dart';
import 'replicas_controller.dart';

/// A strip across the top while a change couldn't be written to this
/// device's storage (full, or the platform refused). The app keeps
/// retrying; this is so nobody closes it believing everything is saved.
class SaveWarning extends ConsumerWidget {
  const SaveWarning({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsaved = ref.watch(
      replicasProvider.select((s) => s.unsaved.isNotEmpty),
    );
    if (!unsaved) return child;
    final s = context.spec;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(Gap.s4),
              child: Material(
                color: s.toastBg,
                borderRadius: BorderRadius.circular(Radii.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.s6,
                    vertical: Gap.s5,
                  ),
                  child: Row(
                    children: [
                      Icon(Ph.warningCircle, size: 20, color: s.danger),
                      const SizedBox(width: Gap.s5),
                      Expanded(
                        child: Text(
                          'Couldn\'t save your latest changes on this '
                          'device. Trying again; keep the app open.',
                          style: s.caption(color: s.toastInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
