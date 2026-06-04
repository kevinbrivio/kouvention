import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';

class ChatListItem extends ConsumerWidget {
  final ChatModel chat;
  final bool isLastItem;

  const ChatListItem({super.key, required this.chat, required this.isLastItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(chatListVM);

    final unread = vm.chatUnreadCount(chat);
    final lastMessage = chat.lastMessage;
    final isPinned = chat.isPinnedBy(vm.currentId!);
    final typing = vm.typingText(chat);
    final isSelected = vm.selectedChatIds.contains(chat.id);

    final displayName = vm.chatDisplayName(chat);
    final initialLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    bool showAvatarPhoto;
    if (chat.isDirect) {
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
          splashColor: AppColors.grey.withValues(alpha: 0.2),
          highlightColor: AppColors.grey.withValues(alpha: 0.1),
          child: Container(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                _buildAvatar(context, vm, initialLetter, showAvatarPhoto),
                Gap(12.w),
                _buildMessagePreview(context, displayName, lastMessage, typing),
                Gap(4.w),
                _buildTimeAndBadge(context, lastMessage, unread, isPinned),
              ],
            ),
          ),
        ),

        // Garis pembatas di bawah chat
        if (!isLastItem)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Divider(height: 1, color: AppColors.grey, thickness: 0.2),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, ChatListVM vm, String initialLetter, bool showAvatarPhoto) => Stack(
    children: [
      CircleAvatar(
        radius: 24.r,
        backgroundColor: AppColors.senderNameColor(
          chat.id,
        ).withValues(alpha: 0.25),
        backgroundImage: vm.chatPhotoURL(chat) != null && showAvatarPhoto
            ? NetworkImage(vm.chatPhotoURL(chat)!)
            : null,
        child: vm.chatPhotoURL(chat) == null || !showAvatarPhoto
            ? (vm.isGroupType(chat)
                  ? Icon(
                      Icons.people_alt_rounded,
                      color: AppColors.senderNameColor(
                        chat.id,
                      ).withValues(alpha: 0.7),
                    )
                  : Text(
                      initialLetter,
                      style: AppTextTheme.of(context).senderName.copyWith(
                        fontSize: 18.sp,
                        color: AppColors.senderNameColor(
                          chat.id,
                        ).withValues(alpha: 0.7),
                      ),
                    ))
            : null,
      ),
      if (vm.selectedChatIds.contains(chat.id))
        Positioned(
          right: 0,
          bottom: 0,
          child: CircleAvatar(
            radius: 8.r,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.check, size: 16.sp, color: AppColors.white),
          ),
        ),
    ],
  );

  Widget _buildMessagePreview(BuildContext context, String displayName, lastMessage, typing) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: AppTextTheme.of(context).senderName.copyWith(color: AppColors.black),
              overflow: TextOverflow.ellipsis,
            ),
            if (lastMessage != null)
              Text(
                typing ?? lastMessage.text,
                style: AppTextTheme.of(context).subDescription2.copyWith(
                  color: typing != null ? AppColors.primary : AppColors.grey,
                ),
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
          ],
        ),
      );

  Widget _buildTimeAndBadge(BuildContext context, LastMessage? lastMessage, int unread, bool isPinned) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (lastMessage != null)
        Text(
          DateTimeHelper.formatChatTime(lastMessage.sentAt),
          style: AppTextTheme.of(context).subDescription3.copyWith(
            color: unread > 0 ? AppColors.primary : Colors.grey,
          ),
        ),
      Gap(4.h),
      Row(
        children: [
          if (isPinned)
            Icon(Icons.push_pin_rounded, color: AppColors.primary, size: 16.sp),
          if (unread > 0) ...[
            Gap(6.h),
            CircleAvatar(
              radius: 10.r,
              backgroundColor: AppColors.primary,
              child: Text(
                '$unread',
                style: AppTextTheme.of(context).subDescription3.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}
