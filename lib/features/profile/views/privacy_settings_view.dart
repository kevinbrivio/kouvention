import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/features/profile/viewmodel/privacy_settings_viewmodel.dart';
import 'package:kouvention/features/profile/widgets/settings_toggle_tile.dart';

class PrivacySettingsView extends StatelessWidget {
  const PrivacySettingsView({super.key});

  @override
  Widget build(BuildContext context) => BaseView(
    provider: privacySettingsVM,
    useGradient: false,
    appBar: (_) => CustomAppBar(
      body: Text('Privacy', style: AppTextTheme.of(context).appBar),
      onBack: () => context.go(RouterRoutes.profile.path),
    ),
    builder: (context, vm) => _Body(viewmodel: vm),
  );
}

class _Body extends StatelessWidget {
  final PrivacySettingsVM viewmodel;

  const _Body({required this.viewmodel});

  @override
  Widget build(BuildContext context) {
    final privacy = viewmodel.privacy;
    if (privacy == null) return const SizedBox();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap(24.h),

            Text(
              'PRIVACY',
              style: AppTextTheme.of(context).subDescription
            ),
            Gap(12.h),

            SettingsToggleTile(
              icon: Icons.wifi_outlined,
              title: 'Online Status',
              subtitle: 'Show when you\'re online',
              value: privacy.showOnlineStatus,
              onChanged: (_) => viewmodel.toggleOnlineStatus(),
            ),

            SettingsToggleTile(
              icon: Icons.access_time_outlined,
              title: 'Last Seen',
              subtitle: 'Show when you were last active',
              value: privacy.showLastSeen,
              onChanged: (_) => viewmodel.toggleLastSeen(),
            ),

            SettingsToggleTile(
              icon: Icons.image_outlined,
              title: 'Profile Photo',
              subtitle: 'Show your profile photo to others',
              value: privacy.showProfilePhoto,
              onChanged: (_) => viewmodel.toggleProfilePhoto(),
            ),

            Gap(32.h),
          ],
        ),
      ),
    );
  }
}
