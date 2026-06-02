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

class _Body extends StatefulWidget {
  final NotificationSettingsVM viewmodel;

  const _Body({required this.viewmodel});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.viewmodel.refreshPermission();
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Gap(24.h),

          Text(
            'NOTIFICATIONS',
            style: textTheme.subDescription2.copyWith(color: AppColors.grey)
          ),
          Gap(12.h),

          if (!widget.viewmodel.osPermissionGranted) ...[
            _buildPermissionBanner(),
            Gap(16.h),
          ],

          Opacity(
            opacity: widget.viewmodel.osPermissionGranted ? 1.0 : 0.5,
            child: AbsorbPointer(
              absorbing: !widget.viewmodel.osPermissionGranted,
              child: SettingsToggleTile(
                icon: Icons.notifications_outlined,
                title: 'Message Notifications',
                subtitle: 'Receive alerts for new messages',
                value: widget.viewmodel.notificationsEnabled,
                onChanged: (_) => widget.viewmodel.toggle(),
              ),
            ),
          ),

          Gap(16.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              widget.viewmodel.osPermissionGranted
                  ? 'You can also manage notification sounds and vibration from your device\'s Settings app.'
                  : 'Notifications are disabled at the system level. Tap "Open Settings" to enable them.',
              style: textTheme.subDescription.copyWith(color: AppColors.grey)
            ),
          ),

          Gap(32.h),
        ],
      ),
    ),
  );

  Widget _buildPermissionBanner() => Container(
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: Colors.amber.shade200),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.amber.shade700,
          size: 32.sp,
        ),
        Gap(12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Permission Required',
                style: textTheme.subDescription.copyWith(color: AppColors.black)
              ),
              Gap(4.h),
              Text(
                'Notifications are disabled in your device settings.',
                style: textTheme.subDescription3.copyWith(color: AppColors.grey)
              ),
            ],
          ),
        ),
        Gap(8.w),
        TextButton(
          onPressed: widget.viewmodel.openAppSettings,
          child: Text(
            'Open Settings',
            style: textTheme.subDescription3.copyWith(color: AppColors.primary)
          ),
        ),
      ],
    ),
  );
}
