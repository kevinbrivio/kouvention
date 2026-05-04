import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/icon_paths.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/auth/viewmodel/login_viewmodel.dart';
import 'package:kouvention/features/auth/widgets/connectivity_banner.dart';

class LoginView extends ConsumerWidget {
  LoginView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BaseView(provider: loginProvider, builder: _buildScreen);

  Widget _buildScreen(BuildContext context, LoginVM loginVM) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Connectivity Banner
            const ConnectivityBanner(),

            Gap(32.h),
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
        width: 220.w,
        height: 220.w,
        child: Image.asset(images.splash, fit: BoxFit.cover),
      ),
    ),
  );

  Widget _buildCard(BuildContext context, LoginVM vm) => TransparentBox(
    color: AppColors.primary.withValues(alpha: 0.4),
    borderColor: AppColors.white.withValues(alpha: 0.7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(child: Text('Welcome Back', style: textTheme.subheadline1)),
        Gap(8.h),
        Center(
          child: Text(
            'Sign in to continue to your messages',
            style: textTheme.subDescription2,
            textAlign: TextAlign.center,
          ),
        ),
        Gap(16.h),

        _buildGoogleButton(context, vm),
        Gap(24.h),

        _buildDivider(),
        Gap(24.h),

        _buildEmailButton(context, vm),
        Gap(32.h),

        _buildSignUpLink(context, vm),
        Gap(32.h),

        _buildTermsText(context),
        Gap(24.h),
      ],
    ),
  );

  Widget _buildGoogleButton(BuildContext context, LoginVM vm) => SizedBox(
    height: 48.h,
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: vm.isLoading ? null : () => vm.signInWithGoogle(),
      icon: Image.asset(icons.google, height: 24.h, width: 24.h),
      label: Text(
        'Continue with Google',
        style: textTheme.body1.copyWith(
          color: AppColors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 0,
      ),
    ),
  );

  Widget _buildEmailButton(BuildContext context, LoginVM vm) => SizedBox(
    height: 48.h,
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: vm.isLoading ? null : () => vm.goToEmailSignIn(context),
      icon: Icon(Icons.email_outlined, color: Colors.white, size: 22.sp),
      label: Text(
        'Sign in with Email',
        style: textTheme.body1.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    ),
  );

  Widget _buildDivider() => Row(
    children: [
      Expanded(child: const Divider(color: Colors.white38, thickness: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Text(
          'OR',
          style: textTheme.subDescription2.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(child: const Divider(color: Colors.white38, thickness: 1)),
    ],
  );

  Widget _buildSignUpLink(BuildContext context, LoginVM vm) => GestureDetector(
    onTap: () => vm.goToSignUp(),
    child: Text.rich(
      TextSpan(
        text: 'Don\'t have an account? ',
        style: textTheme.subDescription2,
        children: [
          TextSpan(
            text: 'Sign up',
            style: textTheme.subDescription2.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildTermsText(BuildContext context) => Text.rich(
    TextSpan(
      text:
          'By continuing, you acknowledge that you\nhave read and agree to our ',
      style: TextStyle(color: Colors.white54, fontSize: 12.sp),
      children: [
        TextSpan(
          text: 'Terms of\nService',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          // Wrap with TapGestureRecognizer for navigation
        ),
        const TextSpan(text: ' and '),
        TextSpan(
          text: 'Privacy Policy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const TextSpan(text: '.'),
      ],
    ),
    textAlign: TextAlign.center,
  );
}
