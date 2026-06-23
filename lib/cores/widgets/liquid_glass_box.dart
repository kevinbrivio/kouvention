import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class LiquidGlassBox extends StatelessWidget {
  final Widget child;

  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final Color? borderColor;
  final double borderWidth;

  const LiquidGlassBox({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16.0,
    this.blurSigma = 10.0,
    this.tintColor,
    this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        borderColor ??
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);
    final effectiveTintColor = tintColor ?? Colors.transparent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ?? EdgeInsets.all(AppRadius.lg.r),
          decoration: BoxDecoration(
            color: effectiveTintColor,
            border: Border.all(color: effectiveBorderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}
