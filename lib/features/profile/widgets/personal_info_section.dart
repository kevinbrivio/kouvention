import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/liquid_glass_box.dart';

class PersonalInfoSection extends StatelessWidget {
  final String displayName;
  final String status;
  final Function() onEditName;
  final Function() onEditStatus;

  PersonalInfoSection({
    required this.displayName,
    required this.status,
    required this.onEditName,
    required this.onEditStatus,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LiquidGlassBox(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      child: Column(
        children: [
          // Display Name
          InkWell(
            onTap: onEditName,
            splashColor: scheme.onSurface.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display Name', style: context.text.subDescription3),
                Gap(4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(displayName, style: context.text.subDescription2),
                    Icon(
                      Icons.create_rounded,
                      size: AppSizing.iconMd.sp,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Gap(AppSpacing.sm.h),
          Divider(
            color: scheme.onSurface.withValues(alpha: 0.15),
          ),
          Gap(6.h),
          InkWell(
            onTap: onEditStatus,
            splashColor: scheme.onSurface.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status', style: context.text.subDescription3),
                Gap(4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(status, style: context.text.subDescription2),
                    Icon(
                      Icons.create_rounded,
                      size: AppSizing.iconMd.sp,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
