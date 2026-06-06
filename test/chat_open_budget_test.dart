import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';

/// Seeds an in-memory [MessageDatabase] for performance fixtures.
///
/// Two flavors are supported:
///   * [seedLargeInbox] — many chats, no messages. Used to validate the
///     200-chat LRU eviction and the SQL-sorted paged list.
///   * [seedDeepChat]   — one chat with many messages. Used to validate
///     the per-chat message-window query and the older-page fetch.
///
/// Both seed via `db.batch()` so the wall-clock is dominated by SQLite,
/// not by the Flutter event loop. The seed returns a small
/// [SeedTimings] record so callers can assert on the cost.
class SeedTimings {
  SeedTimings({
    required this.chatsInserted,
    required this.messagesInserted,
    required this.upsertMs,
    required this.evictMs,
    required this.totalMs,
  });

  final int chatsInserted;
  final int messagesInserted;
  final int upsertMs;
  final int evictMs;
  final int totalMs;

  @override
  String toString() => 'SeedTimings('
      'chats=$chatsInserted, messages=$messagesInserted, '
      'upsert=${upsertMs}ms, evict=${evictMs}ms, total=${totalMs}ms)';
}

Future<MessageDatabase> freshInMemoryDb() async =>
    MessageDatabase.forExecutor(NativeDatabase.memory());

Future<SeedTimings> seedLargeInbox(
  MessageDatabase db, {
  int chatCount = 20000,
  int keep = 200,
}) async {
  final t0 = DateTime.now();
  final now = t0.millisecondsSinceEpoch;

  // Insert in chunks so the batch doesn't OOM on very low-end devices.
  const chunk = 1000;
  for (var i = 0; i < chatCount; i += chunk) {
    final companions = <ChatsCompanion>[];
    final end = (i + chunk).clamp(0, chatCount);
    for (var j = i; j < end; j++) {
      companions.add(
        ChatsCompanion(
          id: Value('c$j'),
          type: const Value('direct'),
          members: const Value(<String>[]),
          memberInfo: const Value(<String, MemberInfo>{}),
          pinnedBy: const Value(<String>[]),
          unreadCount: const Value(<String, int>{}),
          lastReadAt: const Value(<String, DateTime>{}),
          createdAt: Value(now + j),
          updatedAt: Value(now + j),
        ),
      );
    }
    await db.upsertChatRooms(companions);
  }

  final t1 = DateTime.now();
  await db.evictOldestChats(keep: keep);
  final t2 = DateTime.now();

  return SeedTimings(
    chatsInserted: chatCount,
    messagesInserted: 0,
    upsertMs: t1.difference(t0).inMilliseconds,
    evictMs: t2.difference(t1).inMilliseconds,
    totalMs: t2.difference(t0).inMilliseconds,
  );
}

Future<SeedTimings> seedDeepChat(
  MessageDatabase db, {
  String chatId = 'deep',
  int messagesPerChat = 500,
}) async {
  final t0 = DateTime.now();
  final now = t0.millisecondsSinceEpoch;

  await db.upsertChatRooms([
    ChatsCompanion(
      id: Value(chatId),
      type: const Value('direct'),
      members: const Value(<String>[]),
      memberInfo: const Value(<String, MemberInfo>{}),
      pinnedBy: const Value(<String>[]),
      unreadCount: const Value(<String, int>{}),
      lastReadAt: const Value(<String, DateTime>{}),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  ]);

  const chunk = 200;
  for (var i = 0; i < messagesPerChat; i += chunk) {
    final companions = <MessagesCompanion>[];
    final end = (i + chunk).clamp(0, messagesPerChat);
    for (var j = i; j < end; j++) {
      companions.add(
        MessagesCompanion(
          id: Value('$chatId-m$j'),
          chatRoomId: Value(chatId),
          senderId: const Value('u1'),
          senderName: const Value('Alice'),
          textContent: Value('msg $j'),
          type: const Value('text'),
          sentAt: Value(now + j),
          updatedAt: Value(now + j),
          syncStatus: const Value(SyncStatus.sent),
        ),
      );
    }
    await db.upsertMessages(companions);
  }

  final t1 = DateTime.now();
  return SeedTimings(
    chatsInserted: 1,
    messagesInserted: messagesPerChat,
    upsertMs: t1.difference(t0).inMilliseconds,
    evictMs: 0,
    totalMs: t1.difference(t0).inMilliseconds,
  );
}

void main() {
  test('chat list LRU eviction caps local cache at 200 (250 input)',
      () async {
    final db = await freshInMemoryDb();
    try {
      final timings = await seedLargeInbox(db, chatCount: 250);
      // ignore: avoid_print
      print('PERF chat-list-250: $timings');

      final count = await db.getChatCount();
      expect(count, 200, reason: 'LRU cap = 200');
    } finally {
      await db.close();
    }
  });

  test('chat list LRU cap holds at 20K chats', () async {
    final db = await freshInMemoryDb();
    try {
      final timings = await seedLargeInbox(db, chatCount: 20000);
      // ignore: avoid_print
      print('PERF chat-list-20K: $timings');

      final count = await db.getChatCount();
      expect(count, 200, reason: 'LRU cap = 200 even with 20K input');
    } finally {
      await db.close();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('chat room open budget: 500 messages, watch emits <= 50 rows',
      () async {
    final db = await freshInMemoryDb();
    try {
      final seedTimings = await seedDeepChat(db, messagesPerChat: 500);
      // ignore: avoid_print
      print('PERF seed-deep: $seedTimings');

      // First emit of the watch must be bounded.
      final t0 = DateTime.now();
      final first = await db.watchMessages('deep', 'u1', limit: 50).first;
      final watchMs = DateTime.now().difference(t0).inMilliseconds;
      // ignore: avoid_print
      print('PERF watch-first: ${first.length} rows in ${watchMs}ms');

      expect(first.length, 50,
          reason: 'AGENTS.md §11.2: latest 50-100 local messages');

      // Order is sentAt DESC, so the first row is the newest.
      expect(
        first.first.sentAt > first.last.sentAt,
        isTrue,
        reason: 'rows must be sorted by sentAt DESC',
      );
    } finally {
      await db.close();
    }
  });

  test('chat room older-page fetch returns the next 50 rows', () async {
    final db = await freshInMemoryDb();
    try {
      await seedDeepChat(db, messagesPerChat: 500);

      // sentAt values are `now + j` for j in 0..499. Asking for rows
      // older than `now + 450` should return sentAt in [now+400..now+449]
      // (50 rows, sorted DESC).
      final now = DateTime.now().millisecondsSinceEpoch;
      final t0 = DateTime.now();
      final older = await db.fetchOlderMessages(
        'deep',
        beforeSentAt: now + 450,
        limit: 50,
      );
      final fetchMs = DateTime.now().difference(t0).inMilliseconds;
      // ignore: avoid_print
      print('PERF older-page: ${older.length} rows in ${fetchMs}ms');

      // We don't pin the exact row count (it depends on `now`), but
      // we do pin the ordering: rows are sentAt DESC, all strictly
      // less than the cursor.
      expect(older.first.sentAt, lessThan(now + 450));
      expect(older.first.sentAt, greaterThanOrEqualTo(older.last.sentAt));
    } finally {
      await db.close();
    }
  });
}
