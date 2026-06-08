import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:kouvention/features/chat/services/databases/message_database.dart';
import '../test/performance_helpers.dart';

/// Opens a real encrypted file DB on-device at [tmpDir / fileName].
/// Cleans up any previous file at the same path.
Future<MessageDatabase> _openDeviceDb({
  required String fileName,
  required Directory tmpDir,
}) async {
  final file = File('${tmpDir.path}/$fileName');
  if (file.existsSync()) await file.delete();

  return MessageDatabase.forExecutor(
    NativeDatabase(
      file,
      setup: (sqlite3.Database db) {
        // Attempt encryption (sqlite3mc). Silently fall back to unencrypted
        // if the native library doesn't support it (e.g. desktop CI).
        try {
          db.execute("PRAGMA key = 'test-perf-key';");
        } catch (_) {
          // ignore: avoid_print
          print('WARN: sqlite3mc encryption not available — '
              'running unencrypted');
        }
        db.execute('PRAGMA cache_size = -64000;');
        db.execute('PRAGMA synchronous = NORMAL;');
      },
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await getTemporaryDirectory();
  });

  group('on-device scaling performance — encrypted file DB', () {
    testWidgets('seed 20K chats + evict to 200', (tester) async {
      final db = await _openDeviceDb(fileName: 'perf_20k.db', tmpDir: tmpDir);
      try {
        final timings = await seedLargeInbox(db, chatCount: 20000, keep: 200);
        // ignore: avoid_print
        print(
          'DEVICE 20K→200: ${timings.totalMs}ms '
          '(upsert=${timings.upsertMs}ms, evict=${timings.evictMs}ms)',
        );
        expect(await db.getChatCount(), 200);
      } finally {
        await db.close();
        final f = File('${tmpDir.path}/perf_20k.db');
        if (f.existsSync()) await f.delete();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets(
      'open deep chat with 1K messages — first page bounded to 50',
      (tester) async {
        final db = await _openDeviceDb(
          fileName: 'perf_deep.db',
          tmpDir: tmpDir,
        );
        try {
          await seedLargeInbox(db, chatCount: 20000, keep: 200);
          await seedDeepChat(db, messagesPerChat: 1000);

          await db.recomputeLocalMessageBounds('deep');

          final t0 = DateTime.now();
          final first = await db.watchMessages('deep', 'u1', limit: 50).first;
          final watchMs = DateTime.now().difference(t0).inMilliseconds;
          expect(first.length, 50);

          final oldest = first.last.sentAt;
          final t1 = DateTime.now();
          final older = await db.fetchOlderMessages(
            'deep',
            beforeSentAt: oldest,
            limit: 50,
          );
          final fetchMs = DateTime.now().difference(t1).inMilliseconds;
          expect(older.length, 50);

          // ignore: avoid_print
          print(
            'DEVICE open-1000: watch=50 in ${watchMs}ms, '
            'fetch=50 in ${fetchMs}ms',
          );
        } finally {
          await db.close();
          final f = File('${tmpDir.path}/perf_deep.db');
          if (f.existsSync()) await f.delete();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'scroll through all 1K messages in 50-msg pages',
      (tester) async {
        final db = await _openDeviceDb(
          fileName: 'perf_scroll.db',
          tmpDir: tmpDir,
        );
        try {
          await seedLargeInbox(db, chatCount: 20000, keep: 200);
          await seedDeepChat(db, messagesPerChat: 1000);

          await db.recomputeLocalMessageBounds('deep');

          final latest = await db.watchMessages('deep', 'u1', limit: 50).first;
          int total = latest.length;
          int cursor = latest.last.sentAt;
          int pages = 1;

          final t0 = DateTime.now();
          while (true) {
            final page = await db.fetchOlderMessages(
              'deep',
              beforeSentAt: cursor,
              limit: 50,
            );
            if (page.isEmpty) break;
            total += page.length;
            cursor = page.last.sentAt;
            pages++;
          }
          final elapsed = DateTime.now().difference(t0).inMilliseconds;

          expect(pages, 20);
          expect(total, 1000);

          // ignore: avoid_print
          print(
            'DEVICE scroll-1000: $total msgs in $pages pages, '
            '${elapsed}ms total',
          );
        } finally {
          await db.close();
          final f = File('${tmpDir.path}/perf_scroll.db');
          if (f.existsSync()) await f.delete();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
