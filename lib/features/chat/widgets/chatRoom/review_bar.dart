import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kouvention/features/chat/viewmodel/audio_manager.dart';

/// Review bar shown after recording is complete.
/// Replaces the text input area entirely.
/// Shows play/pause, waveform, duration, delete, send.
class ReviewBar extends StatefulWidget {
  final String filePath;
  final int durationSeconds;
  final List<double> amplitudeSamples;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  const ReviewBar({
    super.key,
    required this.filePath,
    required this.durationSeconds,
    this.amplitudeSamples = const [],
    required this.onDelete,
    required this.onSend,
  });

  @override
  State<ReviewBar> createState() => _ReviewBarState();
}

class _ReviewBarState extends State<ReviewBar> {
  bool _isPlaying = false;
  StreamSubscription? _playerSub;

  @override
  void initState() {
    super.initState();
    _playerSub = AudioManager.instance.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    AudioManager.instance.stop();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      AudioManager.instance.pause();
    } else {
      AudioManager.instance.play('file://${widget.filePath}');
    }
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // Play/Pause button
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                _isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: theme.colorScheme.primary,
                size: 32,
              ),
              onPressed: _togglePlay,
            ),
          ),
          const SizedBox(width: 4),
          // Waveform
          SizedBox(
            width: 100,
            height: 36,
            child: CustomPaint(
              painter: _WaveformPainter(
                samples: widget.amplitudeSamples,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Duration label
          Text(
            _formatDuration(widget.durationSeconds),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          // Delete button
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: widget.onDelete,
            ),
          ),
          const SizedBox(width: 4),
          // Send button
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.send_rounded,
                color: theme.colorScheme.primary,
              ),
              onPressed: widget.onSend,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  _WaveformPainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final barCount = (size.width / 4).floor();
    if (barCount == 0) return;

    final step = max(1, samples.length ~/ barCount);

    for (int i = 0; i < barCount; i++) {
      final idx = i * step;
      if (idx >= samples.length) break;

      final amp = samples[idx].clamp(0.0, 1.0);
      final barHeight = amp * size.height * 0.8;
      final barHeightClamped = max(2.0, barHeight);

      final x = i * (size.width / barCount) + (size.width / barCount / 2);

      canvas.drawLine(
        Offset(x, (size.height - barHeightClamped) / 2),
        Offset(x, (size.height + barHeightClamped) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.samples != samples || old.color != color;
}
