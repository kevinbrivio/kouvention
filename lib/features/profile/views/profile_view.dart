import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/liquid_glass_box.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
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
    appBar: (_) => CustomAppBar(
      onBack: () => context.go(RouterRoutes.chatList.path),
      body: Text(
        'Profile',
        style: context.text.appBarTitle,
      ),
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
        color: Theme.of(context).colorScheme.surface,
        child: const Center(child: LoadingIndicator()),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap(AppSpacing.sm.h),
            ProfileHeader(
              displayName: user.displayName,
              email: user.email,
              photoUrl: user.photoUrl,
              bio: user.bio,
              authProviderLabel: viewmodel.authProviderLabel,
              isGoogleLinked: viewmodel.isGoogleLinked,
              onChangePhoto: () => viewmodel.changeProfilePhoto(context),
            ),
            Gap(AppSpacing.lg.h),
            Text(
              'Personal Info',
              style: context.text.bodyMedium.copyWith(
                color: context.text.tertiaryText
              ),
            ),
            Gap(AppSpacing.sm.h),
            PersonalInfoSection(
              displayName: user.displayName,
              status: user.bio ?? 'No status set',
              onEditName: () => viewmodel.navigateToEditName(context),
              onEditStatus: () => viewmodel.navigateToEditStatus(context),
            ),
            Gap(AppSpacing.md.h),
            Text(
              'Settings',
              style: context.text.bodyMedium.copyWith(
                color: context.text.tertiaryText
              ),
            ),
            Gap(AppSpacing.xs.h),
            SettingsTile(
              icon: Icons.shield_outlined,
              iconColor: Theme.of(context).colorScheme.primary,
              title: 'Privacy & Security',
              subtitle: 'Manage your data and visibility',
              onTap: () => context.push(RouterRoutes.privacySettings.path),
            ),
            SettingsTile(
              icon: Icons.notifications_outlined,
              iconColor: Theme.of(context).colorScheme.primary,
              title: 'Notifications',
              subtitle: 'Message alerts and sounds',
              onTap: () =>
                  context.push(RouterRoutes.notificationSettings.path),
            ),
            SettingsTile(
              icon: Icons.brightness_6,
              iconColor: Theme.of(context).colorScheme.primary,
              title: 'Appearance',
              subtitle: switch (themeMode) {
                ThemeMode.system => 'System default',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              onTap: () => context.push(RouterRoutes.appearanceSettings.path),
            ),
            Gap(AppSpacing.lg.h),
            _buildLogoutButton(context),
            Gap(AppSpacing.lg.h),
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
              Gap(AppSpacing.md.h),
              Button(
                text: 'Sign Out',
                isDelete: true,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  viewmodel.signOut();
                },
                isCancel: true,
              ),
              Gap(AppSpacing.md.h),
              Button(
                text: 'Cancel',
                textStyle: context.text.labelMedium,
                onPressed: () => Navigator.pop(sheetContext),
                // isWhiteBackground: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) => TapDetector(
    onTap: viewmodel.isButtonLoading
        ? null
        : () => _showSignOutConfirmation(context),
    child: LiquidGlassBox(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w, vertical: AppSpacing.xs.h),
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
                    size: AppSizing.iconSm.r,
                    color: Colors.red.shade400,
                  ),
                ),
                Gap(AppSpacing.sm.w),
                Text(
                  'Sign Out',
                  style: context.text.titleSmall.copyWith(
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
    ),
  );
}
