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
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_selection_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/message_bubble.dart';
import 'package:kouvention/features/chat/widgets/selection_app_bar.dart';
import 'package:kouvention/features/chat/widgets/typing_dots.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChatRoomView extends ConsumerWidget {
  final String chatId;

  const ChatRoomView({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionVM = ref.watch(chatSelectionVM);

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
        provider: chatRoomVM(chatId),
        useGradient: false,
        backgroundColor: Colors.white,
        appBar: (vm) => selectionVM.isSelecting
            ? SelectionAppBar(chatVM: vm)
            : _buildAppBar(context, vm),
        builder: (context, vm) => _ChatRoomBody(chatId: chatId, viewmodel: vm),
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

PreferredSizeWidget _buildAppBar(BuildContext context, ChatRoomVM vm) => AppBar(
  backgroundColor: Colors.white,
  elevation: 0.5,
  scrolledUnderElevation: 0,
  leading: IconButton(
    icon: Icon(Icons.arrow_back, color: AppColors.primary),
    onPressed: () => context.go(RouterRoutes.chatList.path),
  ),
  title: InkWell(
    onTap: () {
      if (context.mounted) context.push('/chats/${vm.chat!.id}/detail');
    },
    borderRadius: BorderRadius.circular(8.r),
    child: Row(
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
  final ItemScrollController _itemScrollController = ItemScrollController();
  final _focusNode = FocusNode();

  ChatRoomVM get viewmodel => widget.viewmodel;

  // @override
  // void initState() {
  //   super.initState();
  // }

  // void _onScroll() {
  //   if (_itemScrollController.position.pixels >=
  //       _itemScrollController.position.maxScrollExtent - 100) {
  //     viewmodel.loadMoreMessages();
  //   }
  // }

  @override
  void dispose() {
    _textController.dispose();
    // _scrollController.dispose();
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

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      reverse: true,
      padding: EdgeInsets.only(
        bottom: 12.h,
        top: MediaQuery.of(context).padding.top + kToolbarHeight,
      ),
      itemCount: viewmodel.messages.length + (viewmodel.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == viewmodel.messages.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Center(
              child: SizedBox(
                width: 20.w,
                height: 20.w,
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
            MessageBubble(
              viewmodel: viewmodel,
              isFirstSequence: isFirstSequence,
              message: message,
              isMe: isMe,
              onReplyMessage: () => viewmodel.onSwipedMessage(message),
              onTapReply: _scrollToMessage,
            ),
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

  Widget _buildTypingIndicator() => Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
    alignment: Alignment.centerLeft,
    child: Row(
      children: [
        if (viewmodel.isGroup)
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
          child: TypingDots(),
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
    child: _buildTextField(),
  );

  Widget _buildTextField() => Row(
    children: [
      IconButton(
        icon: Icon(Icons.add, color: AppColors.primary),
        onPressed: () {},
      ),

      Flexible(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: viewmodel.replyMessage != null ? 6.w : 12.w,
            vertical: 4.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(
              viewmodel.replyMessage != null ? 12.r : 24.r,
            ),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: Column(
              children: [
                if (viewmodel.replyMessage != null)
                  _buildReplyPreview(viewmodel.replyMessage!),

                TextField(
                  focusNode: _focusNode,
                  controller: _textController,
                  minLines: 1,
                  maxLines: 5,
                  onChanged: viewmodel.onTextChanged,
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
            viewmodel.sendMessage(_textController.text);
            _textController.clear();
          }
        },
        child: CircleAvatar(
          radius: 20.r,
          backgroundColor: viewmodel.isSending
              ? AppColors.grey
              : AppColors.primary,
          child: viewmodel.isSending
              ? SizedBox(
                  width: 18.sp,
                  height: 18.sp,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.send, color: Colors.white, size: 18.sp),
        ),
      ),
    ],
  );

  Widget _buildReplyPreview(MessageModel message) {
    final isMe = viewmodel.isMyMessage(message);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16.r),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3.w),
        ),
      ),
      padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 4.h, bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name
                Text(
                  isMe ? 'You' : viewmodel.senderDisplayName(message.senderId),
                  style: textTheme.senderName,
                ),

                Gap(4.h),

                Text(
                  message.text,
                  style: textTheme.body2.copyWith(
                    color: AppColors.grey.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),

          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              viewmodel.onCancelReply();
            },
            child: Icon(Icons.close, size: 18.r, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _scrollToMessage(String messageId) async {
    final index = await viewmodel.findMessageIndex(messageId);

    if (index == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message not found')));
      }
      return;
    }

    // Rebuild page after we load older mesages
    viewmodel.notifyListeners();

    await Future.delayed(Duration(milliseconds: 100));

    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    viewmodel.highlightMessage(messageId);
  }
}
