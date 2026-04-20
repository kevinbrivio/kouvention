import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/hidden_app_bar.dart';
import 'package:kouvention/cores/widgets/icon_holder.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/privacy_policy/views/viewmodel/privacy_policy_viewmmodel.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) => BaseView(
    provider: privacyPolicyVM,
    appBar: (_) => HiddenAppBar(),
    builder: _buildScreen,
  );

  Widget _buildScreen(BuildContext context, PrivacyPolicyVM vm) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 16.w),
                child: Text('Privacy Policy', style: textTheme.headline1),
              ),
              Gap(4.h),
              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 16.w),
                child: Text(
                  'Please review how we handle your data before continuing.',
                  style: textTheme.subDescription,
                ),
              ),
              Gap(12.h),
              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 16.w),
                child: TransparentBox(child: _buildPolicy()),
              ),

              Gap(12.h),

              _buildAcceptButton(vm),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildPolicy() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Data Collection
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconHolder(
            radius: BorderRadius.circular(24.r),
            icon: const Icon(Icons.abc),
          ),
          Gap(12.w),
          Text('Data Collected', style: textTheme.subheadline1),
        ],
      ),
      Gap(4.h),
      Column(
        children: [
          Text(
            'We collect information necessary to provide you with secure '
            'messaging services. This includes your profile details, usage '
            'data and device information.',
            style: textTheme.subDescription,
            softWrap: true,
          ),
          Gap(6.h),
          Row(
            children: [
              Icon(Icons.check_box_rounded, size: 12.w, color: AppColors.white.withValues(alpha: 0.8),),
              Gap(8.w),
              Text('Basic profile information', style: textTheme.subDescription,)
            ],
          ),
          Gap(4.h),
          Row(
            children: [
              Icon(Icons.check_box_rounded, size: 12.w, color: AppColors.white.withValues(alpha: 0.8),),
              Gap(8.w),
              Text('App interaction metrics', style: textTheme.subDescription,)
            ],
          )
        ],
      ),
      Gap(16.h),
      // Firebase Integration
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Firebase Integration', style: textTheme.subheadline1),
          Gap(12.w),
          IconHolder(
            radius: BorderRadius.circular(24.r),
            icon: const Icon(Icons.dataset),
          ),
        ],
      ),
      Gap(4.h),
      Text(
        'Our real-time messaging infrastructure is powered by Google '
        'Firebase. Your messages are encrypted in transit and securely '
        'stored using Firebase\'s cloud infrastructure, adhering to '
        'strict security protocols.',
        style: textTheme.subDescription,
        softWrap: true,
        textDirection: TextDirection.rtl,
      ),
      Gap(16.h),
      // Your Data Rights
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconHolder(
            radius: BorderRadius.circular(24.r),
            icon: const Icon(Icons.shield_outlined),
          ),
          Gap(12.w),
          Text('Your Data Rights', style: textTheme.subheadline1),
        ],
      ),
      Gap(4.h),
      Text(
        'You have full control over your personal data. You can request '
        'to access, update, or permanently delete your account and '
        'associated data at any time through the app settings.',
        style: textTheme.subDescription,
        softWrap: true,
      ),
      Gap(16.h),
    ],
  );

  Widget _buildAcceptButton(PrivacyPolicyVM vm) => Container(
    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.08),
      border: Border(
        top: BorderSide(
          color: AppColors.white.withValues(alpha: 0.12),
          width: 1.w,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.white.withValues(alpha: 0.12),
          blurRadius: 8.r,
          spreadRadius: -2.r,
          offset: Offset(0, -2.h),
        ),
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.2),
          blurRadius: 28.r,
          spreadRadius: 0,
          offset: Offset(0, -8.h),
        ),
      ],
    ),
    child: Column(
      children: [
        Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 4.w),
          child: Text(
            'By clicking "Accept & Continue", you agree to our'
            ' Privacy Policy and Terms of Service.',
            style: textTheme.subDescription.copyWith(
              fontSize: 12.sp
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Gap(8.h),
        Button(
          text: 'Accept & Continue',
          onPressed: () => vm.acceptPolicy(),
          isWhiteBackground: true,
          textStyle: textTheme.subheadline1.copyWith(
            color: AppColors.primary2,
            fontWeight: FontWeight.w600
          ),
        ),
        Gap(24.h),
      ],
    ),
  );
}
