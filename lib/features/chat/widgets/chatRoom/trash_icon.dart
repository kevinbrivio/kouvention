import 'package:flutter/material.dart';

class TrashIcon extends StatefulWidget {
  final double size;
  final Color color;
  final bool isActive;
  
  const TrashIcon({
    super.key,
    required this.size,
    required this.color,
    required this.isActive,
  });

  @override
  State<TrashIcon> createState() => _TrashIconState();
}

class _TrashIconState extends State<TrashIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _lidAngle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _lidAngle = TweenSequence([
      TweenSequenceItem(
        tween:
            Tween(begin: 0.0, end: -0.7)
                .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -0.7,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(TrashIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double w = widget.size;
    final double h = widget.size * 1.1;

    return AnimatedBuilder(
      animation: _lidAngle,
      builder: (context, _) => SizedBox(
        width: w,
        height: h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 0,
              child: CustomPaint(
                size: Size(w * 0.75, h * 0.65),
                painter: _TrashBodyPainter(color: widget.color),
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform(
                  // Pivot = pojok kiri bawah tutup
                  alignment: Alignment.bottomLeft,
                  transform: Matrix4.rotationZ(_lidAngle.value),
                  child: CustomPaint(
                    size: Size(w * 0.85, h * 0.18),
                    painter: _TrashLidPainter(color: widget.color),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashBodyPainter extends CustomPainter {
  final Color color;
  _TrashBodyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.1, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.9, 0)
      ..close();
    canvas.drawPath(path, paint);

    for (int i = 1; i <= 3; i++) {
      final x = size.width * (i / 4.0);
      canvas.drawLine(
        Offset(x, size.height * 0.2),
        Offset(x, size.height * 0.8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrashBodyPainter old) => old.color != color;
}

class _TrashLidPainter extends CustomPainter {
  final Color color;
  _TrashLidPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, paint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.35,
          0,
          size.width * 0.3,
          size.height * 0.45,
        ),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TrashLidPainter old) => old.color != color;
}
