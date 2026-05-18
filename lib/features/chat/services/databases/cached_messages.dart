import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/services/db_key_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'cached_messages.g.dart';

@TableIndex(name: 'idx_messages_room_sent', columns: {#chatRoomId, #sentAt})
class CachedMessages extends Table {
  // Core
  TextColumn get id => text()();
  TextColumn get chatRoomId => text()();
  TextColumn get messageText => text()();
  TextColumn get textLower => text()();
  TextColumn get senderId => text()();
  TextColumn get senderName => text()();
  IntColumn get sentAt => integer()();
  TextColumn get type => text().withDefault(const Constant('text'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedFor => text().withDefault(const Constant('[]'))();

  // Reply (nullable)
  TextColumn get replyToId => text().nullable()();
  TextColumn get replyToText => text().nullable()();
  TextColumn get replyToSender => text().nullable()();
  IntColumn get replyToSentAt => integer().nullable()();

  // Media (nullable)
  TextColumn get mediaUrl => text().nullable()();
  TextColumn get fileName => text().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get mediaDuration => integer().nullable()();

  // Sync tracking
  IntColumn get syncedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [];
}

class CachedChatRooms extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get members => text()();
  TextColumn get memberInfo => text()();
  TextColumn get lastMessageText => text()();
  TextColumn get lastMessageSender => text()();
  IntColumn get lastMessageSentAt => integer()();

  TextColumn get unreadCount => text()();
  IntColumn get lastSyncTimestamp => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DriftDatabase(tables: [CachedMessages, CachedChatRooms])
class MessageDatabase extends _$MessageDatabase {
  MessageDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await customStatement(
          'ALTER TABLE cached_messages ADD COLUMN reply_to_id TEXT',
        );
        await customStatement(
          'ALTER TABLE cached_messages ADD COLUMN reply_to_text TEXT',
        );
        await customStatement(
          'ALTER TABLE cached_messages ADD COLUMN reply_to_sender TEXT',
        );
        await customStatement(
          'ALTER TABLE cached_messages ADD COLUMN media_url TEXT',
        );
        await customStatement(
          'ALTER TABLE cached_messages ADD COLUMN file_name TEXT',
        );
        await customStatement(
          'ALTER TABLE cached_messages ADD COLUMN file_size_bytes INTEGER',
        );
        await customStatement(
          "ALTER TABLE cached_messages ADD COLUMN deleted_for TEXT DEFAULT '[]'",
        );
      }
      if (from < 3) {
        await migrator.createTable(cachedChatRooms);
      }
      if (from < 4) {
        await customStatement(
          'ALTER TABLE cached_messages ADD COLUMN reply_to_sent_at INTEGER',
        );
      }
      if (from < 5) {
        await customStatement(
            'ALTER TABLE cached_messages ADD COLUMN mime_type TEXT',
          );
        await customStatement(
          'ALTER TABLE cached_messages ADD COLUMN media_duration INTEGER',
        );
      }
    },
  );

  // --- INSERT / UPDATE --------
  Future<void> upsertMessage(CachedMessagesCompanion message) =>
      into(cachedMessages).insertOnConflictUpdate(message);

  Future<void> upsertMessages(List<CachedMessagesCompanion> messages) async {
    await batch((b) {
      for (final m in messages) {
        b.insert(cachedMessages, m, onConflict: DoUpdate((_) => m));
      }
    });
  }

  // --- SEARCH ---
  Future<List<({CachedMessage message, String chatName})>> searchMessages({
    required String query,
    required List<String> chatRoomIds,
    int limit = 50,
  }) {
    final lowerQuery = query.toLowerCase();

    final q = select(cachedMessages).join([
      innerJoin(
        cachedChatRooms,
        cachedChatRooms.id.equalsExp(cachedMessages.chatRoomId),
      ),
    ]);

    q
      ..where(
        (cachedMessages.textLower.like('%$lowerQuery%')) &
            // cachedMessages.senderName.like('%$lowerQuery%') |
            // cachedChatRooms.name.like('%$lowerQuery%')) &
            cachedMessages.isDeleted.equals(false) &
            cachedMessages.chatRoomId.isIn(chatRoomIds),
      )
      ..orderBy([OrderingTerm.desc(cachedMessages.sentAt)])
      ..limit(limit);

    return q.map((row) {
      final message = row.readTable(cachedMessages);
      final chatRoom = row.readTable(cachedChatRooms);
      return (message: message, chatName: chatRoom.name);
    }).get();
  }

  // --- MESSAGES: Stream ----
  /// To stream all messages from SQLite
  Stream<List<CachedMessage>> watchMessages(
    String chatRoomId, {
    int limit = 100,
  }) =>
      (select(cachedMessages)
            ..where((m) => m.chatRoomId.equals(chatRoomId))
            ..orderBy([(m) => OrderingTerm.desc(m.sentAt)]))
          .watch();

  /// Stream only around selected message
  Stream<List<CachedMessage>> watchMessagesAround(
    String chatRoomId, {
    required int targetSentAt,
    int limit = 50,
  }) {
    print('================ Watch Mesages Around ===================');
    final half = limit ~/ 2;

    // Cannot combine 2 queries in .watch()
    return customSelect(
      'SELECT * FROM cached_messages '
      'WHERE chat_room_id = ? '
      'AND ('
      '  id IN ('
      '    SELECT id FROM cached_messages '
      '    WHERE chat_room_id = ? AND sent_at <= ? '
      '    ORDER BY sent_at DESC LIMIT ?'
      '  ) '
      '  OR id IN ('
      '    SELECT id FROM cached_messages '
      '    WHERE chat_room_id = ? AND sent_at > ? '
      '    ORDER BY sent_at ASC LIMIT ?'
      '  )'
      ') '
      'ORDER BY sent_at DESC',
      variables: [
        Variable.withString(chatRoomId),
        Variable.withString(chatRoomId),
        Variable.withInt(targetSentAt),
        Variable.withInt(half),
        Variable.withString(chatRoomId),
        Variable.withInt(targetSentAt),
        Variable.withInt(half),
      ],
      readsFrom: {cachedMessages},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => CachedMessage(
              id: row.read<String>('id'),
              chatRoomId: row.read<String>('chat_room_id'),
              messageText: row.read<String>('message_text'),
              textLower: row.read<String>('text_lower'),
              senderId: row.read<String>('sender_id'),
              senderName: row.read<String>('sender_name'),
              sentAt: row.read<int>('sent_at'),
              type: row.read<String>('type'),
              isDeleted: row.read<bool>('is_deleted'),
              deletedFor: row.read<String>('deleted_for'),
              replyToId: row.readNullable<String>('reply_to_id'),
              replyToText: row.readNullable<String>('reply_to_text'),
              replyToSender: row.readNullable<String>('reply_to_sender'),
              replyToSentAt: row.readNullable<int>('reply_to_sent_at'),
              mediaUrl: row.readNullable<String>('media_url'),
              fileName: row.readNullable<String>('file_name'),
              fileSizeBytes: row.readNullable<int>('file_size_bytes'),
              mimeType: row.readNullable<String>('mime_type'),
              mediaDuration: row.readNullable<int>('media_duration'),
              syncedAt: row.read<int>('synced_at'),
            ),
          )
          .toList(),
    );
  }

  /// Scroll above
  Future<List<CachedMessage>> fetchOlderMessages(
    String chatRoomId, {
    required int beforeSentAt,
    int limit = 50,
  }) =>
      (select(cachedMessages)
            ..where(
              (m) =>
                  m.chatRoomId.equals(chatRoomId) &
                  m.sentAt.isSmallerThanValue(beforeSentAt),
            )
            ..orderBy([(m) => OrderingTerm.desc(m.sentAt)])
            ..limit(limit))
          .get();

  /// Scroll down
  Future<List<CachedMessage>> fetchNewerMessages(
    String chatRoomId, {
    required int afterSentAt,
    int limit = 25,
  }) =>
      (select(cachedMessages)
            ..where(
              (m) =>
                  m.chatRoomId.equals(chatRoomId) &
                  m.sentAt.isBiggerThanValue(afterSentAt),
            )
            ..orderBy([(m) => OrderingTerm.asc(m.sentAt)])
            ..limit(limit))
          .get();

  /// Stream chat list
  Stream<List<CachedChatRoom>> watchChatRooms() => (select(
    cachedChatRooms,
  )..orderBy([(r) => OrderingTerm.desc(r.lastMessageSentAt)])).watch();

  Future<int> getLastSyncTimestamp(String chatId) async {
    final room = await (select(
      cachedChatRooms,
    )..where((r) => r.id.equals(chatId))).getSingleOrNull();
    return room?.lastSyncTimestamp ?? 0;
  }

  Future<CachedMessage?> getMessageByDateTime(String chatId, int sentAt) =>
      (select(cachedMessages)
            ..where((m) => m.chatRoomId.equals(chatId))
            ..where(
              (m) => m.sentAt.isBetweenValues(sentAt - 1000, sentAt + 1000),
            )
            ..orderBy([(m) => OrderingTerm.asc(m.sentAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> updateLastSync(String chatId, int timestamp) =>
      (update(cachedChatRooms)..where((r) => r.id.equals(chatId))).write(
        CachedChatRoomsCompanion(lastSyncTimestamp: Value(timestamp)),
      );

  Future<void> upsertChatRoom(CachedChatRoomsCompanion room) =>
      into(cachedChatRooms).insertOnConflictUpdate(room);

  // --- CLEANUP ---
  /// Mark a message as deleted (soft delete)
  Future<void> markDeleted(String messageId) =>
      (update(cachedMessages)..where((m) => m.id.equals(messageId))).write(
        CachedMessagesCompanion(isDeleted: Value(true)),
      );

  /// Delete all cached messages (for logout/account switch)
  Future<void> clearAll() => delete(cachedMessages).go();

  /// Delete all cached chat rooms when logout
  Future<void> clearAllChatRooms() => delete(cachedChatRooms).go();
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'kouvention.db'));

  // Get encryption key from secure storage
  final key = await DbKeyManager.getOrCreateKey();
  final escapedKey = key.replaceAll("'", "''");

  return NativeDatabase.createInBackground(
    file,
    isolateSetup: () async {
      // Migrate once: Delete old DB
      final marker = File('${file.path}.encrypted');
      if (await file.exists() && !await marker.exists()) {
        await file.delete();
        await marker.create();
      }
    },
    setup: (rawDb) {
      // ════════════════════════════════════════
      // Check: Do app access encrypted SQLite?
      // ════════════════════════════════════════
      assert(() {
        if (rawDb.select('PRAGMA cipher;').isEmpty) {
          throw StateError(
            'SQLite3MultipleCiphers not loaded! '
            'Make sure config exists in pubspec.yaml',
          );
        }
        return true;
      }());

      // ════════════════════════════════════════
      // SET ENCRYPTION KEY
      // ════════════════════════════════════════
      rawDb.execute("PRAGMA key = '$escapedKey';");
    },
  );
});

final messageDatabaseProvider = Provider<MessageDatabase>(
  (ref) => MessageDatabase(),
);
