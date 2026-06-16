import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Users table — the local mirror of authenticated users.
/// We keep one row per device-resident login so that all per-user
/// rows in other tables can be filtered with a single foreign key.
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get phone => text()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get title => text().withDefault(const Constant('新对话'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get role => text()(); // 'user' | 'assistant'
  TextColumn get content => text()();
  TextColumn get status => text().withDefault(const Constant('done'))();
  TextColumn get feedback => text().withDefault(const Constant('none'))();
  DateTimeColumn get timestamp =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Citations extends Table {
  TextColumn get id => text()();
  TextColumn get messageId =>
      text().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get snippet => text()();
  TextColumn get source => text().nullable()();
  TextColumn get url => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Images extends Table {
  TextColumn get id => text()();
  TextColumn get messageId =>
      text().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get uri => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get roiJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Conversations, Messages, Citations, Images])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _defaultExecutor());

  static QueryExecutor _defaultExecutor() => driftDatabase(
        name: 'pathpocket',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );

  @override
  int get schemaVersion => 1;

  // ---- Users ----

  Future<void> upsertUser(UsersCompanion user) =>
      into(users).insertOnConflictUpdate(user);

  Future<User?> findUser(String id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  // ---- Conversations ----

  Future<List<Conversation>> conversationsForUser(String userId) {
    return (select(conversations)
          ..where((c) => c.userId.equals(userId))
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .get();
  }

  Stream<List<Conversation>> watchConversationsForUser(String userId) {
    return (select(conversations)
          ..where((c) => c.userId.equals(userId))
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .watch();
  }

  Future<void> insertConversation(ConversationsCompanion conv) =>
      into(conversations).insert(conv);

  Future<void> renameConversation(String id, String title) {
    return (update(conversations)..where((c) => c.id.equals(id)))
        .write(ConversationsCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> touchConversation(String id) {
    return (update(conversations)..where((c) => c.id.equals(id)))
        .write(ConversationsCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> deleteConversation(String id) =>
      (delete(conversations)..where((c) => c.id.equals(id))).go();

  Future<void> deleteAllConversationsForUser(String userId) =>
      (delete(conversations)..where((c) => c.userId.equals(userId))).go();

  // ---- Messages ----

  Stream<List<Message>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .watch();
  }

  Future<List<Message>> messagesFor(String conversationId) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();
  }

  Future<void> upsertMessage(MessagesCompanion msg) =>
      into(messages).insertOnConflictUpdate(msg);

  Future<void> updateMessageContent({
    required String id,
    required String content,
    required String status,
  }) {
    return (update(messages)..where((m) => m.id.equals(id))).write(
      MessagesCompanion(content: Value(content), status: Value(status)),
    );
  }

  Future<void> updateMessageFeedback(String id, String feedback) {
    return (update(messages)..where((m) => m.id.equals(id)))
        .write(MessagesCompanion(feedback: Value(feedback)));
  }

  Future<void> deleteMessage(String id) =>
      (delete(messages)..where((m) => m.id.equals(id))).go();

  // ---- Citations ----

  Stream<List<Citation>> watchCitations(String messageId) {
    return (select(citations)
          ..where((c) => c.messageId.equals(messageId))
          ..orderBy([(c) => OrderingTerm.asc(c.displayOrder)]))
        .watch();
  }

  /// Batch-fetch citations for many messages in a single query.
  ///
  /// Returned rows are ordered by `displayOrder`; callers group by
  /// `messageId`. Avoids the per-message round-trip when loading a
  /// conversation's full history.
  Future<List<Citation>> citationsForMessages(List<String> messageIds) {
    if (messageIds.isEmpty) return Future.value(const []);
    return (select(citations)
          ..where((c) => c.messageId.isIn(messageIds))
          ..orderBy([(c) => OrderingTerm.asc(c.displayOrder)]))
        .get();
  }

  Future<void> insertCitation(CitationsCompanion citation) =>
      into(citations).insert(citation);

  // ---- Images ----

  Future<List<Image>> imagesFor(String messageId) {
    return (select(images)..where((i) => i.messageId.equals(messageId))).get();
  }

  Future<void> insertImage(ImagesCompanion image) => into(images).insert(image);
}

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden in main() with an AppDatabase '
    'instance created before runApp().',
  );
});
