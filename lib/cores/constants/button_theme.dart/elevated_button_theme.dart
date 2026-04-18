import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';

final elevatedButtonTheme = ElevatedButtonThemeData(
  style: ButtonStyle(
    splashFactory: InkRipple.splashFactory,
    overlayColor: WidgetStateProperty.resolveWith<Color>(
      (states) => AppColors.black.withValues(alpha: 0.05),
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
        return AppColors.white;
      },
    ),
    textStyle: WidgetStateProperty.resolveWith<TextStyle>(
      (states) => textTheme.buttonText.copyWith(
        color: AppColors.white,
        fontWeight: FontWeight.w500,
        fontFamily: 'Asap',
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
