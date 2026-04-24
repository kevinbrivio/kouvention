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

  final chats = await chatService.streamChatList(currentUid).first;

  // Get other users with 'direct' type of chat
  final otherUids = chats
      .where((chat) => chat.type == 'direct')
      .map((chat) => chat.otherMemberUid(currentUid))
      .toList();

  final users = <UserModel>[];
  for (final uid in otherUids) {
    final user = await userService.getUser(uid);
    if (user != null) users.add(user);
  }

  return users;
});
