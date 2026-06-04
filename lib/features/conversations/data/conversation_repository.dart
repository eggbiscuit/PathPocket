import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/app_database.dart' show AppDatabase, databaseProvider;
import '../domain/conversation.dart';

class ConversationRepository {
  ConversationRepository(this._db);
  final AppDatabase _db;

  Stream<List<Conversation>> watchForUser(String userId) {
    return _db.watchConversationsForUser(userId).map(
          (rows) => rows
              .map((r) => Conversation(
                    id: r.id,
                    userId: r.userId,
                    title: r.title,
                    createdAt: r.createdAt,
                    updatedAt: r.updatedAt,
                  ))
              .toList(),
        );
  }

  Future<void> create(Conversation conv) {
    return _db.insertConversation(db.ConversationsCompanion.insert(
      id: conv.id,
      userId: conv.userId,
      title: Value(conv.title),
      createdAt: Value(conv.createdAt),
      updatedAt: Value(conv.updatedAt),
    ));
  }

  Future<void> rename(String id, String title) =>
      _db.renameConversation(id, title);

  Future<void> touch(String id) => _db.touchConversation(id);

  Future<void> remove(String id) => _db.deleteConversation(id);

  Future<void> removeAllForUser(String userId) =>
      _db.deleteAllConversationsForUser(userId);
}

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(databaseProvider));
});
