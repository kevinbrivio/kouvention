import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/services/db_key_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'message_database.g.dart';

enum SyncStatus { pending, sent, failed }

// ===============================
// Table Chats
// ===============================
class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

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

  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get textContent => text()();

  // Multimedia
  TextColumn get localPath => text().nullable()(); // Local path on phone
  TextColumn get mediaUrl => text().nullable()(); // Saved url in cloud
  TextColumn get mediaGroupId => text().nullable()();

  // Reply
  TextColumn get replyToId => text().nullable()();
  TextColumn get replyToName => text().nullable()();
  TextColumn get replyToSenderName => text().nullable()();

  // Syncing status
  IntColumn get sentAt => integer()();
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
      await m.createAll(); // Create the tables

      // Build FTS using FTS5
      await customStatement('''
        CREATE VIRTUAL TABLE messages_fts USING fts5(
          message_id UNINDEXED,
          textContent,
          tokenize='unicode61'
        );
      ''');

      // Build the Trigger
      await customStatement('''
        CREATE TRIGGER after_message_insert
        AFTER INSERT ON messages
        WHEN new.type = 'text'
        BEGIN
          INSERT INTO messages_fts(message_id, textContent)
          VALUES (new.id, new.text_content);
        END;
      ''');

      // Trigger on update
      await customStatement('''
        CREATE TRIGGER after_message_update
        AFTER UPDATE OF text_content ON messages
        WHEN new.type = 'text'
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
        WHEN old.type = 'text'
        BEGIN
          DELETE FROM messages_fts
          WHERE message_id = old.id;
        END;
      ''');
    },

    onUpgrade: (Migrator m, int from, int to) async {
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
  Future<List<Message>> searchMessages(String keyword, {int limit = 50}) async {
    final ftsKeyword = '$keyword*'; // Prefix wildcard

    final query = customSelect(
      '''
        SELECT m.* FROM messages m
        JOIN messages_fts f ON m.id = f.message_id
        WHERE f.textContent MATCH ?
        ORDER BY sent_at DESC
        LIMIT ?
      ''',
      variables: [Variable.withString(ftsKeyword), Variable.withInt(limit)],
      // Update the Message table, help Stream/Watch updates the data
      readsFrom: {messages},
    );

    return query.map((row) => messages.map(row.data)).get();
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
        WHERE m.chatRoomId = ?
        AND (
          id IN (
            SELECT id FROM messages
            WHERE chat_room_id = ? AND sent_at <= ?
            ORDER BY sent_at DESC LIMIT ?
          )
          OR ID IN (
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
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'kouvention.db'));

  final key = await DbKeyManager.getOrCreateKey();
  final escapedKey = key.replaceAll("'", "''");

  return NativeDatabase.createInBackground(
    file,
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
      rawDb.execute("PARGMA key = '$escapedKey;'");
    },
  );
});

final messageDatabaseProvider = Provider<MessageDatabase>(
  (ref) => MessageDatabase(),
);
