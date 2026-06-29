import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart'
    show kChatListPageSize;
import 'package:kouvention/cores/utils/log.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';

/// Single owner of chat-list + chat-room remote reads/writes that view
/// models consume. Wraps [ChatService] (Firestore) and the in-process
/// [SyncService.chatToCompanion] helper, and keeps the local Drift mirror
/// in sync.
///
/// View models no longer import `chat_service.dart` directly — they go
/// through this repository so the I/O layer can move without touching
/// 5+ call sites.
class ChatRepository {
  ChatRepository({
    required ChatService chatService,
    required MessageDatabase db,
  }) : _chatService = chatService,
       _db = db;

  final ChatService _chatService;
  final MessageDatabase _db;

  // --- Single chat -----------------------------------

  /// Streams a single chat document from Firestore. Used for the
  /// chat-room screen header / metadata.
  Stream<ChatModel?> watchChat(String chatId) =>
      _chatService.streamChat(chatId);

  /// Fetches a single chat row from Firestore and mirrors it into Drift.
  /// Returns the fresh model, or null if the chat is missing remotely.
  /// Existing `latestSeenRemoteAt` is preserved.
  Future<ChatModel?> getChat(String chatId) async {
    final remote = await _chatService.getChat(chatId);
    if (remote == null) return null;
    final existing = await _db.getChatById(chatId);
    await _db.upsertChatRooms([
      SyncService.chatToCompanion(
        remote,
        latestSeenRemoteAt: existing?.latestSeenRemoteAt ?? 0,
      ),
    ]);

    return remote;
  }

  Future<ChatModel?> getOrCreateDirectChat({
    required String currentUid,
    required String otherUid,
    required Map<String, MemberInfo> memberInfo,
  }) async {
    final chatId = await _chatService.createDirectChat(
      currentUid: currentUid,
      otherUid: otherUid,
      memberInfo: memberInfo,
    );

    return getChat(chatId);
  }

  // --- Inbox (first page) ----------------------------

  /// Streams the first page of the inbox (top [limit] chats). The stream
  /// seeds Drift with a one-shot fetch, then attaches the realtime
  /// listener. All chat rows are upserted with the existing
  /// `latestSeenRemoteAt` preserved per-id.
  ///
  /// [onInitial] is called with the Firestore-ordered list after the
  /// one-shot fetch and Drift persist, before the realtime stream starts.
  /// Use it to seed the Firestore pagination cursor (see
  /// [ChatListVM.inboxFirstPageProvider]).
  ///
  /// Caller is responsible for clamping [limit] to the screen-scoped
  /// window (50 by default per AGENTS.md §11.1).
  Stream<List<ChatModel>> firstPageStream(
    String uid, {
    int limit = 20,
    Future<void> Function(List<ChatModel> initial)? onInitial,
  }) async* {
    // 1. One-shot initial fetch to seed Drift immediately.
    try {
      final initial = await _chatService.fetchChatRoomsPage(
        limit: limit,
        currentUid: uid,
      );
      if (initial.isNotEmpty) {
        await _persistChats(initial);
        await onInitial?.call(initial);
      }
    } catch (e) {
      eLog('firstPageStream: initial fetch failed: $e');
    }

    // 2. Attach live Firestore listener for the top [limit] chats.
    // Each emission is persisted to Drift so the UI (watchPagedChats)
    // re-renders on remote changes without re-reading Firestore.
    try {
      yield* _chatService.streamChatList(uid, limit: limit).map((chats) {
        unawaited(_persistChats(chats));
        return chats;
      });
    } catch (e) {
      eLog('firstPageStream: live stream failed: $e');
    }
  }

  // --- Inbox (older pages) ---------------------------

  /// Fetches the next older chat page using the compound
  /// `(lastMessage.sentAt, chatId)` cursor. Returns the fetched chats;
  /// the caller updates the A-explicit pagination state in Drift
  /// after the fetch completes.
  ///
  /// Preserves the existing `latestSeenRemoteAt` per row via a single
  /// eviction after a successful write.
  Future<List<ChatModel>> fetchOlderChatsPage({
    required String uid,
    int limit = 20,
    ChatCursor? cursor,
  }) async {
    dLog(
      '🌐 Firestore: fetching chats (cursor: ${cursor?.chatId ?? "none"})',
    );
    final fetched = await _chatService.fetchChatRoomsPage(
      limit: limit,
      currentUid: uid,
      cursor: cursor,
    );
    dLog('🌐 Firestore: got ${fetched.length} chats from remote');

    if (fetched.isEmpty) {
      dLog('🌐 Firestore: empty page, no more chats');
      return fetched;
    }

    await _persistChats(fetched);
    final total = await _db.getChatCount();
    dLog(
      '💾 Drift: persisted ${fetched.length} chats, total in Drift: $total',
    );
    return fetched;
  }

  Future<int> getChatListCount() async => await _db.getChatCount();

  // --- Mutations -------------------------------------

  Future<void> pinChat(String uid, String chatId) async {
    await _chatService.pinChat(uid, chatId);
    await _db.pinChatLocally(chatId, uid);
  }

  Future<void> unpinChat(String uid, String chatId) async {
    await _chatService.unpinChat(uid, chatId);
    await _db.unpinChatLocally(chatId, uid);
  }

  Future<void> deleteChat(String uid, String chatId) async {
    await _chatService.deleteChat(uid, chatId);
    await _db.markChatDeletedLocally(chatId, uid);
  }

  // --- Helpers ---------------------------------------

  /// Persists chats to Drift, preserving existing sync state.
  /// Returns `true` if any new rows were inserted (not just updated).
  Future<bool> _persistChats(List<ChatModel> chats) async {
    if (chats.isEmpty) return false;
    final existing = await _db.getChatsByIds(chats.map((c) => c.id).toList());
    final newIds = chats
        .where((c) => !existing.containsKey(c.id))
        .map((c) => c.id)
        .toSet();

    final companions = <ChatsCompanion>[];
    for (final c in chats) {
      final ex = existing[c.id];
      companions.add(
        SyncService.chatToCompanion(
          c,
          latestSeenRemoteAt: ex?.latestSeenRemoteAt ?? 0,
        ),
      );
    }

    await _db.upsertChatRooms(companions);
    return newIds.isNotEmpty;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(
    chatService: ref.watch(chatServiceProvider),
    db: ref.watch(messageDatabaseProvider),
  ),
);

// Re-export the page-size constants so consumers that already import
// the repository don't also need the viewmodel header.
const int chatListPageSize = kChatListPageSize;
