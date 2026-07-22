import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config.dart' as config;
import '../domain/asr_event.dart';

/// Streams PCM16 audio to the backend /asr/stream WebSocket and yields
/// transcript events. The backend proxies to Aliyun DashScope, so the API key
/// never reaches the client.
///
/// This is the repo's first WebSocket client. The access token rides in the
/// URL query string because WS handshakes can't carry an Authorization header.
class AsrRepository {
  /// Opens a session. Audio frames pushed to [audioFrames] are forwarded as
  /// binary messages; the returned stream emits [AsrEvent]s until the server
  /// closes or [audioFrames] completes (which sends the "__stop__" sentinel).
  Stream<AsrEvent> streamRecognize(
    Stream<Uint8List> audioFrames, {
    required String token,
  }) {
    final controller = StreamController<AsrEvent>();
    final uri = Uri.parse('${config.backendWsUrl}/asr/stream?token=$token');
    final channel = WebSocketChannel.connect(uri);

    StreamSubscription<Uint8List>? audioSub;
    StreamSubscription? socketSub;
    var closed = false;

    Future<void> cleanup() async {
      if (closed) return;
      closed = true;
      await audioSub?.cancel();
      await socketSub?.cancel();
      await channel.sink.close();
      if (!controller.isClosed) await controller.close();
    }

    socketSub = channel.stream.listen(
      (message) {
        if (message is! String) return;
        final Map<String, dynamic> json;
        try {
          json = jsonDecode(message) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        final text = json['text'] as String? ?? '';
        switch (json['type']) {
          case 'partial':
            controller.add(PartialAsrEvent(text));
          case 'final':
            controller.add(FinalAsrEvent(text));
          case 'error':
            controller.add(
              AsrErrorEvent(json['message'] as String? ?? '语音识别出错'),
            );
          case 'closed':
            cleanup();
        }
      },
      onError: (Object e) {
        controller.add(const AsrErrorEvent('语音识别连接中断'));
        cleanup();
      },
      onDone: cleanup,
    );

    audioSub = audioFrames.listen(
      (frame) {
        if (!closed) channel.sink.add(frame);
      },
      onDone: () {
        if (!closed) channel.sink.add('__stop__');
      },
    );

    controller.onCancel = cleanup;
    return controller.stream;
  }
}
