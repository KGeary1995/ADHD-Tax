import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/app_themes.dart';

/// One recognizer for the whole app, as the plugin expects.
SpeechToText? _speech;

/// A mic button that dictates into [controller]: words are added after
/// what's already there, on a new line when [newLine] (brain dump).
/// Works on Android, Mac and in Chrome/Safari; elsewhere it says so and
/// points at the keyboard's own mic.
class VoiceButton extends StatefulWidget {
  const VoiceButton({
    super.key,
    required this.controller,
    this.newLine = false,
  });

  final TextEditingController controller;
  final bool newLine;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) _speech?.stop();
    super.dispose();
  }

  void _stopped() {
    if (mounted && _listening) setState(() => _listening = false);
  }

  Future<void> _toggle() async {
    final speech = _speech ??= SpeechToText();
    if (_listening) {
      await speech.stop();
      _stopped();
      return;
    }
    var ready = false;
    try {
      ready = await speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            _stopped();
          }
        },
        onError: (_) => _stopped(),
      );
    } on Object {
      ready = false;
    }
    if (!mounted) return;
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Voice input isn't available here (or the mic is blocked). "
            "Your keyboard's mic button works too.",
          ),
        ),
      );
      return;
    }
    final before = widget.controller.text.trimRight();
    final joiner = before.isEmpty ? '' : (widget.newLine ? '\n' : ' ');
    setState(() => _listening = true);
    await speech.listen(
      onResult: (r) {
        final text = '$before$joiner${r.recognizedWords}';
        widget.controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return IconButton(
      tooltip: _listening ? 'Stop listening' : 'Say it',
      onPressed: _toggle,
      isSelected: _listening,
      selectedIcon: Icon(Icons.stop_circle_rounded, color: s.danger),
      icon: Icon(Icons.mic_none_rounded, color: s.muted),
    );
  }
}
