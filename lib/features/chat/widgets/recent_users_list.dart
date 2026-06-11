import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
import 'package:kouvention/features/chat/viewmodel/recent_users_provider.dart';
import 'package:kouvention/features/user/models/user_model.dart';

class RecentUsersList extends ConsumerWidget {
  final void Function(UserModel user) onUserTap;
  final bool Function(UserModel user)? isSelected; // ← add
  final bool showSelection;

  const RecentUsersList({
    super.key,
    required this.onUserTap,
    this.isSelected,
    this.showSelection = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentUsersAsync = ref.watch(recentUsersProvider);
    final scheme = Theme.of(context).colorScheme;

    return recentUsersAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Center(
        child: Text(
          'Failed to load recent users',
          style: context.text.bodyMedium.copyWith(
            color: context.text.secondaryText,
          ),
        ),
      ),
      data: (users) {
        print('========== USERS ===========');
        for (final u in users) {
          print(u);
        }
        print('========== USERS.isEmpty: ${users.isEmpty} ==========');
        if (users.isEmpty) {
          return Center(
            child: Text(
              'Search users by name',
              style: context.text.bodyMedium.copyWith(
                color: context.text.secondaryText,
              ),
            ),
          );
        }

        return Container(
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w,
                    vertical: AppSpacing.sm.h,
                  ),
                  child: Text(
                    'Sorted by latest message',
                    style: context.text.labelSmall.copyWith(
                      color: context.text.tertiaryText,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: users.length,
                    itemBuilder: (context, index) =>
                        _buildUserTile(context, users[index]),
                  ),
                ),
              ],
            ),
        );
      },
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user) {
    final selected = isSelected?.call(user) ?? false;

    return TapDetector(
      onTap: () => onUserTap(user),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.betweenCards.h,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor:
                  user.photoUrl != null && user.privacy.showProfilePhoto
                  ? null
                  : AppColorTokens.senderNameColor(
                      user.uid,
                    ).withValues(alpha: 0.2),
              backgroundImage:
                  user.photoUrl != null && user.privacy.showProfilePhoto
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null || !user.privacy.showProfilePhoto
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: context.text.senderName.copyWith(
                        fontSize: 18.sp,
                        color: AppColorTokens.senderNameColor(
                          user.uid,
                        ).withValues(alpha: 0.7),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Selection indicator
            if (showSelection)
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[400],
                size: 24.sp,
              ),
          ],
        ),
      ),
    );
  }
}
