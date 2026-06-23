import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class TypingDots extends StatefulWidget {
  final Color? color;
  final double? size;

  const TypingDots({super.key, this.color, this.size});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.size ?? AppRadius.sm.r;
    final color = widget.color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) => AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            // Each dot starts its bounce at a different phase
            final offset = (index * 0.2);
            final value = (_controller.value - offset).clamp(0.0, 1.0);

            // Bounce: go up then come back down in the first half of its cycle
            final bounce = value < 0.5
                ? (value * 2)       // 0 → 1 (going up)
                : (1 - (value - 0.5) * 2); // 1 → 0 (coming down)

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              child: Transform.translate(
                offset: Offset(0, -bounce * AppSpacing.xxs.h),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.4 + bounce * 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
