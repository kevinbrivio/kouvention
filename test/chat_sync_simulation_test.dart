import 'package:flutter_test/flutter_test.dart';
import 'performance_helpers.dart';

void main() {
  test(
    'full simulation: 20K chats synced, only 200 in local cache',
    () async {
      final db = await freshInMemoryDb();
      try {
        final t0 = DateTime.now();
        await seedLargeInbox(db, chatCount: 20000, keep: 200);
        final count = await db.getChatCount();
        expect(count, 200);
        final elapsed = DateTime.now().difference(t0).inMilliseconds;
        // ignore: avoid_print
        print('SIM 20K→200: $elapsed ms');
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'full simulation: open a 1000-message chat, first page bounded to 50',
    () async {
      final db = await freshInMemoryDb();
      try {
        await seedLargeInbox(db, chatCount: 20000, keep: 200);
        await seedDeepChat(db, messagesPerChat: 1000);

        await db.recomputeLocalMessageBounds('deep');
        await db.updateChatSyncState(
          chatId: 'deep',
          hasMoreOlderRemote: true,
        );

        final t0 = DateTime.now();
        final firstPage = await db
            .watchMessages('deep', 'u1', limit: 100)
            .first;
        final watchMs = DateTime.now().difference(t0).inMilliseconds;
        expect(firstPage.length, 50,
            reason: 'first page must be bounded to 50');

        final oldestInPage = firstPage.last.sentAt;
        final t1 = DateTime.now();
        final olderPage = await db.fetchOlderMessages(
          'deep',
          beforeSentAt: oldestInPage,
          limit: 50,
        );
        final fetchMs = DateTime.now().difference(t1).inMilliseconds;
        expect(olderPage.length, 50,
            reason: 'older page must return 50 rows');
        for (final m in olderPage) {
          expect(m.sentAt, lessThan(oldestInPage),
              reason: 'older page messages must be older than first-page tail');
        }

        // ignore: avoid_print
        print(
          'SIM open-1000: watch=50 in ${watchMs}ms, fetch=50 in ${fetchMs}ms',
        );
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'full simulation: scroll through all 1000 messages in 50-message pages',
    () async {
      final db = await freshInMemoryDb();
      try {
        await seedLargeInbox(db, chatCount: 20000, keep: 200);
        await seedDeepChat(db, messagesPerChat: 1000);

        await db.recomputeLocalMessageBounds('deep');
        await db.updateChatSyncState(
          chatId: 'deep',
          hasMoreOlderRemote: true,
        );

        final latest = await db
            .watchMessages('deep', 'u1', limit: 100)
            .first;
        int total = latest.length;
        int cursor = latest.last.sentAt;
        int pageCount = 1;

        final t0 = DateTime.now();

        while (true) {
          final page = await db.fetchOlderMessages(
            'deep',
            beforeSentAt: cursor,
            limit: 50,
          );
          if (page.isEmpty) break;

          expect(page.length, lessThanOrEqualTo(50),
              reason: 'each page must be ≤ 50');

          for (final m in page) {
            expect(m.sentAt, lessThan(cursor),
                reason:
                    'each message must be older than the cursor ($cursor)');
          }

          for (var i = 0; i < page.length - 1; i++) {
            expect(page[i].sentAt, greaterThan(page[i + 1].sentAt),
                reason:
                    'page $pageCount must be in descending sentAt order');
          }

          total += page.length;
          cursor = page.last.sentAt;
          pageCount++;
        }

        final elapsed = DateTime.now().difference(t0).inMilliseconds;
        expect(pageCount, 20,
            reason: '1000 messages / 50 per page = 20 pages');
        expect(total, 1000,
            reason: 'all 1000 messages must be accounted for');

        // ignore: avoid_print
        print(
          'SIM scroll-1000: $total messages in $pageCount pages, ${elapsed}ms total',
        );
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
