import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';
import 'package:kouvention/cores/widgets/custom_divider.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/utils/display_name_resolver.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_profile_provider.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';

class ChatListItem extends ConsumerWidget {
  final ChatModel chat;
  final bool isLastItem;

  const ChatListItem({super.key, required this.chat, required this.isLastItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(chatListVM);
    final scheme = Theme.of(context).colorScheme;

    final unread = vm.chatUnreadCount(chat);
    final lastMessage = chat.lastMessage;
    final isPinned = chat.isPinnedBy(vm.currentId!);
    final isSelected = vm.selectedChatIds.contains(chat.id);

    final resolver = ref.watch(chatListProfileResolverProvider);
    final displayName = resolveDisplayName(
      chat: chat,
      currentUid: vm.currentId!,
      resolver: resolver,
    );
    final photoUrl = resolveDisplayPhotoUrl(
      chat: chat,
      currentUid: vm.currentId!,
      resolver: resolver,
    );
    final initialLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    final typingText = _resolveTypingText(chat, vm.currentId!, resolver);

    bool showAvatarPhoto;
    final isGroup = !chat.isDirect;
    if (!isGroup) {
      final otherUid = chat.otherMemberUid(vm.currentId!);
      final otherUser = ref.watch(otherUserStreamProvider(otherUid)).value;
      showAvatarPhoto = otherUser?.privacy.showProfilePhoto ?? true;
    } else {
      showAvatarPhoto = true;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          TapDetector(
          onLongPress: () => vm.selectChat(chat.id),
          onTap: () {
            HapticFeedback.selectionClick();
            if (vm.isSelectionMode) {
              vm.selectChat(chat.id);
            } else {
              context.push('/chats/${chat.id}');
            }
          },
          child: Container(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH.w,
              vertical: AppSpacing.xs.h,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(
                  context,
                  initialLetter,
                  showAvatarPhoto,
                  photoUrl,
                  isGroup,
                  isSelected,
                  scheme,
                ),
                Gap(AppSpacing.sm.w),
                _buildMessagePreview(
                  context,
                  displayName,
                  lastMessage,
                  typingText,
                  scheme,
                ),
                Gap(AppSpacing.sm.w),
                _buildTimeAndBadge(
                  context,
                  lastMessage,
                  unread,
                  isPinned,
                  scheme,
                ),
              ],
            ),
          ),
        ),
        if (!isLastItem)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH.w),
              child: CustomDivider(
                color: scheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
          ),
      ],
    );
  }

  String? _resolveTypingText(
    ChatModel chat,
    String? currentUid,
    UserProfileResolver resolver,
  ) {
    if (currentUid == null) return null;
    final others = chat.typingUsers.where((uid) => uid != currentUid).toList();
    if (others.isEmpty) return null;
    final names = others
        .map(
          (uid) =>
              resolver.lookupDisplayName(uid) ??
              chat.memberInfo[uid]?.displayName ??
              'Someone',
        )
        .toList();
    if (names.length == 1) return '${names.first} is typing...';
    return '${names.join(', ')} others are typing...';
  }

  Widget _buildAvatar(
    BuildContext context,
    String initialLetter,
    bool showAvatarPhoto,
    String? photoUrl,
    bool isGroup,
    bool isSelected,
    ColorScheme scheme,
  ) => Stack(
    children: [
      CircleAvatar(
        radius: AppRadius.xl.r,
        backgroundColor: AppColorTokens.senderNameColor(
          chat.id,
        ).withValues(alpha: 0.3),
        child: isGroup
          ? Icon(
              Icons.people_alt_rounded,
              color: AppColorTokens.senderNameColor(chat.id).withValues(alpha: 0.7),
            )
          : Text(
              initialLetter,
              style: context.text.senderName.copyWith(
                color: AppColorTokens.senderNameColor(chat.id).withValues(alpha: 0.7),
              ),
            ),
      ),
      if (photoUrl != null && showAvatarPhoto)
        Positioned.fill(
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
              placeholder: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),
      if (isSelected)
        Positioned(
          right: 0,
          bottom: 0,
          child: CircleAvatar(
            radius: AppRadius.sm.r,
            backgroundColor: scheme.primary,
            child: Icon(
              Icons.check,
              size: AppSizing.iconXxs.r,
              color: scheme.outline,
            ),
          ),
        ),
    ],
  );

  Widget _buildMessagePreview(
    BuildContext context,
    String displayName,
    lastMessage,
    typing,
    ColorScheme scheme,
  ) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          style: context.text.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
        if (lastMessage != null) ...[
          Gap(AppSpacing.xs.h),
          Text(
            typing ?? lastMessage.text,
            style: context.text.bodySmall.copyWith(
              color: typing != null
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.5),
            ),
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ],
      ],
    ),
  );

  Widget _buildTimeAndBadge(
    BuildContext context,
    LastMessage? lastMessage,
    int unread,
    bool isPinned,
    ColorScheme scheme,
  ) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (lastMessage != null) ...[
          Text(
            DateTimeHelper.formatChatTime(lastMessage.sentAt),
            style: context.text.bodySmall.copyWith(
              color: unread > 0 ? scheme.primary : Colors.grey,
            ),
          ),
          Gap(AppSpacing.xs.h),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPinned)
              Icon(
                Icons.push_pin_rounded,
                color: scheme.primary,
                size: AppSizing.iconSm,
              ),
            if (unread > 0) ...[
              Gap(AppSpacing.xs.h),
              CircleAvatar(
                radius: AppSpacing.xs.r,
                backgroundColor: scheme.primary,
                child: Text(
                  '$unread',
                  style: context.text.labelSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
