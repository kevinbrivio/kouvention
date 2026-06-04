import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';

class AppTextTheme {
  static _TextTheme of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _TextTheme(
      primaryText: isDark ? AppColors.white : AppColors.black,
      
      secondaryText: isDark 
          ? AppColors.white.withValues(alpha: 0.7) 
          : AppColors.black.withValues(alpha: 0.7),
          
      appBarText: isDark 
          ? AppColors.white 
          : AppColors.primary.withValues(alpha: 0.9),
          
      typeMessageText: isDark 
          ? AppColors.white.withValues(alpha: 0.8) 
          : AppColors.black.withValues(alpha: 0.8),
          
      greyText: isDark 
          ? AppColors.white.withValues(alpha: 0.7) 
          : AppColors.grey,
      primaryColor: AppColors.primary,
      primary2Color: AppColors.primary2,
    );
  }
}

class _TextTheme {
  final Color primaryText;
  final Color secondaryText;
  final Color appBarText;
  final Color typeMessageText;
  final Color greyText;
  final Color primaryColor;
  final Color primary2Color;

  _TextTheme({
    required this.primaryText,
    required this.secondaryText,
    required this.appBarText,
    required this.typeMessageText,
    required this.greyText,
    required this.primaryColor,
    required this.primary2Color,
  });

  TextStyle get headline1 => TextStyle(
    fontSize: 42.sp,
    color: primaryText,
    fontWeight: FontWeight.bold,
    height: 1.5,
  );
  
  TextStyle get subheadline1 => TextStyle(
    fontSize: 24.sp,
    color: primaryText,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );
  
  TextStyle get body1 => TextStyle(
    fontSize: 16.sp,
    color: primaryText,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  
  TextStyle get body2 => TextStyle(
    fontSize: 12.sp,
    color: primaryText,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  TextStyle get buttonText => TextStyle(
    fontSize: 12.sp,
    color: primaryColor,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  TextStyle get subDescription => TextStyle(
    fontSize: 16.sp,
    color: secondaryText,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  TextStyle get subDescription2 => TextStyle(
    fontSize: 13.sp,
    color: secondaryText,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  TextStyle get subDescription3 => TextStyle(
    fontSize: 11.sp,
    color: greyText,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  TextStyle get contactName => TextStyle(
    fontSize: 13.sp,
    color: greyText,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  TextStyle get senderName => TextStyle(
    fontSize: 14.sp,
    color: primary2Color,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  TextStyle get appBar => TextStyle(
    fontSize: 16.sp,
    color: appBarText,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  TextStyle get typeMessage => TextStyle(
    fontSize: 13.sp,
    color: typeMessageText,
    fontWeight: FontWeight.w500,
    height: 1.5,
    decoration: TextDecoration.none,
  );
}