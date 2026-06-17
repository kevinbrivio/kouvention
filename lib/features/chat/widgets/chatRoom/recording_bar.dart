import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/custom_divider.dart';
import 'package:kouvention/features/chat/viewmodel/audio_manager.dart';
import 'package:kouvention/features/chat/widgets/chatRoom/waveform_painter.dart';

class RecordingBar extends StatefulWidget {
  final bool isReviewing;
  final int recordingDuration;
  final List<double> amplitudeSamples;
  final String? filePath;
  final VoidCallback onCancel;
  final VoidCallback? onPause;
  final VoidCallback onSend;

  const RecordingBar({
    super.key,
    required this.isReviewing,
    this.recordingDuration = 0,
    this.amplitudeSamples = const [],
    this.filePath,
    required this.onCancel,
    this.onPause,
    required this.onSend,
  });

  @override
  State<RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<RecordingBar> {
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
  void didUpdateWidget(RecordingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isReviewing && oldWidget.isReviewing) {
      AudioManager.instance.stop();
      _isPlaying = false;
    }
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    AudioManager.instance.stop();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final path = widget.filePath;
    if (path == null || path.isEmpty) return;
    if (_isPlaying) {
      await AudioManager.instance.pause();
    } else {
      await AudioManager.instance.play('file://$path');
    }
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.xs.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isReviewing)
            _buildReviewTopRow(theme)
          else
            _buildRecordingTopRow(context, theme),
          Gap(AppSpacing.xs.h),
          _buildBottomRow(theme),
        ],
      ),
    );
  }

  Widget _buildRecordingTopRow(BuildContext context, ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _formatDuration(widget.recordingDuration),
        style: context.text.labelLarge.copyWith(color: Colors.red.shade400),
      ),

      CustomDivider(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
      ),
    ],
  );

  Widget _buildReviewTopRow(ThemeData theme) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: AppSpacing.md.w,
        height: AppSpacing.md.h,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: theme.colorScheme.primary,
            size: AppSizing.iconMd.r,
          ),
          onPressed: _togglePlay,
        ),
      ),
      Gap(AppSpacing.md.w),
      Expanded(
        child: SizedBox(
          height: AppSizing.inputHeight.h,
          child: CustomPaint(
            painter: WaveformPainter(
              samples: widget.amplitudeSamples,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
      Gap(AppSpacing.md.w),

      Text(
        _formatDuration(widget.recordingDuration),
        style: context.text.labelMedium.copyWith(
          color: context.text.tertiaryText,
        ),
      ),
    ],
  );

  Widget _buildBottomRow(ThemeData theme) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Cancel trash button
      SizedBox(
        width: AppSizing.iconSm.r,
        height: AppSizing.iconSm.r,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          onPressed: widget.onCancel,
        ),
      ),
      // Center button
      SizedBox(
        width: AppSizing.iconSm.r,
        height: AppSizing.iconSm.r,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            widget.isReviewing ? Icons.mic : Icons.pause,
            color: widget.isReviewing
                ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                : theme.colorScheme.primary,
          ),
          onPressed: widget.isReviewing ? null : widget.onPause,
        ),
      ),
      // Send button
      SizedBox(
        width: AppSizing.iconSm.r,
        height: AppSizing.iconSm.r,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
          onPressed: widget.onSend,
        ),
      ),
    ],
  );
}
