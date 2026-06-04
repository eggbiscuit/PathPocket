import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation.dart';

/// Stream of the current user's conversations.
/// Re-evaluates whenever the user changes — switching users yields a fresh
/// stream from the DB and never leaks the previous user's data.
final conversationsStreamProvider =
    StreamProvider.autoDispose<List<Conversation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(conversationRepositoryProvider).watchForUser(user.id);
});

/// The currently-selected conversation id. Null means "no conversation yet —
/// show empty state or auto-create on first send".
class SelectedConversationNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Reset selection whenever the user changes.
    ref.listen(currentUserProvider, (prev, next) {
      if (prev?.id != next?.id) state = null;
    });
    return null;
  }

  void select(String? id) {
    state = id;
  }
}

final selectedConversationProvider =
    NotifierProvider<SelectedConversationNotifier, String?>(
  SelectedConversationNotifier.new,
);

String generateConversationId() =>
    'c_${DateTime.now().microsecondsSinceEpoch}';
