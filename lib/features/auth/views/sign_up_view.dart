import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/auth/viewmodel/sign_up_viewmodel.dart';
import 'package:kouvention/features/auth/widgets/connectivity_banner.dart';
import 'package:kouvention/features/auth/widgets/password_field.dart';

class SignUpView extends StatelessWidget {
  const SignUpView({super.key});

  @override
  Widget build(BuildContext context) =>
      BaseView(provider: signUpProvider, builder: _buildScreen);

  Widget _buildScreen(BuildContext context, SignUpVM signUpVM) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      child: SizedBox(
        height:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top,
        child: Column(
          children: [
            const ConnectivityBanner(),
            Image.asset(images.splash, height: 180.w, width: 180.w),
            Gap(AppSpacing.xl.h),
            _buildCard(context, signUpVM),
          ],
        ),
      ),
    ),
  );

  Widget _buildCard(BuildContext context, SignUpVM vm) => TransparentBox(
    color: AppColorTokens.primary.withValues(alpha: 0.7),
    child: Form(
      key: vm.formKey,
      child: Column(
        children: [
          Text(
            'Create account',
            style: context.text.headlineSmall.copyWith(
              color: AppColorTokens.info,
            ),
          ),
          Gap(AppSpacing.xs.h),
          Text(
            'Sign up to start messaging.',
            style: context.text.bodySmall.copyWith(color: AppColorTokens.info),
            textAlign: TextAlign.center,
          ),

          Gap(AppSpacing.xxl.h),

          _buildEmailField(context, vm),
          Gap(AppSpacing.md.h),
          PasswordField(
            obscure: vm.obscurePassword,
            onToggle: vm.togglePasswordVisibility,
            controller: vm.form.password.controller,
            validator: (val) => vm.form.password.validator?.call(val ?? ''),
          ),

          if (vm.isOffline) ...[Gap(AppSpacing.md.h), _buildOfflineWarning()],

          Gap(AppSpacing.xxl.h),

          _buildSignUpButton(context, vm),
          Gap(AppSpacing.lg.h),
          _buildLoginLink(context),
        ],
      ),
    ),
  );

  Widget _buildEmailField(BuildContext context, SignUpVM vm) => TextFormField(
    keyboardType: TextInputType.emailAddress,
    controller: vm.form.email.controller,
    style: context.text.bodyMedium.copyWith(color: Colors.white),
    validator: (val) => vm.form.email.validator?.call(val ?? ''),
    decoration: InputDecoration(
      hintText: 'Email',
      hintStyle: context.text.bodyMedium.copyWith(color: Colors.white54),
      prefixIcon: Icon(
        Icons.email_outlined,
        color: Colors.white70,
        size: AppSizing.iconSm.sp,
      ),
      filled: true,
      fillColor: AppColorTokens.primary.withValues(alpha: 0.5),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.md.h,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      errorStyle: context.text.labelMedium.copyWith(color: Colors.orangeAccent),
    ),
  );

  Widget _buildOfflineWarning() => Container(
    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: AppSpacing.sm.w),
    decoration: BoxDecoration(
      color: Colors.orange.shade800.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(AppRadius.sm.r),
      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
    ),
    child: Row(
      children: [
        Icon(Icons.wifi_off, color: Colors.orangeAccent, size: 18.sp),
        SizedBox(width: AppSpacing.xs.w),
        const Expanded(
          child: Text(
            'No internet connection. Please check your network and try again.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildSignUpButton(BuildContext context, SignUpVM vm) => SizedBox(
    width: double.infinity,
    height: AppSizing.buttonHeight.h,
    child: Button(
      onPressed: vm.isLoading ? null : () => vm.signUp(),
      isWhiteBackground: true,
      text: 'Sign Up',
      textStyle: context.text.labelLarge.copyWith(
        color: AppColorTokens.primary,
      ),
    ),
  );

  Widget _buildLoginLink(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).pop(),
    child: RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        text: 'Already have an account? ',
        style: TextStyle(color: Colors.white70, fontSize: 14),
        children: [
          TextSpan(
            text: 'Sign In',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}
