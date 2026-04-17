import 'package:flutter/material.dart';
import 'package:kouvention/cores/constants/colors.dart';

class LoadingIndicator extends StatelessWidget {
  final bool showBackdrop;
  final double? width;
  final double? height;
  final double? indicatorSize;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? indicatorColor;
  final double? strokeWidth;

  const LoadingIndicator({
    super.key,
    this.showBackdrop = false,
    this.width,
    this.height,
    this.indicatorSize,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.all(16),
    this.indicatorColor,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        color: showBackdrop ? AppColors.backdrop : null,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: showBackdrop ? Colors.white : null,
            ),
            padding: padding,
            width: indicatorSize,
            height: indicatorSize,
            child: CircularProgressIndicator(
              color: indicatorColor ?? AppColors.primary,
              strokeWidth: strokeWidth ??
                  (indicatorSize != null ? (indicatorSize! / 8) : 4),
            ),
          ),
        ),
      );
}
