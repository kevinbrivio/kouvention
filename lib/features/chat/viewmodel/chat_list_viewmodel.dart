import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/repositories/chat_repository.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:oktoast/oktoast.dart';

enum ChatFilter { all, direct, group }

const int kChatListPageSize = 50;

class ChatListVM extends BaseNotifier {
  final ChatRepository _chatRepository;
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
    : _chatRepository = ref.read(chatRepositoryProvider),
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
      ref.read(pagedChatListProvider).value ?? const <ChatModel>[];

  // ---- PIN ---------------
  Future<void> pinSelectedChats() async {
    if (_currentUid == null) return;

    final allChats = _currentChatFromStream;
    final selectedChats = allChats
        .where((c) => _selectedChatIds.contains(c.id))
        .toList();
    final unpinned = selectedChats
        .where((c) => !c.isPinnedBy(_currentUid))
        .toList();

    if (unpinned.isEmpty) {
      for (final chat in selectedChats) {
        await _chatRepository.unpinChat(_currentUid, chat.id);
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
      await _chatRepository.pinChat(_currentUid, chat.id);
    }
    clearSelection();
  }

  Future<void> pinChat(String chatId) async {
    if (_currentUid != null) {
      await _chatRepository.pinChat(_currentUid, chatId);
    }
  }

  Future<void> unpinChat(String chatId) async {
    if (_currentUid != null) {
      await _chatRepository.unpinChat(_currentUid, chatId);
    }
  }

  Future<void> deleteSelectedChat() async {
    if (_currentUid == null) return;

    final allChats = _currentChatFromStream;
    final selectedChats = allChats
        .where((c) => _selectedChatIds.contains(c.id))
        .toList();

    for (final chat in selectedChats) {
      await _chatRepository.deleteChat(_currentUid, chat.id);
    }
    clearSelection();
  }

  Future<void> deleteChat(String chatId) async {
    if (_currentUid != null) {
      await _chatRepository.deleteChat(_currentUid, chatId);
    }
  }

  /// Get the visible chats into UI
  List<ChatModel> get visibleChats =>
      ref.read(filteredChatListProvider).value ?? [];

  // ================================
  // PAGINATION
  // ================================
  /// Loads the next page of older chats from Firestore. The cursor and
  /// end-of-list flag live in the A-explicit columns on the [chats] table
  /// (denormalized — every row carries the same values). One SELECT per
  /// scroll check, one UPDATE per page fetch.
  Future<void> fetchOlderChats() async {
    if (_currentUid == null || _isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final db = ref.read(messageDatabaseProvider);

      // Read A-explicit state from any row.
      final state = await db.getChatListPaginationState();
      if (!state.hasMore) {
        debugPrint('⏸️ fetchOlderChats skipped: no more chats (DB)');
        return;
      }

      // Build cursor from denormalized columns.
      ChatCursor? cursor;
      if (state.activityAt != null && state.chatId != null) {
        cursor = (
          lastActivityAt:
              DateTime.fromMillisecondsSinceEpoch(state.activityAt!),
          chatId: state.chatId!,
        );
      }

      final fetched = await _chatRepository.fetchOlderChatsPage(
        uid: _currentUid,
        limit: kChatListPageSize,
        cursor: cursor,
      );

      if (fetched.isEmpty) {
        await db.updateChatListPaginationState(hasMore: false);
        debugPrint('🏁 Reached end of Firestore (empty page)');
      } else if (fetched.length < kChatListPageSize) {
        final lastChat = fetched.last;
        await db.updateChatListPaginationState(
          hasMore: false,
          cursorActivityAt: (lastChat.lastMessage?.sentAt ?? lastChat.createdAt)
              .millisecondsSinceEpoch,
          cursorChatId: lastChat.id,
        );
        debugPrint(
          '🏁 Reached end of Firestore (got ${fetched.length} < $kChatListPageSize)',
        );
      } else {
        final lastChat = fetched.last;
        await db.updateChatListPaginationState(
          hasMore: true,
          cursorActivityAt: (lastChat.lastMessage?.sentAt ?? lastChat.createdAt)
              .millisecondsSinceEpoch,
          cursorChatId: lastChat.id,
        );
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
    ref.read(chatListFilterProvider.notifier).state = value;
    // Reset A-explicit pagination state. Fire-and-forget — the next scroll
    // read will see the cleared cursor and re-fetch page 1.
    ref.read(messageDatabaseProvider).updateChatListPaginationState(
      hasMore: true,
    );
    clearSelection();
  }

  int chatUnreadCount(ChatModel chat) => chat.unreadCountFor(_currentUid!);
}

final chatListVM = ChangeNotifierProvider.autoDispose<ChatListVM>(
  (ref) => ChatListVM(ref),
);

/// Filter for the chat list. Re-keyed when the filter changes so any
/// filter-dependent state (page window, cursor) is reset cleanly.
final chatListFilterProvider = StateProvider.autoDispose<ChatFilter>(
  (ref) => ChatFilter.all,
);

/// IDs of chats currently visible in the user's viewport (debounced).
/// Updated by [ChatListView]'s scroll listener. Read by [ChatListVM] when
/// calling [ChatRepository.fetchOlderChatsPage] to exclude visible chats
/// from the LRU eviction (see [MessageDatabase.evictOldestChats]).
final visibleChatIdsProvider = StateProvider.autoDispose<Set<String>>(
  (ref) => const {},
);

// =============================================================
// SCREEN-SCOPED INBOX (top [kChatListPageSize] chats)
// =============================================================
//
// Single subscription to the first page of the inbox. On subscribe:
//   1. One-shot `fetchChatRoomsPage` to seed local Drift.
//   2. Live `streamChatList` listener that writes every update to Drift.
//
// The typing indicator and the chat list persistence both derive from this
// single stream, so the Firestore cost is one subscription per active
// screen. Replaces the old global `realtimeChatSyncProvider` in `MainShell`.
final inboxFirstPageProvider = StreamProvider.autoDispose<List<ChatModel>>((
  ref,
) async* {
  final uid = ref.watch(authServiceProvider).currentUser?.uid;
  if (uid == null) {
    yield const <ChatModel>[];
    return;
  }
  final chatRepository = ref.watch(chatRepositoryProvider);

  // The repository streams the first page, persisting each emission into
  // Drift (and triggering the 200-chat LRU eviction). The chat list UI
  // and the typing indicator both subscribe to this single stream.
  //
  // After the initial Firestore fetch, seed the compound cursor from
  // Firestore's sort order (lastMessage.sentAt DESC, __name__ DESC) so
  // the first scroll fetches page 2 — not page 1 again. Seeding from
  // Firestore's order avoids the Drift-sort-order mismatch that would
  // cause skipped or duplicated chats when pinned items reorder the
  // Drift page (see AGENTS.md §9.4).
  yield* chatRepository.firstPageStream(
    uid,
    limit: kChatListPageSize,
    onInitial: (initial) async {
      final last = initial.last;
      await ref.read(messageDatabaseProvider).updateChatListPaginationState(
        hasMore: true,
        cursorActivityAt:
            (last.lastMessage?.sentAt ?? last.createdAt).millisecondsSinceEpoch,
        cursorChatId: last.id,
      );
    },
  );
});

/// Typing indicator map derived from the screen-scoped inbox stream.
/// Sharing the underlying Firestore stream with [inboxFirstPageProvider]
/// keeps the cost to one subscription per active screen.
final typingUsersProvider = Provider.autoDispose<Map<String, List<String>>>((
  ref,
) {
  final inbox = ref.watch(inboxFirstPageProvider).valueOrNull;
  if (inbox == null) return const <String, List<String>>{};
  return {for (final chat in inbox) chat.id: chat.typingUsers};
});

// =============================================================
// PAGED LOCAL CHAT LIST
// =============================================================

/// Reactive, paged, SQL-sorted chat list (Drift rows).
///
/// Order is applied in SQL: pinned (for current user) first, then
/// `updated_at DESC, id DESC`. This replaces the unbounded
/// `watchChatRooms()` + in-Dart sort of the old pipeline.
final pagedChatListRowsProvider = StreamProvider.autoDispose<List<Chat>>((ref) {
  final filter = ref.watch(chatListFilterProvider);
  final currentUid = ref.watch(authServiceProvider).currentUser?.uid;
  final db = ref.read(messageDatabaseProvider);

  final typeFilter = switch (filter) {
    ChatFilter.direct => 'direct',
    ChatFilter.group => 'group',
    ChatFilter.all => null,
  };

  return db
      .watchPagedChats(
        typeFilter: typeFilter,
        currentUid: currentUid,
      )
      .map((rows) => rows);
});

/// Maps Drift rows to [ChatModel] and injects the typing users from the
/// screen-scoped inbox stream. This is the typed list the UI consumes.
final pagedChatListProvider = Provider.autoDispose<AsyncValue<List<ChatModel>>>(
  (ref) {
    final rowsAsync = ref.watch(pagedChatListRowsProvider);
    final typingUsersMap = ref.watch(typingUsersProvider);

    return rowsAsync.whenData((rows) {
      final mapped = rows
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

              deletedBy: c.deletedBy != null ? jsonDecode(c.deletedBy!) : null,
              createdBy: c.createdBy,

              typingUsers: const [],
              memberHash: null,
            ),
          )
          .toList();

      if (typingUsersMap.isEmpty) return mapped;

      return mapped.map((chat) {
        final typing = typingUsersMap[chat.id];
        if (typing == null) return chat;
        return chat.copyWith(typingUsers: typing);
      }).toList();
    });
  },
);

/// Final chat list passed to the UI. Type filter and sort are done in SQL
/// (see [pagedChatListRowsProvider]). The only post-page filter is
/// `isDeletedBy(currentUid)` — which is dynamic and depends on
/// `lastMessage.sentAt`, so it cannot live in SQL.
final filteredChatListProvider =
    Provider.autoDispose<AsyncValue<List<ChatModel>>>((ref) {
      final paged = ref.watch(pagedChatListProvider);
      final currentUid = ref.watch(authServiceProvider).currentUser?.uid;
      if (currentUid == null) return paged;
      return paged.whenData(
        (chats) => chats.where((c) => !c.isDeletedBy(currentUid)).toList(),
      );
    });
