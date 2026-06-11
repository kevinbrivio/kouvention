import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class IconHolder extends StatelessWidget {
  final Widget icon;
  final BorderRadius? radius;
  
  IconHolder({super.key, required this.icon, this.radius});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context)
          .colorScheme
          .primary
          .withValues(alpha: 0.8),
      borderRadius: radius ?? BorderRadius.circular(AppRadius.full.r),
      border: Border.all(
        color: AppColorTokens.primaryLighter.withValues(alpha: 0.2),
        style: BorderStyle.solid,
        width: 1.sp,
      ),
    ),
    padding: EdgeInsets.all(AppSpacing.xxs.w),
    child: icon,
  );
}
