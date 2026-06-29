import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/icon_paths.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/auth/viewmodel/login_viewmodel.dart';
import 'package:kouvention/features/auth/widgets/connectivity_banner.dart';

class LoginView extends ConsumerWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BaseView(provider: loginProvider, builder: _buildScreen);

  Widget _buildScreen(BuildContext context, LoginVM loginVM) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const ConnectivityBanner(),
            Gap(AppSpacing.xl.h),
            _buildLogo(),
            _buildCard(context, loginVM),
            Gap(MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    ),
  );

  Widget _buildLogo() => Center(
    child: FloatingWidget(
      child: SizedBox(
        width: 240.w,
        height: 240.w,
        child: Image.asset(images.splash, fit: BoxFit.cover),
      ),
    ),
  );

  Widget _buildCard(BuildContext context, LoginVM vm) => TransparentBox(
    color: AppColorTokens.primary.withValues(alpha: 0.4),
    borderColor: Colors.white.withValues(alpha: 0.7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            'Welcome Back',
            style: context.text.headlineSmall.copyWith(
              color: AppColorTokens.info,
            ),
          ),
        ),
        Gap(AppSpacing.xs.h),
        Center(
          child: Text(
            'Sign in to continue to your messages',
            style: context.text.bodyMedium.copyWith(
              color: AppColorTokens.info,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Gap(AppSpacing.md.h),
        _buildGoogleButton(context, vm),
        Gap(AppSpacing.lg.h),
        _buildDivider(context),
        Gap(AppSpacing.lg.h),
        _buildEmailButton(context, vm),
        Gap(AppSpacing.xl.h),
        _buildSignUpLink(context, vm),
        Gap(AppSpacing.xl.h),
        _buildTermsText(context),
        Gap(AppSpacing.lg.h),
      ],
    ),
  );

  Widget _buildGoogleButton(BuildContext context, LoginVM vm) => SizedBox(
    height: AppSizing.buttonHeight.h,
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: vm.isLoading ? null : () => vm.signInWithGoogle(),
      icon: Image.asset(
        icons.google,
        width: AppSizing.iconMd.r,
        height: AppSizing.iconMd.r,
      ),
      label: Text(
        'Continue with Google',
        style: context.text.bodyMedium.copyWith(color: Colors.black87),
      ),
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md.r),
        ),
        backgroundColor: AppSurfaceLight.surface,
        elevation: 0,
      ),
    ),
  );

  Widget _buildEmailButton(BuildContext context, LoginVM vm) => TapDetector(
    enabled: !vm.isLoading,
    borderRadius: AppRadius.md,
    splashColor: Colors.black,
    onTap: () => vm.goToEmailSignIn(context),
    child: Container(
      height: AppSizing.buttonHeight.h,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.email_outlined,
            color: Colors.white,
            size: AppSizing.iconSm.r,
          ),
          Gap(AppSpacing.sm.w),
          Text(
            'Sign in with Email',
            style: context.text.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    ),
  );

  Widget _buildDivider(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: Colors.white38, thickness: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
        child: Text(
          'OR',
          style: context.text.bodyMedium.copyWith(
            color: AppColorTokens.info,
          ),
        ),
      ),
      const Expanded(child: Divider(color: Colors.white38, thickness: 1)),
    ],
  );

  Widget _buildSignUpLink(BuildContext context, LoginVM vm) => GestureDetector(
    onTap: () => vm.goToSignUp(),
    child: Text.rich(
      TextSpan(
        text: 'Don\'t have an account? ',
        style: context.text.bodyMedium.copyWith(
          color: AppColorTokens.info,
        ),
        children: [
          TextSpan(
            text: 'Sign up',
            style: context.text.bodyMedium.copyWith(
              color: AppColorTokens.info,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildTermsText(BuildContext context) => Text.rich(
    TextSpan(
      text:
          'By continuing, you acknowledge that you\n'
          'have read and agree to our ',
      style: const TextStyle(color: Colors.white54, fontSize: 12),
      children: [
        const TextSpan(
          text: 'Terms of\nService',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const TextSpan(text: ' and '),
        const TextSpan(
          text: 'Privacy Policy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const TextSpan(text: '.'),
      ],
    ),
    textAlign: TextAlign.center,
  );
}
