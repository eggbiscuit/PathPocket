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
  bool _initializing = false;
  String _partial = '';

  @override
  void initState() {
    super.initState();
    if (_speechSupported) _init();
  }

  /// Initializes the engine, requesting mic permission on first use.
  /// Returns whether the engine is ready to listen.
  Future<bool> _init() async {
    if (_ready) return true;
    if (_initializing) return false;
    _initializing = true;
    bool ok = false;
    try {
      ok = await _stt.initialize(
        onError: (err) {
          if (mounted) setState(() => _listening = false);
          _notify('语音识别出错：${err.errorMsg}');
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _listening) setState(() => _listening = false);
          }
        },
      );
    } catch (e) {
      ok = false;
    }
    _initializing = false;
    if (mounted) setState(() => _ready = ok);
    return ok;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ));
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_listening) return;
    if (!_ready) {
      final ok = await _init();
      if (!ok) {
        _notify('无法使用语音输入，请在系统设置中授予麦克风权限');
        return;
      }
    }
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
      final hadPartial = _partial.isNotEmpty;
      if (hadPartial) _commitText(_partial);
      final committed = hadPartial || widget.controller.text.isNotEmpty;
      setState(() {
        _listening = false;
        _partial = '';
      });
      if (!committed) _notify('没有识别到语音');
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
      message: _listening ? '点击停止录音' : '点击开始语音输入',
      child: InkResponse(
        radius: 22,
        onTap: () => _listening ? _stopListening() : _startListening(),
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
        message: '按住说话',
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
                ? context.palette.error.withValues(alpha: 0.15)
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
    final p = context.palette;
    return Icon(
      listening ? Icons.mic : Icons.mic_none,
      color: listening
          ? p.error
          : (ready ? p.primary : p.textTertiary),
      size: 24,
    );
  }
}
