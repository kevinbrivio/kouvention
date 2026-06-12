import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart'
    show kChatListPageSize;
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

/// Maximum number of recent users surfaced in the "New Chat" screen.
///
/// 20 keeps the cost to two whereIn batches (≤10 per chunk) for the profile
/// fetch. The first 20 chats in Drift are pinned to the top 50 by the
/// paged inbox stream, so this list reflects the user's actual recent
/// activity rather than a Firestore scan.
const int kRecentUsersLimit = 20;

/// Firestore `whereIn` upper bound. Chunks must not exceed this.
const int _kWhereInChunk = 10;

/// Pure resolver: given the first 20 chats from Drift (already ordered
/// recency DESC) and the current user's UID, return up to [limit] UIDs
/// to look up. One UID per chat, in input order, deduplicated.
///
/// Rules (pinned by `test/recent_users_extraction_test.dart`):
///   * direct chat → `chat.otherMemberUid(currentUid)`
///   * group chat  → `chat.lastMessage.sentBy` (skip null/empty, skip self)
///   * never returns `currentUid`
///   * bounded to [limit] (default [kRecentUsersLimit])
List<String> extractRecentUids({
  required List<ChatModel> chats,
  required String currentUid,
  int limit = kRecentUsersLimit,
}) {
  final seen = <String>{};
  final result = <String>[];

  for (final chat in chats) {
    if (result.length >= limit) break;

    String? uid;
    if (chat.isDirect) {
      // Defensive: a direct chat with only one member (just `currentUid`)
      // is malformed and otherMemberUid() asserts. Skip rather than crash.
      if (chat.members.length < 2) continue;
      if (!chat.members.contains(currentUid)) continue;
      uid = chat.otherMemberUid(currentUid);
    } else {
      final sentBy = chat.lastMessage?.sentBy;
      if (sentBy == null || sentBy.isEmpty || sentBy == currentUid) continue;
      uid = sentBy;
    }

    if (uid.isEmpty || uid == currentUid) continue;
    if (seen.contains(uid)) continue;

    seen.add(uid);
    result.add(uid);
  }

  return result;
}

/// Maps a Drift `Chat` row to a [ChatModel]. Exposed so the integration
/// test (`test/recent_users_provider_test.dart`) and the chat list
/// provider can share the same shape without duplicating the mapping.
///
/// Mirrors the mapping in `pagedChatListProvider` (chat_list_viewmodel.dart).
ChatModel chatModelFromDriftRow(Chat row) => ChatModel(
    id: row.id,
    type: row.type,
    members: row.members,
    memberInfo: row.memberInfo,
    groupName: row.groupName,
    groupPhotoUrl: row.groupPhotoUrl,
    pinnedBy: row.pinnedBy,
    unreadCount: Map<String, int>.from(row.unreadCount),
    lastReadAt: Map<String, DateTime>.from(row.lastReadAt),
    lastMessage: row.lastMessage,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: row.updatedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.updatedAt!)
        : null,
    // deletedBy is JSON-decoded in the paged provider; not needed for
    // the recent users list.
    deletedBy: null,
    createdBy: row.createdBy,
    typingUsers: const [],
    memberHash: null,
  );

/// Watches the first [kChatListPageSize] chats from Drift and maps them
/// to [ChatModel]s. Drift is the local source of truth for visible UI
/// state (AGENTS.md §3) — we never read chat list data from Firestore
/// on the New Chat View.
Stream<List<ChatModel>> watchRecentChatsFromDrift(
  MessageDatabase db, {
  required String currentUid,
}) {
  return db.watchPagedChats(
    currentUid: currentUid,
  ).map((rows) => rows.map(chatModelFromDriftRow).toList());
}

/// Batches a Firestore `whereIn` fetch of user profiles, respecting the
/// 10-document chunk limit. Returns users in the same order as the
/// input UID list (UIDs missing from Firestore are simply absent).
Future<List<UserModel>> fetchProfilesInOrder({
  required UserService userService,
  required List<String> uids,
}) async {
  if (uids.isEmpty) return const [];

  final fetched = <UserModel>[];
  for (var i = 0; i < uids.length; i += _kWhereInChunk) {
    final end = (i + _kWhereInChunk).clamp(0, uids.length);
    final chunk = await userService.fetchUserByUids(uids.sublist(i, end));
    fetched.addAll(chunk);
  }

  // Re-sort into the same order as the UID list (recency-based).
  final byUid = {for (final u in fetched) u.uid: u};
  return uids.map((uid) => byUid[uid]).whereType<UserModel>().toList();
}

/// Recent users for the New Chat screen.
///
/// Pipeline:
///   1. Watch up to [kChatListPageSize] chats from Drift (local source of
///      truth, AGENTS.md §3). Re-emits when Drift changes.
///   2. Extract up to [kRecentUsersLimit] UIDs via [extractRecentUids].
///   3. Batch-fetch the matching user profiles from Firestore (chunked by
///      10 to respect `whereIn`).
///   4. Re-sort profiles to match the recency order.
///
/// Errors bubble up as `AsyncValue.error` so the UI can render the
/// "Failed to load recent users" state (see `recent_users_list.dart`).
final recentUsersProvider = StreamProvider.autoDispose<List<UserModel>>((
  ref,
) async* {
  final authService = ref.read(authServiceProvider);
  final userService = ref.read(userServiceProvider);
  final db = ref.read(messageDatabaseProvider);

  final currentUid = authService.currentUser?.uid;
  if (currentUid == null) {
    yield const <UserModel>[];
    return;
  }

  try {
    await for (final chats in watchRecentChatsFromDrift(db, currentUid: currentUid)) {
      final uids = extractRecentUids(chats: chats, currentUid: currentUid);
      if (uids.isEmpty) {
        yield const <UserModel>[];
        continue;
      }
      yield await fetchProfilesInOrder(userService: userService, uids: uids);
    }
  } catch (e, st) {
    debugPrint('[recentUsersProvider] failed: $e\n$st');
    throw e; // Preserve error for AsyncValue.error state
  }
});
