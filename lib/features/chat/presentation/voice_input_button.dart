import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme.dart';

/// A hold-to-talk mic button that fills [controller] with the recognised text.
///
/// Hidden on Web and desktop — only rendered on iOS and Android.
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({super.key, required this.controller});

  final TextEditingController controller;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final _stt = SpeechToText();
  bool _ready = false;
  bool _listening = false;
  String _partial = '';

  @override
  void initState() {
    super.initState();
    if (VoiceInputButton._supported) {
      _init();
    }
  }

  Future<void> _init() async {
    final ok = await _stt.initialize(onError: (_) {
      if (mounted) setState(() => _listening = false);
    });
    if (mounted) setState(() => _ready = ok);
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_ready || _listening) return;
    setState(() {
      _listening = true;
      _partial = '';
    });
    await _stt.listen(
      onResult: (r) {
        if (!mounted) return;
        final text = r.recognizedWords;
        if (r.finalResult) {
          _commitText(text);
          setState(() => _partial = '');
        } else {
          setState(() => _partial = text);
        }
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'zh_CN',
        cancelOnError: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    if (mounted) {
      if (_partial.isNotEmpty) _commitText(_partial);
      setState(() {
        _listening = false;
        _partial = '';
      });
    }
  }

  void _commitText(String text) {
    if (text.isEmpty) return;
    final ctrl = widget.controller;
    final existing = ctrl.text;
    final appended = existing.isEmpty ? text : '$existing $text';
    ctrl.value = TextEditingValue(
      text: appended,
      selection: TextSelection.collapsed(offset: appended.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!VoiceInputButton._supported) return const SizedBox.shrink();

    return GestureDetector(
      onLongPressStart: (_) => _startListening(),
      onLongPressEnd: (_) => _stopListening(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _listening ? 52 : 40,
            height: _listening ? 52 : 40,
            decoration: BoxDecoration(
              color: _listening
                  ? AppColors.error.withValues(alpha: 0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          Tooltip(
            message: _ready ? '按住说话' : '麦克风不可用',
            child: Icon(
              _listening ? Icons.mic : Icons.mic_none,
              color: _listening
                  ? AppColors.error
                  : (_ready ? AppColors.primary : AppColors.timestamp),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact overlay shown while recording, floating above the input bar.
class VoiceListeningOverlay extends StatelessWidget {
  const VoiceListeningOverlay({super.key, required this.partial});
  final String partial;

  @override
  Widget build(BuildContext context) {
    if (partial.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              partial,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
