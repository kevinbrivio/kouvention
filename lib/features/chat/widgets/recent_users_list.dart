import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
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

    return recentUsersAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Center(
        child: Text('Search users by name', style: textTheme.subDescription),
      ),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(
              'Search users by name',
              style: textTheme.subDescription,
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.searchBar,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  child: Text(
                    'Sorted by latest message',
                    style: textTheme.subDescription3.copyWith(
                      color: AppColors.primary2,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: users.length,
                    itemBuilder: (context, index) =>
                        _buildUserTile(users[index]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserTile(UserModel user) {
    final selected = isSelected?.call(user) ?? false;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onUserTap(user);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16.sp,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 16.w),
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
                color: selected ? AppColors.primary : Colors.grey[400],
                size: 24.sp,
              ),
          ],
        ),
      ),
    );
  }
}
