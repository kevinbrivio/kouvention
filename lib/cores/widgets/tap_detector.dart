import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class TapDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final bool enableHaptic;
  final bool enabled;

  const TapDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = AppRadius.lg,
    this.enableHaptic = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled
          ? () {
              if (enableHaptic) HapticFeedback.mediumImpact();
              onTap?.call();
            }
          : null,
      onLongPress: enabled && onLongPress != null
          ? () {
              if (enableHaptic) HapticFeedback.mediumImpact();
              onLongPress?.call();
            }
          : null,
      splashColor: scheme.primary.withValues(alpha: 0.1),
      highlightColor: scheme.primary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(borderRadius.r),
      child: child,
    );
  }
}
