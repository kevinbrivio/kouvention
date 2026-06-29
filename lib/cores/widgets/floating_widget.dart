import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class FloatingWidget extends StatefulWidget {
  const FloatingWidget({super.key, required this.child});
  final Widget child;

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true); // goes up then down, forever

    _animation =
        Tween<double>(
          begin: -10, // floats 10px up
          end: 10, // floats 10px down
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut, // smooth, natural feel
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose(); // always dispose!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, _animation.value), // only moves vertically
      child: child,
    ),
    child: Padding(
      padding: EdgeInsetsGeometry.all(AppSpacing.md.w),
      child: widget.child,
    ),
  );
}
