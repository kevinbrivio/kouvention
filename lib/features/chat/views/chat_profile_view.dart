import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_divider.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_profile_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/wallpaper_provider.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';

class ChatProfileView extends StatelessWidget {
  final String chatId;

  ChatProfileView({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) context.pop();
    },
    child: BaseView<ChatProfileVM>(
      useGradient: false,
      provider: chatProfileVM(chatId),
      appBar: (_) => _buildAppBar(context),
      builder: (context, vm) => _ChatProfileBody(vm: vm),
    ),
  );

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
    backgroundColor: Colors.white,
    elevation: 0.5,
    scrolledUnderElevation: 0,
    leading: IconButton(
      icon: Icon(Icons.arrow_back, color: AppColors.primary),
      onPressed: () => context.pop(),
    ),
  );
}

class _ChatProfileBody extends ConsumerStatefulWidget {
  final ChatProfileVM vm;
  _ChatProfileBody({required this.vm});
  @override
  ConsumerState<_ChatProfileBody> createState() => _ChatProfileBodyState();
}

class _ChatProfileBodyState extends ConsumerState<_ChatProfileBody> {
  ChatProfileVM get vm => widget.vm;

  @override
  Widget build(BuildContext context) {
    final chat = vm.chat;
    if (chat == null) return LoadingIndicator();

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsetsGeometry.only(
          left: 16.w,
          right: 16.w,
          top: MediaQuery.of(context).padding.top,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: CircleAvatar(
                radius: 56.r,
                backgroundColor: AppColors.senderNameColor(
                  chat.id,
                ).withValues(alpha: 0.25),
                backgroundImage: vm.chatPhotoURL != null
                    ? NetworkImage(vm.chatPhotoURL!)
                    : null,
                child: vm.chatPhotoURL == null
                    ? vm.isGroupType
                          ? Icon(
                              Icons.people_alt_rounded,
                              color: AppColors.senderNameColor(
                                chat.id,
                              ).withValues(alpha: 0.7),
                            )
                          : Text(
                              vm.chatDisplayName.isNotEmpty
                                  ? vm.chatDisplayName[0].toUpperCase()
                                  : '?',
                              style: AppTextTheme.of(context).senderName.copyWith(
                                fontSize: 48.sp,
                                color: AppColors.senderNameColor(
                                  chat.id,
                                ).withValues(alpha: 0.7),
                              ),
                            )
                    : null,
              ),
            ),

            // User creds
            Gap(6.h),
            Center(
              child: Text(
                vm.chatDisplayName,
                style: AppTextTheme.of(context).subheadline1,
              ),
            ),
            Gap(4.h),
            if (vm.isGroupType) ...[
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Group · ',
                    style: AppTextTheme.of(context).senderName,
                    children: [
                      TextSpan(
                        text: '${vm.members.length} members',
                        style: AppTextTheme.of(context).senderName,
                      ),
                    ],
                  ),
                ),
              ),
              Gap(12.h),
              Text(
                'Created by ${vm.chat?.createdBy?['name']}, ${DateTimeHelper.formatDateMonthYear(vm.chat?.createdAt ?? DateTime.now())}',
                style: AppTextTheme.of(context).senderName
              ),
              Gap(12.h),
              CustomDivider(),
              Gap(12.h),
              Text(
                '${vm.members.length} members',
                style: AppTextTheme.of(context).senderName,
              ),
              Gap(6.h),

              _buildMemberList(),
            ] else ...[
              Center(
                child: Text(
                  vm.otherUserEmail ?? '',
                  style: AppTextTheme.of(context).subDescription2,
                ),
              ),
            ],
            // --- GROUP IN COMMON ----
            if (vm.groupsInCommon.isNotEmpty) ...[
              Gap(18.h),
              Text(
                '${vm.groupsInCommon.length} Groups in common',
                style: AppTextTheme.of(context).subDescription3,
              ),
              Gap(6.h),
              _buildGroupInCommonList(),
            ],

            Gap(18.h),
            _ChatWallpaperSection(chatId: vm.chatId),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList() => ListView.separated(
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    physics: NeverScrollableScrollPhysics(),
    itemCount: vm.members.length,
    separatorBuilder: (_, __) => Gap(10.h),
    itemBuilder: (context, index) {
      final uid = vm.members[index].key;
      final member = vm.members[index].value;
      final name = member.displayName;
      final photoUrl = member.photoUrl;
      final memberUser = ref.read(otherUserStreamProvider(uid)).value;
      final showPhoto = photoUrl != null &&
          (memberUser?.privacy.showProfilePhoto ?? true);

      return InkWell(
        onTap: () => _showMemberSheet(context, vm.members[index]),
        borderRadius: BorderRadius.circular(8.r),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: showPhoto
                  ? AppColors.senderNameColor(uid).withValues(alpha: 0.25)
                  : null,
              backgroundImage: showPhoto ? NetworkImage(photoUrl) : null,
              child: !showPhoto
                  ? Text(
                      name[0].toUpperCase(),
                      style: AppTextTheme.of(context).senderName.copyWith(
                        color: AppColors.senderNameColor(
                          uid,
                        ).withValues(alpha: 0.7),
                      ),
                    )
                  : null,
            ),
            Gap(16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextTheme.of(context).senderName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildGroupInCommonList() => ListView.separated(
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    physics: NeverScrollableScrollPhysics(),
    itemCount: vm.groupsInCommon.length,
    separatorBuilder: (_, __) => Gap(10.h),
    itemBuilder: (context, index) {
      final group = vm.groupsInCommon[index];
      return InkWell(
        onTap: () => context.pushNamed(
          RouterRoutes.chatRoom.name,
          pathParameters: {'chatId': group.id},
        ),
        borderRadius: BorderRadius.circular(8.r),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: AppColors.senderNameColor(
                group.id,
              ).withValues(alpha: 0.25),
              backgroundImage: group.groupPhotoUrl != null
                  ? NetworkImage(group.groupPhotoUrl!)
                  : null,
              child: group.groupPhotoUrl == null
                  ? Icon(
                      Icons.people_alt_rounded,
                      color: AppColors.senderNameColor(
                        group.id,
                      ).withValues(alpha: 0.7),
                    )
                  : null,
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName ?? '',
                    style: AppTextTheme.of(context).senderName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${group.members.length} members',
                    style: AppTextTheme.of(context).subDescription3,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  void _showMemberSheet(
    BuildContext context,
    MapEntry<String, MemberInfo> member,
  ) {
    final memberUser = ref.read(otherUserStreamProvider(member.key)).value;
    final showPhoto = member.value.photoUrl != null &&
        (memberUser?.privacy.showProfilePhoto ?? true);

    showModalBottomSheet(
    context: context,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    backgroundColor: AppColors.backdrop,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 56.r,
              backgroundColor: showPhoto
                  ? AppColors.senderNameColor(member.key).withValues(alpha: 0.25)
                  : null,
              backgroundImage: showPhoto
                  ? NetworkImage(member.value.photoUrl!)
                  : null,
              child: !showPhoto
                  ? Text(
                      member.value.displayName[0].toUpperCase(),
                      style: TextStyle(fontSize: 24.sp),
                    )
                  : null,
            ),
            Gap(8.h),
            Text(
              member.value.displayName,
              style: AppTextTheme.of(context).subheadline1,
            ),
            Gap(16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    Navigator.pop(sheetContext);
                    await vm.navigateTo(context, RouterRoutes.chatRoom, member.key);
                  },
                  child: TransparentBox(
                    radius: BorderRadius.circular(16.r),
                    borderColor: AppColors.primary,
                    child: Row(
                      children: [
                        Icon(Icons.chat, color: AppColors.primary),
                        Gap(6.w),
                        Text('Message'),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    Navigator.pop(sheetContext);
                    await vm.navigateTo(context, RouterRoutes.chatDetail, member.key);
                  },
                  child: TransparentBox(
                    radius: BorderRadius.circular(16.r),
                    borderColor: AppColors.primary,
                    child: Row(
                      children: [
                        Icon(Icons.person, color: AppColors.primary),
                        Gap(6.w),
                        Text('View Profile'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _ChatWallpaperSection extends ConsumerWidget {
  final String chatId;
  const _ChatWallpaperSection({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(chatWallpaperProvider(chatId));
    final hasOverride =
        ref.watch(chatWallpaperOverrideProvider(chatId)) != null;
    final notifier = ref.read(wallpaperProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomDivider(),
        Gap(12.h),
        Text('WALLPAPER', style: AppTextTheme.of(context).subDescription3),
        Gap(10.h),
        _WallpaperRow(
          wallpaper: wallpaper,
          hasOverride: hasOverride,
          onTap: () => _openSheet(context, notifier, hasOverride),
        ),
      ],
    );
  }

  void _openSheet(
    BuildContext context,
    WallpaperNotifier notifier,
    bool hasOverride,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      backgroundColor: AppColors.backdrop,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Pick from Gallery'),
              subtitle: const Text('Choose an image for this chat'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await notifier.pickAndSetForChat(chatId);
              },
            ),
            if (hasOverride)
              ListTile(
                leading: Icon(Icons.public, color: AppColors.primary),
                title: const Text('Use Global Wallpaper'),
                subtitle: const Text('Follow the global setting'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await notifier.resetForChat(chatId);
                },
              ),
            if (hasOverride)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: const Text('Remove Wallpaper'),
                subtitle: const Text('Hide the wallpaper in this chat'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await notifier.resetForChat(chatId);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WallpaperRow extends StatelessWidget {
  final WallpaperConfig wallpaper;
  final bool hasOverride;
  final VoidCallback onTap;

  const _WallpaperRow({
    required this.wallpaper,
    required this.hasOverride,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = wallpaper.image;
    final status = !hasOverride
        ? 'Using global'
        : wallpaper.isRemoved
            ? 'Removed'
            : 'Custom';

    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                image: image == null
                    ? null
                    : DecorationImage(image: image, fit: BoxFit.cover),
                color: image == null ? Colors.grey.shade200 : null,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: image == null
                  ? Icon(
                      Icons.wallpaper,
                      color: Colors.grey.shade400,
                      size: 24.sp,
                    )
                  : null,
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallpaper',
                    style: AppTextTheme.of(context).subDescription2,
                  ),
                  Gap(2.h),
                  Text(
                    status,
                    style: AppTextTheme.of(context).subDescription3,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 24.sp, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
