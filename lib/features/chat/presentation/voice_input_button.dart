import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/storage/secure_token_store.dart';
import '../../../core/theme.dart';
import '../../voice_asr/data/asr_repository.dart';
import '../../voice_asr/data/audio_recorder.dart';
import '../../voice_asr/domain/asr_event.dart';

/// Desktop / web platforms use click-to-toggle instead of press-and-hold.
bool get _isDesktop =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Mic button that adapts interaction to the platform:
/// - Mobile (iOS/Android): press-and-hold to record, release to commit
/// - Desktop / Web: click to start, click again to stop
///
/// Audio is streamed as 16 kHz PCM16 to the backend `/asr/stream` WebSocket,
/// which proxies to Aliyun DashScope. Unlike the old `speech_to_text` engine
/// (browser cloud STT, unreachable in China on Web), this works on all platforms.
class VoiceInputButton extends ConsumerStatefulWidget {
  const VoiceInputButton({super.key, required this.controller});

  final TextEditingController controller;

  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton> {
  final _recorder = AudioRecorder16k();
  final _asr = AsrRepository();

  bool _listening = false;
  bool _starting = false;
  String _partial = '';
  OverlayEntry? _overlay;

  StreamSubscription<AsrEvent>? _asrSub;

  /// Ensures mic permission. On mobile, surfaces an "open settings" action when
  /// the user has permanently denied it.
  Future<bool> _ensurePermission() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
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
    // Web / desktop: the record package + browser prompt handle permission.
    if (!await _recorder.hasPermission()) {
      _notify('需要麦克风权限才能使用语音输入');
      return false;
    }
    return true;
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
    _asrSub?.cancel();
    _recorder.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _startListening() async {
    // Re-entrancy guard: taps/long-presses can arrive during the await gaps
    // below or while the recorder is still winding down.
    if (_listening || _starting) return;
    _starting = true;
    try {
      final allowed = await _ensurePermission();
      if (!allowed) return;

      final token = await ref.read(secureTokenStoreProvider).read('auth.token');
      if (token == null || token.isEmpty) {
        _notify('请先登录后再使用语音输入');
        return;
      }

      final Stream<Uint8List> audio;
      try {
        audio = await _recorder.start();
      } catch (e) {
        debugPrint('[voice] recorder start failed: $e');
        _notify('无法启动录音，请检查麦克风');
        return;
      }
      if (!mounted) {
        await _recorder.stop();
        return;
      }

      setState(() {
        _listening = true;
        _partial = '';
      });
      _showOverlay();

      _asrSub = _asr.streamRecognize(audio, token: token).listen(
        (event) {
          if (!mounted) return;
          switch (event) {
            case PartialAsrEvent(:final text):
              setState(() => _partial = text);
              _overlay?.markNeedsBuild();
            case FinalAsrEvent(:final text):
              _commitText(text);
              setState(() => _partial = '');
              _overlay?.markNeedsBuild();
            case AsrErrorEvent(:final message):
              _notify(message);
              _stopListening();
          }
        },
        onError: (Object e) {
          debugPrint('[voice] asr stream error: $e');
          if (mounted) _stopListening();
        },
      );
    } catch (e) {
      debugPrint('[voice] startListening failed: $e');
      _removeOverlay();
      await _recorder.stop();
      if (mounted) setState(() => _listening = false);
      _notify('无法启动语音识别，请重试');
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    // Stopping the recorder completes the audio stream, which tells the
    // repository to flush "__stop__" and lets the server emit final results
    // before closing. We tear down the overlay/state immediately for
    // responsiveness; any late final event still commits via _commitText.
    await _recorder.stop();
    _removeOverlay();
    if (mounted) {
      final hadPartial = _partial.isNotEmpty;
      if (hadPartial) _commitText(_partial);
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
        child: _MicIcon(listening: _listening),
      ),
    );
  }

  // ── Mobile: press-and-hold ────────────────────────────────────────────────

  Widget _mobileButton() {
    // No Tooltip here: on Android a Tooltip defaults to longPress trigger and
    // would steal the long-press gesture. Use a bare GestureDetector.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _startListening(),
      onLongPressEnd: (_) => _stopListening(),
      onLongPressCancel: _stopListening,
      child: _MicIcon(listening: _listening),
    );
  }

  @override
  Widget build(BuildContext context) {
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
  const _MicIcon({required this.listening});
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Icon(
      listening ? Icons.mic : Icons.mic_none,
      color: listening ? p.error : p.textTertiary,
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
