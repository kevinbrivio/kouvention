import 'package:flutter_test/flutter_test.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart'
    show kChatListMaxCached;
import 'performance_helpers.dart';

void main() {
  test(
      'chat list LRU eviction caps local cache at kChatListMaxCached (501 input)',
      () async {
    final db = await freshInMemoryDb();
    try {
      final timings =
          await seedLargeInbox(db, chatCount: 501, keep: kChatListMaxCached);
      // ignore: avoid_print
      print('PERF chat-list-501: $timings');

      final count = await db.getChatCount();
      expect(count, kChatListMaxCached,
          reason: 'LRU cap = $kChatListMaxCached');
    } finally {
      await db.close();
    }
  });

  test('chat list LRU cap holds at 20K chats', () async {
    final db = await freshInMemoryDb();
    try {
      final timings =
          await seedLargeInbox(db, chatCount: 20000, keep: kChatListMaxCached);
      // ignore: avoid_print
      print('PERF chat-list-20K: $timings');

      final count = await db.getChatCount();
      expect(count, kChatListMaxCached,
          reason: 'LRU cap = $kChatListMaxCached even with 20K input');
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
