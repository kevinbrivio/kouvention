import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:kouvention/features/chat/models/sticker_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class ChatRoomVM extends BaseNotifier {
  final ChatService _chatService;
  final SyncService _syncService;
  final String? _currentUid;
  final String chatId;

  // Subscribing to Firestore
  StreamSubscription? _firestoreSubscription;

  // Pagination
  String? _highlightedMessageId;

  // Typing indicator debounce
  Timer? _typingTimer;
  bool _isTyping = false;

  // Sending message
  bool _isSending = false;

  // Reply Message
  MessageModel? _replyMessage;

  // Upload file
  bool _isUploading = false;
  bool _showMediaPanel = false;

  // Stickers
  bool _showStickerPanel = false;

  // audio record
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  String? _error;

  ChatRoomVM(super.ref, {required this.chatId})
    : _chatService = ref.read(chatServiceProvider),
      _syncService = ref.read(syncServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // --- GETTERS ------------------------------
  String? get currentUid => _currentUid;
  bool get isTyping => _isTyping;
  bool get isSending => _isSending;
  MessageModel? get replyMessage => _replyMessage;
  String? get error => _error;
  String? get highlightedMessageId => _highlightedMessageId;
  bool get isUploading => _isUploading;
  bool get showMediaPanel => _showMediaPanel;
  bool get showStickerPanel => _showStickerPanel;
  bool get isRecording => _isRecording;

  @override
  FutureOr<void> init() async {
    if (_currentUid == null) {
      _error = 'Not authenticated';
    } else {
      // Turn off notification when in the chatId room
      Future.microtask(() async {
        ref.read(activeChatIdProvider.notifier).state = chatId;
        final syncProvider = ref.read(syncServiceProvider);

        // Fetch from local
        await syncProvider.fetchMessages(chatId);

        // Sync this chat's metadata into Drift so the chat list shows it
        try {
          final room = await _chatService.getChat(chatId);
          if (room != null) {
            final db = ref.read(messageDatabaseProvider);
            final existing = await db.getChatById(chatId);
            await db.upsertChatRooms([
              SyncService.chatToCompanion(
                room,
                lastSyncAt: existing?.lastSyncTimestamp,
              ),
            ]);
          }
        } catch (e) {
          debugPrint('Chat metadata sync skipped ($e)');
        }

        // Also listen to Firestore updates
        _firestoreSubscription = await syncProvider
            .streamFirestoreMessages(chatId)
            .listen((_) {
              debugPrint('New messages arrived in Drift local database');
            });

        // Non-critical Firestore writes — won't block init() if offline
        try {
          await _chatService.resetUnreadCount(chatId, _currentUid);
          await _chatService.markChatAsRead(chatId, _currentUid);
        } catch (e) {
          // networkAutoSyncProvider retries on reconnect
          debugPrint('Offline: unread/read update skipped ($e)');
        }
      });
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _currentUid == null) return;

    final chat = ref.read(chatMetadataStreamProvider(chatId)).value;
    if (chat == null) {
      _error = 'Getting chat room ready';
      notifyListeners();
      return;
    }

    UserModel? otherUser;
    if (chat.type == 'direct') {
      final otherUid = chat.otherMemberUid(_currentUid);
      otherUser = ref.read(otherUserStreamProvider(otherUid)).value;
    }

    try {
      _isSending = true;
      notifyListeners();
      // clear typing indicator before sending
      await clearTyping();
      final ReplyToModel? replyTo = _replyMessage != null
          ? ReplyToModel(
              messageId: _replyMessage!.id,
              senderId: _replyMessage!.senderId,
              senderName: _replyMessage!.senderName,
              text: _replyMessage!.text,
              sentAt: _replyMessage!.sentAt,
              mediaUrl: _replyMessage!.allMediaUrls.toString(),
              mediaType: _replyMessage!.type.name,
            )
          : null;

      await _syncService.sendMessage(
        chatRoomId: chat.id,
        textContent: text,
        senderName: chat.displayName(_currentUid),
        memberUids: chat.members,
        otherUserFcmTokens: otherUser?.fcmTokens,
        replyTo: replyTo,
      );

      onCancelReply();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ========================================
  // UPLOAD FILES
  // ========================================
  void toggleMediaPanel(BuildContext context) {
    _showMediaPanel = !_showMediaPanel;
    if (_showMediaPanel) {
      _showStickerPanel = false;
      FocusScope.of(context).unfocus();
    }
    notifyListeners();
  }

  void closeMediaPanel() {
    _showMediaPanel = false;
    notifyListeners();
  }

  void toggleStickerPanel(BuildContext context) {
    _showStickerPanel = !_showStickerPanel;
    if (_showStickerPanel) {
      _showMediaPanel = false;
      FocusScope.of(context).unfocus();
    }
    notifyListeners();
  }

  void closeStickerPanel() {
    _showStickerPanel = false;
    notifyListeners();
  }

  void dismissPanels() {
    if (_showMediaPanel || _showStickerPanel) {
      _showMediaPanel = false;
      _showStickerPanel = false;
      notifyListeners();
    }
  }

  Future<void> sendSticker(StickerModel sticker) async {
    if (_currentUid == null) return;

    final chat = ref.read(chatMetadataStreamProvider(chatId)).value;
    if (chat == null) return;

    try {
      _isSending = true;
      notifyListeners();

      final replyTo = _replyMessage != null
          ? ReplyToModel(
              messageId: _replyMessage!.id,
              senderId: _replyMessage!.senderId,
              senderName: _replyMessage!.senderName,
              text: _replyMessage!.text,
              sentAt: _replyMessage!.sentAt,
              mediaUrl: _replyMessage!.allMediaUrls.toString(),
              mediaType: _replyMessage!.type.name,
            )
          : null;

      UserModel? otherUser;
      if (chat.type == 'direct') {
        final otherUid = chat.otherMemberUid(_currentUid);
        otherUser = ref.read(otherUserStreamProvider(otherUid)).value;
      }

      await _syncService.sendSticker(
        chatRoomId: chatId,
        stickerUrl: sticker.url,
        senderName: chat.displayName(_currentUid),
        memberUids: chat.members,
        otherUserFcmTokens: otherUser?.fcmTokens,
        replyTo: replyTo,
      );
    } catch (e, s) {
      print('Error sending sticker: $e $s');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // --- Typing Indicator --------------------
  /// Calls this when user types in the text field.
  /// Set debounce for 2 seconds when user type first keystroke.
  void onTextChanged(String text) {
    if (_currentUid == null) return;

    if (text.isNotEmpty || !_isTyping) {
      _isTyping = true;
      _chatService.setTyping(chatId, _currentUid);
    }

    // Reset debounce timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 10), clearTyping);

    if (text.isEmpty) clearTyping();
  }

  Future<void> clearTyping() async {
    if (_currentUid != null && _isTyping) {
      _isTyping = false;
      _typingTimer?.cancel();
      await _chatService.clearTyping(chatId, _currentUid);
    }
  }

  // ========================================
  // UI HELPERS (Reply & Scroll)
  // ========================================
  void onSwipedMessage(MessageModel message) {
    _replyMessage = message;
    notifyListeners();
  }

  void onCancelReply() {
    _replyMessage = null;
    notifyListeners();
  }

  void highlightMessage(String messageId) {
    ref.read(highlightMessageProvider(chatId).notifier).state = messageId;

    // reset
    Future.delayed(const Duration(seconds: 2), () {
      ref.read(highlightMessageProvider(chatId).notifier).state = null;
    });
  }

  bool isMyMessage(MessageModel message) => message.senderId == _currentUid;
  bool isRepliedMessageMine(String senderId) => _currentUid == senderId;

  void setJumpTarget(int sentAt) {
    ref.read(jumpToTargetProvider(chatId).notifier).state = sentAt;
  }

  void switchToNormalMode() {
    ref.read(jumpToTargetProvider(chatId).notifier).state = null;
  }

  Future<void> fetchMessagesAround(DateTime sentAt) async {
    await _syncService.fetchMessagesAround(chatId, sentAt);
  }

  Future<void> sendMediaMessage({
    required List<UploadResultModel> files,
  }) async {
    try {
      _isUploading = true;
      notifyListeners();

      final captionedFiles = files
          .where((f) => f.caption != null && f.caption!.isNotEmpty)
          .toList();

      final mediaCaptions = files.map((f) => f.caption ?? '').toList();

      if (captionedFiles.length <= 1) {
        await _sendSingleBubble(
          caption: captionedFiles.isNotEmpty
              ? captionedFiles.first.caption!
              : '',
          files: files,
          mediaCaptions: mediaCaptions,
        );
      } else {
        for (final file in files) {
          try {
            await _sendSingleBubble(
              caption: file.caption ?? '',
              files: [file],
              mediaCaptions: [file.caption ?? ''],
            );
          } catch (_) {
            break;
          }
        }
      }

      onCancelReply();
    } catch (e) {
      _error = 'Failed to send media message';
      notifyListeners();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> _sendSingleBubble({
    required String caption,
    required List<UploadResultModel> files,
    List<String>? mediaCaptions,
  }) async {
    if (_currentUid == null) return;
    if (files.isEmpty) return;
    if (files.any((f) => f.localPath == null)) return;

    final chat = ref.read(chatMetadataStreamProvider(chatId)).value;
    if (chat == null) {
      _error = 'Getting chat room ready';
      notifyListeners();
      return;
    }

    UserModel? otherUser;
    if (chat.type == 'direct') {
      final otherUid = chat.otherMemberUid(_currentUid);
      otherUser = ref.read(otherUserStreamProvider(otherUid)).value;
    }

    final captions =
        mediaCaptions ?? files.map((f) => f.caption ?? '').toList();

    try {
      await _syncService.sendMediaMessageDirect(
        chatRoomId: chatId,
        senderName: chat.displayName(_currentUid),
        memberUids: chat.members,
        caption: caption,
        uploadResults: files,
        mediaCaptions: captions,
        type: files.first.messageType,
        otherUserFcmTokens: otherUser?.fcmTokens,
        replyTo: _replyMessage != null
            ? ReplyToModel(
                messageId: _replyMessage!.id,
                senderId: _replyMessage!.senderId,
                senderName: _replyMessage!.senderName,
                text: _replyMessage!.text,
                sentAt: _replyMessage!.sentAt,
                mediaUrl: _replyMessage!.mediaUrls?.firstOrNull,
                mediaType: _replyMessage!.type.name,
              )
            : null,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =================================
  // AUDIO RECORDING
  // =================================
  Future<void> startRecording() async {
    try {
      // Ketuk pintu: Minta izin mic
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return;
      }

      await _audioRecorder.start(
        const RecordConfig(),
        path: 'my_temp_audio.m4a',
      );

      _isRecording = true;
      notifyListeners();
    } catch (e) {
      print('Error in recording audio: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      _isRecording = false;
      notifyListeners();

      if (path != null) {
        print("Done recording, File in: $path");
      }
    } catch (e) {
      print("Stop recording failed: $e");
    }
  }

  String getCloudinaryThumbnail(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    return videoUrl.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
  }

  // --- CleanUp ----------------------------------
  @override
  void dispose() {
    ref.read(activeChatIdProvider.notifier).state = null;
    _firestoreSubscription?.cancel();
    clearTyping();
    _typingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}

// ==========================
// PROVIDER
// ==========================
// Use .family because each chat room will have its own vm
final chatRoomVMProvider = ChangeNotifierProvider.autoDispose
    .family<ChatRoomVM, String>(
      (ref, chatId) => ChatRoomVM(ref, chatId: chatId),
    );

final jumpToTargetProvider = StateProvider.autoDispose.family<int?, String>(
  (ref, chatId) => null,
);

final chatMessagesStreamProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, chatId) {
      final db = ref.watch(messageDatabaseProvider);

      final targetSentAt = ref.watch(jumpToTargetProvider(chatId));

      Stream<List<Message>> localStream;

      if (targetSentAt != null) {
        localStream = db.watchMessagesAround(
          chatId,
          targetSentAt: targetSentAt,
          limit: 50,
        );
      } else {
        // No target sent means nothing for us to jump
        final uid = ref.read(currentUidProvider);
        localStream = db.watchMessages(chatId, uid!, limit: 50);
      }

      return localStream.map((localMsgs) {
        debugPrint(
          '🕵️‍♂️ [DEBUG CHAT] Local Stream terpanggil! ChatID: $chatId',
        );
        debugPrint(
          '🕵️‍♂️ [DEBUG CHAT] Jumlah pesan dari SQLite (Drift): ${localMsgs.length}',
        );

        return localMsgs
            .map(
              (m) => MessageModel(
                id: m.id,
                senderId: m.senderId,
                senderName: m.senderName,
                text: m.textContent,
                type: MessageType.values.firstWhere(
                  (e) => e.name.toLowerCase() == m.type.toLowerCase(),
                  orElse: () => MessageType.text,
                ),
                sentAt: DateTime.fromMillisecondsSinceEpoch(m.sentAt),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(m.updatedAt),
                isDeleted: m.isDeleted,
                deletedFor: m.deletedFor,

                syncStatus: m.syncStatus,

                // Decode array jika ada
                mediaUrls: m.mediaUrls ?? [],
                mediaCaptions: m.mediaCaptions,
                fileSizeBytes: m.fileSizeBytes,
                fileName: m.fileName,
                mimeType: m.mimeType ?? '',
                mediaDuration: m.mediaDuration,

                // Mapping Reply
                replyTo: m.replyToId != null
                    ? ReplyToModel(
                        messageId: m.replyToId!,
                        senderId: '', // Sesuaikan jika lu butuh
                        senderName: m.replyToSenderName ?? '',
                        text: m.replyToText ?? '',
                        sentAt: DateTime.now(),
                        mediaType: m.replyToMediaType,
                        mediaUrl: m.replyToMediaUrl,
                      )
                    : null,
              ),
            )
            .toList();
      });
    });

final chatMetadataStreamProvider = StreamProvider.autoDispose
    .family<ChatModel?, String>((ref, chatId) {
      final chatService = ref.watch(chatServiceProvider);
      return chatService.streamChat(chatId);
    });

final otherUserStreamProvider = StreamProvider.autoDispose
    .family<UserModel?, String>((ref, otherUserId) {
      final userService = ref.watch(userServiceProvider);
      return userService.streamUser(otherUserId);
    });

final highlightMessageProvider = StateProvider.autoDispose
    .family<String?, String>((ref, chatId) => null);
