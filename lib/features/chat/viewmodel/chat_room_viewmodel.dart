import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/cached_messages.dart';
import 'package:kouvention/features/notification/services/notification_service.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

class ChatRoomVM extends BaseNotifier {
  final ChatService _chatService;
  final UserService _userService;
  final String? _currentUid;
  final String chatId;
  final MessageDatabase _db;

  // Messages from newest
  List<MessageModel> _messages = [];
  StreamSubscription? _localSubscription; // SQLite
  StreamSubscription? _syncSubscription; // Firestore -> SQLite

  // Chat metadata
  ChatModel? _chat;
  StreamSubscription? _chatSubscription;
  StreamSubscription? _otherUserSubscription;
  UserModel? _otherUser;

  // Pagination
  DocumentSnapshot? _lastDocument;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;
  String? _highlightedMessageId;
  String? _pendingScrollMessageId;
  DateTime? _pendingScrollSentAt;

  // Typing indicator debounce
  Timer? _typingTimer;
  bool _isTyping = false;

  // Sending message
  bool _isSending = false;

  // Reply Message
  MessageModel? _replyMessage;

  // Jump to searched message
  int? _jumpToSentAt;
  bool _isJumpMode = false;

  String? _error;

  ChatRoomVM(super.ref, {required this.chatId})
    : _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid,
      _userService = ref.read(userServiceProvider),
      _db = ref.read(messageDatabaseProvider);

  // --- GETTERS ------------------------------
  List<MessageModel> get messages => _messages;
  ChatModel? get chat => _chat;
  String? get currentUid => _currentUid;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isLoadingMore => _isLoadingMore;
  bool get isTyping => _isTyping;
  bool get isGroup => _chat?.type == 'group';
  bool get isSending => _isSending;
  MessageModel? get replyMessage => _replyMessage;
  String? get error => _error;
  String? get highlightedMessageId => _highlightedMessageId;
  String? get pendingScrollMessageId => _pendingScrollMessageId;
  DateTime? get pendingScrollSentAt => _pendingScrollSentAt;
  bool get isJumpMode => _isJumpMode;

  /// Display name for the chat header
  String get chatDisplayName {
    if (_chat == null || _currentUid == null) return '';
    return _chat!.displayName(_currentUid);
  }

  /// Display sender name
  String senderDisplayName(String senderId) =>
      _chat?.memberInfo[senderId]?.displayName ?? '';

  /// Display sender name
  String? senderPhotoUrl(String senderId) =>
      _chat?.memberInfo[senderId]?.photoUrl ?? '';

  /// Photo URL
  String? get chatPhotoUrl {
    if (_chat == null || _currentUid == null) return null;
    return _chat!.displayPhotoUrl(_currentUid);
  }

  /// Get current user whose typing..
  String? get typingText {
    if (_chat == null || _currentUid == null) return null;

    final others = _chat!.typingUsers
        .where((uid) => uid != _currentUid)
        .toList();

    if (others.isEmpty) return null;

    final names = others
        .map((uid) => _chat!.memberInfo[uid]?.displayName ?? '')
        .toList();

    if (names.length == 1) return '${names.first} is typing...';
    return '${names.join(', ')} are typing...';
  }

  /// Get other user status
  String? get onlineStatusText {
    if (_chat == null) return null;

    if (_chat!.type != 'direct') return null;
    if (_otherUser == null) return null;

    if (!_otherUser!.privacy.showOnlineStatus) return null;

    if (_otherUser!.isOnline) return 'Online';
    if (_otherUser!.privacy.showLastSeen && _otherUser!.lastSeen != null) {
      return _formatLastSeen(_otherUser!.lastSeen!);
    }
    return null;
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    return 'Last seen ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  bool isMyMessage(MessageModel message) => message.senderId == _currentUid;
  bool isRepliedMessageMine(String senderId) => _currentUid == senderId;

  void setJumpTarget(int sentAt) {
    _jumpToSentAt = sentAt;
    _isJumpMode = true;

    _localSubscription?.cancel();
    _subscribeToLocalMessages();
  }

  Future<void> switchToNormalMode() async {
    if (!_isJumpMode) return;
    _isJumpMode = false;
    _jumpToSentAt = null;

    final latestMessages = await _db.fetchNewerMessages(
      chatId,
      afterSentAt: 0, // fetch from newest to latest
    );
    if (latestMessages.isNotEmpty) {
      _messages = latestMessages.map(_cachedToMessageModel).toList();
      notifyListeners();
    }
    _localSubscription?.cancel();
    _subscribeToLocalMessages();
  }

  @override
  FutureOr<void> init() async {
    if (_currentUid == null) {
      _error = 'Not authenticated';
    } else {
      scheduleMicrotask(() {
        ref.read(activeChatIdProvider.notifier).state = chatId;
      });

      _subscribeToChat();
      _subscribeToLocalMessages();
      _syncFromFirestore();
      _resetUnreadCount();

      // Mark read when opening the chat
      await _chatService.markChatAsRead(chatId, _currentUid);
    }
  }

  // --- STREAMS -----------------------------
  void _subscribeToChat() {
    _chatSubscription = _chatService
        .streamChat(chatId)
        .listen(
          (chat) {
            _chat = chat;

            if (chat != null &&
                chat.type == 'direct' &&
                _otherUserSubscription == null &&
                _currentUid != null) {
              final otherUid = chat.otherMemberUid(_currentUid);
              _subscribeToOtherUser(otherUid);
            }
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  /// Subscribe to the latest messages
  /// This stream stays live - when someone send a new message
  void _subscribeToLocalMessages() {
    final sw = Stopwatch()..start();

    try {
      final stream = _db.watchMessages(chatId);

      _localSubscription = stream.listen(
        (cachedMessages) {
          _messages = cachedMessages
              .where((m) {
                // parse from json in local version
                final deletedFor = _parseDeletedFor(m.deletedFor);
                return !deletedFor.contains(_currentUid!);
              })
              .map(_cachedToMessageModel)
              .toList();
          _error = null;

          if (sw.isRunning) {
            sw.stop();
            debugPrint('Messages loaded: ${_messages.length}');
            debugPrint('Load time: ${sw.elapsedMilliseconds}ms');
          }

          notifyListeners();
        },
        onError: (error) {
          _error = error.toString();
          notifyListeners();
        },
      );
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  // Catch up newest message -> Update -> Stream
  Future<void> _syncFromFirestore() async {
    try {
      // Catch up latest sync
      final lastSync = await _db.getLastSyncTimestamp(chatId);
      final sinceDate = DateTime.fromMillisecondsSinceEpoch(lastSync);

      // check missed out messages from last sync
      final missedMessages = await _chatService.fetchMessagesSince(
        chatId,
        since: sinceDate,
      );

      debugPrint('---- missed messages: ${missedMessages.length} ---------');

      if (missedMessages.isNotEmpty) {
        // if there is message, UPSERT to local
        debugPrint('----- UPSERTING MESSAGE -----');
        await _db.upsertMessages(
          missedMessages.map(_messageToCompanion).toList(),
        );
        debugPrint('----- SUCCESS UPSERTING -----');
      }

      // update last sync
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.updateLastSync(chatId, now);

      // Stream new message
      _syncSubscription = _chatService
          .streamMessages(chatId)
          .listen(
            (newMessages) {
              // Titik 1: apakah stream fire?
              debugPrint('🔥 Stream fired! ${newMessages.length} messages');
              
              if (newMessages.isNotEmpty) {
                // Titik 2: apakah upsert jalan?
                debugPrint('🔥 Upserting ${newMessages.length} messages');
                _db.upsertMessages(
                  newMessages.map(_messageToCompanion).toList(),
                ).then((_) {
                  // Titik 3: apakah upsert selesai?
                  debugPrint('🔥 Upsert complete!');
                });
              }
            },
          );
    } catch (e) {
      debugPrint('Catch-up sync error: $e');
    }
  }

  /// Subscribe to the latest messages from the other user
  void _subscribeToOtherUser(String otherUserId) {
    _otherUserSubscription = _userService
        .streamUser(otherUserId)
        .listen(
          (user) {
            _otherUser = user;
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  /// Convert CachedMessage → MessageModel (SQLite → UI)
  MessageModel _cachedToMessageModel(CachedMessage m) => MessageModel(
    id: m.id,
    senderId: m.senderId,
    senderName: m.senderName,
    text: m.messageText,
    type: m.type,
    sentAt: DateTime.fromMillisecondsSinceEpoch(m.sentAt),
    isDeleted: m.isDeleted,
    replyTo: m.replyToId != null
        ? ReplyToModel(
            messageId: m.replyToId!,
            text: m.replyToText ?? '',
            senderId: '',
            senderName: m.replyToSender ?? '',
            sentAt: DateTime.fromMillisecondsSinceEpoch(m.replyToSentAt ?? 0),
          )
        : null,
    mediaUrl: m.mediaUrl,
    fileName: m.fileName,
    fileSizeBytes: m.fileSizeBytes,
  );

  /// Convert MessageModel → CachedMessagesCompanion (Firestore → SQLite)
  CachedMessagesCompanion _messageToCompanion(MessageModel m) =>
      CachedMessagesCompanion(
        id: Value(m.id),
        chatRoomId: Value(chatId),
        messageText: Value(m.text),
        textLower: Value(m.text.toLowerCase()),
        senderId: Value(m.senderId),
        senderName: Value(m.senderName),
        sentAt: Value(m.sentAt.millisecondsSinceEpoch),
        type: Value(m.type),
        isDeleted: Value(m.isDeleted),
        deletedFor: Value(m.deletedFor.toString()),
        replyToId: Value(m.replyTo?.messageId),
        replyToText: Value(m.replyTo?.text),
        replyToSender: Value(m.replyTo?.senderName),
        replyToSentAt: Value(m.replyTo?.sentAt.millisecondsSinceEpoch),
        mediaUrl: Value(m.mediaUrl),
        fileName: Value(m.fileName),
        fileSizeBytes: Value(m.fileSizeBytes),
        syncedAt: Value(DateTime.now().millisecondsSinceEpoch),
      );

  /// Parse deletedFor JSON string ke List<String>
  List<String> _parseDeletedFor(String json) {
    try {
      final list = (jsonDecode(json) as List).cast<String>();
      return list;
    } catch (_) {
      return [];
    }
  }

  // --- METHODS -----------------------------
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _currentUid == null || _chat == null) return;

    try {
      _isSending = true;
      notifyListeners();
      // clear typing indicator before sending
      await clearTyping();
      final ReplyToModel? replyTo = _replyMessage != null
          ? ReplyToModel(
              messageId: _replyMessage!.id,
              senderId: _replyMessage!.senderId,
              senderName: senderDisplayName(_replyMessage!.senderId),
              text: _replyMessage!.text,
              sentAt: _replyMessage!.sentAt,
            )
          : null;

      onCancelReply();

      // Write get Id
      final docId = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc()
          .id;

      final now = DateTime.now();
      final localMessage = MessageModel(
        id: docId,
        senderId: _currentUid,
        senderName: senderDisplayName(_currentUid),
        text: trimmed,
        type: 'text',
        sentAt: now,
        isDeleted: false,
        replyTo: replyTo,
      );

      await _db.upsertMessage(_messageToCompanion(localMessage));

      await _chatService.sendMessage(
        chatId: chatId,
        messageId: docId,
        senderId: _currentUid,
        senderName: senderDisplayName(_currentUid),
        text: trimmed,
        memberUids: _chat!.members,
        replyTo: replyTo,
      );

      _sendNotification(trimmed);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void _sendNotification(String messageText) {
    if (_chat?.type != 'direct') return;

    final fcmTokens = _otherUser?.fcmTokens;
    if (fcmTokens == null) return;

    final notificationService = ref.read(notificationServiceProvider);
    for (final tokenString in fcmTokens.keys) {
      notificationService.sendChatNotification(
        targetToken: tokenString,
        messageText: messageText,
        chatId: chatId,
        senderId: _currentUid!,
        senderName: senderDisplayName(_currentUid),
        senderImageUrl: senderPhotoUrl(_currentUid),
      );
    }
  }

  /// Load more messages when the user scrolls to the top.
  Future<void> loadMoreMessages() async {
    // if (_isLoadingMore) return;

    // _isLoadingMore = true;
    // notifyListeners();

    // await _loadOlderBatch();

    // _isLoadingMore = false;
    // notifyListeners();
  }

  void highlightMessage(String messageId) {
    _highlightedMessageId = messageId;
    notifyListeners();

    Future.delayed(Duration(milliseconds: 200), () {
      if (_highlightedMessageId == messageId) {
        _highlightedMessageId = null;
        notifyListeners();
      }
    });
  }

  void scrollToTarget({required String messageId, required DateTime sentAt}) {
    _pendingScrollMessageId = messageId;
    _pendingScrollSentAt = sentAt;
    notifyListeners();
  }

  void clearPendingScroll() {
    _pendingScrollMessageId = null;
    _pendingScrollSentAt = null;
  }

  Future<int?> findMessageIndex(String messageId, {DateTime? sentAt}) async {
    // find from recent messages
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) return index;

    // find via timestamp in sqlite
    int? targetSentAt = sentAt?.millisecondsSinceEpoch;
    debugPrint('$targetSentAt');

    List<CachedMessage> allBatch = [];
    if (targetSentAt == null) {
      // jump to latest messages
      final batch = await _db.fetchNewerMessages(chatId, afterSentAt: 0);
      return _addBatchAndFind(batch, messageId);
    }

    final cached = await _db.getMessageByDateTime(chatId, targetSentAt);

    if (cached != null) {
      final olderBatch = await _db.fetchOlderMessages(
        chatId,
        beforeSentAt: cached.sentAt,
        limit: 50,
      );
      allBatch.addAll(olderBatch);

      final newerBatch = await _db.fetchNewerMessages(
        chatId,
        afterSentAt: cached.sentAt,
        limit: 50,
      );
      allBatch.addAll(newerBatch);
    }

    return _addBatchAndFind(allBatch, messageId);

    // final found = _messages.indexWhere((m) => m.id == messageId);
    // if (found != -1) return found;

    // // Not found in SQLite but try to fetch from Firestore
    // final firestoreBatch = await _chatService.fetchOlderMessages(
    //   chatId,
    //   before: DateTime.fromMillisecondsSinceEpoch(targetSentAt),
    // );

    // if (firestoreBatch.isNotEmpty) {
    //   await _db.upsertMessages(
    //     firestoreBatch.map(_messageToCompanion).toList(),
    //   );

    //   final freshModels = firestoreBatch
    //       .where((m) => !existingIds.contains(m.id))
    //       .toList();
    //   _messages.addAll(freshModels);
    //   _messages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    //   notifyListeners();

    //   return _messages.indexWhere((m) => m.id == messageId);
    // }

    // return null;
  }

  Future<int?> _addBatchAndFind(
    List<CachedMessage> batch,
    String messageId,
  ) async {
    if (batch.isEmpty) return null;

    final batchModels = batch.map(_cachedToMessageModel).toList();
    final existingIds = _messages.map((m) => m.id).toSet();
    final newMessages = batchModels
        .where((m) => !existingIds.contains(m.id))
        .toList();
    _messages.addAll(newMessages);
    _messages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    notifyListeners();
    return _messages.indexWhere((m) => m.id == messageId);
  }

  /// Load pesan lama — cek SQLite dulu, baru Firestore kalau gap
  Future<void> loadOlderFromLocal() async {
    if (_isLoadingMore || _messages.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    final oldestSentAt = _messages.last.sentAt.millisecondsSinceEpoch;

    // Step 1: Cek SQLite
    final localOlder = await _db.fetchOlderMessages(
      chatId,
      beforeSentAt: oldestSentAt,
    );

    if (localOlder.isNotEmpty) {
      // Ada di SQLite — gratis, ga perlu Firestore
      final olderModels = localOlder.map(_cachedToMessageModel).toList();
      _messages = [..._messages, ...olderModels];
      notifyListeners();
    } else {
      _hasMoreMessages = false;
    }

    _isLoadingMore = false;
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
    _typingTimer = Timer(const Duration(seconds: 10), () => clearTyping());

    if (text.isEmpty) clearTyping();
  }

  Future<void> clearTyping() async {
    if (_currentUid != null && _isTyping) {
      _isTyping = false;
      _typingTimer?.cancel();
      await _chatService.clearTyping(chatId, _currentUid);
    }
  }

  // ---- Reply Message -----------------------
  void onSwipedMessage(MessageModel message) {
    _replyMessage = message;
    notifyListeners();
  }

  void onCancelReply() {
    _replyMessage = null;
    notifyListeners();
  }

  // --- Unread Count --------------------------
  void _resetUnreadCount() {
    if (_currentUid != null) {
      _chatService.resetUnreadCount(chatId, _currentUid);
    }
  }

  // ---- Message Status ----------------------
  MessageStatus getMessageStatus(MessageModel message) {
    if (message.senderId != _currentUid) return MessageStatus.sent;

    // Use the flag you already have
    if (_isSending) return MessageStatus.sending;

    if (_chat?.type == 'direct') {
      final otherUid = _chat!.otherMemberUid(_currentUid!);
      final otherLastRead = _chat!.lastReadAt[otherUid];

      if (otherLastRead != null && !message.sentAt.isAfter(otherLastRead)) {
        return MessageStatus.read;
      }
    } else if (_chat != null) {
      final anyRead = _chat!.members.where((uid) => uid != _currentUid).any((
        uid,
      ) {
        final lastRead = _chat!.lastReadAt[uid];
        return lastRead != null && !message.sentAt.isAfter(lastRead);
      });
      if (anyRead) return MessageStatus.read;
    }

    return MessageStatus.sent;
  }

  // --- CleanUp ----------------------------------
  @override
  void dispose() {
    ref.read(activeChatIdProvider.notifier).state = null;

    _localSubscription?.cancel();
    _syncSubscription?.cancel();
    _chatSubscription?.cancel();
    _otherUserSubscription?.cancel();
    clearTyping();
    _typingTimer?.cancel();
    super.dispose();
  }
}

// Use .family because each chat room will have its own vm
final chatRoomVM = ChangeNotifierProvider.autoDispose
    .family<ChatRoomVM, String>(
      (ref, chatId) => ChatRoomVM(ref, chatId: chatId),
    );

enum MessageStatus { sending, sent, read }
