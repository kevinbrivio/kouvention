import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/utils/display_name_resolver.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_profile_provider.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';

class ChatListItem extends ConsumerWidget {
  final ChatModel chat;
  final bool isLastItem;

  const ChatListItem({super.key, required this.chat, required this.isLastItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(chatListVM);
    final scheme = Theme.of(context).colorScheme;

    final unread = vm.chatUnreadCount(chat);
    final lastMessage = chat.lastMessage;
    final isPinned = chat.isPinnedBy(vm.currentId!);
    final isSelected = vm.selectedChatIds.contains(chat.id);

    final resolver = ref.watch(chatListProfileResolverProvider);
    final displayName = resolveDisplayName(chat: chat, currentUid: vm.currentId!, resolver: resolver);
    final photoUrl = resolveDisplayPhotoUrl(chat: chat, currentUid: vm.currentId!, resolver: resolver);
    final initialLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    final typingText = _resolveTypingText(chat, vm.currentId!, resolver);

    bool showAvatarPhoto;
    final isGroup = !chat.isDirect;
    if (!isGroup) {
      final otherUid = chat.otherMemberUid(vm.currentId!);
      final otherUser = ref.watch(otherUserStreamProvider(otherUid)).value;
      showAvatarPhoto = otherUser?.privacy.showProfilePhoto ?? true;
    } else {
      showAvatarPhoto = true;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onLongPress: () => vm.selectChat(chat.id),
          onTap: () {
            HapticFeedback.selectionClick();
            if (vm.isSelectionMode) {
              vm.selectChat(chat.id);
            } else {
              context.push('/chats/${chat.id}');
            }
          },
          splashColor: scheme.onSurface.withValues(alpha: 0.2),
          highlightColor: scheme.onSurface.withValues(alpha: 0.1),
          child: Container(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: AppSpacing.sm.h,
            ),
            child: Row(
              children: [
                _buildAvatar(context, initialLetter, showAvatarPhoto, photoUrl, isGroup, isSelected, scheme),
                Gap(AppSpacing.sm.w),
                _buildMessagePreview(context, displayName, lastMessage, typingText, scheme),
                Gap(4.w),
                _buildTimeAndBadge(context, lastMessage, unread, isPinned, scheme),
              ],
            ),
          ),
        ),
        if (!isLastItem)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: Divider(
                height: 1,
                color: scheme.onSurface.withValues(alpha: 0.5),
                thickness: 0.2,
              ),
            ),
          ),
      ],
    );
  }

  String? _resolveTypingText(ChatModel chat, String? currentUid, UserProfileResolver resolver) {
    if (currentUid == null) return null;
    final others = chat.typingUsers.where((uid) => uid != currentUid).toList();
    if (others.isEmpty) return null;
    final names = others
        .map((uid) =>
            resolver.lookupDisplayName(uid) ??
            chat.memberInfo[uid]?.displayName ??
            'Someone')
        .toList();
    if (names.length == 1) return '${names.first} is typing...';
    return '${names.join(', ')} others are typing...';
  }

  Widget _buildAvatar(
    BuildContext context,
    String initialLetter,
    bool showAvatarPhoto,
    String? photoUrl,
    bool isGroup,
    bool isSelected,
    ColorScheme scheme,
  ) =>
      Stack(
        children: [
          CircleAvatar(
            radius: AppRadius.xl.r,
            backgroundColor: AppColorTokens.senderNameColor(chat.id)
                .withValues(alpha: 0.25),
            backgroundImage: photoUrl != null && showAvatarPhoto
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || !showAvatarPhoto
                ? (isGroup
                    ? Icon(
                        Icons.people_alt_rounded,
                        color: AppColorTokens.senderNameColor(chat.id)
                            .withValues(alpha: 0.75),
                      )
                    : Text(
                        initialLetter,
                        style: context.text.senderName.copyWith(
                          fontSize: 18.sp,
                          color: AppColorTokens.senderNameColor(chat.id)
                              .withValues(alpha: 0.75),
                        ),
                      ))
                : null,
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: AppRadius.sm.r,
                backgroundColor: scheme.primary,
                child: Icon(Icons.check, size: AppSpacing.md.sp, color: Colors.white),
              ),
            ),
        ],
      );

  Widget _buildMessagePreview(
    BuildContext context,
    String displayName,
    lastMessage,
    typing,
    ColorScheme scheme,
  ) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: context.text.senderName,
              overflow: TextOverflow.ellipsis,
            ),
            if (lastMessage != null)
              Text(
                typing ?? lastMessage.text,
                style: context.text.subDescription2.copyWith(
                  color: typing != null
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
          ],
        ),
      );

  Widget _buildTimeAndBadge(
    BuildContext context,
    LastMessage? lastMessage,
    int unread,
    bool isPinned,
    ColorScheme scheme,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessage != null)
            Text(
              DateTimeHelper.formatChatTime(lastMessage.sentAt),
              style: context.text.subDescription3.copyWith(
                color: unread > 0 ? scheme.primary : Colors.grey,
              ),
            ),
          Gap(4.h),
          Row(
            children: [
              if (isPinned)
                Icon(Icons.push_pin_rounded, color: scheme.primary, size: AppSpacing.md.sp),
              if (unread > 0) ...[
                Gap(6.h),
                CircleAvatar(
                  radius: 10.r,
                  backgroundColor: scheme.primary,
                  child: Text(
                    '$unread',
                    style: context.text.subDescription3.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
}
