import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/liquid_glass_box.dart';

class SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsToggleTile({
    super.key,
    required this.icon,
    this.iconColor = AppColorTokens.primary,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs.h),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.md.r),
    ),
    child: LiquidGlassBox(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.xs.h,
      ), 
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppRadius.sm.r),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
            ),
            child: Icon(icon, size: 24.sp, color: iconColor),
          ),
          Gap(AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.bodyMedium.copyWith(fontSize: 13.sp, color: context.text.secondaryText)
                ),
                Gap(2.h),
                Text(
                  subtitle,
                  style: context.text.labelSmall.copyWith(color: context.text.tertiaryText)
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    ),
  );
}
