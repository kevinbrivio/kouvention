import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final Function() onToggle;
  final String? Function(String?)? validator;

  const PasswordField({
    super.key,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    obscureText: obscure,
    controller: controller,
    validator: validator,
    style: context.text.titleMedium.copyWith(color: AppColorTokens.info),
    decoration: InputDecoration(
      hintText: 'Password',
      hintStyle: context.text.typeMessage.copyWith(color: Colors.white54),
      prefixIcon: Icon(
        Icons.lock_outline,
        color: Colors.white70,
        size: AppSizing.iconSm.sp,
      ),
      suffixIcon: GestureDetector(
        onTap: onToggle,
        child: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: Colors.white70,
          size: AppSizing.iconSm.sp,
        ),
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
        borderSide: const BorderSide(
          color: Colors.white, 
          width: 1.5,
        ),
      ),
      errorMaxLines: 2,
      errorStyle: context.text.labelMedium.copyWith(color: Colors.orangeAccent),
    ),
  );
}
