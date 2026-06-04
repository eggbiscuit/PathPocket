import 'dart:async';
import 'dart:convert';

import '../../features/chat/domain/message.dart';

sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class TokenEvent extends ChatStreamEvent {
  const TokenEvent(this.content);
  final String content;
}

class CitationEvent extends ChatStreamEvent {
  const CitationEvent(this.citation);
  final Citation citation;
}

class DoneEvent extends ChatStreamEvent {
  const DoneEvent();
}

/// Parses an OpenAI-style SSE stream into typed [ChatStreamEvent]s.
///
/// In addition to OpenAI's `choices[0].delta.content` chunks, this parser
/// recognises a custom `event: citation` SSE frame whose `data` is a
/// JSON-encoded [Citation]. The backend contract is finalised in Phase 1 so
/// later phases can render the citation drawer without touching the parser.
class SseParser {
  const SseParser();

  Stream<ChatStreamEvent> parse(Stream<List<int>> bytes) async* {
    String? pendingEventType;
    final lineStream = bytes
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final rawLine in lineStream) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        pendingEventType = null;
        continue;
      }

      if (line.startsWith('event:')) {
        pendingEventType = line.substring(6).trim();
        continue;
      }

      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') {
        yield const DoneEvent();
        return;
      }

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(data) as Map<String, dynamic>;
      } on FormatException {
        continue;
      }

      if (pendingEventType == 'citation') {
        try {
          yield CitationEvent(Citation.fromJson(json));
        } catch (_) {
          // skip malformed citation payloads
        }
        pendingEventType = null;
        continue;
      }

      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;
      final delta =
          (choices.first as Map<String, dynamic>)['delta'] as Map?;
      final content = delta?['content'] as String?;
      if (content != null && content.isNotEmpty) {
        yield TokenEvent(content);
      }
    }
  }
}
