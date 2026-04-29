// lib/features/profile/views/profile_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/profile/viewmodel/profile_viewmodel.dart';
import 'package:kouvention/features/profile/widgets/profile_header.dart';
import 'package:kouvention/features/profile/widgets/personal_info_section.dart';
import 'package:kouvention/features/profile/widgets/settings_tile.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => BaseView(
    provider: profileVM,
    backgroundColor: AppColors.backdrop,
    appBar: (_) => AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => context.go(RouterRoutes.chatList.path),
      ),
      title: Text(
        'Profile',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: false,
    ),
    builder: (context, vm) => _ProfileBody(viewmodel: vm),
  );
}

class _ProfileBody extends StatelessWidget {
  final ProfileVM viewmodel;

  const _ProfileBody({required this.viewmodel});

  @override
  Widget build(BuildContext context) {
    final user = viewmodel.user;

    // While user data hasn't arrived from the stream yet
    if (user == null) {
      return Container(
        color: AppColors.backdrop,
        child: const Center(child: LoadingIndicator()),
      );
    }

    return Container(
      color: Colors.grey.shade50,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(24.h),

              // --- Profile Header ---
              ProfileHeader(
                displayName: user.displayName,
                email: user.email,
                photoUrl: user.photoUrl,
                authProviderLabel: viewmodel.authProviderLabel,
                isGoogleLinked: viewmodel.isGoogleLinked,
                onChangePhoto: () => viewmodel.changeProfilePhoto(context),
              ),

              Gap(32.h),

              // --- Personal Info ---
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
                onEditName: () {
                  // TODO: Navigate to edit name screen
                },
                onEditStatus: () {
                  // TODO: Navigate to edit status screen
                },
              ),

              Gap(24.h),

              // --- Settings ---
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
                onTap: () {
                  // TODO: Navigate to privacy settings
                },
              ),
              SettingsTile(
                icon: Icons.notifications_outlined,
                iconColor: AppColors.primary,
                title: 'Notifications',
                subtitle: 'Message alerts and sounds',
                onTap: () {
                  // TODO: Navigate to notification settings
                },
              ),

              Gap(32.h),

              _buildLogoutButton(),
              Gap(32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24.r),
    ),
    child: Button(text: 'Sign out', onPressed: () {}, isCancel: true,),
  );
}
