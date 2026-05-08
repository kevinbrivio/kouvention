import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'search_database.g.dart';

class CachedMessages extends Table {
  // PK
  TextColumn get id => text()();

  TextColumn get chatRoomId => text()();

  TextColumn get messageText => text()();

  TextColumn get textLower => text()();

  TextColumn get senderId => text()();

  TextColumn get senderName => text()();

  // Timestamp stored as int (SQLite doesn't have Timestamp)
  IntColumn get sentAt => integer()();

  TextColumn get type => text().withDefault(const Constant('text'))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  IntColumn get syncedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedMessages])
class SearchDatabase extends _$SearchDatabase {
  SearchDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
  Future<List<CachedMessage>> searchMessages({
    required String query,
    required List<String> chatRoomIds,
    int limit = 50,
  }) {
    final lowerQuery = query.toLowerCase();

    return (select(cachedMessages)
          ..where(
            (m) =>
                m.textLower.like('%$lowerQuery%') &
                m.isDeleted.equals(false) &
                m.chatRoomId.isIn(chatRoomIds),
          )
          ..orderBy([(m) => OrderingTerm.desc(m.sentAt)])
          ..limit(limit))
        .get();
  }

  // --- CLEANUP ---
  /// Mark a message as deleted (soft delete)
  Future<void> markDeleted(String messageId) =>
      (update(cachedMessages)..where((m) => m.id.equals(messageId))).write(
        CachedMessagesCompanion(isDeleted: Value(true)),
      );

  /// Delete all cached messages (for logout/account switch)
  Future<void> clearAll() => delete(cachedMessages).go();
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'kouvention_search.db'));
  return NativeDatabase.createInBackground(file);
});

final searchDatabaseProvider = Provider<SearchDatabase>(
  (ref) => SearchDatabase(),
);
