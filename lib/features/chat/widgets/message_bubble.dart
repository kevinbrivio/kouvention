import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_status.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_selection_viewmodel.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/chat/widgets/bubble_tail_painter.dart';
import 'package:kouvention/features/chat/widgets/media_bubble.dart';
import 'package:swipe_to/swipe_to.dart';

class MessageBubble extends ConsumerWidget {
  final String chatId;
  final MessageModel message;
  final bool isMe;
  final bool isFirstSequence;
  final String senderName;
  final String? senderPhotoUrl;
  final VoidCallback onReplyMessage;
  final bool isGroup;
  final ChatModel? chat; // Bisa nullable agar lebih aman
  final void Function(String messageId)? onTapReply;

  const MessageBubble({
    super.key,
    required this.chatId,
    required this.message,
    required this.isMe,
    required this.isFirstSequence,
    required this.senderName,
    this.senderPhotoUrl,
    required this.onReplyMessage,
    this.isGroup = false,
    required this.chat,
    this.onTapReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid ?? '';

    final selectionVM = ref.watch(chatSelectionVM(chatId));
    final isSelected = selectionVM.isSelected(message.id);
    final isSelecting = selectionVM.isSelecting;

    final highlightedId = ref.watch(highlightMessageProvider(chatId));
    final isHighlighted = highlightedId == message.id;

    final time = _formatTime(message.sentAt);
    final replyMsg = message.replyTo;
    
    final status = message.getUIStatus(chat, currentUid); 

    final sender = ref.watch(otherUserStreamProvider(message.senderId)).value;
    final showSenderPhoto = isGroup && !isMe && senderPhotoUrl != null &&
        (sender?.privacy.showProfilePhoto ?? true);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.22)
          : isHighlighted
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.transparent,
      child: SwipeTo(
        onRightSwipe: !message.isDeleted && !isMe ? (_) => onReplyMessage() : null,
        onLeftSwipe: !message.isDeleted && isMe ? (_) => onReplyMessage() : null,
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
          onTap: isSelecting ? () => selectionVM.toggleSelection(message.id) : null,
          child: _buildBubbleContent(
            context,
            time: time,
            senderName: senderName,
            senderPhotoUrl: senderPhotoUrl,
            showSenderPhoto: showSenderPhoto,
            replyMsg: replyMsg,
            currentUid: currentUid,
            status: status, // Oper status ke bawah
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
    required bool showSenderPhoto,
    required ReplyToModel? replyMsg,
    required String currentUid,
    required MessageStatus status,
  }) => Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                if (isGroup && isFirstSequence)
                  CircleAvatar(
                    radius: 14.r,
                    backgroundColor: showSenderPhoto
                        ? AppColors.senderNameColor(message.senderId)
                            .withValues(alpha: 0.25)
                        : null,
                    backgroundImage: showSenderPhoto
                        ? NetworkImage(senderPhotoUrl!)
                        : null,
                    onBackgroundImageError: showSenderPhoto
                        ? (_, __) {}
                        : null,
                    child: !showSenderPhoto
                        ? Text(
                            senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                            style: textTheme.senderName.copyWith(
                              color: AppColors.senderNameColor(message.senderId)
                                  .withValues(alpha: 0.7),
                            ),
                          )
                        : null,
                  ),
                Gap(8.w),
              ],
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      constraints: BoxConstraints(maxWidth: 260.w),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primary2 : AppColors.otherUserBubble,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isMe ? 16.r : 4.r),
                          topRight: Radius.circular(isMe ? 4.r : 16.r),
                          bottomRight: Radius.circular(16.r),
                          bottomLeft: Radius.circular(16.r),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (replyMsg != null) ...[
                            InkWell(
                              onTap: onTapReply != null
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      onTapReply!(replyMsg.messageId);
                                    }
                                  : null,
                              child: _buildInBubbleReplyPreview(replyMsg, currentUid),
                            ),
                            Gap(6.h),
                          ],
                          if (!isMe && isGroup && isFirstSequence) ...[
                            Text(
                              senderName,
                              style: textTheme.senderName.copyWith(
                                color: AppColors.senderNameColor(message.senderId),
                              ),
                            ),
                            Gap(4.h),
                          ],
                          if (message.type == MessageType.text) ...[
                            Text(
                              (message.text == '' && message.isDeleted)
                                  ? isMe
                                      ? 'You deleted this message'
                                      : 'This message was deleted'
                                  : message.text,
                              style: textTheme.senderName.copyWith(
                                color: isMe
                                    ? message.isDeleted ? AppColors.grey : Colors.white
                                    : message.isDeleted ? AppColors.grey : Colors.black87,
                                fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ] else if (message.mediaUrls != null && message.mediaUrls!.isNotEmpty) ...[
                            MediaBubble(message: message, isMe: isMe),
                          ],
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
                                _buildMessageStatus(status),
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
                            color: isMe ? AppColors.primary2 : AppColors.otherUserBubble,
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
        return Icon(Icons.access_time, size: 12.sp, color: Colors.white70); // Lebih enak ikon Jam
      case MessageStatus.sent:
        return Icon(Icons.done_all, size: 14.sp, color: Colors.white70); // Centang Abu
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14.sp, color: Colors.blueAccent); // Centang Biru
    }
  }

  Widget _buildInBubbleReplyPreview(ReplyToModel replyTo, String currentUid) {
    final isRepliedMessageMine = replyTo.senderId == currentUid;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isMe ? AppColors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border(
          left: BorderSide(
            color: isMe ? AppColors.white : AppColors.senderNameColor(replyTo.senderId),
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
              color: isMe ? AppColors.white : AppColors.senderNameColor(replyTo.senderId),
            ),
          ),
          Gap(2.h),
          if (replyTo.mediaType == 'text')
            Text(
              replyTo.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                color: isMe ? Colors.white70 : Colors.grey[600],
              ),
            ),

          if (replyTo.mediaUrl != null) ...[_buildReplyMediaPreview(replyTo)],
        ],
      ),
    );
  }

  Widget _buildReplyMediaPreview(ReplyToModel replyTo) {
    final type = replyTo.mediaType ?? '';
    final url = replyTo.mediaUrl!;
    final filename = url.split('/').last.toLowerCase().split('?').first;
    final ext = filename.split('.').last.toLowerCase();

    if (ext == 'pdf') return _iconBox(Icons.picture_as_pdf, filename);
    if (ext == 'docx' || ext == 'doc')
      return _iconBox(Icons.description, 'Document');
    if (ext == 'xlsx' || ext == 'xls')
      return _iconBox(Icons.table_chart, 'Spreadsheet');
    if (ext == 'mp3' || ext == 'wav' || ext == 'ogg')
      return _iconBox(Icons.audiotrack, 'Audio');

    if (type == 'image') return _thumbnailBox(imageUrl: url);
    if (type == 'video') {
      return _thumbnailBox(
        imageUrl: _getVideoThumbnailUrl(url),
        icon: Icons.play_circle_fill,
      );
    }

    return _iconBox(Icons.insert_drive_file, 'File');
  }

  String? _getVideoThumbnailUrl(String videoUrl) => videoUrl
      .replaceFirst('/video/upload/', '/video/upload/so_0/')
      .replaceAll('.mp4', '.jpg')
      .replaceAll('.mov', '.jpg')
      .replaceAll('.avi', '.jpg');

  Widget _thumbnailBox({String? imageUrl, IconData? icon}) => SizedBox(
    width: 80.w,
    height: 80.w,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 20.sp),
          ),
        ),
        if (icon != null)
          Center(
            child: Icon(icon, color: Colors.white, size: 20.sp),
          ),
      ],
    ),
  );

  Widget _iconBox(IconData icon, String label) => Padding(
    padding: EdgeInsets.all(4.w),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20.sp, color: AppColors.grey,),
        Gap(4.w),
        Flexible(
          child: Text(
            label, 
            style: textTheme.subDescription3,
          ),
        )
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