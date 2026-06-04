import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/sse_parser.dart';
import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/app_database.dart' show AppDatabase, databaseProvider;
import '../../auth/presentation/auth_provider.dart';
import '../../conversations/data/conversation_repository.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  // Mock by default during Phase 1. Swap to OpenAIChatRepository (or a real
  // backend repository) in main.dart via ProviderScope.overrides when ready.
  return MockChatRepository();
});

/// State for the currently-selected conversation's chat session.
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

/// Per-conversation chat notifier. Scoped by conversationId via `.family`.
///
/// Cancellation contract:
/// - Switching the selected conversation creates a new family instance — the
///   old one is auto-disposed by Riverpod, which fires `ref.onDispose` →
///   cancels the in-flight Dio stream.
/// - Logout registers a hook that cancels every active conversation's stream
///   and waits for them before clearing auth tokens.
class ChatNotifier extends Notifier<ChatState> {
  ChatNotifier(this.conversationId);

  final String conversationId;

  late final ChatRepository _repo;
  late final AppDatabase _db;
  late final ConversationRepository _convRepo;
  CancelToken? _cancelToken;
  StreamSubscription<ChatStreamEvent>? _subscription;
  Completer<void>? _activeRun;
  String? _userId;
  void Function()? _unregisterLogout;

  @override
  ChatState build() {
    _repo = ref.read(chatRepositoryProvider);
    _db = ref.read(databaseProvider);
    _convRepo = ref.read(conversationRepositoryProvider);
    _userId = ref.read(currentUserProvider)?.id;

    _unregisterLogout = registerLogoutHook(ref, _cancelAndWait);
    ref.onDispose(() async {
      _unregisterLogout?.call();
      await _cancelAndWait();
    });

    // Initial load from Drift.
    unawaited(_loadFromDb(conversationId));

    return const ChatState();
  }

  Future<void> _loadFromDb(String conversationId) async {
    final rows = await _db.messagesFor(conversationId);
    final messages = <Message>[];
    for (final r in rows) {
      final citations = await _db.watchCitations(r.id).first;
      messages.add(Message(
        id: r.id,
        conversationId: r.conversationId,
        role: MessageRole.values.firstWhere(
          (e) => e.name == r.role,
          orElse: () => MessageRole.user,
        ),
        content: r.content,
        timestamp: r.timestamp,
        status: MessageStatus.values.firstWhere(
          (s) => s.name == r.status,
          orElse: () => MessageStatus.done,
        ),
        citations: citations
            .map((c) => Citation(
                  id: c.id,
                  title: c.title,
                  snippet: c.snippet,
                  source: c.source,
                  url: c.url,
                ))
            .toList(),
        feedback: Feedback.values.firstWhere(
          (f) => f.name == r.feedback,
          orElse: () => Feedback.none,
        ),
      ));
    }
    state = state.copyWith(messages: messages);
  }

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final userId = _userId;
    if (userId == null) return; // shouldn't happen — router guards this

    final userMsg = Message(
      id: _newId('m_u'),
      conversationId: conversationId,
      role: MessageRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
      status: MessageStatus.done,
    );
    final placeholder = Message(
      id: _newId('m_a'),
      conversationId: conversationId,
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      status: MessageStatus.streaming,
    );

    await _persistMessage(userMsg, userId);
    await _persistMessage(placeholder, userId);
    await _convRepo.touch(conversationId);

    state = state.copyWith(
      messages: [...state.messages, userMsg, placeholder],
      isLoading: true,
      clearError: true,
    );

    await _runStream(placeholder.id, userId);
  }

  Future<void> regenerate(String assistantMessageId) async {
    final idx = state.messages.indexWhere((m) => m.id == assistantMessageId);
    if (idx == -1) return;
    if (state.messages[idx].role != MessageRole.assistant) return;
    final userId = _userId;
    if (userId == null) return;

    await _cancelAndWait();

    // Reset the assistant message to an empty streaming state.
    final updated = state.messages[idx].copyWith(
      content: '',
      status: MessageStatus.streaming,
      citations: const [],
      feedback: Feedback.none,
    );
    final next = [...state.messages];
    next[idx] = updated;
    state = state.copyWith(messages: next, isLoading: true, clearError: true);

    await _persistMessage(updated, userId);
    await _runStream(updated.id, userId);
  }

  Future<void> stopGeneration() async {
    await _cancelAndWait();
    final lastAssistantIdx =
        state.messages.lastIndexWhere((m) => m.role == MessageRole.assistant);
    if (lastAssistantIdx == -1) {
      state = state.copyWith(isLoading: false);
      return;
    }
    final stopped =
        state.messages[lastAssistantIdx].copyWith(status: MessageStatus.stopped);
    final next = [...state.messages];
    next[lastAssistantIdx] = stopped;
    state = state.copyWith(messages: next, isLoading: false);
    final uid = _userId;
    if (uid != null) await _persistMessage(stopped, uid);
  }

  Future<void> setFeedback(String messageId, Feedback feedback) async {
    final next = [...state.messages];
    final i = next.indexWhere((m) => m.id == messageId);
    if (i == -1) return;
    next[i] = next[i].copyWith(feedback: feedback);
    state = state.copyWith(messages: next);
    await _db.updateMessageFeedback(messageId, feedback.name);
  }

  Future<void> _runStream(String assistantId, String userId) async {
    final cancel = CancelToken();
    _cancelToken = cancel;
    final run = Completer<void>();
    _activeRun = run;

    _subscription?.cancel();
    _subscription = _repo
        .streamChat(_historyForRequest(), cancelToken: cancel)
        .listen(
      (event) async {
        if (cancel.isCancelled) return;
        switch (event) {
          case TokenEvent(:final content):
            _appendToken(assistantId, content);
          case CitationEvent(:final citation):
            await _appendCitation(assistantId, citation);
          case DoneEvent():
            await _finalizeAssistant(assistantId, userId,
                MessageStatus.done);
            state = state.copyWith(isLoading: false);
            if (!run.isCompleted) run.complete();
        }
      },
      onError: (Object error, StackTrace _) async {
        if (error is DioException && CancelToken.isCancel(error)) {
          if (!run.isCompleted) run.complete();
          return;
        }
        final msg = error is ChatRepositoryException
            ? error.message
            : error.toString();
        await _finalizeAssistant(assistantId, userId, MessageStatus.error);
        state = state.copyWith(isLoading: false, errorMessage: msg);
        if (!run.isCompleted) run.complete();
      },
      onDone: () {
        if (!run.isCompleted) run.complete();
      },
      cancelOnError: true,
    );

    await run.future;
    _cancelToken = null;
    _activeRun = null;
  }

  void _appendToken(String messageId, String token) {
    final next = [...state.messages];
    final i = next.indexWhere((m) => m.id == messageId);
    if (i == -1) return;
    next[i] = next[i].copyWith(content: next[i].content + token);
    state = state.copyWith(messages: next);
    // Persist incrementally — cheap because Drift uses prepared statements.
    unawaited(_db.updateMessageContent(
      id: messageId,
      content: next[i].content,
      status: MessageStatus.streaming.name,
    ));
  }

  Future<void> _appendCitation(String messageId, Citation citation) async {
    final next = [...state.messages];
    final i = next.indexWhere((m) => m.id == messageId);
    if (i == -1) return;
    final existing = next[i].citations;
    next[i] = next[i].copyWith(citations: [...existing, citation]);
    state = state.copyWith(messages: next);
    await _db.insertCitation(db.CitationsCompanion.insert(
      id: citation.id,
      messageId: messageId,
      title: citation.title,
      snippet: citation.snippet,
      source: Value(citation.source),
      url: Value(citation.url),
      displayOrder: Value(existing.length),
    ));
  }

  Future<void> _finalizeAssistant(
      String messageId, String userId, MessageStatus status) async {
    final next = [...state.messages];
    final i = next.indexWhere((m) => m.id == messageId);
    if (i == -1) return;
    next[i] = next[i].copyWith(status: status);
    state = state.copyWith(messages: next);
    await _db.updateMessageContent(
      id: messageId,
      content: next[i].content,
      status: status.name,
    );
  }

  Future<void> _cancelAndWait() async {
    final token = _cancelToken;
    final run = _activeRun;
    if (token != null && !token.isCancelled) {
      token.cancel('cancelled');
    }
    await _subscription?.cancel();
    _subscription = null;
    if (run != null && !run.isCompleted) {
      // Don't await forever — give the stream a tick to unwind.
      await run.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }
    _activeRun = null;
    _cancelToken = null;
  }

  /// History sent to the API. Excludes the current empty assistant placeholder.
  List<Message> _historyForRequest() {
    final msgs = state.messages;
    if (msgs.isEmpty) return const [];
    final last = msgs.last;
    if (last.role == MessageRole.assistant && last.content.isEmpty) {
      return msgs.sublist(0, msgs.length - 1);
    }
    return msgs;
  }

  Future<void> _persistMessage(Message m, String userId) {
    return _db.upsertMessage(db.MessagesCompanion.insert(
      id: m.id,
      conversationId: m.conversationId,
      userId: userId,
      role: m.role.name,
      content: m.content,
      status: Value(m.status.name),
      feedback: Value(m.feedback.name),
      timestamp: Value(m.timestamp),
    ));
  }
}

final chatProvider =
    NotifierProvider.family<ChatNotifier, ChatState, String>(
  ChatNotifier.new,
);
