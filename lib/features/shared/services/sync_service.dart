import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/services/media/cloud_media_service.dart';
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

  syncStatus: Value(status),

  senderId: Value(msg.senderId),
  senderName: Value(msg.senderName),

  replyToId: Value(msg.replyTo?.messageId),
  replyToText: Value(msg.replyTo?.text),
  replyToSenderName: Value(msg.replyTo?.senderName),

  isDeleted: Value(msg.isDeleted),
  deletedFor: Value(msg.deletedFor),

  mimeType: Value(msg.mimeType),
  mediaDuration: Value(msg.mediaDuration),
  fileName: Value(msg.fileName),
  fileSizeBytes: Value(msg.fileSizeBytes),
  mediaUrls: Value(msg.mediaUrls != null ? jsonEncode(msg.mediaUrls) : null),
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

    final lastSyncAtMap = {
      for (var room in existingLocalRooms) room.id: room.lastSyncTimestamp,
    };

    List<ChatsCompanion> companions;

    if (chatRooms.length < 100) {
      print('Chat list length: ${chatRooms.length}');
      companions = chatRooms.map((chat) {
        return chatToCompanion(chat, lastSyncAt: lastSyncAtMap[chat.id]);
      }).toList();
    } else {
      // Only use Isolate when plenty chats
      companions = await Isolate.run(
        () => chatRooms.map(chatToCompanion).toList(),
      );
    }

    await _db.upsertChatRooms(companions);

    debugPrint(
      ' ========= [Everything is done] Total testing time: ${sw.elapsedMilliseconds} ms =======',
    );

    // 4. Sebagai anak yang baik, kita matikan jamnya jika sudah selesai
    sw.stop();
  }

  static ChatsCompanion chatToCompanion(ChatModel chat, {int? lastSyncAt}) => ChatsCompanion(
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

    // Untuk Map yang kita biarkan nullable string di Drift, encode manual 1 kali:
    deletedBy: Value(
      chat.deletedBy != null ? jsonEncode(chat.deletedBy) : null,
    ),
    createdBy: Value(chat.createdBy),

    lastSyncTimestamp: Value(lastSyncAt ?? 0),
  );

  Future<void> fetchMessages(String chatId) async {
    debugPrint('🕵️‍♂️ [TRIPWIRE 1] Starting fetch for $chatId...');
    final chatRoom = await _db.getChatById(chatId);
    final lastSyncAt = chatRoom?.lastSyncTimestamp ?? 0;
    debugPrint('🕵️‍♂️ [TRIPWIRE 2] Bookmark found: $lastSyncAt');

    final missedMessages = await _chatService.fetchMessages(
      chatId,
      lastSyncTimestamp: DateTime.fromMillisecondsSinceEpoch(lastSyncAt),
      limit: 50,
    );
    debugPrint(
      '🕵️‍♂️ [TRIPWIRE 3] Firestore returned ${missedMessages.length} messages',
    );

    if (missedMessages.isEmpty) {
      debugPrint('🕵️‍♂️ [TRIPWIRE 4] No new messages. Going home early.');
      await _db.updateChatLastSync(chatId, lastSyncAt);
      return;
    }

    final companions = await Isolate.run(() {
      return missedMessages
          .map((m) => messageToCompanion(m, chatId, SyncStatus.sent))
          .toList();
    });

    await _db.upsertMessages(companions);

    debugPrint(
      '🪣 [BUCKET] Successfully saved ${companions.length} messages to Drift!',
    );

    final latestMsgTime = missedMessages
        .first
        .sentAt
        .millisecondsSinceEpoch; // Firestore send descendingly, hence use .first
    await _db.updateChatLastSync(chatId, latestMsgTime);
  }

  Stream<void> streamFirestoreMessages(String chatId) async* {
    final chatRoom = await _db.getChatById(chatId);
    final lastSyncAt = chatRoom?.lastSyncTimestamp ?? 0;

    // Yield the new message stream from Firestore value into Drift stream
    yield* _chatService
        .streamMessagesSince(
          chatId,
          DateTime.fromMillisecondsSinceEpoch(lastSyncAt),
        )
        .asyncMap((newMessages) async {
          if (newMessages.isEmpty) return;

          final companions = await Isolate.run(() {
            return newMessages
                .map((m) => messageToCompanion(m, chatId, SyncStatus.sent))
                .toList();
          });

          await _db.upsertMessages(companions);
          final latestMsgTime = newMessages.first.sentAt.millisecondsSinceEpoch;
          await _db.updateChatLastSync(chatId, latestMsgTime);
        });
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
    final random = generateRandomString(5);
    final now = DateTime.now();
    final tempId = '${now.millisecondsSinceEpoch}_$random';

    // Wrap in MessageModel
    final localMessage = MessageModel(
      id: tempId,
      senderId: _currentUid!,
      senderName: senderName,
      text: textContent,
      sentAt: now,
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
    // Generate Temp ID / Group Media ID
    final isAlbum = files.length > 1;
    final albumGroupId = isAlbum
        ? 'album_${DateTime.now().millisecondsSinceEpoch}'
        : null;

    final List<MessagesCompanion> localMessages = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];

      final randomStr = generateRandomString(5);
      final tempId = '${DateTime.now().millisecondsSinceEpoch}_$randomStr';

      // Upsert to Local with status pending, null mediaURL, but existing localpath
      final localMsg = MessagesCompanion(
        id: Value(tempId),
        chatRoomId: Value(chatRoomId),
        senderId: Value(_currentUid!),
        senderName: Value(senderName),
        textContent: Value(caption ?? ''), // Send empty string if media
        type: Value(type.name),
        sentAt: Value(DateTime.now().millisecondsSinceEpoch),
        syncStatus: Value(SyncStatus.pending),

        localPath: Value(file.path),
        mediaUrls: Value(null), // no url yet
        mediaGroupId: Value(albumGroupId),

        replyToId: Value(replyTo?.messageId),
        replyToText: Value(replyTo?.text),
        replyToSenderName: Value(replyTo?.senderName),
      );

      localMessages.add(localMsg);
    }

    for (var msg in localMessages) {
      await _db.upsertMessage(msg);
    }

    _processMediaUploadsInBackground(
      localMessages: localMessages,
      files: files,
      chatRoomId: chatRoomId,
      type: type,
      caption: caption ?? '',
      senderName: senderName,
      memberUids: memberUids,
      replyTo: replyTo,
    );
  }

  Future<void> _processMediaUploadsInBackground({
    required List<MessagesCompanion> localMessages,
    required List<File> files,
    required String chatRoomId,
    required MessageType type,
    required String caption,
    required String senderName,
    required List<String> memberUids,
    required ReplyToModel? replyTo,
  }) async {
    final uploadTasks = <Future<void>>[];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final tempId = localMessages[i].id.value;
      final fileCaption = (i == 0) ? caption : '';

      uploadTasks.add(() async {
        try {
          final uploadResult = await _mediaService.uploadFile(
            file: file,
            mediaType: type,
          );
          if (uploadResult == null) throw Exception('Upload failed');

          // Shoot to Firestore
          await _chatService.sendMediaMessage(
            chatId: chatRoomId,
            messageId: tempId,
            text: caption,
            type: type,
            senderId: _currentUid!,
            senderName: senderName,
            mediaUrls: [uploadResult.url],
            mediaDuration: uploadResult.mediaDuration,
            mimeType: uploadResult.mimeType,
            fileSizeBytes: uploadResult.fileSizeBytes,
            memberUids: memberUids,
            replyTo: replyTo,
            fileName: file.path.split('/').last, // king_emyu.jpeg
          );

          // Update to SQLite
          await _db.updateMediaMessageSuccess(tempId, uploadResult.url);
        } catch (e) {
          debugPrint('🚨 Failed media upload for $tempId: $e');
          await _db.updateMessageStatus(tempId, SyncStatus.failed);
        }
      }());
    }

    await Future.wait(uploadTasks);
  }

  Future<void> _sendMessageInBackground({
    required MessageModel localMessage,
    required String chatRoomId,
    required List<String> memberUids,
  }) async {
    try {
      await _chatService.sendMessage(
        chatId: chatRoomId,
        memberUids: memberUids,
        messageId: localMessage.id,
        senderId: localMessage.senderId,
        senderName: localMessage.senderName,
        text: localMessage.text,
        replyTo: localMessage.replyTo,
      );

      // Update status in local
      await _db.updateMessageStatus(localMessage.id, SyncStatus.sent);
    } catch (e) {
      await _db.updateMessageStatus(localMessage.id, SyncStatus.failed);
      debugPrint('Failed sending message: $e');
    }
  }

  // ===========================================
  // RETRY SENDING MESSAGE AFTER NO CONNECTION
  // ==========================================
  Future<void> retryStuckMessages() async {
    final stuckMessages = await _db.getStuckPendingMessages();
    if (stuckMessages.isEmpty) return;

    for (final msg in stuckMessages) {
      // if (msg.type == MessageType.text.name) {
      //   _retryTextInBackground(msg);
      // } else {
      //   _retryMediaInBackground(msg);
      // }
    }
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

  // ==========================================
  // HELPER
  // ==========================================
  String generateRandomString(int len) {
    var r = Random();
    const _chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(
      len,
      (index) => _chars[r.nextInt(_chars.length)],
    ).join();
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
