import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/bubble_color_scheme.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/message_status.dart';
import 'package:kouvention/features/chat/utils/display_name_resolver.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_profile_provider.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_selection_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/bubble_scheme_provider.dart';
import 'package:kouvention/features/chat/viewmodel/wallpaper_provider.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/chat_room_skeleton.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/media_sheet.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/message_bubble.dart';
import 'package:kouvention/features/chat/widgets/sticker_picker.dart';
import 'package:kouvention/features/chat/widgets/selection_app_bar.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/typing_dots.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/chat_room_appbar.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/chat_room_appbar_skeleton.dart';

class ChatRoomView extends ConsumerWidget {
  final String chatId;

  const ChatRoomView({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionVM = ref.watch(chatSelectionVM(chatId));
    final currentUid = ref.read(currentUidProvider);
    final wallpaper = ref.watch(chatWallpaperProvider(chatId));
    final wallpaperImage = wallpaper.image;

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
        appBar: (vm) {
          if (selectionVM.isSelecting) {
            return SelectionAppBar(chatId: chatId, currentUid: currentUid!);
          }
          final chatAsync = ref.watch(chatMetadataStreamProvider(chatId));
          if (chatAsync.isLoading) {
            return const ChatRoomAppBarSkeleton();
          }
          return ChatRoomAppBar(chatId: chatId);
        },
        builder: (context, vm) {
          final queryParams = GoRouterState.of(context).uri.queryParameters;
          return _ChatRoomBody(
            chatId: chatId,
            viewmodel: vm,
            scrollToMessageId: queryParams['scrollTo'],
            scrollToSentAt: queryParams['sentAt'],
          );
        },
        backgroundImage: wallpaperImage == null
            ? null
            : DecorationImage(
                image: wallpaperImage,
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
    vm.addListener(_onVmChanged);
    _itemPositionsListener.itemPositions.addListener(_onPositionChanged);

    // Update keyboard height after init screen
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        vm.dismissPanels();
      }
    });

    if (widget.scrollToMessageId != null && widget.scrollToSentAt != null) {
      _handlePendingScroll();
    }
  }

  void _onVmChanged() {
    // The VM already called notifyListeners(). We just need a rebuild so
    // the widget reads the latest loadedOlderMessageModels from the VM
    if (mounted) setState(() {});
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
  void didUpdateWidget(covariant _ChatRoomBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If BaseView rebuilt us with a different VM instance (e.g. the
    // provider recreated for any reason), rebind the listener.
    if (!identical(oldWidget.viewmodel, vm)) {
      oldWidget.viewmodel.removeListener(_onVmChanged);
      vm.addListener(_onVmChanged);
    }
  }

  @override
  void dispose() {
    vm.removeListener(_onVmChanged);
    _textController.dispose();
    _itemPositionsListener.itemPositions.removeListener(_onPositionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The VM listener attached in initState drives rebuilds on every
    // notifyListeners() — including loadOlderMessages, typing, send
    // state, etc. The streams below still re-emit on their own cadence
    // (Drift watch, chat metadata, auth) for their respective concerns.
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.chatId));
    final chatAsync = ref.watch(chatMetadataStreamProvider(widget.chatId));
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid;
    final isChatReady = chatAsync.hasValue && chatAsync.value != null;

    return Column(
      children: [
        if (kDebugMode)
          _DebugSyncStateBar(
            chatId: widget.chatId,
            isLoadingOlder: vm.isLoadingOlder,
            hasMore: vm.hasMoreMessges,
            loadedOlderCount: vm.loadedOlderMessages.length,
            oldestLoadedSentAt: vm.oldestLoadedSentAt,
          ),
        Expanded(
          child: messagesAsync.when(
            loading: () => const ChatRoomSkeleton(),
            error: (err, s) => Center(child: Text('Error: $err')),
            data: (messages) {
              if (messages.isNotEmpty && vm.oldestLoadedSentAt == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (messages.isNotEmpty) {
                    vm.setOldestLoadedSentAt(
                      messages.last.sentAt.millisecondsSinceEpoch,
                    );
                  }
                });
              }
              _currentMessagesCount = messages.length;
              _currentMessagesList = messages;

              debugPrint(
                '[chatRoomView] data: stream=${messages.length} '
                'loadedOlder=${vm.loadedOlderMessages.length} '
                'combined=${messages.length + vm.loadedOlderMessages.length}',
              );

              if (messages.isEmpty && !isChatReady) {
                return const ChatRoomSkeleton();
              }
              if (messages.isEmpty) {
                return const Center(child: Text('No messages yet. Say hi!'));
              }

              return GestureDetector(
                onTap: () => vm.dismissPanels(),
                child: Stack(
                  children: [
                    vm.error != null
                        ? Center(child: Text(vm.error ?? ''))
                        : _buildMessageList(
                            [...messages, ...vm.loadedOlderMessageModels],
                            chatAsync.value,
                            currentUid,
                          ),

                    if (_showScrollBottom)
                      Positioned(
                        right: AppSpacing.md.w,
                        bottom: AppSpacing.md.h,
                        child: GestureDetector(
                          onTap: _scrollToBottom,
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
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
                              color: Theme.of(context).colorScheme.primary,
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
          _buildTypingIndicator(chatAsync.value!, currentUid, ref),

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
      bottom: AppSpacing.sm.h,
      top: MediaQuery.of(context).padding.top + kToolbarHeight,
    ),
    itemCount: messages.length + (vm.hasMoreMessges ? 1 : 0),
    itemBuilder: (context, index) {
      if (index == messages.length) {
        return vm.isLoadingOlder
            ? Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                child: Center(
                  child: SizedBox(
                    width: AppSpacing.xl.w,
                    height: AppSpacing.xl.w,
                    child: LoadingIndicator(),
                  ),
                ),
              )
            : SizedBox.shrink();
      }

      final message = messages[index];
      final isMe = message.senderId == currentUid;
      final showDate = _shouldShowDate(messages, index);

      /// Check if the NEXT message is from the same sender (in reverse)
      final isFirstSequence =
          index == messages.length - 1 ||
          showDate ||
          (index + 1 < messages.length &&
              messages[index + 1].senderId != message.senderId);

      return Column(
        children: [
          if (showDate)
            _buildDateSeparator(
              context,
              message.sentAt,
              ref.watch(bubbleSchemeProvider),
            ),
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

  Widget _buildDateSeparator(
    BuildContext context,
    DateTime date,
    BubbleColorScheme bubbleScheme,
  ) {
    final now = DateTime.now();
    final isToday =
        date.day == now.day && date.month == now.month && date.year == now.year;

    final separatorBg = bubbleScheme.sentBubble.withValues(alpha: 0.12);
    final separatorText = bubbleScheme.isDark
        ? Colors.white.withValues(alpha: 0.7)
        : bubbleScheme.sentBubble.withValues(alpha: 0.8);

    return Container(
      decoration: BoxDecoration(
        color: separatorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      padding: EdgeInsets.all(AppSpacing.xxs.w),
      child: Text(
        isToday ? 'TODAY' : '${date.day}/${date.month}/${date.year}',
        style: context.text.bodySmall.copyWith(color: separatorText),
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
        return Icon(
          Icons.done_all,
          size: 14.sp,
          color: Theme.of(context).colorScheme.primary,
        );
    }
  }

  Widget _buildTypingIndicator(
    ChatModel? chat,
    String? currentUid,
    WidgetRef ref,
  ) {
    if (chat == null || currentUid == null) return const SizedBox.shrink();
    final others = chat.typingUsers.where((uid) => uid != currentUid).toList();
    if (others.isEmpty) return const SizedBox.shrink();

    final isGroup = chat.type == 'group';
    final resolver = ref.watch(chatRoomProfileResolverProvider(chat.id));
    final chatName = resolveDisplayName(
      chat: chat,
      currentUid: currentUid,
      resolver: resolver,
    );
    final scheme = ref.watch(bubbleSchemeProvider);
    final receivedColor = scheme.receivedBubble;
    final isLightReceived = receivedColor.computeLuminance() > 0.5;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 4.h),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (isGroup)
            CircleAvatar(
              radius: 14.r,
              backgroundColor: receivedColor,
              child: Text(
                chatName.isNotEmpty ? chatName[0] : '?',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isLightReceived ? Colors.grey[700] : Colors.white,
                ),
              ),
            ),
          Gap(AppSpacing.xs.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: receivedColor,
              borderRadius: BorderRadius.circular(AppRadius.lg.r),
            ),
            child: TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatModel? chat, String? currentUid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        left: 6.w,
        right: 6.w,
        top: AppSpacing.xs.h,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: _buildTextField(ctx, chat, currentUid),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    ChatModel? chat,
    String? currentUid,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xs.w,
              vertical: AppSpacing.xxs.h,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppSurfaceDark.surfaceInputBar
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(
                vm.replyMessage != null ? AppRadius.md.r : AppRadius.xl.r,
              ),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: Column(
                children: [
                  if (vm.replyMessage != null)
                    _buildReplyPreview(vm.replyMessage!),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          AppSizing.chatInputBarMin.h - (AppSpacing.xxs.h * 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          padding: EdgeInsets.all(AppSpacing.xxs.r),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            size: AppSizing.iconSm.r,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () {
                            vm.toggleStickerPanel(context);
                            _focusNode.unfocus();
                          },
                        ),
                        Flexible(
                          child: TextField(
                            focusNode: _focusNode,
                            controller: _textController,
                            minLines: 1,
                            maxLines: 5,
                            onChanged: vm.onTextChanged,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: context.text.labelMedium.copyWith(
                                color: context.text.tertiaryText,
                              ),
                              isDense: true,
                              filled: false,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: AppSpacing.xxs.h,
                              ),
                            ),
                            style: context.text.typeMessage,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.all(AppSpacing.xxs.r),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.add,
                            size: AppSizing.iconSm.r,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () => vm.toggleMediaPanel(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Gap(AppSpacing.xs.w),
        _SendMicButton(
          controller: _textController,
          isSending: vm.isSending,
          onSend: () {
            vm.sendMessage(_textController.text);
            _textController.clear();
            _scrollToBottom();
          },
          onRecord: vm.startRecording,
        ),
      ],
    );
  }

  Widget _buildMediaPanel() => AnimatedSize(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    alignment: Alignment.topCenter,
    child: vm.showMediaPanel
        ? SizedBox(
            width: double.infinity,
            child: MediaSheet(vm: vm),
          )
        : const SizedBox.shrink(),
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

    // Resolve fresh display name for the replied-to sender
    final replySender = ref
        .watch(otherUserStreamProvider(message.senderId))
        .value;
    final resolvedReplyName = replySender?.displayName ?? message.senderName;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm.r),
      child: Container(
        height: 76.h,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3.w,
            ),
          ),
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.sm.w,
                  right: AppSpacing.xs.w,
                  top: AppSpacing.xs.h,
                  bottom: AppSpacing.xs.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isMe ? 'You' : resolvedReplyName,
                      style: context.text.senderName,
                    ),
                    Gap(AppSpacing.xxs.h),

                    if (message.allMediaUrls.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            _getReplyMediaIcon(message),
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                            size: AppRadius.lg.r,
                          ),
                          Gap(AppSpacing.xxs.w),
                          Expanded(
                            child: Text(
                              message.allMediaUrls.length > 1
                                  ? _getReplyMediaCountLabel(message)
                                  : _getReplyMediaLabel(message),
                              style: context.text.senderName.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
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
                        style: context.text.bodySmall.copyWith(
                          color: context.text.secondaryText,
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
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
              child: Center(
                child: InkWell(
                  onTap: () {
                    vm.onCancelReply();
                    HapticFeedback.selectionClick();
                  },
                  child: Icon(
                    Icons.close,
                    size: AppSizing.iconSm.r,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            if (message.allMediaUrls.isNotEmpty)
              Stack(
                key: ValueKey('reply_thumb_${message.id}'),
                alignment: Alignment.center,
                children: [
                  if ((message.isImage ||
                          message.type == MessageType.sticker) &&
                      _isImageUrl(message.allMediaUrls.first)) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                      child: CachedNetworkImage(
                        imageUrl: message.allMediaUrls.first,
                        width: 76.h,
                        height: 76.h,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.5)
                              .withValues(alpha: 0.2),
                          width: 64.w,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.5)
                              .withValues(alpha: 0.2),
                          width: 64.w,
                          child: Icon(
                            Icons.broken_image,
                            size: AppRadius.lg.r,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ] else if (message.isVideo) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                      child: SizedBox(
                        width: 76.h,
                        height: 76.h,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: vm.getCloudinaryThumbnail(
                                message.allMediaUrls.first,
                              ),
                              fit: BoxFit.cover,
                            ),
                            Center(
                              child: Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: AppSpacing.lg.w,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (message.isFile && _isPdf(message.fileName)) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                      child: CachedNetworkImage(
                        imageUrl: vm.getCloudinaryThumbnail(
                          message.allMediaUrls.first,
                        ),
                        width: 76.h,
                        height: 76.h,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 76.h,
                          height: 76.h,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.5)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm.r),
                          ),
                          child: Icon(
                            _getReplyMediaIcon(message),
                            size: AppRadius.xl.r,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ] else if (message.isFile) ...[
                    Container(
                      width: 76.h,
                      height: 76.h,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.5)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm.r),
                      ),
                      child: Icon(
                        _getReplyMediaIcon(message),
                        size: AppRadius.xl.r,
                        color: Colors.grey,
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

  bool _isPdf(String? fileName) =>
      (fileName ?? '').toLowerCase().endsWith('.pdf');

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

    debugPrint('===== Current pagination position: $maxIndex');

    final threshold = _currentMessagesCount - 5;

    if (_currentMessagesCount >= 10 && maxIndex >= threshold) {
      vm.loadOlderMessages();
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
}

bool _isImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp');
}

/// Mic/Send button that rebuilds itself without touching the parent state.
class _SendMicButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onRecord;
  final bool isSending;

  const _SendMicButton({
    required this.controller,
    required this.onSend,
    required this.onRecord,
    required this.isSending,
  });

  @override
  State<_SendMicButton> createState() => _SendMicButtonState();
}

class _SendMicButtonState extends State<_SendMicButton> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _SendMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final nowHasText = widget.controller.text.trim().isNotEmpty;
    if (nowHasText != _hasText) {
      setState(() => _hasText = nowHasText);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _hasText ? widget.onSend() : widget.onRecord(),
    child: Container(
      width: AppSizing.chatInputBarMin.h,
      height: AppSizing.chatInputBarMin.h,
      decoration: BoxDecoration(
        color: widget.isSending
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: widget.isSending
            ? SizedBox(
                height: AppSizing.iconMd,
                width: AppSizing.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Icon(
                _hasText ? Icons.send : Icons.mic,
                size: AppSizing.iconMd.r,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
      ),
    ),
  );
}

/// Debug-only bar shown above the message list. Surfaces the 4-field
/// sync state (AGENTS.md §8) so older-message pagination can be
/// observed live in the simulator without tailing `adb logcat`.
///
/// Only rendered when [kDebugMode] is true; the production view shows
/// the legacy "PAGINATION IS WORKING!" banner instead.
class _DebugSyncStateBar extends ConsumerWidget {
  final String chatId;
  final bool isLoadingOlder;
  final bool hasMore;
  final int loadedOlderCount;
  final int oldestLoadedSentAt;

  const _DebugSyncStateBar({
    required this.chatId,
    required this.isLoadingOlder,
    required this.hasMore,
    required this.loadedOlderCount,
    required this.oldestLoadedSentAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatRowAsync = ref.watch(chatRowDebugStreamProvider(chatId));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 6.h),
      color: Colors.black.withValues(alpha: 0.85),
      child: chatRowAsync.when(
        loading: () => const Text(
          '4-field state: loading...',
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
        error: (e, _) => Text(
          '4-field state error: $e',
          style: const TextStyle(color: Colors.redAccent, fontSize: 11),
        ),
        data: (row) {
          if (row == null) {
            return const Text(
              '4-field state: chat row missing locally',
              style: TextStyle(color: Colors.white, fontSize: 11),
            );
          }
          return Wrap(
            spacing: 6.w,
            runSpacing: 4.h,
            children: [
              _chip(
                label: 'hasMoreOlderRemote',
                value: row.hasMoreOlderRemote.toString(),
                color: row.hasMoreOlderRemote ? Colors.green : Colors.orange,
              ),
              _chip(
                label: 'hasLocalGap',
                value: row.hasLocalGap.toString(),
                color: row.hasLocalGap ? Colors.red : Colors.grey,
              ),
              _chip(
                label: 'isLoadingOlder',
                value: isLoadingOlder.toString(),
                color: isLoadingOlder ? Colors.amber : Colors.grey,
              ),
              _chip(
                label: 'hasMore(vm)',
                value: hasMore.toString(),
                color: hasMore ? Colors.green : Colors.grey,
              ),
              _chip(
                label: 'oldestCachedAt',
                value: row.oldestCachedAt == 0
                    ? '0 (none)'
                    : _fmtTs(row.oldestCachedAt),
                color: Colors.cyan,
              ),
              _chip(
                label: 'latestSeenRemoteAt',
                value: row.latestSeenRemoteAt == 0
                    ? '0 (none)'
                    : _fmtTs(row.latestSeenRemoteAt),
                color: Colors.cyan,
              ),
              _chip(
                label: 'oldestLoaded(vm)',
                value: oldestLoadedSentAt == 0
                    ? '0'
                    : _fmtTs(oldestLoadedSentAt),
                color: Colors.cyan,
              ),
              _chip(
                label: 'loadedOlderRows',
                value: loadedOlderCount.toString(),
                color: Colors.purpleAccent,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10.sp,
                fontFamily: 'monospace',
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTs(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}
