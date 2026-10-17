import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

const _settingsKey = 'settings.v1';

enum CelebrationLevel {
  off('Off', 'No animation. Just the XP.'),
  subtle('Subtle', 'A small card, no confetti.'),
  normal('Normal', 'Confetti and a summary card.'),
  party('Party', 'Maximum confetti. You earned it.');

  const CelebrationLevel(this.label, this.description);
  final String label;
  final String description;
}

class AppSettings {
  const AppSettings({
    this.themeId = 'graphite',
    this.celebration = CelebrationLevel.normal,
    this.quoteSeconds = 20,
    this.phiGuard = true,
  });

  final String themeId;
  final CelebrationLevel celebration;
  final int quoteSeconds;

  /// Warn when Work tasks look like they contain patient info.
  final bool phiGuard;

  AppSettings copyWith({
    String? themeId,
    CelebrationLevel? celebration,
    int? quoteSeconds,
    bool? phiGuard,
  }) => AppSettings(
    themeId: themeId ?? this.themeId,
    celebration: celebration ?? this.celebration,
    quoteSeconds: quoteSeconds ?? this.quoteSeconds,
    phiGuard: phiGuard ?? this.phiGuard,
  );

  Map<String, Object?> toJson() => {
    'themeId': themeId,
    'celebration': celebration.name,
    'quoteSeconds': quoteSeconds,
    'phiGuard': phiGuard,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    themeId: j['themeId'] as String? ?? 'graphite',
    celebration:
        CelebrationLevel.values.asNameMap()[j['celebration']] ??
        CelebrationLevel.normal,
    quoteSeconds: j['quoteSeconds'] as int? ?? 20,
    phiGuard: j['phiGuard'] as bool? ?? true,
  );
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final raw = ref.read(keyValueStoreProvider).read(_settingsKey);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  void update(AppSettings Function(AppSettings) f) {
    state = f(state);
    ref
        .read(keyValueStoreProvider)
        .write(_settingsKey, jsonEncode(state.toJson()));
  }
}
