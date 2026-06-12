import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/recent_users_provider.dart';

/// End-to-end test: extract UIDs from a real Drift database.
///
/// Proves the recent_users_provider reads from Drift (not Firestore)
/// by seeding a `MessageDatabase` with chats, then running the same
/// extraction logic the provider uses. No Firestore, no auth, no
/// mocks — the only dependency is SQLite-in-memory.
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
    required String type,
    required List<String> members,
    int updatedAt = 0,
    String? lastSentBy,
    int? lastSentAt,
  }) {
    return ChatsCompanion(
      id: Value(id),
      type: Value(type),
      members: Value(members),
      memberInfo: Value({
        for (final m in members) m: MemberInfo(displayName: 'User $m'),
      }),
      pinnedBy: const Value(<String>[]),
      unreadCount: const Value(<String, int>{}),
      lastReadAt: const Value(<String, DateTime>{}),
      createdAt: Value(updatedAt),
      updatedAt: Value(updatedAt),
      lastMessage: (lastSentBy != null && lastSentAt != null)
          ? Value(
              LastMessage(
                text: 'hi',
                sentBy: lastSentBy,
                sentAt: DateTime.fromMillisecondsSinceEpoch(lastSentAt),
              ),
            )
          : const Value.absent(),
    );
  }

  test('extracts direct-chat UIDs from Drift', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.upsertChatRooms([
      _chatCompanion(
        id: 'c1',
        type: 'direct',
        members: const ['me', 'alice'],
        updatedAt: now,
      ),
      _chatCompanion(
        id: 'c2',
        type: 'direct',
        members: const ['me', 'bob'],
        updatedAt: now - 1,
      ),
    ]);

    final rows = await db.fetchPagedChats(limit: 20, currentUid: 'me');
    final chats = rows.map(chatModelFromDriftRow).toList();
    final uids = extractRecentUids(chats: chats, currentUid: 'me');

    expect(uids, ['alice', 'bob']);
  });

  test('extracts group-chat sentBy from Drift', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.upsertChatRooms([
      _chatCompanion(
        id: 'g1',
        type: 'group',
        members: const ['me', 'alice', 'bob', 'carol'],
        updatedAt: now,
        lastSentBy: 'carol',
        lastSentAt: now,
      ),
    ]);

    final rows = await db.fetchPagedChats(limit: 20, currentUid: 'me');
    final chats = rows.map(chatModelFromDriftRow).toList();
    final uids = extractRecentUids(chats: chats, currentUid: 'me');

    expect(uids, ['carol']);
  });

  test('respects the recency order from Drift (updated_at DESC)', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.upsertChatRooms([
      _chatCompanion(
        id: 'oldest',
        type: 'direct',
        members: const ['me', 'carol'],
        updatedAt: now - 100,
      ),
      _chatCompanion(
        id: 'newest',
        type: 'direct',
        members: const ['me', 'alice'],
        updatedAt: now,
      ),
      _chatCompanion(
        id: 'middle',
        type: 'direct',
        members: const ['me', 'bob'],
        updatedAt: now - 50,
      ),
    ]);

    final rows = await db.fetchPagedChats(limit: 20, currentUid: 'me');
    final chats = rows.map(chatModelFromDriftRow).toList();
    final uids = extractRecentUids(chats: chats, currentUid: 'me');

    // fetchPagedChats orders by updated_at DESC, then id DESC.
    expect(uids, ['alice', 'bob', 'carol']);
  });

  test('caps at 20 even when more chats exist in Drift', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final companions = <ChatsCompanion>[
      for (var i = 0; i < 30; i++)
        _chatCompanion(
          id: 'c$i',
          type: 'direct',
          members: ['me', 'u$i'],
          updatedAt: now + i,
        ),
    ];
    // Batch insert
    for (var i = 0; i < companions.length; i += 50) {
      final end = (i + 50).clamp(0, companions.length);
      await db.upsertChatRooms(companions.sublist(i, end));
    }

    final rows = await db.fetchPagedChats(limit: 20, currentUid: 'me');
    final chats = rows.map(chatModelFromDriftRow).toList();
    final uids = extractRecentUids(chats: chats, currentUid: 'me');

    expect(uids.length, 20);
  });

  test('skips chats where current user is not a member', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.upsertChatRooms([
      _chatCompanion(
        id: 'unrelated',
        type: 'direct',
        members: const ['alice', 'bob'], // me is missing
        updatedAt: now,
      ),
    ]);

    final rows = await db.fetchPagedChats(limit: 20, currentUid: 'me');
    final chats = rows.map(chatModelFromDriftRow).toList();
    final uids = extractRecentUids(chats: chats, currentUid: 'me');

    // fetchPagedChats may return the row (its filter is on pinnedBy, not
    // members), but the resolver drops it because the current user is
    // not in the members list. This is the defensive path that prevents
    // a corrupted Drift row from crashing the screen.
    expect(uids, isEmpty);
  });
}
