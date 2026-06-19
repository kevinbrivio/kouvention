import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';

/// Single owner of per-message I/O for view models. Wraps [SyncService]
/// for message writes, [ChatService] for chat-metadata writes that ride
/// along with messages (typing, read receipts), and [MessageDatabase] for
/// the local Drift `watchMessages*` queries.
///
/// `ChatRoomVM` and any future message-sending UI no longer import
/// `SyncService` or `ChatService` directly — they go through this
/// repository.
class MessageRepository {
  MessageRepository({
    required SyncService sync,
    required ChatService chatService,
    required MessageDatabase db,
  }) : _sync = sync,
       _chatService = chatService,
       _db = db;

  final SyncService _sync;
  final ChatService _chatService;
  final MessageDatabase _db;

  /// Reactive local watch around a target `sentAt` (jump-to-message).
  Stream<List<Message>> watchLocalMessagesAround(
    String chatId, {
    required int targetSentAt,
    int limit = 100,
  }) =>
      _db.watchMessagesAround(chatId, targetSentAt: targetSentAt, limit: limit);

  /// Watch all messages from local
  Stream<List<Message>> watchAllCachedMessages(
    String chatId,
    String currentUid,
  ) => _db.watchAllCachedMessages(chatId, currentUid);

  // --- Read: remote sync -----------------------------

  /// One-shot fetch of the latest [limit] messages for a chat. Used by
  /// the search VM to show recent messages from contact-matched chats.
  Future<List<Message>> fetchRecentMessages(String chatId, {int limit = 20}) =>
      _db.fetchRecentMessages(chatId, limit: limit);

  /// Fetches every message newer than the chat's `latestSeenRemoteAt`
  /// in bounded pages. Returns a summary `{pages, messages}`.
  Future<({int pages, int messages})> fetchMissedMessages(String chatId) =>
      _sync.fetchMissedMessagesBounded(chatId);

  /// Fetches one older page using the 4-field sync state. Returns
  /// `{pages, messages}` — `messages == 0` means "we've reached the
  /// beginning of the chat".
  Future<({int pages, int messages})> fetchOlderMessages(
    String chatId, {
    int limit = 50,
    int maxPages = 1,
  }) => _sync.fetchOlderMessages(chatId, limit: limit, maxPages: maxPages);

  /// Loads a window of messages around [sentAt] (used by the
  /// jump-to-message path).
  Future<void> fetchMessagesAround(String chatId, DateTime sentAt) =>
      _sync.fetchMessagesAround(chatId, sentAt);

  // --- Read: realtime -------------------------------

  /// Live Firestore listener for a single active chat. Upserts each
  /// emission into Drift; the local Drift watch in turn re-emits to
  /// the UI. The upsert is what reconciles locally-pending rows whose
  /// `messageId` arrives as a server echo (AGENTS.md §7 rule 7).
  Stream<void> watchActiveChatRealtime(String chatId) =>
      _sync.streamFirestoreMessages(chatId);

  // --- Write: send -----------------------------------

  Future<void> sendTextMessage({
    required String chatRoomId,
    required String textContent,
    required String senderName,
    required List<String> memberUids,
    Map<String, dynamic>? otherUserFcmTokens,
    ReplyToModel? replyTo,
  }) => _sync.sendMessage(
    chatRoomId: chatRoomId,
    textContent: textContent,
    senderName: senderName,
    memberUids: memberUids,
    otherUserFcmTokens: otherUserFcmTokens,
    replyTo: replyTo,
  );

  Future<void> sendSticker({
    required String chatRoomId,
    required String stickerUrl,
    required String senderName,
    required List<String> memberUids,
    Map<String, dynamic>? otherUserFcmTokens,
    ReplyToModel? replyTo,
  }) => _sync.sendSticker(
    chatRoomId: chatRoomId,
    stickerUrl: stickerUrl,
    senderName: senderName,
    memberUids: memberUids,
    otherUserFcmTokens: otherUserFcmTokens,
    replyTo: replyTo,
  );

  Future<void> sendMediaMessage({
    required String chatRoomId,
    required List<File> files,
    required MessageType type,
    String? caption,
    required String senderName,
    required List<String> memberUids,
    Map<String, dynamic>? otherUserFcmTokens,
    ReplyToModel? replyTo,
  }) => _sync.sendMediaMessage(
    chatRoomId: chatRoomId,
    files: files,
    type: type,
    caption: caption,
    senderName: senderName,
    memberUids: memberUids,
    otherUserFcmTokens: otherUserFcmTokens,
    replyTo: replyTo,
  );

  Future<void> sendMediaMessageDirect({
    required String chatRoomId,
    required List<UploadResultModel> uploadResults,
    required MessageType type,
    required String caption,
    required String senderName,
    required List<String> memberUids,
    List<String>? mediaCaptions,
    Map<String, dynamic>? otherUserFcmTokens,
    ReplyToModel? replyTo,
  }) => _sync.sendMediaMessageDirect(
    chatRoomId: chatRoomId,
    uploadResults: uploadResults,
    type: type,
    caption: caption,
    senderName: senderName,
    memberUids: memberUids,
    mediaCaptions: mediaCaptions,
    otherUserFcmTokens: otherUserFcmTokens,
    replyTo: replyTo,
  );

  // --- Write: read receipts / typing -----------------

  /// Marks a chat as read. The single write to Firestore resets
  /// `unreadCount.$uid` and advances `lastReadAt.$uid` atomically
  /// (AGENTS.md §9.8).
  Future<void> markChatAsRead(String chatId, String uid) =>
      _chatService.markChatAsRead(chatId, uid);

  /// Sets the typing flag for the current user in the given chat.
  Future<void> setTyping(String chatId, String uid) =>
      _chatService.setTyping(chatId, uid);

  Future<void> clearTyping(String chatId, String uid) =>
      _chatService.clearTyping(chatId, uid);

  // --- Delete ----------------------------------------

  Future<void> deleteMessageForMe({
    required String chatId,
    required List<String> messageIds,
  }) => _sync.deleteMessageForMe(chatId: chatId, messageIds: messageIds);

  Future<void> deleteMessageForEveryone({
    required String chatId,
    required List<String> messageIds,
  }) => _sync.deleteMessageForEveryone(chatId: chatId, messageIds: messageIds);
}

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(
    sync: ref.watch(syncServiceProvider),
    chatService: ref.watch(chatServiceProvider),
    db: ref.watch(messageDatabaseProvider),
  );
});
