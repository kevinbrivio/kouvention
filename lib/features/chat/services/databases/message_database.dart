import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/services/db_key_manager.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

part 'message_database.g.dart';

enum SyncStatus { pending, sent, failed }

// ===============================
// Table Chats
// ===============================
@TableIndex(name: 'idx_chats_updated_id', columns: {#updatedAt, #id})
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

  BoolColumn get hasReachedBeginning =>
      boolean().withDefault(const Constant(false))();

  // Deprecated. The 4-field sync state below (`latestSeenRemoteAt`,
  // `oldestCachedAt`, `hasMoreOlderRemote`, `hasLocalGap`) is now the sole
  // cursor (AGENTS.md §8). The column is kept for the v1→v2 migration that
  // backfilled it into `latest_seen_remote_at`; new code must not write to
  // it. Remove in a future v3 migration.
  IntColumn get lastSyncTimestamp => integer().withDefault(const Constant(0))();

  IntColumn get latestSeenRemoteAt =>
      integer().withDefault(const Constant(0))();
  IntColumn get oldestCachedAt => integer().withDefault(const Constant(0))();
  BoolColumn get hasMoreOlderRemote =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get hasLocalGap => boolean().withDefault(const Constant(false))();

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
  TextColumn get mediaUrls => text()
      .map(const StringListConverter())
      .nullable()(); // Saved url in cloud
  TextColumn get mediaCaptions =>
      text().map(const StringListConverter()).nullable()();
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

  /// Test-only constructor. Pass an in-memory [QueryExecutor] (e.g.
  /// `NativeDatabase.memory()`) to avoid touching the real encrypted
  /// database file. The Phase 7 performance fixtures in `test/` rely on
  /// this to seed 20,000 chats and 500-message chats in seconds.
  MessageDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      print('🛠️ [DATABASE] Membuat tabel baru dari nol!');
      await m.createAll();

      await customStatement('''
        CREATE VIRTUAL TABLE messages_fts USING fts5(
          message_id UNINDEXED,
          text_content,
          sender_name,
          tokenize='unicode61'
        );
      ''');

      await customStatement('''
        CREATE TRIGGER after_message_insert
        AFTER INSERT ON messages
        BEGIN
          INSERT INTO messages_fts(message_id, text_content, sender_name)
          VALUES (new.id, new.text_content, new.sender_name);
        END;
      ''');

      await customStatement('''
        CREATE TRIGGER after_message_update
        AFTER UPDATE OF text_content ON messages
        BEGIN
          UPDATE messages_fts
          SET text_content = new.text_content
          WHERE message_id = new.id;
        END;
      ''');

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
      print('🛠️ [DATABASE] Migrasi dari v$from ke v$to');
      await customStatement('PRAGMA foreign_keys = OFF');

      if (from < 2) {
        await m.addColumn(chats, chats.latestSeenRemoteAt);
        await m.addColumn(chats, chats.oldestCachedAt);
        await m.addColumn(chats, chats.hasMoreOlderRemote);
        await m.addColumn(chats, chats.hasLocalGap);

        await customStatement(
          'UPDATE chats SET latest_seen_remote_at = last_sync_timestamp',
        );
      }
    },

    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA cache_size = -64000;');
    },
  );

  // ===========================
  // Search using FTS5
  // ===========================
  Future<List<Message>> searchMessages(
    String keyword,
    String currentUid, {
    int limit = 50,
  }) async {
    if (keyword.trim().isEmpty) return [];

    final cleaned = keyword.replaceAll(RegExp(r'["*^()~:+\[\]]'), ' ');
    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (tokens.isEmpty) return [];
    final ftsQuery = tokens.map((t) => '$t*').join(' ');

    // Query A: FTS5
    final rawSql = '''
      SELECT m.* FROM messages m
      INNER JOIN messages_fts f ON m.id = f.message_id
      WHERE f.messages_fts MATCH ?
        AND m.is_deleted = 0
        AND m.deleted_for NOT LIKE ?
      ORDER BY m.sent_at DESC
      LIMIT ?
    ''';

    final uidLikeParam = '%"$currentUid"%';

    final rows = await customSelect(
      rawSql,
      variables: [
        Variable.withString(ftsQuery),
        Variable.withString(uidLikeParam),
        Variable.withInt(limit),
      ],
    ).get();

    return rows.map((row) => messages.map(row.data)).toList();

    // final ftsRows = await customSelect(
    //   'SELECT message_id FROM messages_fts WHERE messages_fts MATCH ?',
    //   variables: [Variable.withString(ftsQuery)],
    // ).get();
    // if (ftsRows.isEmpty) return [];

    // final ids = ftsRows.map((r) => r.data['message_id'] as String).toList();

    // // Query B: Simple PK lookup — no JOIN, no FTS5
    // final results =
    //     await (select(messages)
    //           ..where((m) => m.id.isIn(ids))
    //           ..where((m) => m.isDeleted.equals(false))
    //           ..where((m) => m.deletedFor.like('%"$currentUid"%').not()))
    //         .get();

    // results.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    // return results.take(limit).toList();
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
  Stream<List<Message>> watchMessages(
    String chatRoomId,
    String currentUid, {
    int limit = 50,
  }) =>
      (select(messages)
            ..where((m) => m.chatRoomId.equals(chatRoomId))
            ..where((m) => m.deletedFor.like('%"$currentUid"%').not())
            ..orderBy([(m) => OrderingTerm.desc(m.sentAt)])
            ..limit(limit))
          .watch();

  /// Unbounded watch. **Deprecated** — kept only for legacy callers and tests.
  /// The chat list screen must use [watchPagedChats] or [fetchPagedChats] instead.
  Stream<List<Chat>> watchChatRooms() =>
      (select(chats)..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])).watch();

  /// Reactive, bounded, SQL-sorted chat list page.
  ///
  /// Pinned chats (for [currentUid]) come first, then by [updatedAt] DESC with
  /// [id] DESC as a stable tie-breaker. Bounded to [limit] rows.
  ///
  /// [typeFilter] is the literal `'direct'` or `'group'`. Pass `null` for all.
  Stream<List<Chat>> watchPagedChats({
    required int limit,
    int offset = 0,
    String? typeFilter,
    String? currentUid,
  }) {
    final typeClause = typeFilter != null ? 'AND type = ?' : '';
    final pinnedOrder = currentUid != null
        ? "CASE WHEN pinned_by LIKE ? THEN 0 ELSE 1 END"
        : "0";

    final sql = '''
      SELECT * FROM chats
      WHERE 1=1 $typeClause
      ORDER BY $pinnedOrder, updated_at DESC, id DESC
      LIMIT ? OFFSET ?
    ''';

    final variables = <Variable<Object>>[];
    if (typeFilter != null) {
      variables.add(Variable.withString(typeFilter));
    }
    if (currentUid != null) {
      variables.add(Variable.withString('%"$currentUid"%'));
    }
    variables.add(Variable.withInt(limit));
    variables.add(Variable.withInt(offset));

    return customSelect(
      sql,
      variables: variables,
      readsFrom: {chats},
    ).watch().map((rows) => rows.map((row) => chats.map(row.data)).toList());
  }

  /// One-shot variant of [watchPagedChats]. Used by `loadMore` so the second
  /// and subsequent pages are appended to the first page without the first
  /// page re-emit stealing focus.
  Future<List<Chat>> fetchPagedChats({
    required int limit,
    int offset = 0,
    String? typeFilter,
    String? currentUid,
  }) async {
    final typeClause = typeFilter != null ? 'AND type = ?' : '';
    final pinnedOrder = currentUid != null
        ? "CASE WHEN pinned_by LIKE ? THEN 0 ELSE 1 END"
        : "0";

    final sql = '''
      SELECT * FROM chats
      WHERE 1=1 $typeClause
      ORDER BY $pinnedOrder, updated_at DESC, id DESC
      LIMIT ? OFFSET ?
    ''';

    final variables = <Variable<Object>>[];
    if (typeFilter != null) {
      variables.add(Variable.withString(typeFilter));
    }
    if (currentUid != null) {
      variables.add(Variable.withString('%"$currentUid"%'));
    }
    variables.add(Variable.withInt(limit));
    variables.add(Variable.withInt(offset));

    final rows = await customSelect(
      sql,
      variables: variables,
      readsFrom: {chats},
    ).get();
    return rows.map((row) => chats.map(row.data)).toList();
  }

  Future<int> getChatCount() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS cnt FROM chats',
      readsFrom: {chats},
    ).getSingle();
    return row.read<int>('cnt');
  }

  /// LRU eviction: keep the [keep] most recently updated chats in local cache.
  /// Returns the number of rows deleted.
  Future<int> evictOldestChats({required int keep}) async {
    final count = await getChatCount();
    if (count <= keep) return 0;

    final toDeleteCount = count - keep;
    final toDelete = await customSelect(
      'SELECT id FROM chats ORDER BY updated_at ASC LIMIT ?',
      variables: [Variable.withInt(toDeleteCount)],
      readsFrom: {chats},
    ).get();

    if (toDelete.isEmpty) return 0;

    final ids = toDelete.map((r) => r.read<String>('id')).toList();
    return (delete(chats)..where((c) => c.id.isIn(ids))).go();
  }

  Future<Map<String, Chat>> getChatsByIds(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await (select(chats)..where((c) => c.id.isIn(ids))).get();
    return {for (final c in rows) c.id: c};
  }

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
  }) => (update(messages)..where((m) => m.id.equals(messageId))).write(
    MessagesCompanion(
      syncStatus: Value(SyncStatus.sent),
      mediaUrls: Value(cloudUrls),
      fileSizeBytes: Value(fileSizeBytes),
      mimeType: Value(mimeType),
      fileName: Value(fileName),
    ),
  );

  Future<void> updateLatestSeenRemoteAt(String chatId, int timestamp) =>
      (update(chats)..where((c) => c.id.equals(chatId))).write(
        ChatsCompanion(latestSeenRemoteAt: Value(timestamp)),
      );

  Future<void> updateChatSyncState({
    required String chatId,
    int? latestSeenRemoteAt,
    int? oldestCachedAt,
    bool? hasMoreOlderRemote,
    bool? hasLocalGap,
  }) {
    final companion = ChatsCompanion(
      latestSeenRemoteAt: latestSeenRemoteAt != null
          ? Value(latestSeenRemoteAt)
          : const Value.absent(),
      oldestCachedAt: oldestCachedAt != null
          ? Value(oldestCachedAt)
          : const Value.absent(),
      hasMoreOlderRemote: hasMoreOlderRemote != null
          ? Value(hasMoreOlderRemote)
          : const Value.absent(),
      hasLocalGap: hasLocalGap != null
          ? Value(hasLocalGap)
          : const Value.absent(),
    );
    return (update(chats)..where((c) => c.id.equals(chatId))).write(companion);
  }

  Future<void> recomputeLocalMessageBounds(String chatId) async {
    final row = await customSelect(
      'SELECT MIN(sent_at) AS min_sent, MAX(sent_at) AS max_sent, COUNT(*) AS cnt '
      'FROM messages WHERE chat_room_id = ?',
      variables: [Variable.withString(chatId)],
      readsFrom: {messages},
    ).getSingleOrNull();

    if (row == null) {
      await updateChatSyncState(
        chatId: chatId,
        oldestCachedAt: 0,
        hasMoreOlderRemote: true,
      );
      return;
    }

    final minSent = row.data['min_sent'] as int? ?? 0;
    final count = row.data['cnt'] as int? ?? 0;

    await updateChatSyncState(
      chatId: chatId,
      oldestCachedAt: minSent,
      hasMoreOlderRemote: true,
    );
  }

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
    final existing = await (select(
      chats,
    )..where((c) => c.id.equals(chatId))).getSingleOrNull();
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
    final existing = await (select(
      chats,
    )..where((c) => c.id.equals(chatId))).getSingleOrNull();
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
    final existing = await (select(
      chats,
    )..where((c) => c.id.equals(chatId))).getSingleOrNull();
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
    // The 5-minute gate stops the retry loop from racing the in-flight
    // initial send. Pending rows newer than 5 min are assumed to still be
    // trying. Once the gate passes, the retry calls the transaction-guarded
    // flush (see SyncService.flushPendingMessage), which is safe to call
    // even if the message already exists in Firestore.
    final fiveMinutesAgo = DateTime.now()
        .subtract(const Duration(minutes: 5))
        .millisecondsSinceEpoch;

    return (select(messages)
          ..where(
            (m) =>
                m.syncStatus.equals(SyncStatus.pending.name) |
                m.syncStatus.equals(SyncStatus.failed.name),
          )
          ..where((m) => m.sentAt.isSmallerThanValue(fiveMinutesAgo)))
        .get();
  }

  Future<List<Chat>> getAllChatRooms(String currentUid) =>
      (select(chats)..where((c) => c.memberInfo.contains(currentUid))).get();

  Future<List<Message>> getRecentMediaMessages({int limit = 10}) async {
    final imageType = MessageType.image.name;
    final videoType = MessageType.video.name;
    return (select(messages)
          ..where((m) => m.type.isIn([imageType, videoType]))
          ..where((m) => m.mediaUrls.isNotNull())
          ..orderBy([(m) => OrderingTerm.desc(m.sentAt)])
          ..limit(limit))
        .get();
  }
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
  final markerFile = File(p.join(dbFolder.path, '.encrypted_db'));

  if (!await markerFile.exists() && await file.exists()) {
    await file.delete();
  }

  await markerFile.create(recursive: true);
  final key = await DbKeyManager.getOrCreateKey();

  return NativeDatabase(
    file,
    setup: (sqlite3.Database db) {
      db.execute("PRAGMA key = '$key';");
    },
  );
});

final messageDatabaseProvider = Provider<MessageDatabase>(
  (ref) => MessageDatabase(),
);
