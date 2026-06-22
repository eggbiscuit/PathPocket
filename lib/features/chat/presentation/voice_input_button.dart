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
  bool _starting = false;
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
        debugLogging: true,
        onError: (err) {
          debugPrint('[voice] onError: ${err.errorMsg} '
              '(permanent=${err.permanent})');
          if (mounted) setState(() => _listening = false);
          _removeOverlay();
          // Cancel so the underlying engine fully releases; otherwise web's
          // SpeechRecognition stays "started" and the next attempt throws
          // "recognition has already started".
          _stt.cancel();
          _notify(_describeError(err.errorMsg));
        },
        onStatus: (status) {
          debugPrint('[voice] onStatus: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _listening) setState(() => _listening = false);
          }
        },
      );
      debugPrint('[voice] initialize -> $ok');
    } catch (e) {
      debugPrint('[voice] initialize threw: $e');
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

  /// Maps a speech_to_text error code to a human-friendly Chinese message.
  String _describeError(String code) {
    // On web, recognition streams audio to the browser's cloud STT service
    // (Chrome → Google). When that service is unreachable the plugin reports
    // "network", which is common on networks that can't reach Google.
    if (code.contains('network')) {
      return '语音识别服务连接失败：网页端依赖浏览器云端识别，请检查网络或改用 App 端';
    }
    if (code.contains('no_match') || code.contains('no match')) {
      return '没有识别到语音，请靠近麦克风再试一次';
    }
    if (code.contains('audio')) {
      return '麦克风无法录音，请检查设备权限';
    }
    if (code.contains('not_available') || code.contains('unavailable')) {
      return '当前设备/浏览器不支持语音识别';
    }
    return '语音识别出错：$code';
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
    // Re-entrancy guard: clicks/long-presses can arrive while a previous
    // start is still in flight (await gaps below), or while the native engine
    // is winding down. Without this, web throws
    // "recognition has already started".
    if (_listening || _starting) return;
    _starting = true;
    try {
      final allowed = await _ensurePermission();
      if (!allowed) return;
      if (!_ready) {
        final ok = await _init();
        if (!ok) {
          _notify('无法启动语音识别引擎');
          return;
        }
      }
      // The engine may still be running even though our flag was cleared by a
      // stray onStatus (web reports notListening before fully stopping). Make
      // sure it's stopped before we start a fresh session.
      if (_stt.isListening) {
        await _stt.stop();
      }
      if (!mounted) return;
      setState(() {
        _listening = true;
        _partial = '';
      });
      _showOverlay();

      // Pick a Chinese locale if installed; otherwise fall back to the device
      // default. Forcing zh_CN on a device without that pack can make the
      // engine silently produce no results.
      String? localeId;
      try {
        final locales = await _stt.locales();
        final zh = locales.where((l) => l.localeId.startsWith('zh'));
        if (zh.isNotEmpty) {
          localeId = zh.first.localeId;
        } else {
          final sys = await _stt.systemLocale();
          localeId = sys?.localeId;
        }
        debugPrint('[voice] using localeId=$localeId '
            '(available zh: ${zh.map((l) => l.localeId).toList()})');
      } catch (e) {
        debugPrint('[voice] locale lookup failed: $e');
      }

      await _stt.listen(
        onResult: (r) {
          debugPrint('[voice] onResult: "${r.recognizedWords}" '
              'final=${r.finalResult}');
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
          localeId: localeId,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('[voice] startListening failed: $e');
      _removeOverlay();
      if (mounted) setState(() => _listening = false);
      // Reset the engine so a stuck "already started" state recovers and the
      // next press can start cleanly.
      _stt.cancel();
      _notify('无法启动语音识别，请重试');
    } finally {
      _starting = false;
    }
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
