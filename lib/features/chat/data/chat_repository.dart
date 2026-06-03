import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/config.dart' as config;
import '../domain/message.dart';

class ChatRepository {
  ChatRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Stream<String> streamChat(List<Message> messages) async* {
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
      throw ChatRepositoryException(
        'Request failed: ${e.message ?? e.type.name}',
        cause: e,
      );
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const ChatRepositoryException('Empty response stream');
    }

    final byteStream = stream.cast<List<int>>();
    final lineStream = byteStream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final rawLine in lineStream) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;

        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;

          final delta = (choices.first as Map<String, dynamic>)['delta']
              as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } on FormatException {
          continue;
        }
      }
    } on DioException catch (e) {
      throw ChatRepositoryException(
        'Stream interrupted: ${e.message ?? e.type.name}',
        cause: e,
      );
    }
  }
}

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ChatRepositoryException: $message';
}
