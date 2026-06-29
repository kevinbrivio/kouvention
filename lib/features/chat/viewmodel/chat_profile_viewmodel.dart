import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/utils/log.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

final chatProfileVM = ChangeNotifierProvider.autoDispose
    .family<ChatProfileVM, String>(
      (ref, chatId) => ChatProfileVM(ref, chatId: chatId),
    );

class ChatProfileVM extends BaseNotifier {
  final String chatId;
  final String? _currentUid;
  final UserService _userService;
  final ChatService _chatService;

  ChatProfileVM(super.ref, {required this.chatId})
    : _userService = ref.read(userServiceProvider),
      _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  ChatModel? _chat;
  List<UserModel> _users = [];
  List<ChatModel> _groupsInCommon = [];

  // GETTERS
  ChatModel? get chat => _chat;
  UserModel? get otherUser =>
      _chat?.type == 'direct' ? _users.firstOrNull : null;
  List<MapEntry<String, MemberInfo>> get members =>
      _chat?.memberInfo.entries.toList() ?? [];
  bool get isGroupType => _chat?.type == 'group';
  String? get otherUserEmail =>
      _chat?.type == 'direct' ? _users.firstOrNull?.email : '';
  List<ChatModel> get groupsInCommon => _groupsInCommon;

  @override
  FutureOr<void> init() async {
    _chat = await _chatService.getChat(chatId);

    if (_chat?.type == 'direct') {
      final otherUid = _chat!.otherMemberUid(_currentUid!);
      final user = await _userService.getUser(otherUid);
      if (user != null) _users = [user];
      _groupsInCommon = await _chatService.getGroupInCommon(
        _currentUid,
        otherUid,
      );
    }
  }

  Future<String> getOrCreateDirectChat(String otherUid) async {
    final otherMember = _chat!.memberInfo[otherUid];
    final currentMember = _chat!.memberInfo[_currentUid];

    return await _chatService.createDirectChat(
      currentUid: _currentUid!,
      otherUid: otherUid,
      memberInfo: {_currentUid: currentMember!, otherUid: otherMember!},
    );
  }

  Future<void> navigateTo(BuildContext context, RouterRoute route, String memberId) async {
    isLoading = true;
    try {
      final chatId = await getOrCreateDirectChat(memberId);
      if (context.mounted) {
        if (route == RouterRoutes.chatDetail) {
          context.push('/chats/$chatId/detail');
        } else if (route == RouterRoutes.chatRoom) {
          context.go('/chats/$chatId');
        }
      }
    } catch (e) {
      eLog('Navigating in profile detail error: $e');
    } finally {
      isLoading = false;
    }
  }

  String get chatDisplayName {
    if (_chat == null) return '';
    if (isGroupType) return _chat!.groupName ?? '';
    // For direct chats, get the other user's name from memberInfo
    final otherUid = _chat!.members.firstWhere(
      (uid) => uid != _currentUid,
      orElse: () => '',
    );
    return _chat!.memberInfo[otherUid]?.displayName ?? '';
  }

  String? get chatPhotoURL {
    if (_chat == null) return null;
    if (isGroupType) return _chat!.groupPhotoUrl;
    final otherUid = _chat!.members.firstWhere(
      (uid) => uid != _currentUid,
      orElse: () => '',
    );
    return _chat!.memberInfo[otherUid]?.photoUrl;
  }
}
