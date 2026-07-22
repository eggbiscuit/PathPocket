import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Thin wrapper over the `record` package producing a raw 16 kHz mono PCM16
/// stream — the format Aliyun Paraformer expects. `record` exposes an identical
/// `startStream` API on Web and native, so no platform split is needed here.
///
/// On Web, PCM16 stream support depends on the browser (Chrome/Edge/Firefox
/// support it via WebAudio; Safari is the known gap). If a target browser
/// can't emit `pcm16bits`, this is the seam to add a Web-Audio fallback.
class AudioRecorder16k {
  final _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts recording and returns the PCM16 byte stream (~chunked frames).
  Future<Stream<Uint8List>> start() async {
    return _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
  }

  Future<void> stop() async {
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
