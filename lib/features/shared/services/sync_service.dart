import 'dart:convert';
import 'dart:io';

import 'package:kouvention/cores/utils/id_generator.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:kouvention/features/chat/services/media/cloud_media_service.dart';
import 'package:kouvention/features/chat/utils/message_label.dart';
import 'package:kouvention/features/notification/services/notification_service.dart';

MessagesCompanion messageToCompanion(
  MessageModel msg,
  String chatRoomId,
  SyncStatus status,
) => MessagesCompanion(
  id: Value(msg.id),
  chatRoomId: Value(chatRoomId),
  textContent: Value(msg.text),

  type: Value(msg.type.name),
  sentAt: Value(msg.sentAt.millisecondsSinceEpoch),
  updatedAt: Value(msg.updatedAt.millisecondsSinceEpoch),

  syncStatus: Value(status),

  senderId: Value(msg.senderId),
  senderName: Value(msg.senderName),

  replyToId: Value(msg.replyTo?.messageId),
  replyToText: Value(msg.replyTo?.text),
  replyToSenderName: Value(msg.replyTo?.senderName),
  replyToMediaType: Value(msg.replyTo?.mediaType),
  replyToMediaUrl: Value(msg.replyTo?.mediaUrl),
  replyToSentAt: Value(msg.replyTo?.sentAt.millisecondsSinceEpoch),

  isDeleted: Value(msg.isDeleted),
  deletedFor: Value(msg.deletedFor),

  mimeType: Value(msg.mimeType),
  mediaDuration: Value(msg.mediaDuration),
  fileName: Value(msg.fileName),
  fileSizeBytes: Value(msg.fileSizeBytes),
  mediaUrls: Value(msg.mediaUrls),
  localPath: Value(null), // Firestore doesn't know about local path at all
  mediaGroupId: Value(msg.mediaGroupId),
);

class SyncService {
  final MessageDatabase _db;
  final ChatService _chatService;
  final CloudMediaService _mediaService; // Upload to Cloudinary
  final NotificationService _notificationService; // Send FCM
  final String? _currentUid;

  SyncService(
    this._db,
    this._chatService,
    this._mediaService,
    this._notificationService,
    this._currentUid,
  );

  // ============================
  // Sync Chat Rooms after Login
  // ============================
  Future<void> syncInitialChatRooms(String currentUid) async {
    final sw = Stopwatch()..start();

    debugPrint(
      ' ================== [Start Sync Chats] ========================',
    );

    final List<ChatModel> chatRooms = await _chatService.fetchChatRooms(
      currentUid,
    );

    debugPrint(
      ' ========= [Fetching from Firestore done!] Took: ${sw.elapsedMilliseconds} ms =========',
    );

    final existingLocalRooms = await _db.getAllChatRooms(currentUid);

    // The 4-field sync state (see AGENTS.md §8) is the sole cursor. The
    // v1→v2 migration backfilled `latest_seen_remote_at` from
    // `last_sync_timestamp`; once a user is on v2 we never read the legacy
    // column again.
    final latestSeenRemoteAtMap = {
      for (var room in existingLocalRooms) room.id: room.latestSeenRemoteAt,
    };

    List<ChatsCompanion> companions;

    if (chatRooms.length < 100) {
      print('Chat list length: ${chatRooms.length}');
      companions = chatRooms.map((chat) {
        return chatToCompanion(
          chat,
          latestSeenRemoteAt: latestSeenRemoteAtMap[chat.id],
        );
      }).toList();
    } else {
      companions = chatRooms.map(chatToCompanion).toList();
    }

    await _db.upsertChatRooms(companions);

    debugPrint(
      ' ========= [Everything is done] Total testing time: ${sw.elapsedMilliseconds} ms =======',
    );

    sw.stop();
  }

  static ChatsCompanion chatToCompanion(
    ChatModel chat, {
    int? latestSeenRemoteAt,
  }) => ChatsCompanion(
    id: Value(chat.id),
    type: Value(chat.type),
    groupName: Value(chat.groupName),
    groupPhotoUrl: Value(chat.groupPhotoUrl),

    members: Value(chat.members),
    memberInfo: Value(chat.memberInfo),
    pinnedBy: Value(chat.pinnedBy),
    unreadCount: Value(chat.unreadCount),
    lastReadAt: Value(chat.lastReadAt),
    lastMessage: Value(chat.lastMessage),

    createdAt: Value(chat.createdAt.millisecondsSinceEpoch),
    updatedAt: Value(chat.updatedAt?.millisecondsSinceEpoch),

    deletedBy: Value(
      chat.deletedBy != null
          ? jsonEncode(
              chat.deletedBy!.map(
                (k, v) =>
                    MapEntry(k, v is Timestamp ? v.millisecondsSinceEpoch : v),
              ),
            )
          : null,
    ),
    createdBy: Value(chat.createdBy),

    // The 4-field sync state is the sole cursor (AGENTS.md §8). The legacy
    // `lastSyncTimestamp` column is left untouched — it stays at the value
    // copied by the v1→v2 migration.
    latestSeenRemoteAt: Value(latestSeenRemoteAt ?? 0),
  );

  Future<void> fetchMessagesAround(
    String chatId,
    DateTime aroundTimestamp,
  ) async {
    final messages = await _chatService.fetchMessageAround(
      chatId,
      aroundTimestamp: aroundTimestamp,
      limit: 50,
    );
    if (messages.isEmpty) return;

    final companions = messages
        .map((m) => messageToCompanion(m, chatId, SyncStatus.sent))
        .toList();

    await _db.upsertMessages(companions);

    await _db.updateChatSyncState(
      chatId: chatId,
      latestSeenRemoteAt: messages.first.sentAt.millisecondsSinceEpoch,
      hasLocalGap: false,
    );
  }

  Future<void> fetchMessages(String chatId) async {
    await fetchMissedMessagesBounded(chatId);
  }

  /// Fetches every message newer than the chat's [latestSeenRemoteAt] in
  /// pages, until either the server returns less than a full page or
  /// [maxPages] is reached. The 4-field sync state is the sole cursor
  /// (AGENTS.md §8).
  ///
  /// If the server keeps returning full pages at [maxPages], the local
  /// cache is marked with `hasLocalGap = true` so a follow-up fetch can
  /// finish the job — we never silently leave the cache behind the server.
  Future<({int pages, int messages})> fetchMissedMessagesBounded(
    String chatId, {
    int limit = 50,
    int maxPages = 20,
  }) async {
    final chatRoom = await _db.getChatById(chatId);
    int cursor = chatRoom?.latestSeenRemoteAt ?? 0;

    int pagesFetched = 0;
    int totalInserted = 0;
    bool hitMaxPages = false;

    while (pagesFetched < maxPages) {
      final page = await _chatService.fetchMessages(
        chatId,
        lastSyncTimestamp: DateTime.fromMillisecondsSinceEpoch(cursor),
        limit: limit,
      );

      if (page.isEmpty) break;

      final companions = page
          .map((m) => messageToCompanion(m, chatId, SyncStatus.sent))
          .toList();
      await _db.upsertMessages(companions);

      final newest = page.first.sentAt.millisecondsSinceEpoch;
      if (newest <= cursor) break;

      cursor = newest;
      pagesFetched++;
      totalInserted += page.length;

      if (page.length < limit) break;
    }

    hitMaxPages = pagesFetched >= maxPages && totalInserted > 0;

    await _db.updateChatSyncState(
      chatId: chatId,
      latestSeenRemoteAt: cursor,
      hasLocalGap: hitMaxPages,
    );

    if (totalInserted > 0) {
      await _db.recomputeLocalMessageBounds(chatId);
    }

    return (pages: pagesFetched, messages: totalInserted);
  }

  /// Fetches the next page of messages OLDER than the local cache for one
  /// chat. Used by `ChatRoomVM.loadOlderMessages` when the user scrolls
  /// up past the locally-cached window and the 4-field sync state
  /// (`hasMoreOlderRemote`) is still `true`.
  ///
  /// Each call:
  ///   1. Reads the local chat row from Drift to get `oldestCachedAt`.
  ///   2. Returns immediately if `hasMoreOlderRemote == false`.
  ///   3. Asks `ChatService.fetchOlderMessagesPage` for one older page
  ///      (`startAfter` on `sentAt DESC`, `limit = [limit]`).
  ///   4. Upserts the page into Drift.
  ///   5. Updates the 4-field sync state: `oldestCachedAt = min(sentAt)`,
  ///      `hasMoreOlderRemote` flipped off the moment the server returns
  ///      a short or empty page.
  ///
  /// Returns the number of messages inserted (0 means "we've reached
  /// the beginning of the chat, stop scrolling").
  Future<({int pages, int messages})> fetchOlderMessages(
    String chatId, {
    int limit = 100,
    int maxPages = 2,
  }) async {
    final chatRoom = await _db.getChatById(chatId);
    if (chatRoom == null) {
      debugPrint('fetchOlderMessages: chat $chatId missing locally — skip');
      return (pages: 0, messages: 0);
    }
    if (!chatRoom.hasMoreOlderRemote) {
      return (pages: 0, messages: 0);
    }

    int pagesFetched = 0;
    int totalInserted = 0;
    int cursor = chatRoom.oldestCachedAt;
    bool serverExhausted = false;

    while (pagesFetched < maxPages) {
      if (cursor <= 0) {
        serverExhausted = true;
        break;
      }

      final page = await _chatService.fetchOlderMessagesPage(
        chatId: chatId,
        beforeSentAt: cursor,
        limit: limit,
      );

      if (page.isEmpty) {
        // Server has nothing older than the cursor.
        serverExhausted = true;
        break;
      }

      final companions = page
          .map((m) => messageToCompanion(m, chatId, SyncStatus.sent))
          .toList();
      await _db.upsertMessages(companions);

      final oldest = page.first.sentAt.millisecondsSinceEpoch;
      pagesFetched++;
      totalInserted += page.length;

      // Cursor must strictly advance; if it didn't, bail to avoid an
      // infinite loop (shouldn't happen with startAfter on a unique
      // timestamp, but the guard is cheap).
      if (oldest <= 0 || oldest >= cursor) {
        serverExhausted = true;
        cursor = oldest > 0 ? oldest : 0;
        break;
      }
      cursor = oldest;

      if (page.length < limit) {
        // Short page = the server has no more rows after this one.
        serverExhausted = true;
        break;
      }
    }

    await _db.updateChatSyncState(
      chatId: chatId,
      oldestCachedAt: cursor,
      hasMoreOlderRemote: !serverExhausted,
    );

    if (totalInserted > 0) {
      await _db.recomputeLocalMessageBounds(chatId);
    }

    return (pages: pagesFetched, messages: totalInserted);
  }

  /// Subscribes to a single chat's messages newer than the local
  /// [latestSeenRemoteAt]. Each emission is upserted into Drift, which
  /// also reconciles any locally `pending` row whose `messageId` matches
  /// the realtime echo (the upsert updates `syncStatus` to `sent` — see
  /// §7 rule 7).
  Stream<void> streamFirestoreMessages(String chatId) async* {
    var retryDelay = 1;

    while (true) {
      try {
        final chatRoom = await _db.getChatById(chatId);
        // 4-field sync state is the sole cursor (AGENTS.md §8).
        int latestSeen = chatRoom?.latestSeenRemoteAt ?? 0;

        yield* _chatService
            .streamMessagesSince(
              chatId,
              DateTime.fromMillisecondsSinceEpoch(latestSeen),
            )
            .asyncMap((newMessages) async {
              if (newMessages.isEmpty) return;

              // messageToCompanion passes SyncStatus.sent for every echo.
              // _db.upsertMessages uses insertOnConflictUpdate, so a
              // locally-pending row with the same messageId is reconciled
              // to `sent` here (AGENTS.md §7 rule 7).
              final companions = newMessages
                  .map((m) => messageToCompanion(m, chatId, SyncStatus.sent))
                  .toList();

              await _db.upsertMessages(companions);

              final newest = newMessages.first;
              final latestMsgTime = newest.sentAt.millisecondsSinceEpoch;
              await _db.updateChatSyncState(
                chatId: chatId,
                latestSeenRemoteAt: latestMsgTime,
                hasLocalGap: false,
              );

              final label = lastMessageLabel(
                newest.text,
                newest.type,
                newest.fileName ?? '',
              );
              await _db.updateChatLastMessage(
                chatId,
                LastMessage(
                  text: label,
                  sentBy: newest.senderId,
                  sentAt: newest.sentAt,
                  type: newest.type.name,
                ),
              );
            });

        break;
      } catch (e) {
        debugPrint(
          '⚠️ streamFirestoreMessages error for $chatId: $e, '
          'retrying in ${retryDelay}s',
        );
        await Future.delayed(Duration(seconds: retryDelay));
        retryDelay = (retryDelay * 2).clamp(1, 30);
      }
    }
  }

  // ==========================================
  // SEND TEXT MESSAGE
  // ==========================================
  Future<void> sendMessage({
    required String chatRoomId,
    required String textContent,
    required String senderName,
    required List<String> memberUids,
    Map<String, dynamic>? otherUserFcmTokens,
    ReplyToModel? replyTo,
  }) async {
    // Generate Temp ID
    final tempId = IdGenerator.generateId();
    final now = DateTime.now();

    // Wrap in MessageModel
    final localMessage = MessageModel(
      id: tempId,
      senderId: _currentUid!,
      senderName: senderName,
      text: textContent,
      sentAt: now,
      updatedAt: now,
      isDeleted: false,
      syncStatus: SyncStatus.pending,
      replyTo: replyTo,
    );

    // Show to UI
    await _db.upsertMessage(
      messageToCompanion(localMessage, chatRoomId, SyncStatus.pending),
    );

    // Update to Firestore (in background)
    _sendMessageInBackground(
      localMessage: localMessage,
      chatRoomId: chatRoomId,
      memberUids: memberUids,
      otherUserFcmTokens: otherUserFcmTokens,
    );
  }

  // ==========================================
  // SEND MEDIA MESSAGE
  // ==========================================
  Future<void> sendMediaMessage({
    required String chatRoomId,
    required List<File> files,
    required MessageType type,
    String? caption,
    required String senderName,
    required List<String> memberUids,
    Map<String, dynamic>? otherUserFcmTokens,
    ReplyToModel? replyTo,
  }) async {
    final tempId = IdGenerator.generateId();
    final now = DateTime.now();

    final localMsg = MessagesCompanion(
      id: Value(tempId),
      chatRoomId: Value(chatRoomId),
      senderId: Value(_currentUid!),
      senderName: Value(senderName),
      textContent: Value(caption ?? ''),
      type: Value(type.name),
      sentAt: Value(now.millisecondsSinceEpoch),
      updatedAt: Value(now.millisecondsSinceEpoch),
      syncStatus: Value(SyncStatus.pending),
      localPath: Value(files.first.path),
      mediaUrls: Value(null),
      mediaGroupId: Value(null),
      replyToId: Value(replyTo?.messageId),
      replyToText: Value(replyTo?.text),
      replyToSenderName: Value(replyTo?.senderName),
    );

    await _db.upsertMessage(localMsg);

    _processMediaUploadsInBackground(
      tempId: tempId,
      sentAt: now,
      files: files,
      chatRoomId: chatRoomId,
      type: type,
      caption: caption ?? '',
      senderName: senderName,
      memberUids: memberUids,
      otherUserFcmTokens: otherUserFcmTokens,
      replyTo: replyTo,
    );
  }

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
  }) async {
    final tempId = IdGenerator.generateId();
    final now = DateTime.now();

    final allUrls = uploadResults.map((r) => r.url).toList();
    final allCaptions =
        mediaCaptions ?? uploadResults.map((r) => r.caption ?? '').toList();
    final first = uploadResults.first;

    final localMsg = MessagesCompanion(
      id: Value(tempId),
      chatRoomId: Value(chatRoomId),
      senderId: Value(_currentUid!),
      senderName: Value(senderName),
      textContent: Value(caption),
      type: Value(type.name),
      sentAt: Value(now.millisecondsSinceEpoch),
      updatedAt: Value(now.millisecondsSinceEpoch),
      syncStatus: Value(SyncStatus.sent),
      localPath: Value(first.localPath),
      mediaUrls: Value(allUrls),
      mediaCaptions: Value(allCaptions),
      mediaGroupId: Value(null),
      replyToId: Value(replyTo?.messageId),
      replyToText: Value(replyTo?.text),
      replyToSenderName: Value(replyTo?.senderName),
      replyToMediaType: Value(replyTo?.mediaType),
      replyToMediaUrl: Value(replyTo?.mediaUrl),
      replyToSentAt: Value(replyTo?.sentAt.millisecondsSinceEpoch),
    );

    await _db.upsertMessage(localMsg);

    await _chatService.sendMediaMessage(
      chatId: chatRoomId,
      messageId: tempId,
      text: caption,
      type: type,
      senderId: _currentUid,
      senderName: senderName,
      mediaUrls: allUrls,
      mediaCaptions: allCaptions,
      mediaDuration: first.mediaDuration,
      mimeType: first.mimeType,
      fileSizeBytes: first.fileSizeBytes,
      sentAt: now,
      memberUids: memberUids,
      replyTo: replyTo,
      fileName: first.fileName,
    );

    await _db.updateMediaMessageSuccess(
      tempId,
      allUrls,
      fileName: first.fileName,
      fileSizeBytes: first.fileSizeBytes,
      mimeType: first.mimeType,
    );

    await _db.updateChatLastMessage(
      chatRoomId,
      LastMessage(
        text: lastMessageLabel(caption, type, first.fileName),
        sentBy: _currentUid,
        sentAt: now,
        type: type.name,
      ),
    );

    await _sendFcmToRecipients(
      otherUserFcmTokens: otherUserFcmTokens,
      chatRoomId: chatRoomId,
      senderId: _currentUid,
      senderName: senderName,
      messageText: fcmLabel(caption, type, mediaCount: uploadResults.length),
      isGroup: memberUids.length > 2,
    );
  }

  Future<void> _processMediaUploadsInBackground({
    required String tempId,
    required DateTime sentAt,
    required List<File> files,
    required String chatRoomId,
    required MessageType type,
    required String caption,
    required String senderName,
    required List<String> memberUids,
    Map<String, dynamic>? otherUserFcmTokens,
    required ReplyToModel? replyTo,
  }) async {
    try {
      final results = await Future.wait(
        files.map(
          (file) => _mediaService.uploadFile(file: file, mediaType: type),
        ),
      );

      final uploaded = results.whereType<UploadResultModel>().toList();
      if (uploaded.isEmpty) throw Exception('All uploads failed');

      final allUrls = uploaded.map((r) => r.url).toList();

      await _chatService.sendMediaMessage(
        chatId: chatRoomId,
        messageId: tempId,
        text: caption,
        type: type,
        senderId: _currentUid!,
        senderName: senderName,
        mediaUrls: allUrls,
        mediaDuration: uploaded.first.mediaDuration,
        mimeType: uploaded.first.mimeType,
        fileSizeBytes: uploaded.first.fileSizeBytes,
        sentAt: sentAt,
        memberUids: memberUids,
        replyTo: replyTo,
        fileName: files.first.path.split('/').last,
      );

      final fileName = files.first.path.split('/').last;
      await _db.updateMediaMessageSuccess(
        tempId,
        allUrls,
        fileName: fileName,
        fileSizeBytes: uploaded.first.fileSizeBytes,
        mimeType: uploaded.first.mimeType,
      );

      await _db.updateChatLastMessage(
        chatRoomId,
        LastMessage(
          text: lastMessageLabel(caption, type, fileName),
          sentBy: _currentUid,
          sentAt: sentAt,
          type: type.name,
        ),
      );

      await _sendFcmToRecipients(
        otherUserFcmTokens: otherUserFcmTokens,
        chatRoomId: chatRoomId,
        senderId: _currentUid,
        senderName: senderName,
        messageText: fcmLabel(caption, type, mediaCount: files.length),
        isGroup: memberUids.length > 2,
      );
    } catch (e) {
      debugPrint('🚨 Failed media upload for $tempId: $e');
      await _db.updateMessageStatus(tempId, SyncStatus.failed);
    }
  }

  Future<void> _sendMessageInBackground({
    required MessageModel localMessage,
    required String chatRoomId,
    required List<String> memberUids,
    Map<String, dynamic>? otherUserFcmTokens,
  }) async {
    try {
      await _chatService.sendMessage(
        chatId: chatRoomId,
        memberUids: memberUids,
        messageId: localMessage.id,
        senderId: localMessage.senderId,
        senderName: localMessage.senderName,
        text: localMessage.text,
        sentAt: localMessage.sentAt,
        replyTo: localMessage.replyTo,
      );

      // Update status in local
      await _db.updateMessageStatus(localMessage.id, SyncStatus.sent);

      await _db.updateChatLastMessage(
        chatRoomId,
        LastMessage(
          text: localMessage.text,
          sentBy: localMessage.senderId,
          sentAt: localMessage.sentAt,
          type: MessageType.text.name,
        ),
      );

      await _sendFcmToRecipients(
        otherUserFcmTokens: otherUserFcmTokens,
        chatRoomId: chatRoomId,
        senderId: localMessage.senderId,
        senderName: localMessage.senderName,
        messageText: localMessage.text,
        isGroup: memberUids.length > 2,
      );
    } catch (e) {
      await _db.updateMessageStatus(localMessage.id, SyncStatus.failed);
      debugPrint('Failed sending message: $e');
    }
  }

  Future<void> sendSticker({
    required String chatRoomId,
    required String stickerUrl,
    required String senderName,
    required List<String> memberUids,
    Map<String, dynamic>? otherUserFcmTokens,
    ReplyToModel? replyTo,
  }) async {
    final tempId = IdGenerator.generateId();
    final now = DateTime.now();

    final localMsg = MessagesCompanion(
      id: Value(tempId),
      chatRoomId: Value(chatRoomId),
      senderId: Value(_currentUid!),
      senderName: Value(senderName),
      textContent: Value(''),
      type: Value(MessageType.sticker.name),
      sentAt: Value(now.millisecondsSinceEpoch),
      updatedAt: Value(now.millisecondsSinceEpoch),
      syncStatus: Value(SyncStatus.sent),
      mediaUrls: Value([stickerUrl]),
      mimeType: Value('image/gif'),
      fileName: Value('sticker.gif'),
      fileSizeBytes: Value(0),
      replyToId: Value(replyTo?.messageId),
      replyToSenderName: Value(replyTo?.senderName),
      replyToSentAt: Value(replyTo?.sentAt.millisecondsSinceEpoch),
      replyToText: Value(replyTo?.text),
      replyToMediaType: Value(replyTo?.mediaType),
      replyToMediaUrl: Value(replyTo?.mediaUrl),
    );

    await _db.upsertMessage(localMsg);

    try {
      await _chatService.sendMediaMessage(
        chatId: chatRoomId,
        messageId: tempId,
        text: 'Sticker',
        type: MessageType.sticker,
        senderId: _currentUid,
        senderName: senderName,
        mediaUrls: [stickerUrl],
        mimeType: 'image/gif',
        fileSizeBytes: 0,
        fileName: 'sticker.gif',
        sentAt: now,
        memberUids: memberUids,
        replyTo: replyTo,
      );

      await _db.updateChatLastMessage(
        chatRoomId,
        LastMessage(
          text: 'Sticker',
          sentBy: _currentUid,
          sentAt: now,
          type: MessageType.sticker.name,
        ),
      );
  
      await _sendFcmToRecipients(
        chatRoomId: chatRoomId,
        messageText: 'Sticker',
        senderId: _currentUid,
        senderName: senderName,
        isGroup: memberUids.length > 2,
        otherUserFcmTokens: otherUserFcmTokens,
      );
    } catch (e) {
      await _db.updateMessageStatus(tempId, SyncStatus.failed);
      rethrow;
    }
  }

  Future<void> _sendFcmToRecipients({
    required Map<String, dynamic>? otherUserFcmTokens,
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String messageText,
    bool isGroup = false,
  }) async {
    if (otherUserFcmTokens == null || otherUserFcmTokens.isEmpty) {
      debugPrint('[SyncService] _sendFcmToRecipients: no tokens to send to');
      return;
    }

    debugPrint(
      '[SyncService] Sending FCM to ${otherUserFcmTokens.length} token(s)',
    );
    debugPrint('[SyncService] Sending FCM with Message: $messageText');

    final senderPhotoUrl = FirebaseAuth.instance.currentUser?.photoURL;

    for (final entry in otherUserFcmTokens.entries) {
      final token = entry.key;
      try {
        await _notificationService.sendChatNotification(
          targetToken: token,
          messageText: messageText,
          chatId: chatRoomId,
          senderId: senderId,
          senderName: senderName,
          senderImageUrl: senderPhotoUrl,
          isGroup: isGroup,
        );
        debugPrint(
          '[SyncService] FCM sent to token: ${token.substring(0, 20)}...',
        );
      } catch (e) {
        debugPrint('[SyncService] FCM send failed for token: $e');
      }
    }
  }

  // ===========================================
  // RETRY SENDING MESSAGE AFTER NO CONNECTION
  // ==========================================
  /// Sweeps every locally `pending` or `failed` message older than the
  /// 5-min gate and re-flushes it. Called by the connectivity-resume
  /// handler (`networkAutoSyncProvider`) when the device comes back
  /// online, so a queue of unsent messages replays deterministically.
  ///
  /// Each call is idempotent because the underlying [ChatService.sendMessage]
  /// is transaction-guarded (§6 / §7). Retries, realtime echoes, and
  /// concurrent devices all converge to the same Firestore state.
  Future<void> retryStuckMessages() async {
    final stuckMessages = await _db.getStuckPendingMessages();
    if (stuckMessages.isEmpty) return;

    debugPrint('🔁 Retrying ${stuckMessages.length} stuck message(s)');

    for (final msg in stuckMessages) {
      await flushPendingMessage(msg);
    }
  }

  /// Re-flushes a single pending or failed message.
  ///
  /// The local row's `messageId` and `sentAt` are reused (deterministic
  /// identity, §6). The transaction in [ChatService.sendMessage] reads
  /// `chats/{chatId}/messages/{messageId}` first:
  ///   * if it exists, the transaction is a no-op;
  ///   * else it writes the message + chat metadata + unread bump
  ///     atomically, with the **client** `sentAt` (never
  ///     `FieldValue.serverTimestamp()`).
  ///
  /// Either path leaves the message in Firestore. The local row goes from
  /// `pending`/`failed` to `sent` regardless, so this method is safe to
  /// call from retry loops, from the connectivity-resume handler, and
  /// from a periodic background task.
  ///
  /// Media messages that failed at the Cloudinary upload step have no
  /// `mediaUrls` in Drift; without a successful upload there is nothing
  /// to re-send, so we skip them. The row stays `failed` until the user
  /// manually re-attaches the media.
  Future<void> flushPendingMessage(Message msg) async {
    final hasMediaUrls =
        msg.mediaUrls != null && msg.mediaUrls!.isNotEmpty;
    if (msg.type != MessageType.text.name && !hasMediaUrls) {
      return;
    }

    try {
      final chat = await _db.getChatById(msg.chatRoomId);
      if (chat == null) {
        debugPrint(
          'flushPendingMessage: chat ${msg.chatRoomId} missing locally — '
          'skipping ${msg.id}',
        );
        return;
      }
      final memberUids = chat.members;
      final sentAt = DateTime.fromMillisecondsSinceEpoch(msg.sentAt);
      final replyTo = _replyToFromDrift(msg);

      if (msg.type == MessageType.text.name) {
        await _chatService.sendMessage(
          chatId: msg.chatRoomId,
          messageId: msg.id,
          senderId: msg.senderId,
          senderName: msg.senderName,
          text: msg.textContent,
          sentAt: sentAt,
          memberUids: memberUids,
          replyTo: replyTo,
        );
      } else {
        await _chatService.sendMediaMessage(
          chatId: msg.chatRoomId,
          messageId: msg.id,
          senderId: msg.senderId,
          senderName: msg.senderName,
          text: msg.textContent,
          type: MessageType.fromString(msg.type),
          mediaUrls: msg.mediaUrls!,
          mediaCaptions: msg.mediaCaptions,
          fileName: msg.fileName ?? '',
          fileSizeBytes: msg.fileSizeBytes ?? 0,
          mimeType: msg.mimeType ?? '',
          mediaDuration: msg.mediaDuration,
          sentAt: sentAt,
          memberUids: memberUids,
          replyTo: replyTo,
        );
      }

      // Transaction either wrote or was a no-op; either way the message
      // is in Firestore now. Mark local sent.
      await _db.updateMessageStatus(msg.id, SyncStatus.sent);

      // Re-sync the local chat's lastMessage cache. The transaction
      // already wrote the remote `lastMessage`; this keeps the local
      // Drift mirror consistent in case the post-write step in the
      // original send path failed (network drop after the transaction
      // commit but before the local updateChatLastMessage call).
      await _db.updateChatLastMessage(
        msg.chatRoomId,
        LastMessage(
          text: msg.textContent,
          sentBy: msg.senderId,
          sentAt: sentAt,
          type: msg.type,
        ),
      );
    } catch (e) {
      // Leave the row at its current status (pending or failed). The
      // 5-min gate in getStuckPendingMessages prevents an infinite
      // retry-storm on a persistent failure.
      debugPrint('flushPendingMessage failed for ${msg.id}: $e');
    }
  }

  /// Constructs a [ReplyToModel] from the local Drift [Message] row. The
  /// reply-to `senderId` is not stored in the local schema (the
  /// `replyToSenderName` is the canonical display field, see AGENTS.md §5
  /// schema) so we pass an empty string — the field is unused by the
  /// chat service when serializing the reply-to map.
  ReplyToModel? _replyToFromDrift(Message m) {
    if (m.replyToId == null) return null;
    return ReplyToModel(
      messageId: m.replyToId!,
      text: m.replyToText ?? '',
      senderId: '',
      senderName: m.replyToSenderName ?? '',
      sentAt: m.replyToSentAt != null
          ? DateTime.fromMillisecondsSinceEpoch(m.replyToSentAt!)
          : DateTime.fromMillisecondsSinceEpoch(m.sentAt),
      mediaUrl: m.replyToMediaUrl,
      mediaType: m.replyToMediaType,
    );
  }

  // ============================
  // DELETE MESSAGE
  // ============================
  Future<void> deleteMessageForMe({
    required String chatId,
    required List<String> messageIds,
  }) async {
    if (_currentUid == null) return;
    // Hard delete
    await _db.hardDeleteMessages(messageIds: messageIds);

    try {
      await _chatService.deleteMessageForMe(
        uid: _currentUid,
        chatId: chatId,
        messageIds: messageIds,
      );
    } catch (e) {
      debugPrint('Failed to delete on Cloud: $e');
    }
  }

  Future<void> deleteMessageForEveryone({
    required String chatId,
    required List<String> messageIds,
  }) async {
    if (_currentUid == null) return;
    // Soft delete
    await _db.softDeleteMessages(messageIds: messageIds);
  }

  // =========================================
  // CLEAR ALL DATA
  // =========================================
  /// Used when user sign out. Clear all the cache data in th phone.
  Future<void> clearAllData() async {
    // 1. Delete all local table
    await _db.clearAllTables();

    // 2. Delete all cache temporary medias
  }
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(messageDatabaseProvider),
    ref.watch(chatServiceProvider),
    ref.watch(cloudMediaServiceProvider),
    ref.watch(notificationServiceProvider),
    ref.watch(authServiceProvider).currentUser?.uid,
  ),
);
