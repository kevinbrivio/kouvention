import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';

class TransparentBox extends StatelessWidget {
  final Widget child;
  final BorderRadius? radius;

  const TransparentBox({
    super.key,
    required this.child,
    this.radius,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.35),
      borderRadius: radius ?? BorderRadius.circular(28.r),
      border: Border.all(
        color: AppColors.white.withValues(alpha: 0.2),
        style: BorderStyle.solid,
        width: 1.sp,
      ),
    ),
    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
    child: child,
  );
}
