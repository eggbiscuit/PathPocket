import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/config.dart' as config;
import '../../../core/network/sse_parser.dart';
import '../domain/message.dart';

abstract class ChatRepository {
  /// Streams chat events for the given conversation history.
  ///
  /// The returned stream emits a mix of [TokenEvent]s (text chunks for the
  /// current assistant message), [CitationEvent]s (RAG references to be shown
  /// in the citation drawer), and a terminal [DoneEvent].
  ///
  /// Implementations must respect [cancelToken]. When cancelled the stream
  /// MUST close promptly without yielding further events.
  Stream<ChatStreamEvent> streamChat(
    List<Message> messages, {
    CancelToken? cancelToken,
  });
}

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ChatRepositoryException: $message';
}

class OpenAIChatRepository implements ChatRepository {
  OpenAIChatRepository({Dio? dio, SseParser? parser})
      : _dio = dio ?? Dio(),
        _parser = parser ?? const SseParser();

  final Dio _dio;
  final SseParser _parser;

  @override
  Stream<ChatStreamEvent> streamChat(
    List<Message> messages, {
    CancelToken? cancelToken,
  }) async* {
    final payload = {
      'model': config.model,
      'stream': true,
      'messages': [
        {'role': 'system', 'content': config.systemPrompt},
        ...messages.map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content,
            }),
      ],
    };

    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        config.apiEndpoint,
        data: payload,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      throw ChatRepositoryException(
        'Request failed: ${e.message ?? e.type.name}',
        cause: e,
      );
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const ChatRepositoryException('Empty response stream');
    }

    try {
      yield* _parser.parse(stream);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      throw ChatRepositoryException(
        'Stream interrupted: ${e.message ?? e.type.name}',
        cause: e,
      );
    }
  }
}

/// Frontend-only mock used while no real backend exists.
///
/// Emits a stream of token events with realistic per-token delays, then a
/// single citation event before [DoneEvent]. The generated content includes
/// inline `[1]` markers so the citation drawer can be wired up end-to-end.
class MockChatRepository implements ChatRepository {
  MockChatRepository({
    Duration tokenInterval = const Duration(milliseconds: 35),
    Random? random,
  })  : _tokenInterval = tokenInterval,
        _random = random ?? Random();

  final Duration _tokenInterval;
  final Random _random;

  static const _stockReplies = <String>[
    '根据您描述的病理特征 [1]，初步考虑为**腺癌**可能。建议进一步行免疫组化检测以明确分型。',
    '该视野中可见**异型增生**细胞 [1]，核质比明显增大，建议结合临床进一步评估。',
    '从切片图像看，组织结构尚保留，但局部可见**炎性细胞浸润** [1]。建议补充 HE 染色复核。',
    '观察到的特征符合**慢性炎症伴轻度上皮异型** [1]。可考虑短期随访 + 复检。',
  ];

  static const _mockCitation = Citation(
    id: 'mock-1',
    title: 'WHO 消化系统肿瘤分类（第 5 版）',
    snippet:
        '腺癌的组织学诊断要点：腺体结构紊乱、细胞极向消失、核异型明显，伴或不伴间质浸润。',
    source: 'WHO Classification of Tumours, 5th Edition',
  );

  @override
  Stream<ChatStreamEvent> streamChat(
    List<Message> messages, {
    CancelToken? cancelToken,
  }) async* {
    final reply = _stockReplies[_random.nextInt(_stockReplies.length)];
    final tokens = _tokenize(reply);

    for (final token in tokens) {
      if (cancelToken?.isCancelled ?? false) return;
      await Future.delayed(_tokenInterval);
      if (cancelToken?.isCancelled ?? false) return;
      yield TokenEvent(token);
    }

    if (cancelToken?.isCancelled ?? false) return;
    yield const CitationEvent(_mockCitation);
    yield const DoneEvent();
  }

  /// Splits the reply into small chunks (1-3 chars) to approximate a
  /// realistic streaming cadence in zh-CN where each character is a token.
  List<String> _tokenize(String text) {
    final out = <String>[];
    final runes = text.runes.toList();
    var i = 0;
    while (i < runes.length) {
      final chunk = 1 + _random.nextInt(2);
      final end = (i + chunk).clamp(0, runes.length);
      out.add(String.fromCharCodes(runes.sublist(i, end)));
      i = end;
    }
    return out;
  }
}
