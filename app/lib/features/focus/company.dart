import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Background sound for a focus session. Synthesized loops in
/// assets/sounds (tool/make_sounds.py).
enum FocusSound {
  off('Off', ''),
  brown('Brown noise', 'sounds/brown.wav'),
  rain('Rain', 'sounds/rain.wav'),
  fan('Fan', 'sounds/fan.wav');

  const FocusSound(this.label, this.asset);
  final String label;
  final String asset;
}

/// Body doubling: what keeps you company while the timer runs.
/// Device-local, remembered between sessions.
class Company {
  const Company({this.sound = FocusSound.off, this.buddy = false});
  final FocusSound sound;

  /// A quiet "working alongside you" line under the timer.
  final bool buddy;

  bool get any => sound != FocusSound.off || buddy;
}

final companyProvider = NotifierProvider<CompanyController, Company>(
  CompanyController.new,
);

class CompanyController extends Notifier<Company> {
  @override
  Company build() {
    final store = ref.read(keyValueStoreProvider);
    return Company(
      sound:
          FocusSound.values.asNameMap()[store.read('focus.sound')] ??
          FocusSound.off,
      buddy: store.read('focus.buddy') == 'true',
    );
  }

  void setSound(FocusSound s) {
    ref.read(keyValueStoreProvider).write('focus.sound', s.name);
    state = Company(sound: s, buddy: state.buddy);
  }

  void setBuddy(bool on) {
    ref.read(keyValueStoreProvider).write('focus.buddy', '$on');
    state = Company(sound: state.sound, buddy: on);
  }
}

/// Plays one sound on a loop. Overridden in tests.
abstract class AmbientPlayer {
  Future<void> play(FocusSound sound);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

final ambientPlayerProvider = Provider<AmbientPlayer>((ref) {
  final p = _AudioAmbient();
  ref.onDispose(p.dispose);
  return p;
});

class _AudioAmbient implements AmbientPlayer {
  AudioPlayer? _player;

  // Sound is a nice-to-have: any failure (no audio device, plugin missing
  // on this platform) just means silence.
  Future<void> _try(Future<void> Function(AudioPlayer p) f) async {
    try {
      await f(_player ??= AudioPlayer());
    } on Object {
      // Silence.
    }
  }

  @override
  Future<void> play(FocusSound sound) async {
    if (sound == FocusSound.off) return stop();
    await _try((p) => p.setReleaseMode(ReleaseMode.loop));
    // Mix with other audio; never stop someone's music or a call.
    await _try(
      (p) => p.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      ),
    );
    await _try((p) => p.play(AssetSource(sound.asset), volume: 0.6));
  }

  @override
  Future<void> pause() async {
    if (_player != null) await _try((p) => p.pause());
  }

  @override
  Future<void> resume() async {
    if (_player != null) await _try((p) => p.resume());
  }

  @override
  Future<void> stop() async {
    if (_player != null) await _try((p) => p.stop());
  }

  void dispose() => _player?.dispose();
}

/// Things the buddy is "doing", one every few minutes. Ordinary, quiet
/// work, so it feels like a coworker at the next desk, not a coach.
const buddyLines = [
  'Answering emails',
  'Sorting a messy folder',
  'Writing a to-do list',
  'Filing some paperwork',
  'Clearing out the inbox',
  'Making a phone call',
  'Tidying the desk',
  'Reading a long document',
  'Paying a bill',
  'Updating a spreadsheet',
];
