import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/providers.dart';
import '../../data/models/task.dart';
import '../safety/phi_guard.dart';
import 'breakdown.dart';

/// Where the user's Anthropic API key lives: the OS keychain / keystore
/// (browser storage on the web). Never synced, never in a backup file.
abstract class AiKeyStore {
  Future<String?> read();
  Future<void> write(String? key);
}

class _SecureKeyStore implements AiKeyStore {
  static const _name = 'ai.anthropicKey';
  final _storage = const FlutterSecureStorage(
    // Same as the Google token: works in an ad-hoc signed Mac build.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _name);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String? key) => key == null || key.isEmpty
      ? _storage.delete(key: _name)
      : _storage.write(key: _name, value: key);
}

final aiKeyStoreProvider = Provider<AiKeyStore>((_) => _SecureKeyStore());

final httpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

class AiSettings {
  const AiSettings({this.key, this.allowWork = false});

  final String? key;

  /// Work tasks go to Claude only if the user turned this on, after
  /// confirming they keep other people's personal details out of them.
  final bool allowWork;

  bool get hasKey => key != null && key!.isNotEmpty;
}

final aiSettingsProvider = NotifierProvider<AiSettingsController, AiSettings>(
  AiSettingsController.new,
);

class AiSettingsController extends Notifier<AiSettings> {
  static const _workKey = 'ai.allowWork';

  @override
  AiSettings build() {
    final allowWork = ref.read(keyValueStoreProvider).read(_workKey) == 'true';
    // The keychain is async; the key arrives a moment after startup.
    ref.read(aiKeyStoreProvider).read().then((k) {
      // Skip if a key was saved meanwhile: that one is newer.
      if (k != null && ref.mounted && !state.hasKey) {
        state = AiSettings(key: k, allowWork: state.allowWork);
      }
    });
    return AiSettings(allowWork: allowWork);
  }

  Future<void> setKey(String? key) async {
    final k = key?.trim();
    await ref.read(aiKeyStoreProvider).write(k);
    state = AiSettings(
      key: k == null || k.isEmpty ? null : k,
      allowWork: state.allowWork,
    );
  }

  void setAllowWork(bool on) {
    ref.read(keyValueStoreProvider).write(_workKey, '$on');
    state = AiSettings(key: state.key, allowWork: on);
  }

  /// Steps for [t], or a [BreakdownException] saying why not.
  Future<List<String>> breakDown(Task t) {
    final reason = aiBlockReason(
      settings: state,
      workspace: t.workspace,
      text: '${t.title}\n${t.notes}',
    );
    if (reason != null) throw BreakdownException(reason);
    return requestBreakdown(
      client: ref.read(httpClientProvider),
      apiKey: state.key!,
      title: t.title,
      notes: t.notes,
      estimateMin: t.estimateMin,
    );
  }
}

/// Why a task can't be sent to Claude, or null when it can.
String? aiBlockReason({
  required AiSettings settings,
  required Workspace workspace,
  required String text,
}) {
  if (!settings.hasKey) {
    return 'Add your Anthropic API key in Settings → AI helper first.';
  }
  if (workspace == Workspace.work) {
    if (!settings.allowWork) {
      return 'The AI helper is off for Work tasks. You can turn it on in '
          'Settings → AI helper.';
    }
    if (scanForPhi(text).isNotEmpty) {
      return 'This looks like it has someone\'s personal details, so it '
          'wasn\'t sent. Use initials or a reference number instead.';
    }
  }
  return null;
}
