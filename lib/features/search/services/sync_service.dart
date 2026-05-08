import 'package:drift/drift.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/search/services/databases/search_database.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(searchDatabaseProvider);
  final chatService = ref.read(chatServiceProvider);
  final prefsService = ref.read(prefsServiceProvider);
  return SyncService(db, chatService, prefsService);
});

class SyncService {
  final SearchDatabase _db;
  final ChatService _chatService;
  final PrefsService _prefsService;

  SyncService(this._db, this._chatService, this._prefsService);

  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  // Sync from ALL chat room x messages
  // Called on app launch
  Future<void> syncAllChatRooms({
    required String currentUid,
    required List<ChatModel> chatRooms,
  }) async {
    if (_isSyncing) return;
    _isSyncing = true;

    final since = _prefsService.lastSynced ?? DateTime(2020);

    debugPrint('🥷 Sync starting from: $since');
    debugPrint('🥷 Syncing ${chatRooms.length} chat rooms...');

    int totalSynced = 0;

    for (final chat in chatRooms) {
      try {
        final messages = await _chatService.fetchMessagesSince(
          chat.id,
          since: since,
        );

        if (messages.isEmpty) continue;

        // Convert MessageModel to CachedMessagesCompanion
        final companions = messages
            .map((msg) => _toCompanion(msg, chat.id, currentUid))
            .toList();

        await _db.upsertMessages(companions);
        totalSynced += companions.length;
        debugPrint('🥷 Synced ${messages.length} messages from ${chat.id}');
      } catch (e) {
        debugPrint('🥷 Sync failed for ${chat.id}: $e');
      }
    }

    _prefsService.lastSyncTime = DateTime.now();
    _isSyncing = false;

    debugPrint('🥷 Sync complete! Total: $totalSynced messages');
  }

  /// Wiped out all data when signout
  Future<void> clearAllData() async {
    await _db.clearAll();
    _prefsService.lastSyncTime = null;
    debugPrint('🥷 Search cache cleared');
  }

  // Real-time sync from sending message in Firestore
  // Convert and write batch messages in SQLite
  // Future<void> syncMessages({
  //   required List<MessageModel> messages,
  //   required String chatRoomId,
  //   required String currentUid,
  // }) async {
  //   if (messages.isEmpty) return;
  //   final sw = Stopwatch()..start();

  //   final companions = messages
  //       .map((m) => _toCompanion(m, chatRoomId, currentUid))
  //       .toList();

  //   await _db.upsertMessages(companions);

  //   sw.stop();
  //   debugPrint(
  //     '🥷 Syncing Message in Chat Room process took: ${sw.elapsedMilliseconds}ms',
  //   );
  // }

  CachedMessagesCompanion _toCompanion(
    MessageModel msg,
    String chatRoomId,
    String currentUid,
  ) => CachedMessagesCompanion(
    id: Value(msg.id),
    messageText: Value(msg.text),
    chatRoomId: Value(chatRoomId),
    senderId: Value(msg.senderId),
    senderName: Value(msg.senderName),
    textLower: Value(msg.text.toLowerCase()),
    isDeleted: Value(
      msg.isDeleted || (msg.deletedFor?.contains(currentUid) ?? false),
    ),
    sentAt: Value(msg.sentAt.millisecondsSinceEpoch),
    type: Value(msg.type),
    syncedAt: Value(DateTime.now().millisecondsSinceEpoch),
  );
}
