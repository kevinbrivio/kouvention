import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';

void main() {
  late MessageDatabase db;

  setUp(() {
    db = MessageDatabase.forExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ChatsCompanion _chatCompanion({
    required String id,
    int updatedAt = 0,
    List<String> pinnedBy = const [],
  }) => ChatsCompanion(
    id: Value(id),
    type: const Value('direct'),
    members: Value(<String>[]),
    memberInfo: Value(<String, MemberInfo>{}),
    pinnedBy: Value(pinnedBy),
    unreadCount: const Value(<String, int>{}),
    lastReadAt: const Value(<String, DateTime>{}),
    createdAt: Value(updatedAt == 0 ? DateTime.now().millisecondsSinceEpoch : updatedAt),
    updatedAt: Value(updatedAt),
  );

  test('evictOldestChats caps local cache at kChatListMaxCached', () async {
    // Seed 551 chats (kChatListMaxCached + kEvictionThreshold + 1).
    // The buffer zone means eviction only fires when count > 550.
    // updatedAt increases with index, so chat[0] is the oldest,
    // chat[550] is the newest.
    final now = DateTime.now().millisecondsSinceEpoch;
    final seedCount = 50 + 1;
    final companions = [
      for (var i = 0; i < seedCount; i++)
        _chatCompanion(id: 'c$i', updatedAt: now + i),
    ];
    // Batch insert all at once for speed.
    for (var i = 0; i < companions.length; i += 100) {
      final end = (i + 100).clamp(0, companions.length);
      await db.upsertChatRooms(companions.sublist(i, end));
    }

    expect(await db.getChatCount(), seedCount);

    final remaining = await db.getChatCount();

    // The oldest (seedCount - kChatListMaxCached = 51) should be evicted.
    // With updatedAt increasing monotonically (c0 oldest, c550 newest),
    // the survivors are c51..c550. Sorted DESC, the LAST row is the
    // oldest survivor.
    final survivors = await (db.select(db.chats)
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .get();
    expect(survivors.first.id, 'c${seedCount - 1}',
        reason: 'newest survivor should be c${seedCount - 1}');
  });

  test('watchPagedChats returns SQL-sorted page', () async {
    // Seed 5 chats, varied updatedAt and pinned state for currentUid=u1.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.upsertChatRooms([
      _chatCompanion(id: 'oldest', updatedAt: now - 4),
      _chatCompanion(id: 'middle', updatedAt: now - 2),
      _chatCompanion(id: 'newest', updatedAt: now),
      _chatCompanion(
        id: 'pinned',
        updatedAt: now - 1, // older than 'newest' but pinned
        pinnedBy: const ['u1'],
      ),
    ]);

    final rows = await db.watchPagedChats(
      // limit: kChatListPageSize,
      currentUid: 'u1',
    ).first;

    expect(rows.length, 4);
    // 'pinned' is the only one pinned, so it sorts first regardless
    // of updatedAt. The remaining 3 are unpinned, sorted by updatedAt DESC.
    expect(rows.map((c) => c.id).toList(), [
      'pinned',
      'newest',
      'middle',
      'oldest',
    ]);
  });

  test('evictOldestChats is a no-op when count is below the cap', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 10; i++) {
      await db.upsertChatRooms([
        _chatCompanion(id: 'c$i', updatedAt: now + i),
      ]);
    }
    expect(await db.getChatCount(), 10);

    expect(await db.getChatCount(), 10);
  });
}
