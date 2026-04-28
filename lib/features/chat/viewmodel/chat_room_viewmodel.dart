import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/shared/services/notification_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

class ChatRoomVM extends BaseNotifier {
  final ChatService _chatService;
  final UserService _userService;
  final String? _currentUid;
  final String chatId;

  // Messages from newest
  List<MessageModel> _messages = [];
  StreamSubscription? _messageSubscription;

  // Chat metadata
  ChatModel? _chat;
  StreamSubscription? _chatSubscription;
  StreamSubscription? _otherUserSubscription;
  UserModel? _otherUser;

  // Pagination
  DocumentSnapshot? _lastDocument;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  // Typing indicator debounce
  Timer? _typingTimer;
  bool _isTyping = false;

  String? _error;

  ChatRoomVM(super.ref, {required this.chatId})
    : _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid,
      _userService = ref.read(userServiceProvider);

  // --- GETTERS ------------------------------
  List<MessageModel> get messages => _messages;
  ChatModel? get chat => _chat;
  String? get urrentUid => _currentUid;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isLoadingMore => _isLoadingMore;
  bool get isTyping => _isTyping;
  bool get isGroup => _chat?.type == 'group';
  String? get error => _error;

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

  @override
  FutureOr<void> init() async {
    if (_currentUid == null) {
      _error = 'Not authenticated';
    } else {
      _subscribeToChat();
      _subscribeToMessages();
      _resetUnreadCount();
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
              final otherUid = chat.otherMemberUid(_currentUid!);
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
  void _subscribeToMessages() {
    _messageSubscription = _chatService
        .streamMessages(chatId)
        .listen(
          (msg) {
            _messages = msg;
            _error = null;

            if (_lastDocument == null && messages.isNotEmpty)
              _fetchPaginationCursor();

            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            notifyListeners();
          },
        );
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

  Future<void> _fetchPaginationCursor() async {
    final snapshot = await _chatService.fetchRawMesages(chatId);
    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }
  }

  // --- METHODS -----------------------------
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _currentUid == null || _chat == null) return;

    try {
      // clear typing indicator before sending
      await clearTyping();

      await _chatService.sendMessage(
        chatId: chatId,
        senderId: _currentUid,
        text: trimmed,
        memberUids: _chat!.members,
      );

      _sendNotification(trimmed);
    } catch (e) {
      _error = e.toString();
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
        senderName: senderDisplayName(_currentUid!),
        messageText: messageText,
        chatId: chatId,
      );
    }
  }

  /// Load more messages when the user scrolls to the top.
  Future<void> loadMoreMessages() async {
    if (!_isLoadingMore || !_hasMoreMessages || _lastDocument == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final snapshot = await _chatService.fetchRawMesages(
        chatId,
        lastDocument: _lastDocument!,
      );

      if (snapshot.docs.isEmpty) {
        _hasMoreMessages = false;
      } else {
        final olderMessages = snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
            .toList();
        _messages = [...messages, ...olderMessages];
        _lastDocument = snapshot.docs.last;
      }
    } catch (e) {
      _error = e.toString();
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
    _typingTimer = Timer(const Duration(seconds: 2), () {
      clearTyping();
    });

    if (text.isEmpty) clearTyping();
  }

  Future<void> clearTyping() async {
    if (_currentUid != null && _isTyping) {
      _isTyping = false;
      _typingTimer?.cancel();
      await _chatService.clearTyping(chatId, _currentUid);
    }
  }

  // --- Unread Count --------------------------
  void _resetUnreadCount() {
    if (_currentUid != null) {
      _chatService.resetUnreadCount(chatId, _currentUid);
    }
  }

  // --- CleanUp ----------------------------------
  @override
  void dispose() {
    _messageSubscription?.cancel();
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
