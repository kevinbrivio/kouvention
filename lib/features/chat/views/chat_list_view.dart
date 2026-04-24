import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';

class ChatListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BaseView(
    provider: chatListVM,
    useGradient: false,
    builder: (context, vm) => Stack(
      children: [
        _buildScreen(context, vm),

        Positioned(
          right: 16.w,
          bottom: MediaQuery.of(context).padding.bottom + 12.h,
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: () {
              context.push(RouterRoutes.newChat.path);
            },
            child: Icon(Icons.edit, color: Colors.white, size: 20.sp,),
          ),
        ),
      ],
    ),
  );

  Widget _buildScreen(BuildContext context, ChatListVM vm) {
    if (!vm.hasChats) return Center(child: Text('No conversations yet.'));

    return ListView.builder(
      itemCount: vm.chats.length,
      itemBuilder: (context, index) {
        final chat = vm.chats[index];
        final unread = vm.chatUnreadCount(chat);
        final lastMessage = chat.lastMessage;

        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/chats/${chat.id}');
          },
          splashColor: AppColors.grey.withValues(alpha: 0.1),
          highlightColor: AppColors.grey.withValues(alpha: 0.05),
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundImage: vm.chatPhotoURL(chat) != null
                      ? NetworkImage(vm.chatPhotoURL(chat)!)
                      : null,
                  child: vm.chatPhotoURL(chat) == null
                      ? vm.isGroupType(chat)
                            ? Icon(
                                Icons.people_alt_rounded,
                                color: AppColors.primary,
                              )
                            : Text(
                                vm.chatDisplayName(chat).isNotEmpty
                                    ? vm.chatDisplayName(chat)[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.sp,
                                ),
                              )
                      : null,
                ),
                Gap(12.w),

                // Name + Last message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.chatDisplayName(chat),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lastMessage != null)
                        Text(
                          vm.typingText(chat) ?? lastMessage.text,
                          style: textTheme.subDescription2.copyWith(
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                    ],
                  ),
                ),

                // Time + unread badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lastMessage != null)
                      Text(
                        _formatChatTime(lastMessage.sentAt),
                        style: textTheme.subDescription3.copyWith(
                          color: unread > 0 ? AppColors.primary2 : Colors.grey,
                        ),
                      ),

                    if (unread > 0) ...[
                      Gap(6.h),
                      CircleAvatar(
                        radius: 10.r,
                        backgroundColor: AppColors.primary2,
                        child: Text(
                          '$unread',
                          style: textTheme.subDescription3.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatChatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    // Today — show time
    if (diff.inDays == 0 && now.day == dateTime.day) {
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }

    // Yesterday
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dateTime.day)) {
      return 'Yesterday';
    }

    // Within this week — show day name
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    }

    // Older — show date
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
  }
}
