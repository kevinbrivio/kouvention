import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';

class IconHolder extends StatelessWidget {
  final Widget icon;
  final BorderRadius? radius;
  
  IconHolder({super.key, required this.icon, this.radius});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.primary2.withValues(alpha: 0.4),
      borderRadius: radius ?? BorderRadius.circular(50.r),
      border: Border.all(
        color: AppColors.primary2.withValues(alpha: 0.2),
        style: BorderStyle.solid,
        width: 1.sp,
      ),
    ),
    padding: EdgeInsets.all(12.w),
    child: icon,
  );
}
