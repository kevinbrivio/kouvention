import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ThemeIrisOverlay extends StatefulWidget {
  final Widget child;
  final ui.Image? snapshotImage;
  final VoidCallback onComplete;

  const ThemeIrisOverlay({
    super.key,
    required this.child,
    required this.snapshotImage,
    required this.onComplete,
  });

  @override
  State<ThemeIrisOverlay> createState() => _ThemeIrisOverlayState();
}

class _ThemeIrisOverlayState extends State<ThemeIrisOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _radiusFraction;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _radiusFraction = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.addListener(_onAnimating);
    if (widget.snapshotImage != null) _controller.forward();
  }

  @override
  void didUpdateWidget(ThemeIrisOverlay old) {
    super.didUpdateWidget(old);
    if (widget.snapshotImage != null && old.snapshotImage == null) {
      _completed = false;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimating);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimating() {
    if (_controller.isCompleted && !_completed) {
      _completed = true;
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.snapshotImage == null) return widget.child;
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 3;

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _radiusFraction,
          builder: (context, _) {
            final radius = _radiusFraction.value * maxRadius;
            return ClipPath(
              clipper: _IrisClipper(radius, center),
              child: RawImage(
                image: widget.snapshotImage,
                width: size.width,
                height: size.height,
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _IrisClipper extends CustomClipper<Path> {
  final double radius;
  final Offset center;

  _IrisClipper(this.radius, this.center);

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_IrisClipper old) =>
      old.radius != radius || old.center != center;
}
