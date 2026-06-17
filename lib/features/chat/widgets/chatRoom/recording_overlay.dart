import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/trash_icon.dart';

/// Overlay shown during voice recording (before locking).
/// Displays slide hints, a pulsing red dot, and threshold markers.
class RecordingOverlay extends StatefulWidget {
  final bool isLocked;
  final Offset fingerOffset;

  const RecordingOverlay({
    super.key,
    required this.isLocked,
    this.fingerOffset = Offset.zero,
  });

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final cancelThreshold = screenWidth * 0.1;

    final cancelActive = widget.fingerOffset.dx < -cancelThreshold;
    return Flexible(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs.w,
          vertical: AppSpacing.xs.h,
        ),
        constraints: BoxConstraints(
          minHeight: AppSizing.chatInputBarMin.h - (AppSpacing.xs.h * 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Trash icon — cancel threshold marker (left zone)
            TrashIcon(
              size: AppSizing.iconSm.r,
              color: cancelActive
                  ? AppColorTokens.error.withValues(alpha: 0.7)
                  : AppColorTokens.error,
              isActive: cancelActive,
            ),
            Gap(AppSpacing.xs.w),

            // Pulse dot
            FadeTransition(
              opacity: Tween<double>(
                begin: 0.3,
                end: 1.0,
              ).animate(_pulseController),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Gap(AppSpacing.sm.w),
            // Hint text
            Text(
              'Slide ← cancel',
              style: context.text.labelSmall.copyWith(
                color: context.text.tertiaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
