import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  final String? _currentUid;

  // Filter chats
  ChatFilter _filter = ChatFilter.all;

  // Pin chat
  static const maxPinnedChat = 3;

  // Selected chat
  final Set<String> _selectedChatIds = {};

  // Pagination
  bool _isLoadingMore = false;

  String? _error;

  ChatListVM(super.ref)
    : _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // --- GETTERS ----------------------
  String? get error => _error;
  String? get currentId => _currentUid;
  ChatFilter get filter => _filter;
  bool get isLoadingMore => _isLoadingMore;
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
  // PAGINATION
  // ================================
  Future<void> fetchOlderChats() async {
    if (_currentUid == null || _isLoadingMore) return;

    final cursor = ref.read(chatCursorProvider);
    if (cursor == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final fetched = await _chatService.fetchChatRooms(
        _currentUid,
        limit: 20,
        startAfter: cursor,
      );

      if (fetched.isNotEmpty) {
        final db = ref.read(messageDatabaseProvider);
        final companions = <ChatsCompanion>[];
        for (final c in fetched) {
          final existing = await db.getChatById(c.id);
          companions.add(
            SyncService.chatToCompanion(
              c,
              lastSyncAt: existing?.lastSyncTimestamp,
            ),
          );
        }
        await db.upsertChatRooms(companions);

        if (fetched.length < 20) {
          ref.read(chatCursorProvider.notifier).state = null;
        } else {
          final sentAt = fetched.last.lastMessage?.sentAt ?? fetched.last.createdAt;
          ref.read(chatCursorProvider.notifier).state = sentAt;
        }
      }
    } catch (e) {
      debugPrint('fetchOlderChats failed: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
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

final chatCursorProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

final typingUsersProvider =
    StreamProvider.autoDispose<Map<String, List<String>>>((ref) {
      final chatService = ref.watch(chatServiceProvider);
      final currentUid = ref.watch(authServiceProvider).currentUser?.uid;
      if (currentUid == null) return Stream.value({});

      return chatService.streamChatList(currentUid, limit: 20).map(
        (chats) => {for (final chat in chats) chat.id: chat.typingUsers},
      );
    });

/// Keeps the local Drift [Chats] table in sync with Firestore.
///
/// Subscribes to a real-time snapshot of the **top 20** most recently
/// updated chats — any chat that pushes its [updatedAt] forward naturally
/// enters the watched set.
///
/// On the first stream emission, initializes the pagination cursor from
/// the 20th chat so [ChatListVM.fetchOlderChats] can load more.
///
/// Lives as long as the [MainShell] is mounted (i.e. while the user is
/// authenticated). Cancels the subscription on dispose.
final realtimeChatSyncProvider = Provider.autoDispose<void>((ref) {
  final uid = ref.watch(authServiceProvider).currentUser?.uid;
  if (uid == null) return;

  final db = ref.read(messageDatabaseProvider);
  final chatService = ref.read(chatServiceProvider);

  final sub = chatService
      .streamChatList(uid, limit: 20)
      .listen((chats) async {
        final companions = <ChatsCompanion>[];
        for (final c in chats) {
          final existing = await db.getChatById(c.id);
          companions.add(
            SyncService.chatToCompanion(
              c,
              lastSyncAt: existing?.lastSyncTimestamp,
            ),
          );
        }
        unawaited(db.upsertChatRooms(companions));

        // Initialize cursor from the 20th chat on first emission
        if (chats.isNotEmpty && ref.read(chatCursorProvider) == null) {
          final sentAt = chats.last.lastMessage?.sentAt ?? chats.last.createdAt;
          ref.read(chatCursorProvider.notifier).state = sentAt;
        }
      });

  ref.onDispose(() => sub.cancel());
});

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
      final typingUsersMap = ref.watch(typingUsersProvider).valueOrNull ?? {};
      final filter = ref.watch(chatListVM).filter;
      final currentUid = ref.watch(authServiceProvider).currentUser?.uid;

      return chatAsyncValue.whenData((chats) {
        List<ChatModel> filtered = chats.map((chat) {
          final typing = typingUsersMap[chat.id];
          if (typing == null) return chat;
          return chat.copyWith(typingUsers: typing);
        }).toList();

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
