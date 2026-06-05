import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';

class LiquidGlassBox extends StatelessWidget {
  final Widget child;

  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const LiquidGlassBox({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: padding ?? EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: isDark
                ? AppColors.lightBackground
                : AppColors.darkBackground
                .withValues(alpha: 0.15),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}
