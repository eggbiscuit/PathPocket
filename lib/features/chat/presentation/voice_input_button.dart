import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
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
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    // Don't initialize here: on Android the very first initialize() may race
    // with the permission prompt and fail, leaving the engine in a bad state.
    // Initialize lazily on first press instead (see _startListening).
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
          _removeOverlay();
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

  /// Ensures mic permission. On mobile, surfaces an "open settings" action when
  /// the user has permanently denied it (speech_to_text alone can't reopen the
  /// system prompt once permanently denied).
  Future<bool> _ensurePermission() async {
    if (kIsWeb || _isDesktop) return true;
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      _notifyOpenSettings();
      return false;
    }
    status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      _notifyOpenSettings();
    } else {
      _notify('需要麦克风权限才能使用语音输入');
    }
    return false;
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

  void _notifyOpenSettings() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('麦克风权限已被拒绝，请在系统设置中开启'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        action: SnackBarAction(
          label: '打开设置',
          onPressed: openAppSettings,
        ),
      ));
  }

  @override
  void dispose() {
    _stt.stop();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_listening) return;
    final allowed = await _ensurePermission();
    if (!allowed) return;
    if (!_ready) {
      final ok = await _init();
      if (!ok) {
        _notify('无法启动语音识别引擎');
        return;
      }
    }
    setState(() {
      _listening = true;
      _partial = '';
    });
    _showOverlay();
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
        _overlay?.markNeedsBuild();
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
    _removeOverlay();
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

  // ── Live transcript overlay ───────────────────────────────────────────────

  void _showOverlay() {
    _removeOverlay();
    final overlayState = Overlay.of(context, rootOverlay: true);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _overlay = OverlayEntry(
      builder: (_) => _PartialTranscriptOverlay(
        partial: _partial,
        bottomInset: bottomInset,
      ),
    );
    overlayState.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
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
    // No Tooltip here: on Android a Tooltip defaults to longPress trigger and
    // would steal the long-press gesture (showing its bubble instead of
    // starting recording). Use a bare GestureDetector.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _startListening(),
      onLongPressEnd: (_) => _stopListening(),
      onLongPressCancel: _stopListening,
      child: _MicIcon(listening: _listening, ready: _ready),
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

/// Floating panel shown above the keyboard/input bar while recording,
/// displaying the live (partial) transcript — mirrors 豆包 / Gemini.
class _PartialTranscriptOverlay extends StatelessWidget {
  const _PartialTranscriptOverlay({
    required this.partial,
    required this.bottomInset,
  });
  final String partial;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottomInset + 120,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: p.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: p.divider),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, size: 18, color: p.error),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    partial.isEmpty ? '正在聆听…' : partial,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      height: 1.4,
                      color: partial.isEmpty ? p.textTertiary : p.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
