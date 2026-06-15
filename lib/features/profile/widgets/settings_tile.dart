import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/liquid_glass_box.dart';
// import 'package:kouvention/cores/widgets/tap_detector.dart'; // Tergantung apakah lu masih butuh ini

class SettingsTile extends StatefulWidget {
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
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  bool _isInteracting = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs.h),
    child: GestureDetector(
      onTapDown: (_) => setState(() => _isInteracting = true),
      onTapUp: (_) {
        setState(() => _isInteracting = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isInteracting = false),
      behavior: HitTestBehavior.opaque,

      child:
          LiquidGlassBox(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w,
                  vertical: AppSpacing.xs.h,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppRadius.sm.r),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm.r),
                      ),
                      child: Icon(
                        widget.icon,
                        size: AppSizing.iconSm.r,
                        color: widget.iconColor,
                      ),
                    ),
                    Gap(AppSpacing.sm.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: context.text.labelMedium.copyWith(
                              color: context.text.secondaryText,
                            ),
                          ),
                          Gap(2.h),
                          Text(
                            widget.subtitle,
                            style: context.text.labelSmall.copyWith(
                              color: context.text.tertiaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.trailing ??
                        Icon(
                          Icons.chevron_right,
                          size: AppSizing.iconMd.r,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                  ],
                ),
              )
              .animate(target: _isInteracting ? 1 : 0)
              .shimmer(angle: 1.27, size: 1.2)
              .flipH(curve: Curves.easeInOutCubic, duration: 600.ms, end: 0.1)
              .scaleXY(end: 1.05, alignment: const Alignment(0, 0.1)),
    ),
  );
}
