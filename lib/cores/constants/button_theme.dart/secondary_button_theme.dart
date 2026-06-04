import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';

final secondaryElevatedButtonTheme = ElevatedButtonThemeData(
  style: ButtonStyle(
    splashFactory: InkRipple.splashFactory,
    overlayColor: WidgetStateProperty.resolveWith<Color>(
      (states) => AppColors.black.withValues(alpha: 0.1),
    ),
    padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
      (states) => EdgeInsets.symmetric(
        horizontal: 12.w,
      ),
    ),
    shape: WidgetStateProperty.resolveWith<OutlinedBorder>(
      (_) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
    ),
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.buttonDisabled;
        }
        return AppColors.primary;
      },
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (states) {
        if (states.contains(WidgetState.disabled)) return AppColors.white;
        return AppColors.primary;
      },
    ),
    textStyle: WidgetStateProperty.resolveWith<TextStyle>(
      (states) => TextStyle(
        fontSize: 12.sp,
        color: AppColors.white,
        fontWeight: FontWeight.w500,
        fontFamily: 'Asap',
        height: 1.5,
      ),
    ),
    elevation: WidgetStateProperty.resolveWith<double>(
      (states) => 0,
    ),
    minimumSize: WidgetStateProperty.resolveWith<Size>(
      (states) => const Size(double.minPositive, double.minPositive),
    ),
  ),
);

