import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/services/db_key_manager.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'message_database.g.dart';

enum SyncStatus { pending, sent, failed }

// ===============================
// Table Chats
// ===============================
class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();

  // Group
  TextColumn get groupName => text().nullable()();
  TextColumn get groupPhotoUrl => text().nullable()();

  TextColumn get members => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get memberInfo => text()
      .map(const MemberInfoMapConverter())
      .withDefault(const Constant('{}'))();
  TextColumn get pinnedBy => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get unreadCount => text()
      .map(const MapStringIntConverter())
      .withDefault(const Constant('{}'))();
  TextColumn get lastReadAt => text()
      .map(const MapStringDateTimeConverter())
      .withDefault(const Constant('{}'))();

  // Last Message
  TextColumn get lastMessage =>
      text().map(const LastMessageConverter()).nullable()();

  // Timestamp
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer().nullable()();

  TextColumn get createdBy =>
      text().map(const MapStringStringConverter()).nullable()();
  TextColumn get deletedBy => text().nullable()();

  // Flag to point last message existence, so Firestore cannot reach it
  BoolColumn get hasReachedBeginning =>
      boolean().withDefault(const Constant(false))();

  // Flag to syncing
  IntColumn get lastSyncTimestamp => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

// ===============================
// Table Messages
// ===============================
@TableIndex(name: 'idx_messages_room_sent', columns: {#chatRoomId, #sentAt})
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get chatRoomId => text().references(Chats, #id)();
  TextColumn get senderId => text()();
  TextColumn get senderName => text()();

  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get textContent => text()();

  // Multimedia
  TextColumn get localPath => text().nullable()(); // Local path on phone
  TextColumn get mediaUrls => text().map(const StringListConverter()).nullable()(); // Saved url in cloud
  TextColumn get mediaCaptions => text().map(const StringListConverter()).nullable()();
  TextColumn get mediaGroupId => text().nullable()();
  IntColumn get mediaDuration => integer().nullable()();
  TextColumn get mimeType => text().nullable()();
  TextColumn get fileName => text().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();

  // Reply
  TextColumn get replyToId => text().nullable()();
  TextColumn get replyToText => text().nullable()();
  TextColumn get replyToSenderName => text().nullable()();
  IntColumn get replyToSentAt => integer().nullable()();
  TextColumn get replyToMediaUrl => text().nullable()();
  TextColumn get replyToMediaType => text().nullable()();

  // Deleted
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedFor => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))(); // Will be in Json

  // Syncing status
  IntColumn get sentAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DriftDatabase(tables: [Chats, Messages])
class MessageDatabase extends _$MessageDatabase {
  MessageDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      print('🛠️ [DATABASE] Membuat tabel baru dari nol!');
      await m.createAll(); // Create the tables

      // Build FTS using FTS5
      await customStatement('''
        CREATE VIRTUAL TABLE messages_fts USING fts5(
          message_id UNINDEXED,
          text_content,
          sender_name,
          tokenize='unicode61'
        );
      ''');

      // Trigger on insert
      await customStatement('''
        CREATE TRIGGER after_message_insert
        AFTER INSERT ON messages
        BEGIN
          INSERT INTO messages_fts(message_id, text_content, sender_name)
          VALUES (new.id, new.text_content, new.sender_name);
        END;
      ''');

      // Trigger on update
      await customStatement('''
        CREATE TRIGGER after_message_update
        AFTER UPDATE OF text_content ON messages
        BEGIN
          UPDATE messages_fts
          SET text_content = new.text_content
          WHERE message_id = new.id;
        END;
      ''');

      // Trigger on delete
      await customStatement('''
        CREATE TRIGGER after_message_delete
        AFTER DELETE ON messages
        BEGIN
          DELETE FROM messages_fts
          WHERE message_id = old.id;
        END;
      ''');
    },

    onUpgrade: (Migrator m, int from, int to) async {
      print('🛠️ [DATABASE] Migrasi! Menghancurkan dan membuat ulang...');
      await customStatement('PRAGMA foreign_keys = OFF');

      if (from < 2) {}
    },

    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ===========================
  // Search using FTS5
  // ===========================
  Future<List<Message>> searchMessages(String keyword, String currentUid, {int limit = 50}) async {
    if (keyword.trim().isEmpty) return [];

    final cleaned = keyword.replaceAll(RegExp(r'["*^()~:+\[\]]'), ' ');
    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (tokens.isEmpty) return [];
    final ftsQuery = tokens.map((t) => '$t*').join(' ');

    // Query A: FTS5 only — proven instant
    final ftsRows = await customSelect(
      'SELECT message_id FROM messages_fts WHERE messages_fts MATCH ?',
      variables: [Variable.withString(ftsQuery)],
    ).get();
    if (ftsRows.isEmpty) return [];

    final ids = ftsRows.map((r) => r.data['message_id'] as String).toList();

    // Query B: Simple PK lookup — no JOIN, no FTS5
    final results = await (select(messages)
        ..where((m) => m.id.isIn(ids))
        ..where((m) => m.isDeleted.equals(false))
        ..where((m) => m.deletedFor.like('%"$currentUid"%').not())
    ).get();

    results.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return results.take(limit).toList();
  }

  // ===========================
  // Pagination
  // ===========================
  /// Pagination for Scroll UP (To the old message)
  Future<List<Message>> fetchOlderMessages(
    String chatRoomId, {
    required int beforeSentAt,
    int limit = 50,
  }) async =>
      (select(messages)
            ..where(
              (m) =>
                  m.chatRoomId.equals(chatRoomId) &
                  m.sentAt.isSmallerThanValue(beforeSentAt),
            )
            ..orderBy([(m) => OrderingTerm.desc(m.sentAt)])
            ..limit(limit))
          .get();

  /// Pagination for scroll down (fetch new messages)
  Future<List<Message>> fetchNewerMessages(
    String chatRoomId, {
    required int afterSentAt,
    int limit = 50,
  }) async =>
      (select(messages)
            ..where(
              (m) =>
                  m.chatRoomId.equals(chatRoomId) &
                  m.sentAt.isBiggerThanValue(afterSentAt),
            )
            ..orderBy([
              (m) => OrderingTerm.asc(m.sentAt),
            ]) // Ascending because the closest data to 'sent_at' target
            ..limit(limit))
          .get();

  // ===========================
  // Jump To / Teleportation
  // ===========================

  /// Get the target and Stream it
  ///The reason is, after we jump to target, there could be a case that
  ///Target was deleted, edited. If we use Future then its static, no changes
  ///Stream enables our App to keep listen to it
  Stream<List<Message>> watchMessagesAround(
    String chatRoomId, {
    required int targetSentAt,
    int limit = 50,
  }) {
    int half = limit ~/ 2;

    // Use custom statement for bidirectional UNION
    // 1. GET data AND half of previous data
    // 2. Fetch the half of next data
    return customSelect(
      '''
        SELECT * FROM messages m
        WHERE m.chat_room_id = ?
        AND (
          id IN (
            SELECT id FROM messages
            WHERE chat_room_id = ? AND sent_at <= ?
            ORDER BY sent_at DESC LIMIT ?
          )
          OR id IN (
            SELECT id FROM messages
            WHERE chat_room_id = ? AND sent_at > ?
            ORDER BY sent_at ASC LIMIT ?
          )
        )
        ORDER BY sent_at DESC
      ''',
      variables: [
        Variable.withString(chatRoomId),

        Variable.withString(chatRoomId),
        Variable.withInt(targetSentAt),
        Variable.withInt(half),

        Variable.withString(chatRoomId),
        Variable.withInt(targetSentAt),
        Variable.withInt(half),
      ],
      readsFrom: {messages},
    ).watch().map((rows) => rows.map((row) => messages.map(row.data)).toList());
  }

  // ==============================
  // WATCH CHAT ROOM MESSAGES
  // ==============================
  /// Only watch messages limited in chat room
  Stream<List<Message>> watchMessages(String chatRoomId, String currentUid, {int limit = 50}) =>
      (select(messages)
            ..where((m) => m.chatRoomId.equals(chatRoomId))
            ..where((m) => m.deletedFor.like('%"$currentUid"%').not())
            ..orderBy([(m) => OrderingTerm.desc(m.sentAt)])
            ..limit(limit))
          .watch();

  Stream<List<Chat>> watchChatRooms({int limit = 100}) =>
      (select(chats)
            ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])
            ..limit(limit))
          .watch();

  // ============================
  // Upsert
  // ============================
  Future<void> upsertChatRooms(List<ChatsCompanion> newChatRooms) async {
    await batch((b) {
      for (final room in newChatRooms) {
        b.insert(chats, room, onConflict: DoUpdate((old) => room));
      }
    });
  }

  Future<void> upsertMessages(List<MessagesCompanion> newMessages) async {
    await batch((b) {
      for (final msg in newMessages) {
        b.insert(messages, msg, onConflict: DoUpdate((old) => msg));
      }
    });
  }

  Future<void> upsertMessage(MessagesCompanion message) =>
      into(messages).insertOnConflictUpdate(message);

  // ============================
  // UPDATE
  // ============================
  Future<void> updateMessageStatus(String messageId, SyncStatus newStatus) =>
      (update(messages)..where((m) => m.id.equals(messageId))).write(
        MessagesCompanion(syncStatus: Value(newStatus)),
      );

  Future<void> updateMediaMessageSuccess(
    String messageId,
    List<String> cloudUrls, {
    int? fileSizeBytes,
    String? mimeType,
    String? fileName,
  }) =>
      (update(messages)..where((m) => m.id.equals(messageId))).write(
        MessagesCompanion(
          syncStatus: Value(SyncStatus.sent),
          mediaUrls: Value(cloudUrls),
          fileSizeBytes: Value(fileSizeBytes),
          mimeType: Value(mimeType),
          fileName: Value(fileName)
        ),
      );

  Future<void> updateChatLastSync(String chatId, int timestamp) =>
      (update(chats)..where((c) => c.id.equals(chatId))).write(
        ChatsCompanion(lastSyncTimestamp: Value(timestamp)),
      );

  Future<void> updateChatLastMessage(String chatId, LastMessage lastMessage) =>
      (update(chats)..where((c) => c.id.equals(chatId))).write(
        ChatsCompanion(
          lastMessage: Value(lastMessage),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  // ===========================
  // DELETE
  // ===========================
  Future<int> hardDeleteMessages({required List<String> messageIds}) async {
    if (messageIds.isEmpty) return Future.value(0);

    // Hard delete on SQLite, then StreamProvider will automatically updates the value
    return (delete(messages)..where((m) => m.id.isIn(messageIds))).go();
  }

  Future<int> softDeleteMessages({required List<String> messageIds}) async {
    if (messageIds.isEmpty) return Future.value(0);
    // Soft delete on SQLite, append DeletedFor column
    return (update(messages)..where((m) => m.id.isIn(messageIds))).write(
      const MessagesCompanion(
        isDeleted: Value(true),
        syncStatus: Value(SyncStatus.pending),
        textContent: Value('This message was deleted'),
        mediaUrls: Value(null),
        mediaGroupId: Value(null),
      ),
    );
  }

  Future<void> markChatDeletedLocally(String chatId, String uid) async {
    final existing = await (select(chats)..where((c) => c.id.equals(chatId))).getSingleOrNull();
    if (existing == null) return;

    Map<String, dynamic> deletedBy = {};
    if (existing.deletedBy != null) {
      deletedBy = jsonDecode(existing.deletedBy!) as Map<String, dynamic>;
    }
    deletedBy[uid] = DateTime.now().millisecondsSinceEpoch;

    await (update(chats)..where((c) => c.id.equals(chatId))).write(
      ChatsCompanion(deletedBy: Value(jsonEncode(deletedBy))),
    );
  }

  Future<void> pinChatLocally(String chatId, String uid) async {
    final existing = await (select(chats)..where((c) => c.id.equals(chatId))).getSingleOrNull();
    if (existing == null) return;

    final current = List<String>.from(existing.pinnedBy);
    if (!current.contains(uid)) {
      current.add(uid);
    }

    await (update(chats)..where((c) => c.id.equals(chatId))).write(
      ChatsCompanion(pinnedBy: Value(current)),
    );
  }

  Future<void> unpinChatLocally(String chatId, String uid) async {
    final existing = await (select(chats)..where((c) => c.id.equals(chatId))).getSingleOrNull();
    if (existing == null) return;

    final current = List<String>.from(existing.pinnedBy);
    current.remove(uid);

    await (update(chats)..where((c) => c.id.equals(chatId))).write(
      ChatsCompanion(pinnedBy: Value(current)),
    );
  }

  Future<void> deleteForMeLocal(String messageId, String currentUid) async {
    if (messageId.isEmpty) return;

    final msg = await (select(
      messages,
    )..where((m) => m.id.equals(messageId))).getSingle();
    final currentDeletedFor = List<String>.from(msg.deletedFor);
    if (!currentDeletedFor.contains(currentUid)) {
      currentDeletedFor.add(currentUid);
    }

    await (update(messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(
        deletedFor: Value(currentDeletedFor),
        syncStatus: Value(SyncStatus.pending),
      ),
    );
  }

  // ====================================
  // CLEAN ALL DATA
  // ====================================
  Future<void> clearAllTables() async {
    await transaction(() async {
      await delete(messages).go();
      await delete(chats).go();
    });
  }

  // ==============================
  // HELPER
  // ==============================
  Future<Chat?> getChatById(String chatId) =>
      (select(chats)..where((c) => c.id.equals(chatId))).getSingleOrNull();

  Future<List<Message>> getStuckPendingMessages() async {
    final fiveMinutesAgo = DateTime.now()
        .subtract(const Duration(minutes: 5))
        .millisecondsSinceEpoch;

    return (select(messages)
          ..where((m) => m.syncStatus.equals(SyncStatus.pending.name))
          ..where((m) => m.sentAt.isSmallerThanValue(fiveMinutesAgo)))
        .get();
  }

  Future<List<Chat>> getAllChatRooms(String currentUid) =>
      (select(chats)..where((c) => c.memberInfo.contains(currentUid))).get();
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) => List<String>.from(jsonDecode(fromDb));

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class MapStringStringConverter
    extends TypeConverter<Map<String, String>, String> {
  const MapStringStringConverter();

  @override
  Map<String, String> fromSql(String fromDb) =>
      Map<String, String>.from(jsonDecode(fromDb));

  @override
  String toSql(Map<String, String> value) => jsonEncode(value);
}

class MapStringIntConverter extends TypeConverter<Map<String, int>, String> {
  const MapStringIntConverter();
  @override
  Map<String, int> fromSql(String fromDb) =>
      Map<String, int>.from(jsonDecode(fromDb));
  @override
  String toSql(Map<String, int> value) => jsonEncode(value);
}

class MemberInfoMapConverter
    extends TypeConverter<Map<String, MemberInfo>, String> {
  const MemberInfoMapConverter();
  @override
  Map<String, MemberInfo> fromSql(String fromDb) {
    final map = jsonDecode(fromDb) as Map<String, dynamic>;
    // Asumsi lu punya factory MemberInfo.fromJson(json)
    return map.map((k, v) => MapEntry(k, MemberInfo.fromMap(v)));
  }

  @override
  String toSql(Map<String, MemberInfo> value) {
    final map = value.map((k, v) => MapEntry(k, v.toMap()));
    return jsonEncode(map);
  }
}

class MapStringDateTimeConverter
    extends TypeConverter<Map<String, DateTime>, String> {
  const MapStringDateTimeConverter();
  @override
  Map<String, DateTime> fromSql(String fromDb) {
    final map = jsonDecode(fromDb) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(k, DateTime.fromMillisecondsSinceEpoch(v)),
    );
  }

  @override
  String toSql(Map<String, DateTime> value) {
    final map = value.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch));
    return jsonEncode(map);
  }
}

class LastMessageConverter extends TypeConverter<LastMessage, String> {
  const LastMessageConverter();
  @override
  LastMessage fromSql(String fromDb) =>
      LastMessage.fromJson(jsonDecode(fromDb));
  @override
  String toSql(LastMessage value) => jsonEncode(value.toJson());
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'kouvention.db'));

  final key = await DbKeyManager.getOrCreateKey();
  final escapedKey = key.replaceAll("'", "''");

  return NativeDatabase.createInBackground(
    file,
    logStatements: true,
    isolateSetup: () async {
      final marker = File('${file.path}.encrypted');
      // Check if marker exist, then repalce it with encrypted one
      if (await file.exists() && !await marker.exists()) {
        await file.delete();
        await marker.create();
      }
    },
    setup: (rawDb) {
      assert(() {
        if (rawDb.select('PRAGMA cipher;').isEmpty) {
          throw StateError('SQLite3MultiCiphers not loaded!');
        }
        return true;
      }());

      // LOCK
      rawDb.execute("PRAGMA key = '$escapedKey';");
      rawDb.execute('PRAGMA cache_size = -64000;'); // 64MB page cache for FTS5
    },
  );
});

final messageDatabaseProvider = Provider<MessageDatabase>(
  (ref) => MessageDatabase(),
);
