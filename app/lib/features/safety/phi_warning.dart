import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart';
import '../settings/settings_controller.dart';
import 'phi_guard.dart';

/// Inline warning shown under Work task fields that look like patient info.
class PhiWarning extends ConsumerWidget {
  const PhiWarning({super.key, required this.text, required this.workspace});

  final String text;
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(settingsProvider.select((s) => s.phiGuard));
    if (!enabled || workspace != Workspace.work) return const SizedBox.shrink();
    final hits = scanForPhi(text);
    if (hits.isEmpty) return const SizedBox.shrink();
    final s = context.spec;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: s.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(s.radius / 1.5),
        border: Border.all(color: s.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: s.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$phiWarning\nDetected: ${hits.map((h) => h.kind).join(', ')}',
              style: TextStyle(color: s.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
