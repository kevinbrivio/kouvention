import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart'
    show kChatListMaxCached, kChatListPageSize;
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
  Stream<ChatModel?> watchChat(String chatId) => _chatService.streamChat(chatId);

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

  // --- Inbox (first page) ----------------------------

  /// Streams the first page of the inbox (top [limit] chats). The stream
  /// seeds Drift with a one-shot fetch, then attaches the realtime
  /// listener. All chat rows are upserted with the existing
  /// `latestSeenRemoteAt` preserved per-id.
  ///
  /// Caller is responsible for clamping [limit] to the screen-scoped
  /// window (50 by default per AGENTS.md §11.1).
  Stream<List<ChatModel>> firstPageStream(String uid, {int limit = 50}) async* {
    try {
      final initial = await _chatService.fetchChatRoomsPage(
        currentUid: uid,
        limit: limit,
      );
      if (initial.isNotEmpty) {
        await _persistChats(initial);
        await _db.evictOldestChats(keep: kChatListMaxCached);
      }
    } catch (e) {
      debugPrint('firstPageStream: initial fetch failed: $e');
    }
    yield* _chatService
        .streamChatList(uid, limit: limit)
        .asyncMap((chats) async {
          await _persistChats(chats);
          return chats;
        });
  }

  // --- Inbox (older pages) ---------------------------

  /// Fetches the next older chat page using the compound
  /// `(lastMessage.sentAt, chatId)` cursor. Returns the fetched chats;
  /// the caller is responsible for updating its own cursor state
  /// (`chatCursorProvider`).
  ///
  /// Preserves the existing `latestSeenRemoteAt` per row via a single
  /// `getChatsByIds` lookup (AGENTS.md §9.10). Triggers 200-chat LRU
  /// eviction after a successful write.
  Future<List<ChatModel>> fetchOlderChatsPage({
    required String uid,
    required int limit,
    ChatCursor? cursor,
  }) async {
    final fetched = await _chatService.fetchChatRoomsPage(
      currentUid: uid,
      limit: limit,
      cursor: cursor,
    );
    if (fetched.isEmpty) return fetched;

    await _persistChats(fetched);
    await _db.evictOldestChats(keep: kChatListMaxCached);
    return fetched;
  }

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

  Future<void> _persistChats(List<ChatModel> chats) async {
    if (chats.isEmpty) return;
    final existing = await _db.getChatsByIds(chats.map((c) => c.id).toList());
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
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    chatService: ref.watch(chatServiceProvider),
    db: ref.watch(messageDatabaseProvider),
  );
});

// Re-export the page-size constants so consumers that already import
// the repository don't also need the viewmodel header.
const int chatListPageSize = kChatListPageSize;
const int chatListMaxCached = kChatListMaxCached;
