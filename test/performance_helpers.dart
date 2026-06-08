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
