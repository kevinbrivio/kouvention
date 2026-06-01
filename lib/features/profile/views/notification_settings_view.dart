import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/features/profile/viewmodel/notification_settings_viewmodel.dart';
import 'package:kouvention/features/profile/widgets/settings_toggle_tile.dart';

class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({super.key});

  @override
  Widget build(BuildContext context) => BaseView(
    provider: notificationSettingsVM,
    backgroundColor: AppColors.backdrop,
    useGradient: false,
    appBar: (_) => CustomAppBar(
      body: Text('Notifications', style: textTheme.appBar),
      onBack: () => context.go(RouterRoutes.profile.path),
    ),
    builder: (context, vm) => _Body(viewmodel: vm),
  );
}

class _Body extends StatelessWidget {
  final NotificationSettingsVM viewmodel;

  const _Body({required this.viewmodel});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap(24.h),

            Text(
              'NOTIFICATIONS',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 1.0,
              ),
            ),
            Gap(12.h),

            SettingsToggleTile(
              icon: Icons.notifications_outlined,
              title: 'Message Notifications',
              subtitle: 'Receive alerts for new messages',
              value: viewmodel.notificationsEnabled,
              onChanged: (_) => viewmodel.toggle(),
            ),

            Gap(16.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                'You can also manage notification sounds and vibration from your device\'s Settings app.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ),

            Gap(32.h),
          ],
        ),
      ),
    );
  }
}
