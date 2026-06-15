import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class BubblePainter extends CustomPainter {
  final Color color;
  final double radius;
  final double nubSize;

  BubblePainter({
    required this.color,
    this.radius = 16,
    this.nubSize = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
  
    final path = Path();
    final bodyBottom = size.height - nubSize;
  
    // 1. Top-left corner
    path.moveTo(radius, 0);
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
  
    // 2. Right side down
    path.lineTo(size.width, bodyBottom - radius);
    path.quadraticBezierTo(size.width, bodyBottom, size.width - radius, bodyBottom);
  
    // 3. Bottom edge → nub pointing down-left
    path.lineTo(nubSize * 2 + radius, bodyBottom);
    path.lineTo(nubSize, size.height);          // nub tip
    path.lineTo(radius, bodyBottom);
  
    // 4. Bottom-left corner
    path.quadraticBezierTo(0, bodyBottom, 0, bodyBottom - radius);
  
    // 5. Left side up to start
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
  
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BubblePainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      nubSize != oldDelegate.nubSize;
}

class BubbleContainer extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;

  const BubbleContainer({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: BubblePainter(
      color: color ?? AppColorTokens.primaryLighter.withValues(alpha: 0.08),
      radius: AppRadius.lg.r,
      nubSize: AppRadius.sm.r,
    ),
    child: Padding(
      // Extra top padding to account for the nub
      padding: padding.copyWith(top: padding.top, bottom: padding.bottom + AppRadius.sm.r),
      child: child,
    ),
  );
}
