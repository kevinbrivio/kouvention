import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_selection_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/bubble_tail_painter.dart';
import 'package:swipe_to/swipe_to.dart';

class MessageBubble extends ConsumerWidget {
  final MessageModel message;
  final bool isMe;
  final bool isFirstSequence;
  final VoidCallback onReplyMessage;
  final ChatRoomVM viewmodel;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isFirstSequence,
    required this.onReplyMessage,
    required this.viewmodel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Each bubble watches selection state independently
    final selectionVM = ref.watch(chatSelectionVM);
    final isSelected = selectionVM.isSelected(message.id);
    final isSelecting = selectionVM.isSelecting;

    final time = _formatTime(message.sentAt);
    final senderName = viewmodel.senderDisplayName(message.senderId);
    final senderPhotoUrl = viewmodel.senderPhotoUrl(message.senderId);
    final replyMsg = message.replyTo;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.22)
          : Colors.transparent,
      child: SwipeTo(
        onRightSwipe: !isMe ? (_) => onReplyMessage() : null,
        onLeftSwipe: isMe ? (_) => onReplyMessage() : null,
        // GestureDetector goes HERE — inside SwipeTo, on the content
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            if (selectionVM.isSelecting) {
              selectionVM.toggleSelection(message.id);
            } else {
              selectionVM.startSelection(message.id);
            }
          },
          onTap: isSelecting
              ? () => selectionVM.toggleSelection(message.id)
              : null,
          child: _buildBubbleContent(
            context,
            time: time,
            senderName: senderName,
            senderPhotoUrl: senderPhotoUrl,
            replyMsg: replyMsg,
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleContent(
    BuildContext context, {
    required String time,
    required String senderName,
    required String? senderPhotoUrl,
    required ReplyToModel? replyMsg,
  }) => Column(
    crossAxisAlignment: isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              if (viewmodel.isGroup)
                if (isFirstSequence)
                  CircleAvatar(
                    radius: 14.r,
                    backgroundColor: AppColors.senderNameColor(
                      message.senderId,
                    ).withValues(alpha: 0.25),
                    backgroundImage:
                        senderPhotoUrl != null && senderPhotoUrl.isNotEmpty
                        ? NetworkImage(senderPhotoUrl)
                        : null,
                    onBackgroundImageError:
                        senderPhotoUrl != null && senderPhotoUrl.isNotEmpty
                        ? (_, __) {}
                        : null,
                    child: senderPhotoUrl == null || senderPhotoUrl.isEmpty
                        ? Text(
                            senderName.isNotEmpty
                                ? senderName[0].toUpperCase()
                                : '?',
                            style: textTheme.senderName.copyWith(
                              color: AppColors.senderNameColor(
                                message.senderId,
                              ).withValues(alpha: 0.7),
                            ),
                          )
                        : null,
                  )
                else
                  SizedBox(width: 28.r),
              Gap(8.w),
            ],
            Flexible(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: 260.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.primary2
                          : AppColors.otherUserBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 16.r : 4.r),
                        topRight: Radius.circular(isMe ? 4.r : 16.r),
                        bottomRight: Radius.circular(16.r),
                        bottomLeft: Radius.circular(16.r),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (replyMsg != null) ...[
                          _buildInBubbleReplyPreview(replyMsg),
                          Gap(6.h),
                        ],
                        if (!isMe && viewmodel.isGroup && isFirstSequence) ...[
                          Text(
                            senderName,
                            style: textTheme.senderName.copyWith(
                              color: AppColors.senderNameColor(
                                message.senderId,
                              ),
                            ),
                          ),
                          Gap(4.h),
                        ],
                        Text(
                          (message.text == '' && message.isDeleted)
                            ? isMe
                              ? 'You deleted this message'
                              : 'This message was deleted'
                            : message.text,
                          style: textTheme.senderName.copyWith(
                            color: isMe
                                ? message.isDeleted
                                      ? AppColors.grey
                                      : Colors.white
                                : Colors.black87,
                            fontStyle: message.isDeleted
                                ? FontStyle.italic
                                : FontStyle.normal,
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
                              _buildMessageStatus(
                                viewmodel.getMessageStatus(message),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isFirstSequence)
                    Positioned(
                      top: 0,
                      left: isMe ? null : -4.w,
                      right: isMe ? -4.w : null,
                      child: CustomPaint(
                        size: Size(8.w, 12.h),
                        painter: BubbleTailPainter(
                          color: isMe
                              ? AppColors.primary2
                              : AppColors.otherUserBubble,
                          isMe: isMe,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildMessageStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.check, size: 14.sp, color: Colors.grey);
      case MessageStatus.sent:
        return Icon(Icons.done_all, size: 14.sp, color: Colors.grey);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14.sp, color: AppColors.primary);
    }
  }

  Widget _buildInBubbleReplyPreview(ReplyToModel replyTo) {
    final isRepliedMessageMine = viewmodel.isRepliedMessageMine(
      replyTo.senderId,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border(
          left: BorderSide(
            color: isMe
                ? AppColors.white
                : AppColors.senderNameColor(replyTo.senderId),
            width: 3.w,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRepliedMessageMine ? 'You' : replyTo.senderName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.sp,
              color: isMe
                  ? AppColors.primary
                  : AppColors.senderNameColor(replyTo.senderId),
            ),
          ),
          Gap(2.h),
          Text(
            replyTo.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              color: isMe ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
