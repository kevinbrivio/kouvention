import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';

class ChatListVM extends BaseNotifier {
  final ChatService _chatService;
  final String? _currentUid;

  // Live chat list - updated everytime Firestore emits
  List<ChatModel> _chats = [];
  StreamSubscription? _chatSubscription;

  String? _error;

  ChatListVM(super.ref)
    : _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // --- GETTERS ----------------------
  List<ChatModel> get chats => _chats;
  String? get error => _error;
  String? get currentId => _currentUid;
  bool get hasChats => _chats.isNotEmpty;

  bool isGroupType(ChatModel chat) => !chat.isDirect;
  
  @override
  FutureOr<void> init() {
    if (_currentUid == null) {
      _error = 'Not authenticated';
    } else {
      _subscribeToChatList();
    }
  }

  void _subscribeToChatList() {
    _chatSubscription = _chatService
        .streamChatList(_currentUid!)
        .listen(
          (chats) {
            _chats = chats;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  String chatDisplayName(ChatModel chat) => chat.displayName(_currentUid!);

  String? chatPhotoURL(ChatModel chat) => chat.displayPhotoUrl(_currentUid!);

  int chatUnreadCount(ChatModel chat) => chat.unreadCountFor(_currentUid!);

  String? typingText(ChatModel chat) {
    final others = chat.typingUsers.where((uid) => uid != _currentUid).toList();

    if (others.isEmpty) return null;

    final names = others
        .map((uid) => chat.memberInfo[uid]?.displayName ?? 'Someone')
        .toList();

    if (names.length == 1) {
      return '${names.first} is typing...';
    } else {
      return '${names.join(', ')} others are typing...';
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
  }
}

final chatListVM = ChangeNotifierProvider.autoDispose<ChatListVM>(
  (ref) => ChatListVM(ref),
);
