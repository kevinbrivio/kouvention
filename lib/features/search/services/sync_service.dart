import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/cached_messages.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(messageDatabaseProvider);
  final chatService = ref.read(chatServiceProvider);
  final prefsService = ref.read(prefsServiceProvider);
  return SyncService(db, chatService, prefsService);
});

class SyncService {
  final MessageDatabase _db;
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

    int totalSynced = 0;

    final sw = Stopwatch()..start();

    for (final chat in chatRooms) {
      try {
        await syncChatRoom(currentUid, chat);

        final lastSync = await _db.getLastSyncTimestamp(chat.id);

        debugPrint(
          '🥷 Sync starting from: ${DateTime.fromMillisecondsSinceEpoch(lastSync)}',
        );
        debugPrint('🥷 Syncing ${chatRooms.length} chat rooms...');

        List<MessageModel> messages;
        if (lastSync == 0) {
          messages = await _chatService.fetchAllMessages(chat.id);
        } else {
          final since = DateTime.fromMillisecondsSinceEpoch(lastSync);

          messages = await _chatService.fetchMessagesSince(
            chat.id,
            since: since,
          );
        }

        if (messages.isNotEmpty) {
          final companions = messages
              .map((m) => _toCompanion(m, chat.id, currentUid))
              .toList();
          await _db.upsertMessages(companions);
          totalSynced += companions.length;
        }

        // update last sync time
        await _db.updateLastSync(
          chat.id,
          DateTime.now().millisecondsSinceEpoch,
        );

        debugPrint('🥷 Synced ${messages.length} messages from ${chat.id}');
      } catch (e) {
        debugPrint('🥷 Sync failed for ${chat.id}: $e');
      }
    }

    sw.stop();

    // _prefsService.lastSyncTime = DateTime.now();
    _isSyncing = false;

    debugPrint(
      '🥷 Syncing Message in Chat Room process took: ${sw.elapsedMilliseconds}ms',
    );
    debugPrint('🥷 Sync complete! Total: $totalSynced messages');
  }

  Future<void> syncChatRoom(String currentUid, ChatModel chat) async {
    final companion = CachedChatRoomsCompanion(
      id: Value(chat.id),
      name: Value(chat.displayName(currentUid)),
      type: Value(chat.type),
      members: Value(jsonEncode(chat.members)),
      memberInfo: Value(
        jsonEncode(chat.memberInfo.map((k, v) => MapEntry(k, v.toMap()))),
      ),
      lastMessageText: Value(chat.lastMessage?.text ?? ''),
      lastMessageSender: Value(chat.lastMessage?.sentBy ?? ''),
      lastMessageSentAt: Value(
        chat.lastMessage?.sentAt.millisecondsSinceEpoch ?? 0,
      ),
      unreadCount: Value(jsonEncode(chat.unreadCount)),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );

    await _db.upsertChatRoom(companion);
  }

  Future<void> syncChatRooms(String currentUid, List<ChatModel> chats) async {
    for (final chat in chats) {
      await syncChatRoom(currentUid, chat);
    }
  }

  Future<void> syncSingleChat(
    String currentUid,
    String chatId,
    int lastSync,
  ) async {
    final since = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final messages = await _chatService.fetchMessagesSince(
      chatId,
      since: since,
    );

    if (messages.isNotEmpty) {
      await _db.upsertMessages(
        messages.map((m) => _toCompanion(m, chatId, currentUid)).toList(),
      );
    }

    // update last sync
    await _db.updateLastSync(chatId, DateTime.now().millisecondsSinceEpoch);
  }

  /// Wiped out all data when signout
  Future<void> clearAllData() async {
    await _db.clearAll();
    await _db.clearAllChatRooms();
    _prefsService.lastSyncTime = null;
    debugPrint('🥷 Search cache cleared');
  }

  CachedMessagesCompanion _toCompanion(
    MessageModel msg,
    String chatRoomId,
    String currentUid,
  ) => CachedMessagesCompanion(
    id: Value(msg.id),
    chatRoomId: Value(chatRoomId),
    messageText: Value(msg.text),
    textLower: Value(msg.text.toLowerCase()),
    senderId: Value(msg.senderId),
    senderName: Value(msg.senderName),
    sentAt: Value(msg.sentAt.millisecondsSinceEpoch),
    type: Value(msg.type.name),
    isDeleted: Value(msg.isDeleted),
    deletedFor: Value(jsonEncode(msg.deletedFor)),
    replyToId: Value(msg.replyTo?.messageId),
    replyToText: Value(msg.replyTo?.text),
    replyToSender: Value(msg.replyTo?.senderName),
    mediaUrls: Value(jsonEncode(msg.allMediaUrls)),
    fileName: Value(msg.fileName),
    fileSizeBytes: Value(msg.fileSizeBytes),
    syncedAt: Value(DateTime.now().millisecondsSinceEpoch),
  );
}
