import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart'
    show kChatListPageSize;
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

const int kRecentUsersLimit = 20;

/// Firestore `whereIn` upper bound. Chunks must not exceed this.
const int _kWhereInChunk = 10;

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
      if (chat.members.length < 2) continue;
      if (!chat.members.contains(currentUid)) continue;
      if (chat.lastMessage == null) continue;
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

Stream<List<ChatModel>> watchRecentChatsFromDrift(
  MessageDatabase db, {
  required String currentUid,
}) {
  return db
      .watchPagedChats(currentUid: currentUid)
      .map((rows) => rows.map(chatModelFromDriftRow).toList());
}

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
    await for (final chats in watchRecentChatsFromDrift(
      db,
      currentUid: currentUid,
    )) {
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
