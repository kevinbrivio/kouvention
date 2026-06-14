import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/utils/display_name_resolver.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_profile_provider.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/user/models/user_model.dart';

class ChatRoomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String chatId;

  const ChatRoomAppBar({super.key, required this.chatId});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    return 'Last seen ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid;
    final scheme = Theme.of(context).colorScheme;

    final chatAsync = ref.watch(chatMetadataStreamProvider(chatId));

    return chatAsync.when(
      loading: () => AppBar(
        elevation: 0.5,
        title: const CircularProgressIndicator.adaptive(),
      ),
      error: (err, stack) => AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Error: $err'),
      ),
      data: (chat) {
        if (chat == null || currentUid == null) {
          return AppBar();
        }

        final isDirect = chat.type == 'direct';
        final resolver = ref.watch(chatRoomProfileResolverProvider(chatId));
        final chatDisplayName = resolveDisplayName(
          chat: chat,
          currentUid: currentUid,
          resolver: resolver,
        );
        final chatPhotoUrl = resolveDisplayPhotoUrl(
          chat: chat,
          currentUid: currentUid,
          resolver: resolver,
        );

        String? onlineStatusText;
        UserModel? otherUser;
        if (isDirect) {
          final otherUid = chat.otherMemberUid(currentUid);
          otherUser = ref.watch(otherUserStreamProvider(otherUid)).value;

          if (otherUser != null && otherUser.privacy.showOnlineStatus) {
            if (otherUser.isOnline) {
              onlineStatusText = 'Online';
            } else if (otherUser.privacy.showLastSeen &&
                otherUser.lastSeen != null) {
              onlineStatusText = _formatLastSeen(otherUser.lastSeen!);
            }
          }
        }

        final showPhoto = isDirect
            ? (otherUser?.privacy.showProfilePhoto ?? true) &&
                  chatPhotoUrl != null
            : chatPhotoUrl != null;

        return AppBar(
          elevation: 0.5,
          scrolledUnderElevation: 0,
          leading: TapDetector(
            onTap: () => context.go(RouterRoutes.chatList.path),
            borderRadius: AppRadius.full.r,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.sm.r),
              child: Icon(
                Icons.arrow_back,
                color: scheme.primary,
                size: AppSizing.iconSm.r,
              ),
            ),
          ),
          title: TapDetector(
            onTap: () {
              if (context.mounted) context.push('/chats/${chat.id}/detail');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Container(
                    width: AppSizing.avatarSm.r,
                    height: AppSizing.avatarSm.r,
                    color: scheme.primary.withValues(alpha: 0.2),
                    child: showPhoto
                        ? CachedNetworkImage(
                            imageUrl: chatPhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox(),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                chatDisplayName.isNotEmpty
                                    ? chatDisplayName[0].toUpperCase()
                                    : '?',
                                style: context.text.senderName.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              chatDisplayName.isNotEmpty
                                  ? chatDisplayName[0].toUpperCase()
                                  : '?',
                              style: context.text.senderName.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                  ),
                ),
                Gap(AppSpacing.avatarGap.w),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chatDisplayName,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: context.text.senderName,
                      ),
                      if (onlineStatusText != null)
                        Text(
                          onlineStatusText,
                          style: context.text.labelSmall.copyWith(
                            color: onlineStatusText == 'Online'
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.6),
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
              icon: Icon(
                Icons.phone,
                color: scheme.primary,
                size: AppSizing.iconMd.w,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: scheme.primary,
                size: AppSizing.iconMd.w,
              ),
              onPressed: () {},
            ),
          ],
        );
      },
    );
  }
}
