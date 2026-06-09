import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

final recentUsersProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  final userService = ref.read(userServiceProvider);
  final authService = ref.read(authServiceProvider);
  final chatService = ref.read(chatServiceProvider);

  final currentUid = authService.currentUser?.uid;
  if (currentUid == null) return [];

  // One-shot paged fetch — no live stream listener (AGENTS.md §9.2).
  final chats = await chatService.fetchChatRoomsPage(
    currentUid: currentUid,
    limit: 20,
  );

  // Get other UIDs from direct chats, preserving recency order.
  final otherUids = chats
      .where((chat) => chat.type == 'direct')
      .map((chat) => chat.otherMemberUid(currentUid))
      .toList();

  if (otherUids.isEmpty) return [];

  // Batch Firestore read, chunked to respect whereIn ≤10.
  final users = <UserModel>[];
  for (var i = 0; i < otherUids.length; i += 10) {
    final chunk = otherUids.sublist(
      i,
      i + 10 > otherUids.length ? otherUids.length : i + 10,
    );
    users.addAll(await userService.fetchUserByUids(chunk));
  }

  // Re-sort into the same order as the chat list (most recent first).
  final byUid = {for (final u in users) u.uid: u};
  return otherUids.map((uid) => byUid[uid]).whereType<UserModel>().toList();
});
