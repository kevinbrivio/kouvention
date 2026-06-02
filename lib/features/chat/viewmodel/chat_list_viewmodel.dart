import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';
import 'package:oktoast/oktoast.dart';

enum ChatFilter { all, direct, group }

class ChatListVM extends BaseNotifier {
  final ChatService _chatService;
  final SyncService _syncService;
  final String? _currentUid;

  // Filter chats
  ChatFilter _filter = ChatFilter.all;

  // Pin chat
  static const maxPinnedChat = 3;

  // Selected chat
  final Set<String> _selectedChatIds = {};

  String? _error;

  ChatListVM(super.ref)
    : _chatService = ref.read(chatServiceProvider),
      _syncService = ref.read(syncServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // --- GETTERS ----------------------
  String? get error => _error;
  String? get currentId => _currentUid;
  ChatFilter get filter => _filter;
  bool isGroupType(ChatModel chat) => !chat.isDirect;
  Set<String> get selectedChatIds => _selectedChatIds;
  bool get isSelectionMode => _selectedChatIds.isNotEmpty;
  bool get isSelectedChatsPinned {
    final allChats = _currentChatFromStream;
    final selected = allChats.where(
      (chat) => selectedChatIds.contains(chat.id),
    );
    if (selected.isEmpty) return false;

    return selected.every((chat) => chat.isPinnedBy(currentId!));
  }

  @override
  FutureOr<void> init() {
    if (_currentUid == null) {
      _error = 'Not authenticated';
    }

    // Sync all chat rooms from Firestore -> Local
    _syncService.syncInitialChatRooms(currentId!);
  }

  List<ChatModel> get _currentChatFromStream =>
      ref.read(localChatListFromStreamProvider).value ?? [];

  // ---- PIN ---------------
  Future<void> pinSelectedChats() async {
    if (_currentUid == null) return;

    final db = ref.read(messageDatabaseProvider);
    final allChats = _currentChatFromStream;
    final selectedChats = allChats
        .where((c) => _selectedChatIds.contains(c.id))
        .toList();
    final unpinned = selectedChats
        .where((c) => !c.isPinnedBy(_currentUid))
        .toList();

    if (unpinned.isEmpty) {
      for (final chat in selectedChats) {
        await _chatService.unpinChat(_currentUid, chat.id);
        await db.unpinChatLocally(chat.id, _currentUid);
      }
      clearSelection();
      return;
    }

    final currentPinnedCount = allChats
        .where((c) => c.isPinnedBy(_currentUid))
        .length;

    if (currentPinnedCount + unpinned.length > maxPinnedChat) {
      showToast(
        'You can only pin up to $maxPinnedChat chats',
        position: ToastPosition.bottom,
      );
      clearSelection();
      return;
    }

    for (final chat in unpinned) {
      await _chatService.pinChat(_currentUid, chat.id);
      await db.pinChatLocally(chat.id, _currentUid);
    }
    clearSelection();
  }

  Future<void> pinChat(String chatId) async {
    if (_currentUid != null) {
      final db = ref.read(messageDatabaseProvider);
      await _chatService.pinChat(_currentUid, chatId);
      await db.pinChatLocally(chatId, _currentUid);
    }
  }

  Future<void> unpinChat(String chatId) async {
    if (_currentUid != null) {
      final db = ref.read(messageDatabaseProvider);
      await _chatService.unpinChat(_currentUid, chatId);
      await db.unpinChatLocally(chatId, _currentUid);
    }
  }

  Future<void> deleteSelectedChat() async {
    if (_currentUid == null) return;

    final db = ref.read(messageDatabaseProvider);
    final allChats = _currentChatFromStream;
    final selectedChats = allChats
        .where((c) => _selectedChatIds.contains(c.id))
        .toList();

    for (final chat in selectedChats) {
      await _chatService.deleteChat(_currentUid, chat.id);
      await db.markChatDeletedLocally(chat.id, _currentUid);
    }
    clearSelection();
  }

  Future<void> deleteChat(String chatId) async {
    if (_currentUid != null) {
      final db = ref.read(messageDatabaseProvider);
      await _chatService.deleteChat(_currentUid, chatId);
      await db.markChatDeletedLocally(chatId, _currentUid);
    }
  }

  // ================================
  // HELPER
  // ================================

  void selectChat(String chatId) {
    if (_selectedChatIds.contains(chatId)) {
      _selectedChatIds.remove(chatId);
    } else {
      _selectedChatIds.add(chatId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedChatIds.clear();
    notifyListeners();
  }

  void setFilter(ChatFilter value) {
    _filter = value;
    clearSelection();
    notifyListeners();
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
}

final chatListVM = ChangeNotifierProvider.autoDispose<ChatListVM>(
  (ref) => ChatListVM(ref),
);

final localChatListFromStreamProvider =
    StreamProvider.autoDispose<List<ChatModel>>((ref) {
      final db = ref.watch(messageDatabaseProvider);

      return db.watchChatRooms().map(
        (driftChats) => driftChats
            .map(
              (c) => ChatModel(
                id: c.id,
                type: c.type,
                members: c.members,
                memberInfo: c.memberInfo,
                groupName: c.groupName,
                groupPhotoUrl: c.groupPhotoUrl,
                pinnedBy: c.pinnedBy,
                unreadCount: c.unreadCount,
                lastReadAt: c.lastReadAt,
                lastMessage: c.lastMessage,

                createdAt: DateTime.fromMillisecondsSinceEpoch(c.createdAt),
                updatedAt: c.updatedAt != null
                    ? DateTime.fromMillisecondsSinceEpoch(c.updatedAt!)
                    : null,

                deletedBy: c.deletedBy != null
                    ? jsonDecode(c.deletedBy!)
                    : null,
                createdBy: c.createdBy,

                typingUsers: [],
                memberHash: null,
              ),
            )
            .toList(),
      );
    });

final filteredChatListProvider =
    Provider.autoDispose<AsyncValue<List<ChatModel>>>((ref) {
      final chatAsyncValue = ref.watch(localChatListFromStreamProvider);
      final filter = ref.watch(chatListVM).filter;
      final currentUid = ref.watch(authServiceProvider).currentUser?.uid;

      return chatAsyncValue.whenData((chats) {
        List<ChatModel> filtered = chats;

        // 1. Filter out deleted chats
        if (currentUid != null) {
          filtered = filtered
              .where((c) => !c.isDeletedBy(currentUid))
              .toList();
        }

        // 2. Type filter
        if (filter == ChatFilter.direct) {
          filtered = filtered.where((c) => c.type == 'direct').toList();
        } else if (filter == ChatFilter.group) {
          filtered = filtered.where((c) => c.type == 'group').toList();
        }

        // 3. Sorting
        if (currentUid != null) {
          filtered.sort((a, b) {
            final aPinned = a.isPinnedBy(currentUid) ? 0 : 1;
            final bPinned = b.isPinnedBy(currentUid) ? 0 : 1;

            if (aPinned != bPinned) return aPinned.compareTo(bPinned);

            final aTime = a.lastMessage?.sentAt ?? a.createdAt;
            final bTime = b.lastMessage?.sentAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          });
        }

        return filtered;
      });
    });
