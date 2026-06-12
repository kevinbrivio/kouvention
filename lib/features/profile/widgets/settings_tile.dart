import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/liquid_glass_box.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs.h),
    child: TapDetector(
      onTap: onTap,
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
              child: Icon(icon, size: AppSizing.iconSm.r, color: iconColor),
            ),
            Gap(AppSpacing.sm.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.labelMedium.copyWith(
                      color: context.text.secondaryText,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    subtitle,
                    style: context.text.labelSmall.copyWith(
                      color: context.text.tertiaryText,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  size: AppSizing.iconMd.r,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
          ],
        ),
      ),
    ),
  );
}
