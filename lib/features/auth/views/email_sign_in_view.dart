// lib/features/auth/views/email_sign_in_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/auth/viewmodel/email_signin_viewmodel.dart';
import 'package:kouvention/features/auth/widgets/connectivity_banner.dart';
import 'package:kouvention/features/auth/widgets/password_field.dart';

class EmailSignInView extends StatelessWidget {
  const EmailSignInView({super.key});

  @override
  Widget build(BuildContext context) =>
      BaseView(provider: emailSignInVM, builder: _buildScreen);

  Widget _buildScreen(BuildContext context, EmailSignInVM vm) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.md.w, 
        right: AppSpacing.md.w, 
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top,
        child: Column(
          children: [
            const ConnectivityBanner(),
            Image.asset(images.splash, height: 180.w, width: 180.w),
            Gap(AppSpacing.xl.h),
            _buildCard(context, vm),
          ],
        ),
      ),
    ),
  );

  Widget _buildCard(BuildContext context, EmailSignInVM vm) => TransparentBox(
    color: AppColorTokens.primary.withValues(alpha: 0.3),
    borderColor: Colors.white.withValues(alpha: 0.7),
    child: Form(
      key: vm.formKey,
      child: Column(
        children: [
          Text(
            'Welcome back',
            style: context.text.bodyMedium.copyWith(color: AppColorTokens.info),
          ),
          Gap(AppSpacing.xs.h),
          Text(
            'Sign in to continue messaging.',
            style: context.text.bodySmall.copyWith(color: AppColorTokens.info),
            textAlign: TextAlign.center,
          ),
          Gap(AppSpacing.xl.h),
          _buildEmailField(context, vm),
          Gap(AppSpacing.md.h),
          PasswordField(
            obscure: vm.obscurePassword,
            onToggle: vm.togglePasswordVisibility,
            controller: vm.form.password.controller,
            validator: (val) => vm.form.password.validator?.call(val ?? ''),
          ),
          Gap(AppSpacing.lg.h),
          _buildSignInButton(context, vm),
          Gap(AppSpacing.lg.h),
          _buildSignUpLink(context),
        ],
      ),
    ),
  );
  
  Widget _buildEmailField(BuildContext context, EmailSignInVM vm) => TextFormField(
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

  Widget _buildSignInButton(BuildContext context, EmailSignInVM vm) => SizedBox(
    height: AppSizing.buttonHeight.h,
    child: Button(
      onPressed: vm.isLoading ? null : () => vm.signIn(),
      text: 'Sign In',
      textStyle: context.text.labelLarge.copyWith(
        color: AppColorTokens.primary
      ),
      isWhiteBackground: true,
    ),
  );

  Widget _buildSignUpLink(BuildContext context) => GestureDetector(
    onTap: () => context.push(RouterRoutes.signUp.path),
    child: RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        text: "Don't have an account? ",
        style: TextStyle(color: Colors.white70, fontSize: 14),
        children: [
          TextSpan(
            text: 'Sign Up',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
