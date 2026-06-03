import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/chat_repository.dart';
import '../domain/message.dart';

const String _historyKey = 'chat_history';
const int _historyLimit = 20;

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Message> messages;
  final bool isLoading;
  final String? errorMessage;

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope with '
    'a SharedPreferences instance loaded before runApp().',
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatNotifier extends Notifier<ChatState> {
  late final SharedPreferences _prefs;
  late final ChatRepository _repository;
  StreamSubscription<String>? _subscription;

  @override
  ChatState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    _repository = ref.read(chatRepositoryProvider);
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return _loadInitialState();
  }

  ChatState _loadInitialState() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return const ChatState();
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final messages = decoded
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
      final tail = messages.length <= _historyLimit
          ? messages
          : messages.sublist(messages.length - _historyLimit);
      return ChatState(messages: tail);
    } catch (_) {
      _prefs.remove(_historyKey);
      return const ChatState();
    }
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final userMessage = Message(
      id: _newId(),
      role: MessageRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
    );
    final placeholder = Message(
      id: _newId(),
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, placeholder],
      isLoading: true,
      clearError: true,
    );

    final historyForRequest = <Message>[...state.messages]
      ..removeLast(); // drop empty assistant placeholder

    final completer = Completer<void>();
    _subscription?.cancel();
    _subscription = _repository.streamChat(historyForRequest).listen(
      (token) {
        final messages = [...state.messages];
        if (messages.isEmpty) return;
        final last = messages.last;
        messages[messages.length - 1] =
            last.copyWith(content: last.content + token);
        state = state.copyWith(messages: messages);
      },
      onError: (Object error, StackTrace _) {
        final msg = error is ChatRepositoryException
            ? error.message
            : error.toString();
        state = state.copyWith(isLoading: false, errorMessage: msg);
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        state = state.copyWith(isLoading: false);
        unawaited(saveHistory());
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
  }

  Future<void> clearChat() async {
    _subscription?.cancel();
    _subscription = null;
    state = const ChatState();
    await _prefs.remove(_historyKey);
  }

  Future<void> saveHistory() async {
    final tail = state.messages.length <= _historyLimit
        ? state.messages
        : state.messages.sublist(state.messages.length - _historyLimit);
    final encoded = jsonEncode(tail.map((m) => m.toJson()).toList());
    await _prefs.setString(_historyKey, encoded);
  }

  Future<void> loadHistory() async {
    state = state.copyWith(messages: _loadInitialState().messages);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
