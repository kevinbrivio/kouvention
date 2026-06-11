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
    style: context.text.titleMedium.copyWith(color: context.text.secondaryText),
    decoration: InputDecoration(
      hintText: 'Password',
      hintStyle: const TextStyle(color: Colors.white54),
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
      fillColor: Colors.white.withValues(alpha: 0.1),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 14.h,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        borderSide: BorderSide.none,
      ),
      errorMaxLines: 2,
      errorStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
    ),
  );
}
