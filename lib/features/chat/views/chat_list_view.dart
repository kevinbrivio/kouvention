import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/hidden_app_bar.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';

class ChatListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BaseView(
    provider: chatListVM,
    useGradient: false,
    appBar: (_) => HiddenAppBar(),
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
            child: Icon(Icons.edit, color: Colors.white, size: 20.sp),
          ),
        ),
      ],
    ),
  );

  Widget _buildScreen(BuildContext context, ChatListVM vm) {
    if (!vm.hasChats) return Center(child: Text('No conversations yet.'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap(16.h),
        _buildHeader(context),

        _buildFilterChips(vm),

        Expanded(
          child: vm.filteredChats.isEmpty
              ? Center(
                  child: Text(
                    'No ${vm.filter == ChatFilter.direct ? 'direct' : 'group'} chats yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: vm.filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = vm.filteredChats[index];
                    final unread = vm.chatUnreadCount(chat);
                    final lastMessage = chat.lastMessage;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/chats/${chat.id}');
                          },
                          splashColor: AppColors.grey.withValues(alpha: 0.1),
                          highlightColor: AppColors.grey.withValues(
                            alpha: 0.05,
                          ),
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
                                  backgroundColor: AppColors.senderNameColor(
                                    chat.id,
                                  ).withValues(alpha: 0.25),
                                  backgroundImage: vm.chatPhotoURL(chat) != null
                                      ? NetworkImage(vm.chatPhotoURL(chat)!)
                                      : null,
                                  child: vm.chatPhotoURL(chat) == null
                                      ? vm.isGroupType(chat)
                                            ? Icon(
                                                Icons.people_alt_rounded,
                                                color:
                                                    AppColors.senderNameColor(
                                                      chat.id,
                                                    ).withValues(alpha: 0.7),
                                              )
                                            : Text(
                                                vm
                                                        .chatDisplayName(chat)
                                                        .isNotEmpty
                                                    ? vm
                                                          .chatDisplayName(
                                                            chat,
                                                          )[0]
                                                          .toUpperCase()
                                                    : '?',
                                                style: textTheme.senderName
                                                    .copyWith(
                                                      fontSize: 18.sp,
                                                      color:
                                                          AppColors.senderNameColor(
                                                            chat.id,
                                                          ).withValues(
                                                            alpha: 0.7,
                                                          ),
                                                    ),
                                              )
                                      : null,
                                ),
                                Gap(12.w),

                                // Name + Last message
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vm.chatDisplayName(chat),
                                        style: textTheme.senderName.copyWith(
                                          color: AppColors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (lastMessage != null)
                                        Text(
                                          vm.typingText(chat) ??
                                              lastMessage.text,
                                          style: textTheme.subDescription2
                                              .copyWith(color: Colors.grey),
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: true,
                                        ),
                                    ],
                                  ),
                                ),

                                Gap(4.w),

                                // Time + unread badge
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (lastMessage != null)
                                      Text(
                                        _formatChatTime(lastMessage.sentAt),
                                        style: textTheme.subDescription3
                                            .copyWith(
                                              color: unread > 0
                                                  ? AppColors.primary
                                                  : Colors.grey,
                                            ),
                                      ),

                                    if (unread > 0) ...[
                                      Gap(6.h),
                                      CircleAvatar(
                                        radius: 10.r,
                                        backgroundColor: AppColors.primary,
                                        child: Text(
                                          '$unread',
                                          style: textTheme.subDescription3
                                              .copyWith(color: AppColors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (index != vm.filteredChats.length - 1)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: Divider(
                                height: 1,
                                color: AppColors.grey,
                                // indent: 64.w,
                                thickness: 0.2,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    child: Row(
      children: [
        Text(
          'Kouvention',
          style: textTheme.subheadline1.copyWith(color: AppColors.primary),
        ),
      ],
    ),
  );

  Widget _buildFilterChips(ChatListVM vm) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Row(
      children: ChatFilter.values.map((filter) {
        final isSelected = vm.filter == filter;
        final label = switch (filter) {
          ChatFilter.all => 'All',
          ChatFilter.direct => 'Direct',
          ChatFilter.group => 'Groups',
        };

        return Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              vm.setFilter(filter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

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
