import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/bubble_color_scheme.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_status.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_profile_provider.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_selection_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/bubble_scheme_provider.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/bubble_tail_painter.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/media_bubble.dart';
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
  final void Function(ReplyToModel replyTo)? onTapReply;

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
    final showSenderPhoto =
        isGroup &&
        !isMe &&
        senderPhotoUrl != null &&
        (sender?.privacy.showProfilePhoto ?? true);

    final resolver = ref.read(chatRoomProfileResolverProvider(chatId));
    final senderName = resolver.lookupDisplayName(message.senderId);
    final repliedSenderName = resolver.lookupDisplayName(
      message.replyTo?.senderId ?? '',
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)
          : isHighlighted
          ? Colors.amber.withValues(alpha: 0.2)
          : Colors.transparent,
      child: SwipeTo(
        onRightSwipe: !message.isDeleted && !isMe
            ? (_) => onReplyMessage()
            : null,
        onLeftSwipe: !message.isDeleted && isMe
            ? (_) => onReplyMessage()
            : null,
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
            scheme: ref.watch(bubbleSchemeProvider),
            time: time,
            senderName: senderName ?? 'You',
            senderPhotoUrl: senderPhotoUrl,
            showSenderPhoto: showSenderPhoto,
            replyMsg: replyMsg,
            currentUid: currentUid,
            status: status,
            repliedSenderName: repliedSenderName,
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleContent(
    BuildContext context, {
    required BubbleColorScheme scheme,
    required String time,
    required String senderName,
    required String? senderPhotoUrl,
    required bool showSenderPhoto,
    required ReplyToModel? replyMsg,
    required String currentUid,
    required MessageStatus status,
    String? repliedSenderName,
  }) {
    final sentBubbleColor = scheme.sentBubble;
    final receivedBubbleColor = scheme.receivedBubble;

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: AppSpacing.xs.h,
            horizontal: AppSpacing.sm.w,
          ),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                if (isGroup && isFirstSequence)
                  CircleAvatar(
                    radius: AppSizing.avatarSm.r,
                    backgroundColor: showSenderPhoto
                        ? AppColorTokens.senderNameColor(
                            message.senderId,
                          ).withValues(alpha: 0.25)
                        : null,
                    backgroundImage: showSenderPhoto
                        ? NetworkImage(senderPhotoUrl!)
                        : null,
                    onBackgroundImageError: showSenderPhoto
                        ? (exception, stackTrace) {}
                        : null,
                    child: !showSenderPhoto
                        ? Text(
                            senderName.isNotEmpty
                                ? senderName[0].toUpperCase()
                                : '?',
                            style: context.text.senderName.copyWith(
                              color: AppColorTokens.senderNameColor(
                                message.senderId,
                              ).withValues(alpha: 0.7),
                            ),
                          )
                        : null,
                  ),
                Gap(AppSpacing.xs.w),
              ],
              Flexible(
                fit: FlexFit.loose,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      constraints: isMe
                          ? null
                          : BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                            ),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs.w,
                        vertical: AppSpacing.xs.w,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? sentBubbleColor : receivedBubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(
                            isMe ? AppRadius.sm.r : AppRadius.xs.r,
                          ),
                          topRight: Radius.circular(
                            isMe ? AppRadius.xs.r : AppRadius.sm.r,
                          ),
                          bottomRight: Radius.circular(AppRadius.sm.r),
                          bottomLeft: Radius.circular(AppRadius.sm.r),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (replyMsg != null) ...[
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.8,
                              ),
                              child: InkWell(
                                onTap: onTapReply != null
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        onTapReply!(replyMsg);
                                      }
                                    : null,
                                child: _buildInBubbleReplyPreview(
                                  context,
                                  replyMsg,
                                  currentUid,
                                  repliedSenderName ?? '',
                                ),
                              ),
                            ),
                            Gap(AppSpacing.xxs.h),
                          ],
                          if (!isMe && isGroup && isFirstSequence) ...[
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.8,
                              ),
                              child: Text(
                                senderName,
                                style: context.text.senderName.copyWith(
                                  color: AppColorTokens.senderNameColor(
                                    message.senderId,
                                  ),
                                ),
                              ),
                            ),
                            Gap(4.h),
                          ],
                          if (message.type == MessageType.text) ...[
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: 120.w,
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.8,
                              ),
                              child: Builder(
                                builder: (_) {
                                  final content = Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      (message.text == '' && message.isDeleted)
                                          ? isMe
                                                ? 'You deleted this message'
                                                : 'This message was deleted'
                                          : message.text,
                                      style: context.text.bodySmall.copyWith(
                                        color: isMe
                                            ? message.isDeleted
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.5)
                                                  : context.text.secondaryText
                                            : context.text.secondaryText,
                                        fontStyle: message.isDeleted
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                    Gap(AppSpacing.xxs.h),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            time,
                                            style: context.text.labelSmall
                                                .copyWith(
                                                  color: isMe
                                                      ? message.isDeleted
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  )
                                                            : context
                                                                  .text
                                                                  .secondaryText
                                                      : context
                                                            .text
                                                            .secondaryText,
                                                ),
                                          ),
                                          if (isMe) ...[
                                            Gap(4.w),
                                            _buildMessageStatus(
                                              status,
                                              context.text.secondaryText,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    ],
                                  );

                                  return replyMsg == null
                                      ? IntrinsicWidth(child: content)
                                      : SizedBox(
                                          width: double.infinity,
                                          child: content,
                                        );
                                },
                              ),
                            ),
                          ] else if (message.mediaUrls != null &&
                              message.mediaUrls!.isNotEmpty) ...[
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                MediaBubble(
                                  message: message,
                                  isMe: isMe,
                                  scheme: scheme,
                                ),
                                Gap(AppSpacing.xxs.h),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      time,
                                      style: context.text.labelSmall.copyWith(
                                        color: context.text.secondaryText,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      Gap(4.w),
                                      _buildMessageStatus(
                                        status,
                                        context.text.secondaryText.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isFirstSequence)
                      Positioned(
                        top: 0,
                        left: isMe ? null : -4.w,
                        right: isMe ? -4.w : null,
                        child: CustomPaint(
                          size: Size(AppSpacing.xs.w, AppSpacing.sm.h),
                          painter: BubbleTailPainter(
                            color: isMe ? sentBubbleColor : receivedBubbleColor,
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
  }

  Widget _buildMessageStatus(MessageStatus status, Color color) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time, size: AppSizing.iconXxs.r, color: color);
      case MessageStatus.sent:
        return Icon(Icons.done_all, size: AppSizing.iconXxs.r, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: AppSizing.iconXxs.r, color: color);
    }
  }

  Widget _buildInBubbleReplyPreview(
    BuildContext context,
    ReplyToModel replyTo,
    String currentUid,
    String resolvedReplyName,
  ) {
    // When senderId is empty (Drift mapping limitation), skip "You" check.
    final isRepliedMessageMine =
        replyTo.senderId.isNotEmpty && replyTo.senderId == currentUid;
    final hasValidMediaUrl =
        replyTo.mediaUrl != null &&
        replyTo.mediaUrl!.isNotEmpty &&
        replyTo.mediaUrl != '[]';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        border: Border(
          left: BorderSide(
            color: isMe
                ? Colors.white
                : AppColorTokens.senderNameColor(replyTo.senderId),
            width: 3.w,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              isRepliedMessageMine ? 'You' : resolvedReplyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall.copyWith(
                color: context.text.secondaryText,
              ),
            ),
          Gap(2.h),
          if (replyTo.isStoryReference)
            _buildStoryReplyPreview(context, replyTo)
          else if (replyTo.mediaType == 'text' || !hasValidMediaUrl)
            Text(
              replyTo.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall.copyWith(
                color: context.text.secondaryText,
              ),
            )
          else ...[
            _buildReplyMediaPreview(context, replyTo),
          ],
        ],
      ),
    );
  }

  Widget _buildStoryReplyPreview(BuildContext context, ReplyToModel replyTo) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Story',
            style: context.text.labelSmall.copyWith(
              color: context.text.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          Gap(4.h),
          switch (replyTo.storyType) {
            'image' || 'video' => _buildStoryThumbnail(context, replyTo),
            'text' => Text(
              replyTo.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall.copyWith(
                color: context.text.secondaryText,
              ),
            ),
            'audio' => _buildStoryAudioWaveform(context),
            _ => _storyIconBox(context, replyTo.storyType),
          },
        ],
      );

  Widget _buildStoryThumbnail(BuildContext context, ReplyToModel replyTo) {
    final thumbnailUrl = replyTo.mediaUrl?.trim();
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return _storyIconBox(context, replyTo.storyType);
    }

    return SizedBox(
      width: 120.w,
      height: 84.h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                _storyIconBox(context, replyTo.storyType),
            ),
            if (replyTo.storyType == 'video')
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryAudioWaveform(BuildContext context) {
    const samples = <double>[
      0.35,
      0.7,
      0.45,
      0.9,
      0.55,
      0.3,
      0.75,
      0.5,
      0.85,
      0.4,
      0.65,
      0.35,
    ];

    return SizedBox(
      width: 120.w,
      height: 36.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final sample in samples)
            Container(
              width: 3.w,
              height: (8 + (sample * 24)).h,
              decoration: BoxDecoration(
                color: context.text.secondaryText.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
        ],
      ),
    );
  }

    Widget _storyIconBox(BuildContext context, String? storyType) => Container(
    width: 44.w,
    height: 44.w,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6.r),
    ),
    child: Icon(
      switch (storyType) {
        'video' => Icons.play_circle_fill,
        'audio' => Icons.graphic_eq_rounded,
        'text' => Icons.format_quote_rounded,
        _ => Icons.auto_stories_outlined,
      },
      size: 22.sp,
      color: context.text.secondaryText,
    ),
  );

  Widget _buildReplyMediaPreview(BuildContext context, ReplyToModel replyTo) {
    final type = replyTo.mediaType ?? '';
    final url = replyTo.mediaUrl!;
    final filename = url.split('/').last.toLowerCase().split('?').first;
    final ext = filename.split('.').last.toLowerCase();

    if (ext == 'pdf') return _pdfThumbnailOrIcon(context, url, filename);
    if (ext == 'docx' || ext == 'doc') {
      return _iconBox(context, Icons.description, 'Document');
    }
    if (ext == 'xlsx' || ext == 'xls') {
      return _iconBox(context, Icons.table_chart, 'Spreadsheet');
    }
    if (ext == 'mp3' || ext == 'wav' || ext == 'ogg') {
      return _iconBox(context, Icons.audiotrack, 'Audio');
    }

    if (type == 'image') return _thumbnailBox(imageUrl: url);
    if (type == 'video') {
      return _thumbnailBox(
        imageUrl: _getVideoThumbnailUrl(url),
        icon: Icons.play_circle_fill,
      );
    }

    return _iconBox(context, Icons.insert_drive_file, 'File');
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
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
          child: Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.broken_image, size: 20.sp),
          ),
        ),
        if (icon != null)
          Center(
            child: Icon(icon, color: Colors.white, size: 20.sp),
          ),
      ],
    ),
  );

  Widget _pdfThumbnailOrIcon(
    BuildContext context,
    String url,
    String filename,
  ) {
    final thumbUrl = url.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
    return SizedBox(
      width: 80.w,
      height: 80.w,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: Image.network(
          thumbUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _iconBox(context, Icons.picture_as_pdf, filename),
        ),
      ),
    );
  }

  Widget _iconBox(BuildContext context, IconData icon, String label) => Padding(
    padding: EdgeInsets.all(4.w),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20.sp,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        Gap(4.w),
        Flexible(
          child: Text(
            label,
            style: context.text.labelSmall.copyWith(
              color: context.text.tertiaryText,
            ),
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
