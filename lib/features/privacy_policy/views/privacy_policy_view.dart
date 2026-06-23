import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
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
      leading: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md.w,
          top: AppSpacing.xs.h,
          bottom: AppSpacing.xs.h,
        ),
        child: Center(
          child: Container(
            width: AppSizing.touchMin.w,
            height: AppSizing.touchMin.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showDeclineDialog(context, vm);
                },
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: AppSizing.iconSm.sp,
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: AppSpacing.xs.w),
          child: Text(
            'LAST UPDATED: JUNE 2026',
            style: context.text.labelSmall.copyWith(
              color: AppColorTokens.info.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    ),
    builder: (context, vm) =>
        SafeArea(bottom: false, child: _buildScreen(context, vm)),
  );

  Widget _buildScreen(BuildContext context, PrivacyPolicyVM vm) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(AppSpacing.xxs.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
                child: Text(
                  'Privacy Policy',
                  style: context.text.titleMedium.copyWith(
                    color: AppColorTokens.info,
                  ),
                ),
              ),
              Gap(AppSpacing.xxs.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
                child: Text(
                  'Please review how we handle your data before continuing.',
                  style: context.text.bodySmall.copyWith(
                    color: AppColorTokens.info,
                  ),
                ),
              ),
              Gap(AppSpacing.lg.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
                child: TransparentBox(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderColor: AppColorTokens.info.withValues(alpha: 0.3),
                  child: _buildPolicy(context),
                ),
              ),
              Gap(AppSpacing.md.h),
              _buildAcceptButton(context, vm),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildPolicy(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Data Collection
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconHolder(
            icon: Icon(
              Icons.data_array,
              size: AppSizing.iconXs,
              color: AppColorTokens.info,
            ),
          ),
          Gap(AppSpacing.sm.w),
          Flexible(
            child: Text(
              'Data Collected',
              style: context.text.bodyLarge.copyWith(
                color: AppColorTokens.info,
              ),
            ),
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
            textAlign: TextAlign.justify,
            style: context.text.bodySmall.copyWith(color: AppColorTokens.info),
            softWrap: true,
          ),
          Gap(AppSpacing.betweenCards.h),
          Row(
            children: [
              Icon(
                Icons.check_box_rounded,
                size: AppSizing.iconXxs,
                color: AppColorTokens.info,
              ),
              Gap(AppSpacing.xs.w),
              Text(
                'Basic profile information',
                style: context.text.bodySmall.copyWith(
                  color: AppColorTokens.info,
                ),
              ),
            ],
          ),
          Gap(4.h),
          Row(
            children: [
              Icon(
                Icons.check_box_rounded,
                size: AppSizing.iconXxs,
                color: AppColorTokens.info,
              ),
              Gap(AppSpacing.xs.w),
              Text(
                'App interaction metrics',
                style: context.text.bodySmall.copyWith(
                  color: AppColorTokens.info,
                ),
              ),
            ],
          ),
        ],
      ),
      Gap(AppSpacing.md.h),
      // Firebase Integration
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Firebase Integration',
                  style: context.text.bodyLarge.copyWith(
                    color: AppColorTokens.info,
                  ),
                ),
              ),
              Gap(AppSpacing.sm.w),
              IconHolder(
                icon: Icon(
                  Icons.dataset,
                  size: AppSizing.iconXs,
                  color: AppColorTokens.info,
                ),
              ),
            ],
          ),
        ],
      ),
      Gap(4.h),
      Text(
        'Our real-time messaging infrastructure is powered by Google '
        'Firebase. Your messages are encrypted in transit and securely '
        'stored using Firebase\'s cloud infrastructure, adhering to '
        'strict security protocols',
        style: context.text.bodySmall.copyWith(color: AppColorTokens.info),
        textAlign: TextAlign.justify,
        softWrap: true,
        textDirection: TextDirection.rtl,
      ),
      Gap(AppSpacing.md.h),
      // Your Data Rights
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconHolder(
            radius: BorderRadius.circular(24.r),
            icon: Icon(
              Icons.shield_outlined,
              size: AppSizing.iconXs,
              color: AppColorTokens.info,
            ),
          ),
          Gap(AppSpacing.sm.w),
          Flexible(
            child: Text(
              'Your Data Rights',
              style: context.text.bodyLarge.copyWith(
                color: AppColorTokens.info,
              ),
            ),
          ),
        ],
      ),
      Gap(4.h),
      Text(
        'You have full control over your personal data. You can request '
        'to access, update, or permanently delete your account and '
        'associated data at any time through the app settings',
        textAlign: TextAlign.justify,
        style: context.text.bodySmall.copyWith(color: AppColorTokens.info),
        softWrap: true,
      ),
      Gap(AppSpacing.md.h),
    ],
  );

  Widget _buildAcceptButton(BuildContext context, PrivacyPolicyVM vm) =>
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: const Border(
            top: BorderSide(color: Colors.white, width: 0.2),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.cardPadding.w,
            AppSpacing.cardPadding.h,
            AppSpacing.cardPadding.w,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  onTap: () => vm.toggleCheckbox(),
                  splashColor: Colors.white.withValues(alpha: 0.08),
                  highlightColor: Colors.white.withValues(alpha: 0.04),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppSpacing.xs.h,
                      horizontal: 4.w,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          width: AppSizing.iconMd.w,
                          height: AppSizing.iconMd.w,
                          decoration: BoxDecoration(
                            color: vm.isChecked
                                ? AppColorTokens.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.xs.r),
                            border: Border.all(
                              color: vm.isChecked
                                  ? AppColorTokens.primary
                                  : Colors.white.withValues(alpha: 0.55),
                              width: 1.5.w,
                            ),
                            boxShadow: vm.isChecked
                                ? [
                                    BoxShadow(
                                      color: AppColorTokens.primary.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 10.r,
                                      spreadRadius: -2.r,
                                    ),
                                  ]
                                : null,
                          ),
                          child: vm.isChecked
                              ? Icon(
                                  Icons.check_rounded,
                                  size: AppSizing.iconSm.sp,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        Gap(AppSpacing.sm.w),
                        Expanded(
                          child: Text(
                            'I have read and agree to the Privacy Policy',
                            style: context.text.bodyMedium.copyWith(
                              color: AppColorTokens.info,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Gap(AppSpacing.betweenCards.h),

              // --- DISCLAIMER (bodySmall = 12sp, no .copyWith override) ---
              Text(
                'By tapping "Accept & Continue" you agree to our '
                'Privacy Policy and Terms of Service.',
                style: context.text.bodySmall.copyWith(
                  color: AppColorTokens.info.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              Gap(AppSpacing.md.h),

              // --- PRIMARY ACTION ---
              Button(
                text: 'Accept & Continue',
                onPressed: vm.isChecked ? () => vm.acceptPolicy() : null,
                isWhiteBackground: true,
                leadingWidget: Icon(
                  Icons.arrow_forward_rounded,
                  size: AppSizing.iconSm.sp,
                  color: AppColorTokens.primary,
                ),
                widgetSpacing: 10,
                textStyle: context.text.titleMedium.copyWith(
                  color: AppColorTokens.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),

              Gap(AppSpacing.betweenCards.h),

              // --- SECONDARY ACTION (quiet, no underline) ---
              TextButton(
                onPressed: () => _showDeclineDialog(context, vm),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.55),
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
                  minimumSize: Size(0, AppSizing.touchMin.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                  ),
                ),
                child: Text(
                  'Decline',
                  style: context.text.labelLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              Gap(AppSpacing.md.h),
            ],
          ),
        ),
      );

  void _showDeclineDialog(BuildContext context, PrivacyPolicyVM vm) =>
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColorTokens.primaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg.r),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.w,
            ),
          ),
          title: Text(
            'Decline Privacy Policy',
            style: context.text.titleLarge.copyWith(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to decline the privacy policy? '
            'You will not be able to use the app without accepting it.',
            style: context.text.labelMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          actionsPadding: EdgeInsets.fromLTRB(
            AppSpacing.md.w,
            0,
            AppSpacing.md.w,
            AppSpacing.md.h,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                    ),
                    child: Text(
                      'Cancel',
                      style: context.text.titleSmall.copyWith(
                        color: AppColorTokens.info,
                      ),
                    ),
                  ),
                ),
                Gap(AppSpacing.sm.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      vm.declinePolicy();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorTokens.primaryLighter.withValues(
                        alpha: 0.2,
                      ),
                      foregroundColor: AppColorTokens.primaryLighter,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg.r),
                        side: BorderSide(
                          color: AppColorTokens.info.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: context.text.titleMedium.copyWith(
                        color: AppColorTokens.info
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
