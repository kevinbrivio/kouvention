import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/icon_holder.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/privacy_policy/viewmodel/privacy_policy_viewmodel.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) => BaseView(
    provider: privacyPolicyVM,
    appBar: (vm) => AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.5,
      leadingWidth: 64.w,
      leading: Padding(
        padding: EdgeInsets.only(left: 16.w),
        child: Center(
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              _showDeclineDialog(context, vm);
            },
            child: Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12.r),
                border: BoxBorder.all(
                  color: AppColors.white.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                color: AppColors.white,
                size: 20.sp,
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 8.w),
          child: Text(
            'LAST UPDATED: MAY 2026',
            style: AppTextTheme.of(context).subDescription3.copyWith(
              color: AppColors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    ),
    builder: _buildScreen,
  );

  Widget _buildScreen(BuildContext context, PrivacyPolicyVM vm) => SafeArea(
    child: Column(
      children: [
        Gap(MediaQuery.of(context).padding.top),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsetsGeometry.symmetric(horizontal: 16.w),
                  child: Text('Privacy Policy', style: AppTextTheme.of(context).subheadline1),
                ),
                Gap(4.h),
                Padding(
                  padding: EdgeInsetsGeometry.symmetric(horizontal: 16.w),
                  child: Text(
                    'Please review how we handle your data before continuing.',
                    style: AppTextTheme.of(context).subDescription2,
                  ),
                ),
                Gap(24.h),
                Padding(
                  padding: EdgeInsetsGeometry.symmetric(horizontal: 16.w),
                  child: TransparentBox(
                    color: AppColors.white.withValues(alpha: 0.3),
                    child: _buildPolicy(context),
                  ),
                ),

                Gap(16.h),

                _buildAcceptButton(context, vm),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildPolicy(BuildContext context, ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Data Collection
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconHolder(
            radius: BorderRadius.circular(24.r),
            icon: const Icon(Icons.data_array),
          ),
          Gap(12.w),
          Flexible(
            child: Text('Data Collected', style: AppTextTheme.of(context).subheadline1),
          ),
        ],
      ),
      Gap(4.h),
      Column(
        children: [
          Text(
            'We collect information necessary to provide you with secure '
            'messaging services. This includes your profile details, usage '
            'data and device information',
            style: AppTextTheme.of(context).subDescription,
            softWrap: true,
          ),
          Gap(6.h),
          Row(
            children: [
              Icon(
                Icons.check_box_rounded,
                size: 12.w,
              ),
              Gap(8.w),
              Text(
                'Basic profile information',
                style: AppTextTheme.of(context).subDescription,
              ),
            ],
          ),
          Gap(4.h),
          Row(
            children: [
              Icon(
                Icons.check_box_rounded,
                size: 12.w,
              ),
              Gap(8.w),
              Text('App interaction metrics', style: AppTextTheme.of(context).subDescription),
            ],
          ),
        ],
      ),
      Gap(16.h),
      // Firebase Integration
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text('Firebase Integration', style: AppTextTheme.of(context).subheadline1),
          ),
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
        'strict security protocols',
        style: AppTextTheme.of(context).subDescription,
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
          Flexible(
            child: Text('Your Data Rights', style: AppTextTheme.of(context).subheadline1),
          ),
        ],
      ),
      Gap(4.h),
      Text(
        'You have full control over your personal data. You can request '
        'to access, update, or permanently delete your account and '
        'associated data at any time through the app settings',
        style: AppTextTheme.of(context).subDescription,
        softWrap: true,
      ),
      Gap(16.h),
    ],
  );

  Widget _buildAcceptButton(BuildContext context, PrivacyPolicyVM vm) =>
      Container(
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
            // --- CHECKBOX
            GestureDetector(
              onTap: () => vm.toggleCheckbox(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      color: vm.isChecked
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.8),
                        width: 1.w,
                      ),
                    ),
                    child: Checkbox(
                      value: vm.isChecked,
                      onChanged: (_) => vm.toggleCheckbox(),
                      activeColor: AppColors.white,
                      checkColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.white.withValues(alpha: 0.5),
                        width: 1.2.w,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                  Gap(8.w),
                  Flexible(
                    child: Text(
                      'I have read and agree to the Privacy Policy',
                      style: AppTextTheme.of(context).subDescription,
                    ),
                  ),
                ],
              ),
            ),

            Gap(12.h),
            // --- DISCLAIMER TEXT
            Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 4.w),
              child: Text(
                'By clicking "Accept & Continue", you agree to our'
                ' Privacy Policy and Terms of Service.',
                style: AppTextTheme.of(context).subDescription.copyWith(fontSize: 12.sp),
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
            Gap(8.h),
            Button(
              text: 'Accept & Continue',
              onPressed: vm.isChecked ? () => vm.acceptPolicy() : null,
              isWhiteBackground: true,
              textStyle: AppTextTheme.of(context).subheadline1.copyWith(
                color: AppColors.primary2,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(8.h),
            TextButton(
              onPressed: () => _showDeclineDialog(context, vm),
              child: Text(
                'Decline',
                style: AppTextTheme.of(context).subDescription.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.white.withValues(alpha: 0.6),
                  color: AppColors.white.withValues(alpha: 0.6),
                  fontSize: 14.sp,
                ),
              ),
            ),
            Gap(24.h),
          ],
        ),
      );

  void _showDeclineDialog(BuildContext context, PrivacyPolicyVM vm) =>
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.primary.withValues(alpha: 0.99),
          title: Text('Decline Privacy Policy', style: AppTextTheme.of(context).subheadline1),
          content: Text(
            'Are you sure you want to decline the privacy policy? '
            'You will not be able to use the app without accepting it.',
            style: AppTextTheme.of(context).subDescription2,
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              text: 'Cancel',
              isWhiteBackground: true,
            ),

            SizedBox(height: 4.h),

            Button(
              onPressed: () {
                Navigator.pop(dialogContext);
                vm.declinePolicy();
              },
              isWhiteBackground: true,
              text: 'Decline',
            ),
          ],
        ),
      );
}
