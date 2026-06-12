import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme.dart';

/// Platforms where speech_to_text has a working native implementation.
/// Web uses Chrome's built-in Web Speech API — supported by speech_to_text.
bool get _speechSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

/// Desktop / web platforms use click-to-toggle instead of press-and-hold.
bool get _isDesktop =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Mic button that adapts interaction to the platform:
/// - Mobile (iOS/Android): press-and-hold to record, release to commit
/// - Desktop (macOS/Windows): click to start, click again to stop
///
/// Hidden on Web and Linux (no speech_to_text support).
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({super.key, required this.controller});

  final TextEditingController controller;

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
    if (_speechSupported) _init();
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
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
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

  // ── Desktop: click-to-toggle ──────────────────────────────────────────────

  Widget _desktopButton() {
    return Tooltip(
      message: _ready
          ? (_listening ? '点击停止录音' : '点击开始语音输入')
          : '麦克风不可用',
      child: InkResponse(
        radius: 22,
        onTap: _ready
            ? () => _listening ? _stopListening() : _startListening()
            : null,
        child: _MicIcon(listening: _listening, ready: _ready),
      ),
    );
  }

  // ── Mobile: press-and-hold ────────────────────────────────────────────────

  Widget _mobileButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startListening(),
      onLongPressEnd: (_) => _stopListening(),
      child: Tooltip(
        message: _ready ? '按住说话' : '麦克风不可用',
        child: _MicIcon(listening: _listening, ready: _ready),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_speechSupported) return const SizedBox.shrink();

    return Stack(
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
        _isDesktop ? _desktopButton() : _mobileButton(),
      ],
    );
  }
}

class _MicIcon extends StatelessWidget {
  const _MicIcon({required this.listening, required this.ready});
  final bool listening;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Icon(
      listening ? Icons.mic : Icons.mic_none,
      color: listening
          ? AppColors.error
          : (ready ? AppColors.primary : AppColors.timestamp),
      size: 24,
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
