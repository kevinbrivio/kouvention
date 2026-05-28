import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

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
  ReplyToModel? _replyMessage;

  // Upload file
  bool _isUploading = false;
  bool _showMediaPanel = false;

  String? _error;

  ChatRoomVM(super.ref, {required this.chatId})
    : _chatService = ref.read(chatServiceProvider),
      _syncService = ref.read(syncServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // --- GETTERS ------------------------------
  String? get currentUid => _currentUid;
  bool get isTyping => _isTyping;
  bool get isSending => _isSending;
  ReplyToModel? get replyMessage => _replyMessage;
  String? get error => _error;
  String? get highlightedMessageId => _highlightedMessageId;
  bool get isUploading => _isUploading;
  bool get showMediaPanel => _showMediaPanel;

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

        // Also listen to Firestore updates
        _firestoreSubscription = await syncProvider
            .streamFirestoreMessages(chatId)
            .listen((_) {
              debugPrint('New messages arrived in Drift local database');
            });
      });

      await _chatService.resetUnreadCount(chatId, _currentUid);
      await _chatService.markChatAsRead(chatId, _currentUid);
    }
  }

  // ============================================
  // SEND MESSAGE
  // ============================================
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

      await _syncService.sendMessage(
        chatRoomId: chatId,
        textContent: trimmed,
        senderName: chat.displayName(_currentUid),
        memberUids: chat.members,
        otherUserFcmTokens: otherUser?.fcmTokens,
        replyTo: _replyMessage,
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
  Future<void> sendMediaMessage(
    List<File> files,
    MessageType type,
    String caption,
  ) async {
    if (_currentUid == null) return;
    _isUploading = true;
    notifyListeners();

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
      await _syncService.sendMediaMessage(
        chatRoomId: chatId,
        type: type,
        caption: caption,
        files: files,

        senderName: chat.displayName(_currentUid),
        memberUids: chat.members,
        otherUserFcmTokens: otherUser?.fcmTokens,
        replyTo: _replyMessage,
      );

      onCancelReply();
    } catch (e) {
      _error = 'Failed to upload file';
      notifyListeners();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  void toggleMediaPanel(BuildContext context) {
    _showMediaPanel = !_showMediaPanel;
    if (_showMediaPanel) {
      FocusScope.of(context).unfocus();
    }
    notifyListeners();
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
  void onSwipedMessage(ReplyToModel message) {
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

  void setJumpTarget(int sentAt) {
    ref.read(jumpToTargetProvider(chatId).notifier).state = sentAt;
  }

  void switchToNormalMode() {
    ref.read(jumpToTargetProvider(chatId).notifier).state = null;
  }

  // --- CleanUp ----------------------------------
  @override
  void dispose() {
    ref.read(activeChatIdProvider.notifier).state = null;
    _firestoreSubscription?.cancel();
    clearTyping();
    _typingTimer?.cancel();
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
        localStream = db.watchMessages(chatId, limit: 50);
      }

      return localStream.map((localMsgs) {
        debugPrint('🕵️‍♂️ [DEBUG CHAT] Stream terpanggil! ChatID: $chatId');
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
                  (e) => e.name == m.type,
                  orElse: () => MessageType.text,
                ),
                sentAt: DateTime.fromMillisecondsSinceEpoch(m.sentAt),
                isDeleted: m.isDeleted,

                syncStatus: m.syncStatus,

                // Decode array jika ada
                mediaUrls: m.mediaUrl != null
                    ? List<String>.from(jsonDecode(m.mediaUrl!))
                    : null,
                fileName: m.fileName,

                // Mapping Reply
                replyTo: m.replyToId != null
                    ? ReplyToModel(
                        messageId: m.replyToId!,
                        senderId: '', // Sesuaikan jika lu butuh
                        senderName: m.replyToSenderName ?? '',
                        text: m.replyToText ?? '',
                        sentAt: DateTime.now(), // Sesuaikan
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
