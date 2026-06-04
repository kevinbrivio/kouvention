import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/auth/viewmodel/sign_up_viewmodel.dart';
import 'package:kouvention/features/auth/widgets/connectivity_banner.dart';
import 'package:kouvention/features/auth/widgets/password_field.dart';

class SignUpView extends StatelessWidget {
  SignUpView({super.key});

  @override
  Widget build(BuildContext context) =>
      BaseView(provider: signUpProvider, builder: _buildScreen);

  Widget _buildScreen(BuildContext context, SignUpVM signUpVM) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
      child: SizedBox(
        height:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top,
        child: Column(
          children: [
            const ConnectivityBanner(),

            Gap(40.h),

            _buildLogo(),

            Gap(32.h),

            _buildCard(context, signUpVM),
          ],
        ),
      ),
    ),
  );

  Widget _buildLogo() => Column(
    children: [
      Image.asset(images.logo, height: 48.h),
      Gap(8.h),
      Text(
        'Kouvention',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildCard(BuildContext context, SignUpVM vm) => TransparentBox(
    color: AppColors.primary.withValues(alpha: 0.3),
    borderColor: AppColors.white.withValues(alpha: 0.7),
    child: Form(
      key: vm.formKey,
      child: Column(
        children: [
          Text('Create account', style: AppTextTheme.of(context).body1),

          Gap(8.h),
          Text(
            'Sign up to start messaging.',
            style: AppTextTheme.of(context).subDescription2,
            textAlign: TextAlign.center,
          ),
          Gap(32.h),

          _buildEmailField(context, vm),

          Gap(16.h),

          PasswordField(
            obscure: vm.obscurePassword,
            onToggle: vm.togglePasswordVisibility,
            controller: vm.form.password.controller,
            validator: (val) => vm.form.password.validator?.call(val ?? ''),
          ),

          Gap(8.h),

          if (vm.isOffline) _buildOfflineWarning(),

          Gap(24.h),

          _buildSignUpButton(vm),
          Gap(24.h),

          _buildLoginLink(context),
        ],
      ),
    ),
  );

  Widget _buildEmailField(BuildContext context, SignUpVM vm) => TextFormField(
    keyboardType: TextInputType.emailAddress,
    controller: vm.form.email.controller,
    style: AppTextTheme.of(context).subDescription2,
    validator: (val) => vm.form.email.validator?.call(val ?? ''),
    decoration: InputDecoration(
      hintText: 'Email',
      hintStyle: TextStyle(color: Colors.white54),
      prefixIcon: Icon(
        Icons.email_outlined,
        color: Colors.white70,
        size: 20.sp,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      errorStyle: TextStyle(color: Colors.orangeAccent, fontSize: 12.sp),
    ),
  );

  Widget _buildOfflineWarning() => Container(
    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
    decoration: BoxDecoration(
      color: Colors.orange.shade800.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: Row(
      children: [
        Icon(Icons.wifi_off, color: Colors.orangeAccent, size: 18.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'No internet connection. Please check your network and try again.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12.sp),
          ),
        ),
      ],
    ),
  );

  Widget _buildSignUpButton(SignUpVM vm) => SizedBox(
    height: 48.h,
    child: Button(
      onPressed: vm.isLoading ? null : () => vm.signUp(),
      isWhiteBackground: true,
      text: 'Sign Up',
    ),
  );

  Widget _buildLoginLink(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).pop(),
    child: RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        text: 'Already have an account? ',
        style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        children: [
          TextSpan(
            text: 'Sign In',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
