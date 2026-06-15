import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/liquid_glass_box.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';

class PersonalInfoSection extends StatelessWidget {
  final String displayName;
  final String status;
  final Function() onEditName;
  final Function() onEditStatus;

  const PersonalInfoSection({
    super.key,
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
          TapDetector(
            onTap: onEditName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display Name',
                  style: context.text.labelMedium.copyWith(
                    color: context.text.tertiaryText,
                  ),
                ),
                Gap(4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayName,
                      style: context.text.titleMedium.copyWith(
                        color: context.text.secondaryText,
                      ),
                    ),
                    Icon(
                      Icons.create_rounded,
                      size: AppSizing.iconSm.r,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Gap(AppSpacing.sm.h),
          Divider(color: scheme.onSurface.withValues(alpha: 0.15)),
          Gap(6.h),
          TapDetector(
            onTap: onEditStatus,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: context.text.labelSmall.copyWith(
                    color: context.text.tertiaryText,
                  ),
                ),
                Gap(4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      status,
                      style: context.text.titleMedium.copyWith(
                        color: context.text.secondaryText,
                      ),
                    ),
                    Icon(
                      Icons.create_rounded,
                      size: AppSizing.iconSm.r,
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
