import 'package:flutter/material.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.grey,
      elevation: 0.5,
    ),
    extensions: [
      SkeletonizerConfigData(
        effect: ShimmerEffect(
          baseColor: AppColors.lightSkeleton,
          highlightColor: AppColors.lightSkeletonHighlight
        )
      ),
    ]
  );
  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryDark,
    scaffoldBackgroundColor: AppColors.black,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.grey,
      elevation: 0.5,
    ),
    extensions: [
      SkeletonizerConfigData(
        effect: ShimmerEffect(
          baseColor: AppColors.darkSkeleton,
          highlightColor: AppColors.darkSkeletonHighlight
        )
      ),
    ]
  );
}
