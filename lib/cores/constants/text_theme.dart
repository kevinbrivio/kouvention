import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';

class _TextTheme {
  final headline1 = TextStyle(
    fontSize: 42.sp,
    color: AppColors.white,
    fontWeight: FontWeight.bold,
    height: 1.5,
  );
  final subheadline1 = TextStyle(
    fontSize: 24.sp,
    color: AppColors.white,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );
  final body1 = TextStyle(
    fontSize: 16.sp,
    color: AppColors.white,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  final body2 = TextStyle(
    fontSize: 12.sp,
    color: AppColors.white,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // Specific cases
  final buttonText = TextStyle(
    fontSize: 12.sp,
    color: AppColors.primary,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );
  
  final subDescription = TextStyle(
    fontSize: 16.sp,
    color: AppColors.white.withValues(alpha: 0.7),
    fontWeight: FontWeight.w500,
    height: 1.5,
  );
  
}

final textTheme = _TextTheme();
