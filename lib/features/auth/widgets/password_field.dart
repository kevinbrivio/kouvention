import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/text_theme.dart';

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
    style: textTheme.subDescription,
    decoration: InputDecoration(
      hintText: 'Password',
      hintStyle: TextStyle(color: Colors.white54),
      prefixIcon: Icon(Icons.lock_outline, color: Colors.white70, size: 20.sp),
      suffixIcon: GestureDetector(
        onTap: onToggle,
        child: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: Colors.white70,
          size: 20.sp,
        ),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      // Error text styling so it's visible on the gradient background
      errorMaxLines: 2,
      errorStyle: TextStyle(color: Colors.orangeAccent, fontSize: 12.sp),
    ),
  );
}
