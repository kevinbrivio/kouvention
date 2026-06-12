import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class TransparentBox extends StatelessWidget {
  final Widget child;
  final BorderRadius? radius;
  final Color? color;
  final Color? borderColor;

  const TransparentBox({
    super.key,
    required this.child,
    this.radius,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color ?? AppSurfaceLight.surface,
      borderRadius: radius ?? BorderRadius.circular(AppRadius.xl.r),
      border: Border.all(
        color: borderColor ??
            AppSurfaceLight.surface.withValues(alpha: 0.2),
        style: BorderStyle.solid,
        width: 1.sp,
      ),
    ),
    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
    child: child,
  );
}
