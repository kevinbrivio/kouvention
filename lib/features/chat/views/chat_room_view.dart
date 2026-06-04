import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/message_status.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_selection_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/media_sheet.dart';
import 'package:kouvention/features/chat/widgets/message_bubble.dart';
import 'package:kouvention/features/chat/widgets/sticker_picker.dart';
import 'package:kouvention/features/chat/widgets/selection_app_bar.dart';
import 'package:kouvention/features/chat/widgets/typing_dots.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:kouvention/features/chat/widgets/chat_room_appbar.dart';

class ChatRoomView extends ConsumerWidget {
  final String chatId;

  const ChatRoomView({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionVM = ref.watch(chatSelectionVM(chatId));
    final currentUid = ref.read(currentUidProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (selectionVM.isSelecting) {
          selectionVM.clearSelection();
        }
        if (!didPop) {
          // Navigate to chat list
          context.go(RouterRoutes.chatList.path);
        }
      },
      child: BaseView<ChatRoomVM>(
        provider: chatRoomVMProvider(chatId),
        useGradient: false,
        backgroundColor: Colors.white,
        appBar: (vm) => selectionVM.isSelecting
            ? SelectionAppBar(chatId: chatId, currentUid: currentUid!)
            : ChatRoomAppBar(chatId: chatId,),
        builder: (context, vm) {
          final queryParams = GoRouterState.of(context).uri.queryParameters;
          return _ChatRoomBody(
            chatId: chatId,
            viewmodel: vm,
            scrollToMessageId: queryParams['scrollTo'],
            scrollToSentAt: queryParams['sentAt'],
          );
        },
        backgroundImage: DecorationImage(
          image: AssetImage(images.chatWallpaper),
          fit: BoxFit.cover,
          onError: (error, stackTrace) {
            debugPrint('Background image error: $error');
          },
        ),
      ),
    );
  }
}

/// Separated into a StatefulWidget because the text controller
/// and scroll controller need State lifecycle management.
/// BaseView is a ConsumerWidget (stateless), so stateful
/// concerns like controllers live here instead.
class _ChatRoomBody extends ConsumerStatefulWidget {
  final String chatId;
  final ChatRoomVM viewmodel;
  final String? scrollToMessageId;
  final String? scrollToSentAt;

  const _ChatRoomBody({
    required this.chatId,
    required this.viewmodel,
    this.scrollToMessageId,
    this.scrollToSentAt,
  });

  @override
  ConsumerState<_ChatRoomBody> createState() => _ChatRoomBodyState();
}

class _ChatRoomBodyState extends ConsumerState<_ChatRoomBody> {
  final _textController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final _focusNode = FocusNode();

  bool _showScrollBottom = false;
  int? _initialScrollIndex;

  // For pagination later
  int _currentMessagesCount = 0;
  List<MessageModel> _currentMessagesList = [];

  ChatRoomVM get vm => widget.viewmodel;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onPositionChanged);

    // Update keyboard height after init screen
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        if (vm.showMediaPanel) {
          vm.toggleMediaPanel(ctx);
        }
      }
    });

    if (widget.scrollToMessageId != null && widget.scrollToSentAt != null) {
      _handlePendingScroll();
    }
  }

  Future<void> _handlePendingScroll() async {
    final sentAt = int.parse(widget.scrollToSentAt!);
    vm.setJumpTarget(sentAt);

    final index = _currentMessagesList.indexWhere(
      (m) => m.id == widget.scrollToMessageId,
    );

    if (index != -1 && mounted) {
      setState(() => _initialScrollIndex = index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        vm.highlightMessage(widget.scrollToMessageId!);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _itemPositionsListener.itemPositions.removeListener(_onPositionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.chatId));
    final chatAsync = ref.watch(chatMetadataStreamProvider(widget.chatId));
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid;

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            loading: () => const LoadingIndicator(),
            error: (err, s) => Center(child: Text('Error: $err')),
            data: (messages) {
              _currentMessagesCount = messages.length;
              _currentMessagesList = messages;

              if (messages.isEmpty) {
                return const Center(child: Text('No messages yet. Say hi!'));
              }

              return GestureDetector(
                onTap: () => vm.toggleMediaPanel(context),
                child: Stack(
                  children: [
                    vm.error != null
                        ? Center(child: Text(vm.error ?? ''))
                        : _buildMessageList(
                            messages,
                            chatAsync.value,
                            currentUid,
                          ),

                    if (_showScrollBottom)
                      Positioned(
                        right: 16.w,
                        bottom: 16.h,
                        child: GestureDetector(
                          onTap: _scrollToBottom,
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.primary,
                              size: 24.sp,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (chatAsync.value?.typingUsers.isNotEmpty == true)
          _buildTypingIndicator(chatAsync.value!, currentUid),

        _buildInputBar(chatAsync.value, currentUid),
        _buildMediaPanel(),
        _buildStickerPanel(),
      ],
    );
  }

  Widget _buildMessageList(
    List<MessageModel> messages,
    ChatModel? chat,
    String? currentUid,
  ) => ScrollablePositionedList.builder(
    itemScrollController: _itemScrollController,
    itemPositionsListener: _itemPositionsListener,
    initialScrollIndex: _initialScrollIndex ?? 0,
    reverse: true,
    padding: EdgeInsets.only(
      bottom: 12.h,
      top: MediaQuery.of(context).padding.top + kToolbarHeight,
    ),
    itemCount: messages.length,
    itemBuilder: (context, index) {
      if (index == messages.length) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Center(
            child: SizedBox(
              width: 24.w,
              height: 24.w,
              child: CircularProgressIndicator(
                strokeWidth: 2.w,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      }

      final message = messages[index];
      final isMe = message.senderId == currentUid;
      final showDate = _shouldShowDate(messages, index);

      /// Check if the NEXT message is from the same sender (in reverse)
      final isFirstSequence =
          index == messages.length - 1 ||
          showDate ||
          messages[index + 1].senderId != message.senderId;

      return Column(
        children: [
          if (showDate) _buildDateSeparator(message.sentAt),
          MessageBubble(
            chat: chat,
            chatId: chat?.id ?? '',
            isFirstSequence: isFirstSequence,
            message: message,
            isMe: isMe,
            senderName: message.senderName,
            onReplyMessage: () => vm.onSwipedMessage(message),
            onTapReply: (_) => _scrollToMessage(
              message.replyTo != null ? message.replyTo!.messageId : message.id,
              sentAt: message.replyTo != null
                  ? message.replyTo!.sentAt
                  : message.sentAt,
            ),
          ),
        ],
      );
    },
  );

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

  Widget buildMessageStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.check, size: 14.sp, color: Colors.grey);
      case MessageStatus.sent:
        return Icon(Icons.done_all, size: 14.sp, color: Colors.grey);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14.sp, color: AppColors.primary);
    }
  }

  Widget _buildTypingIndicator(ChatModel? chat, String? currentUid) {
    if (chat == null || currentUid == null) return const SizedBox.shrink();
    final others = chat.typingUsers.where((uid) => uid != currentUid).toList();
    if (others.isEmpty) return const SizedBox.shrink();

    final isGroup = chat.type == 'group';
    final chatName = chat.displayName(currentUid);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (isGroup)
            CircleAvatar(
              radius: 14.r,
              backgroundColor: Colors.grey[300],
              child: Text(
                chatName.isNotEmpty ? chatName[0] : '?',
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
            child: TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatModel? chat, String? currentUid) => Container(
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
    child: _buildTextField(ctx, chat, currentUid),
  );

  Widget _buildTextField(
    BuildContext context,
    ChatModel? chat,
    String? currentUid,
  ) => Row(
    children: [
      IconButton(
        icon: Icon(Icons.add, color: AppColors.primary),
        onPressed: () => vm.toggleMediaPanel(context),
      ),
      IconButton(
        icon: Icon(Icons.emoji_emotions_outlined, color: AppColors.primary),
        onPressed: () {
          vm.toggleStickerPanel(context);
          _focusNode.unfocus();
        },
      ),

      Flexible(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: vm.replyMessage != null ? 6.w : 12.w,
            vertical: 4.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(
              vm.replyMessage != null ? 12.r : 24.r,
            ),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: Column(
              children: [
                if (vm.replyMessage != null)
                  _buildReplyPreview(vm.replyMessage!),

                TextField(
                  focusNode: _focusNode,
                  controller: _textController,
                  minLines: 1,
                  maxLines: 5,
                  onChanged: vm.onTextChanged,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: textTheme.typeMessage.copyWith(
                      color: AppColors.grey,
                    ),
                    isDense: true,
                    filled: false,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 10.h,
                    ),
                  ),
                  style: textTheme.typeMessage,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ),
      ),
      Gap(8.w),
      GestureDetector(
        onTap: () {
          if (_textController.text.trim().isNotEmpty) {
            vm.sendMessage(_textController.text);
            _textController.clear();
            _scrollToBottom();
          } else {
            vm.startRecording();
          }
        },

        child: CircleAvatar(
          radius: 20.r,
          backgroundColor: vm.isSending ? AppColors.grey : AppColors.primary,
          child: vm.isSending
              ? SizedBox(
                  width: 18.sp,
                  height: 18.sp,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  vm.isTyping ? Icons.send : Icons.mic,
                  color: Colors.white,
                  size: 18.sp,
                ),
        ),
      ),
    ],
  );

  Widget _buildMediaPanel() => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    height: vm.showMediaPanel ? 280.h : 0,
    child: SingleChildScrollView(child: MediaSheet(vm: vm)),
  );

  Widget _buildStickerPanel() => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    height: vm.showStickerPanel ? 280.h : 0,
    child: StickerPicker(
      onStickerSelected: (sticker) {
        vm.sendSticker(sticker);
        setState(() => _showScrollBottom = true);
        _scrollToBottom();
      },
    ),
  );

  Widget _buildReplyPreview(MessageModel message) {
    final isMe = vm.isMyMessage(message);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 76.h,
        decoration: BoxDecoration(
          color: AppColors.grey.withValues(alpha: 0.35),
          border: Border(
            left: BorderSide(color: AppColors.primary, width: 3.w),
          ),
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12.w,
                  right: 8.w,
                  top: 8.h,
                  bottom: 8.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isMe ? 'You' : message.senderName,
                      style: textTheme.senderName,
                    ),
                    Gap(4.h),

                    if (message.allMediaUrls.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            _getReplyMediaIcon(message),
                            color: AppColors.grey,
                            size: 16.r,
                          ),
                          Gap(4.w),
                          Expanded(
                            child: Text(
                              message.allMediaUrls.length > 1
                                  ? _getReplyMediaCountLabel(message)
                                  : _getReplyMediaLabel(message),
                              style: textTheme.senderName.copyWith(
                                color: AppColors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        message.text,
                        style: textTheme.body2.copyWith(
                          color: isMe ? AppColors.grey : AppColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Center(
                child: InkWell(
                  onTap: () {
                    vm.onCancelReply();
                    HapticFeedback.selectionClick();
                  },
                  child: Icon(Icons.close, size: 18.r, color: Colors.grey),
                ),
              ),
            ),

            if (message.allMediaUrls.isNotEmpty)
              Stack(
                alignment: Alignment.center,
                children: [
                  if (message.isImage ||
                      message.type == MessageType.sticker) ...[
                    CachedNetworkImage(
                      imageUrl: message.isImage
                          ? message.allMediaUrls.first
                          : vm.getCloudinaryThumbnail(
                              message.allMediaUrls.first,
                            ),
                      width: 64.w,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.grey.withValues(alpha: 0.2),
                        width: 64.w,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.grey.withValues(alpha: 0.2),
                        width: 64.w,
                        child: Icon(
                          Icons.broken_image,
                          size: 16.r,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ] else if (message.isVideo) ...[
                    Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20.w,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  IconData _getReplyMediaIcon(MessageModel message) {
    if (message.isFile) {
      final ext = (message.fileName ?? '').split('.').last.toLowerCase();
      switch (ext) {
        case 'pdf':
          return Icons.picture_as_pdf;
        case 'doc':
        case 'docx':
          return Icons.description;
        case 'xls':
        case 'xlsx':
          return Icons.table_chart;
        case 'ppt':
        case 'pptx':
          return Icons.slideshow;
        default:
          return Icons.insert_drive_file;
      }
    }
    if (message.isVideo) return Icons.videocam_outlined;
    if (message.type == MessageType.sticker)
      return Icons.emoji_emotions_outlined;
    return Icons.image_outlined;
  }

  String _getReplyMediaLabel(MessageModel message) {
    if (message.text.isNotEmpty) return message.text;
    if (message.type == MessageType.sticker) return 'Sticker';
    if (message.isFile) return message.fileName ?? 'File';
    if (message.isVideo) return 'Video';
    if (message.isAudio) return 'Audio';
    return 'Photo';
  }

  String _getReplyMediaCountLabel(MessageModel message) {
    final count = message.allMediaUrls.length;
    if (message.isFile) return '$count files';
    if (message.isVideo) return '$count videos';
    if (message.isAudio) return '$count audios';
    return '$count photos';
  }

  Future<void> _scrollToMessage(String messageId, {DateTime? sentAt}) async {
    if (sentAt != null) {
      vm.setJumpTarget(sentAt.millisecondsSinceEpoch);
      await vm.fetchMessagesAround(sentAt);
    }

    int? index;
    for (int i = 0; i < 5; i++) {
      index = _currentMessagesList.indexWhere((m) => m.id == messageId);
      if (index != -1) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (index == null || index == -1) {
      if (mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('Message not found')));
      }
      return;
    }

    if (_itemScrollController.isAttached) {
      _itemScrollController.jumpTo(index: index);
    }

    vm.highlightMessage(messageId);
  }

  void _onPositionChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final isAtBottom = positions.any((pos) => pos.index == 0);
    final shouldShow = !isAtBottom;
    if (_showScrollBottom != shouldShow) {
      setState(() => _showScrollBottom = shouldShow);
    }

    // Pagination
    final maxIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);
    final threshold = _currentMessagesCount - 5;

    if (_currentMessagesCount >= 50 && maxIndex >= threshold) {
      // LOAD MORE MSG
    }
  }

  void _scrollToBottom() async {
    vm.switchToNormalMode();
    setState(() {
      _initialScrollIndex = null;
    });
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> onClickMedia(MediaOptions options) async {
    // Switch every media options value
    switch (options) {
      case MediaOptions.image:
      case MediaOptions.camera:
      // await vm.openCamera();
      case MediaOptions.files:
      // await vm.pickFiles();
      case MediaOptions.audio:
      //TODO: Add audio
      case MediaOptions.location:
      // TODO: Add Location Picker
    }
  }
}
