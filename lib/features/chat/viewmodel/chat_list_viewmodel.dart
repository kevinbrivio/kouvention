import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:oktoast/oktoast.dart';

enum ChatFilter { all, direct, group }

class ChatListVM extends BaseNotifier {
  final ChatService _chatService;
  final String? _currentUid;

  // Live chat list - updated everytime Firestore emits
  List<ChatModel> _chats = [];
  StreamSubscription? _chatSubscription;

  // Filter chats
  ChatFilter _filter = ChatFilter.all;

  // Pin chat
  static const maxPinnedChat = 3;
  final Set<String> _selectedChatIds = {};

  String? _error;

  ChatListVM(super.ref)
    : _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // --- GETTERS ----------------------
  List<ChatModel> get chats => _chats;
  String? get error => _error;
  String? get currentId => _currentUid;
  bool get hasChats => _chats.isNotEmpty;
  ChatFilter get filter => _filter;

  bool isGroupType(ChatModel chat) => !chat.isDirect;

  Set<String> get selectedChatIds => _selectedChatIds;
  bool get isSelectionMode => _selectedChatIds.isNotEmpty;

  List<ChatModel> get selectedChats =>
      _chats.where((c) => _selectedChatIds.contains(c.id)).toList();

  void selectChat(String chatId) {
    if (_selectedChatIds.contains(chatId)) {
      _selectedChatIds.remove(chatId);
    } else {
      _selectedChatIds.add(chatId);
    }
    notifyListeners();
  }

  void clearSection() {
    _selectedChatIds.clear();
    notifyListeners();
  }

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
            _chats =
                chats.where((chat) => !chat.isDeletedBy(_currentUid)).toList()
                  ..sort((a, b) {
                    // Pinned first
                    final aPinned = a.isPinnedBy(_currentUid) ? 0 : 1;
                    final bPinned = b.isPinnedBy(_currentUid) ? 0 : 1;
                    if (aPinned != bPinned) return aPinned.compareTo(bPinned);
                    // Then by last message
                    final aTime = a.lastMessage?.sentAt ?? a.createdAt;
                    final bTime = b.lastMessage?.sentAt ?? b.createdAt;
                    return bTime.compareTo(aTime);
                  });
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  void setFilter(ChatFilter value) {
    _filter = value;
    clearSection();
    notifyListeners();
  }

  List<ChatModel> get filteredChats {
    switch (_filter) {
      case ChatFilter.all:
        return chats;
      case ChatFilter.direct:
        return chats.where((chat) => chat.type == 'direct').toList();
      case ChatFilter.group:
        return chats.where((chat) => chat.type == 'group').toList();
    }
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

  // ---- PIN ---------------
  Future<void> pinSelectedChats() async {
    final unpinned = selectedChats
        .where((c) => !c.isPinnedBy(_currentUid!))
        .toList();

    if (unpinned.isEmpty) {
      // This mean all selected are pinned
      for (final chat in selectedChats) {
        await _chatService.unpinChat(_currentUid!, chat.id);
      }
      clearSection();
      return;
    }
    
    final currentPinnedCount = _chats.where((c) => c.isPinnedBy(_currentUid!)).length;
    if (currentPinnedCount + unpinned.length > maxPinnedChat) {
      showToast('You can only pin up to $maxPinnedChat chats', position: ToastPosition.bottom);
      clearSection();
      return;
    }
  
    for (final chat in unpinned) {
      await _chatService.pinChat(_currentUid!, chat.id);
    }
    
    clearSection();
  }

  Future<void> deleteSelectedChat() async {
    for (final chat in selectedChats) {
      await _chatService.deleteChat(_currentUid!, chat.id);
    }
    clearSection();
  }

  Future<void> pinChat(String chatId) async {
    await _chatService.pinChat(_currentUid!, chatId);
  }

  Future<void> unpinChat(String chatId) async {
    await _chatService.unpinChat(_currentUid!, chatId);
  }

  Future<void> deleteChat(String chatId) async {
    await _chatService.deleteChat(_currentUid!, chatId);
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
