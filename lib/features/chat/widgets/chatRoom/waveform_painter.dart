import 'dart:math';
import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  WaveformPainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
  
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
  
    final barCount = (size.width / 6).floor();
    if (barCount == 0) return;
   
    final recentSamples = samples.length > barCount
        ? samples.sublist(samples.length - barCount)  
        : samples;
  
    for (int i = 0; i < recentSamples.length; i++) {
      final amp = recentSamples[i].clamp(0.0, 1.0);
  
      final barHeight = amp * size.height * 0.8;
      final barHeightClamped = max(4.0, barHeight);
  
      final barWidth = size.width / barCount;
      final x = i * barWidth + barWidth / 2;
  
      canvas.drawLine(
        Offset(x, (size.height - barHeightClamped) / 2),
        Offset(x, (size.height + barHeightClamped) / 2), 
        paint,
      );
    }
  }

  // 🔧 Fix #3: Cek sample TERAKHIR untuk repaint
  @override
  bool shouldRepaint(covariant WaveformPainter old) {
    if (old.color != color) return true;
    if (old.samples.length != samples.length) return true;
    if (samples.isEmpty) return false;
    return old.samples.last != samples.last;
  }
}