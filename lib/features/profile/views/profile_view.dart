import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/profile/viewmodel/profile_viewmodel.dart';
import 'package:kouvention/features/profile/widgets/profile_header.dart';
import 'package:kouvention/features/profile/widgets/personal_info_section.dart';
import 'package:kouvention/features/profile/widgets/settings_tile.dart';
import 'package:kouvention/features/shared/viewmodel/theme_mode_provider.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => BaseView(
    provider: profileVM,
    useGradient: false,
    appBar: (_) => AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.primary,),
        onPressed: () => context.go(RouterRoutes.chatList.path),
      ),
      title: Text('Profile', style: AppTextTheme.of(context).appBar),
      centerTitle: false,
    ),
    builder: (context, vm) => _ProfileBody(viewmodel: vm),
  );
}

class _ProfileBody extends ConsumerWidget {
  final ProfileVM viewmodel;

  const _ProfileBody({required this.viewmodel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = viewmodel.user;
    final themeMode = ref.watch(themeModeProvider);

    if (user == null) {
      return Container(
        color: AppColors.backdrop,
        child: const Center(child: LoadingIndicator()),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap(24.h),
            ProfileHeader(
              displayName: user.displayName,
              email: user.email,
              photoUrl: user.photoUrl,
              bio: user.bio,
              authProviderLabel: viewmodel.authProviderLabel,
              isGoogleLinked: viewmodel.isGoogleLinked,
              onChangePhoto: () => viewmodel.changeProfilePhoto(context),
            ),
            Gap(32.h),
            Text(
              'PERSONAL INFO',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 1.0,
              ),
            ),
            Gap(12.h),
            PersonalInfoSection(
              displayName: user.displayName,
              status: user.bio ?? 'No status set',
              onEditName: () => viewmodel.navigateToEditName(context),
              onEditStatus: () => viewmodel.navigateToEditStatus(context),
            ),
            Gap(24.h),
            Text(
              'SETTINGS',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 1.0,
              ),
            ),
            Gap(12.h),
            SettingsTile(
              icon: Icons.shield_outlined,
              iconColor: AppColors.primary,
              title: 'Privacy & Security',
              subtitle: 'Manage your data and visibility',
              onTap: () => context.push(RouterRoutes.privacySettings.path),
            ),
            SettingsTile(
              icon: Icons.notifications_outlined,
              iconColor: AppColors.primary,
              title: 'Notifications',
              subtitle: 'Message alerts and sounds',
              onTap: () =>
                  context.push(RouterRoutes.notificationSettings.path),
            ),
            SettingsTile(
              icon: Icons.brightness_6,
              iconColor: AppColors.primary,
              title: 'Appearance',
              subtitle: switch (themeMode) {
                ThemeMode.system => 'System default',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              onTap: () => context.push(RouterRoutes.appearanceSettings.path),
            ),
            Gap(32.h),
            _buildLogoutButton(context),
            Gap(32.h),
          ],
        ),
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    if (viewmodel.isButtonLoading) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sign Out',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
              ),
              Gap(8.h),
              Text(
                'Are you sure you want to sign out?',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
              ),
              Gap(24.h),
              Button(
                text: 'Sign Out',
                onPressed: () {
                  Navigator.pop(sheetContext);
                  viewmodel.signOut();
                },
                isCancel: true,
              ),
              Gap(8.h),
              Button(
                text: 'Cancel',
                onPressed: () => Navigator.pop(sheetContext),
                isWhiteBackground: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) => GestureDetector(
    onTap: viewmodel.isButtonLoading
        ? null
        : () => _showSignOutConfirmation(context),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
      child: viewmodel.isButtonLoading
          ? Center(
              child: SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.red.shade400,
                ),
              ),
            )
          : Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 24.sp,
                    color: Colors.red.shade400,
                  ),
                ),
                Gap(12.w),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
    ),
  );
}
