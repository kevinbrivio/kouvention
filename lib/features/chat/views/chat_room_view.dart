// lib/features/chat/views/chat_room_view.dart

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';

class ChatRoomView extends StatelessWidget {
  final String chatId;

  const ChatRoomView({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) => BaseView<ChatRoomVM>(
    provider: chatRoomVM(chatId),
    useGradient: false,
    backgroundColor: Colors.white,
    appBar: (vm) => _buildAppBar(context, vm),
    builder: (context, vm) => _ChatRoomBody(chatId: chatId, viewmodel: vm),
    backgroundImage: DecorationImage(
      image: AssetImage(images.chatWallpaper),
      fit: BoxFit.cover,
      onError: (error, stackTrace) {
        debugPrint('Background image error: $error');
      },
    ),
  );
}

PreferredSizeWidget _buildAppBar(BuildContext context, ChatRoomVM vm) => AppBar(
  backgroundColor: Colors.white,
  elevation: 0.5,
  leading: IconButton(
    icon: Icon(Icons.arrow_back, color: AppColors.primary),
    onPressed: () => context.go(RouterRoutes.chatList.path),
  ),
  title: Row(
    children: [
      CircleAvatar(
        radius: 18.r,
        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
        backgroundImage: vm.chatPhotoUrl != null
            ? NetworkImage(vm.chatPhotoUrl!)
            : null,
        child: vm.chatPhotoUrl == null
            ? Text(
                vm.chatDisplayName.isNotEmpty
                    ? vm.chatDisplayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              )
            : null,
      ),
      Gap(10.w),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vm.chatDisplayName,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (vm.onlineStatusText != null)
              Text(
                vm.onlineStatusText!,
                style: textTheme.subDescription3.copyWith(
                  color: vm.onlineStatusText == 'Online'
                      ? Colors.green
                      : Colors.grey[500],
                  fontSize: 12.sp,
                ),
              ),
          ],
        ),
      ),
    ],
  ),
  actions: [
    IconButton(
      icon: Icon(Icons.phone, color: AppColors.primary),
      onPressed: () {},
    ),
    IconButton(
      icon: Icon(Icons.info_outline, color: AppColors.primary),
      onPressed: () {},
    ),
  ],
);

/// Separated into a StatefulWidget because the text controller
/// and scroll controller need State lifecycle management.
/// BaseView is a ConsumerWidget (stateless), so stateful
/// concerns like controllers live here instead.
class _ChatRoomBody extends StatefulWidget {
  final String chatId;
  final ChatRoomVM viewmodel;

  const _ChatRoomBody({required this.chatId, required this.viewmodel});

  @override
  State<_ChatRoomBody> createState() => _ChatRoomBodyState();
}

class _ChatRoomBodyState extends State<_ChatRoomBody> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  ChatRoomVM get viewmodel => widget.viewmodel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      viewmodel.loadMoreMessages();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: viewmodel.error != null
            ? Center(child: Text(viewmodel.error ?? ''))
            : _buildMessageList(),
      ),
      if (viewmodel.typingText != null) _buildTypingIndicator(),
      _buildInputBar(),
    ],
  );

  Widget _buildMessageList() {
    if (viewmodel.messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet. Say hi!',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: viewmodel.messages.length + (viewmodel.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == viewmodel.messages.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = viewmodel.messages[index];
        final isMe = viewmodel.isMyMessage(message);
        final showDate = _shouldShowDate(viewmodel.messages, index);

        /// Check if the NEXT message is from the same sender (in reverse)
        final isFirstSequence =
            index == viewmodel.messages.length - 1 ||
            showDate ||
            viewmodel.messages[index + 1].senderId != message.senderId;

        return Column(
          children: [
            if (showDate) _buildDateSeparator(message.sentAt),
            _buildMessageBubble(message, isMe, isFirstSequence),
          ],
        );
      },
    );
  }

  bool _shouldShowDate(List<MessageModel> messages, int index) {
    if (index == messages.length - 1) return true;
    final current = messages[index].sentAt;
    final previous = messages[index + 1].sentAt;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.day == now.day && date.month == now.month && date.year == now.year;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Text(
        isToday ? 'TODAY' : '${date.day}/${date.month}/${date.year}',
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool isMe,
    bool isFirstSequence,
  ) {
    final time = _formatTime(message.sentAt);
    final senderName = viewmodel.senderDisplayName(message.senderId);
    final senderPhotoUrl = viewmodel.senderPhotoUrl(message.senderId);

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (isFirstSequence)
              CircleAvatar(
                radius: 14.r,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    senderPhotoUrl != null && senderPhotoUrl.isNotEmpty
                    ? NetworkImage(senderPhotoUrl)
                    : null,
                onBackgroundImageError:
                    senderPhotoUrl != null && senderPhotoUrl.isNotEmpty
                    ? (_, __) {} // silently fall back to child
                    : null,
                child: senderPhotoUrl == null || senderPhotoUrl.isEmpty
                    ? Text(
                        senderName.isNotEmpty
                            ? senderName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey[700],
                        ),
                      )
                    : null,
              )
            else
              SizedBox(width: 28.r), // same width as avatar to keep alignment
            Gap(8.w),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: 260.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(isMe ? 16.r : 4.r),
                  bottomRight: Radius.circular(isMe ? 4.r : 16.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe && viewmodel.isGroup && isFirstSequence) ...[
                    Text(senderName, style: textTheme.senderName),
                    Gap(4.h),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14.sp,
                    ),
                  ),
                  Gap(4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey[500],
                          fontSize: 11.sp,
                        ),
                      ),
                      if (isMe) ...[
                        Gap(4.w),
                        Icon(
                          Icons.done_all,
                          size: 14.sp,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() => Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
    alignment: Alignment.centerLeft,
    child: Row(
      children: [
        CircleAvatar(
          radius: 14.r,
          backgroundColor: Colors.grey[300],
          child: Text(
            viewmodel.chatDisplayName.isNotEmpty
                ? viewmodel.chatDisplayName[0].toUpperCase()
                : '?',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[700]),
          ),
        ),
        Gap(8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Text(
            '•••',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[500],
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildInputBar() => Container(
    padding: EdgeInsets.only(
      left: 8.w,
      right: 8.w,
      top: 8.h,
      bottom: MediaQuery.of(context).padding.bottom + 8.h,
    ),
    decoration: BoxDecoration(
      color: Colors.transparent,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          offset: const Offset(0, -1),
          blurRadius: 4,
        ),
      ],
    ),
    child: Row(
      children: [
        IconButton(
          icon: Icon(Icons.add, color: AppColors.primary),
          onPressed: () {},
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: TextField(
              controller: _textController,
              onChanged: viewmodel.onTextChanged,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              style: TextStyle(fontSize: 14.sp),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ),
        Gap(8.w),
        GestureDetector(
          onTap: () {
            if (_textController.text.trim().isNotEmpty) {
              viewmodel.sendMessage(_textController.text);
              _textController.clear();
            }
          },
          child: CircleAvatar(
            radius: 20.r,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.send, color: Colors.white, size: 18.sp),
          ),
        ),
      ],
    ),
  );

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
