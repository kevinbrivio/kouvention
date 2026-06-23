import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';

class RecordButton extends StatefulWidget {
  final bool hasText;
  final bool isSending;
  final RecordingState recordingState;
  final VoidCallback onSend;
  final VoidCallback onStartRecord; // long-press path → 'recording' state
  final VoidCallback onStartLockedRecord; // tap path → 'locked' state
  final VoidCallback onLockRecord; // slide-up during recording
  final VoidCallback onStopRecord; // stop button when locked
  final VoidCallback onCancelRecord;
  final ValueChanged<Offset>? onFingerOffsetChanged;

  const RecordButton({
    super.key,
    required this.hasText,
    required this.isSending,
    required this.recordingState,
    required this.onSend,
    required this.onStartRecord,
    required this.onStartLockedRecord,
    required this.onLockRecord,
    required this.onStopRecord,
    required this.onCancelRecord,
    this.onFingerOffsetChanged,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with TickerProviderStateMixin {
  Offset? _fingerOffset;
  Offset? _longPressDownPosition;
  AnimationController? _pulseController;

  static const double _lockThresholdPx = -35.0;
  static const double _cancelThresholdPx = -20.0;

  @override
  void initState() {
    super.initState();
    if (widget.recordingState == RecordingState.recording) {
      _initPulse();
    }
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recordingState == RecordingState.recording &&
        oldWidget.recordingState != RecordingState.recording) {
      _initPulse();
    } else if (widget.recordingState != RecordingState.recording &&
        oldWidget.recordingState == RecordingState.recording) {
      _disposePulse();
    }
  }

  @override
  void dispose() {
    _disposePulse();
    super.dispose();
  }

  void _initPulse() {
    _pulseController?.dispose();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  void _disposePulse() {
    _pulseController?.stop();
    _pulseController?.dispose();
    _pulseController = null;
  }

  bool get _isInLockZone {
    if (_fingerOffset == null) return false;
    return _fingerOffset!.dy < _lockThresholdPx;
  }

  bool get _isInCancelZone {
    if (_fingerOffset == null) return false;
    return _fingerOffset!.dx < _cancelThresholdPx;
  }

  // ── Unified gesture handler ──

  void _onTap() {
    if (widget.recordingState != RecordingState.idle) return;
    if (widget.isSending) return;
    if (widget.hasText) {
      widget.onSend();
    } else {
      widget.onStartLockedRecord();
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.recordingState != RecordingState.idle) return;
    if (widget.hasText) return;
    _longPressDownPosition = details.localPosition;
    setState(() => _fingerOffset = Offset.zero);
    widget.onFingerOffsetChanged?.call(Offset.zero);
    widget.onStartRecord();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (widget.recordingState != RecordingState.recording) return;
    // Compute offset from initial press position
    if (_longPressDownPosition != null) {
      final delta = details.localPosition - _longPressDownPosition!;
      setState(() => _fingerOffset = delta);
      widget.onFingerOffsetChanged?.call(delta);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (widget.recordingState != RecordingState.recording) return;
    // Compute offset from initial press position
    Offset delta = Offset.zero;
    if (_longPressDownPosition != null) {
      delta = details.localPosition - _longPressDownPosition!;
    }
    if (delta.dy < _lockThresholdPx) {
      widget.onLockRecord();
    } else {
      widget.onCancelRecord();
    }
    setState(() {
      _fingerOffset = null;
      _longPressDownPosition = null;
    });
    widget.onFingerOffsetChanged?.call(delta);
  }

  void _onLongPressCancel() {
    if (widget.recordingState != RecordingState.recording) return;
    widget.onCancelRecord();
    setState(() {
      _fingerOffset = null;
      _longPressDownPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = AppSizing.chatInputBarMin.h;

    // Sending spinner
    if (widget.isSending) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: SizedBox(
            width: AppSizing.iconMd.r,
            height: AppSizing.iconMd.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      );
    }

    // Locked controls
    if (widget.recordingState == RecordingState.locked) {
      return _LockedControls(
        size: size,
        onStop: widget.onStopRecord,
        onCancel: widget.onCancelRecord,
      );
    }

    // Reviewing placeholder
    if (widget.recordingState == RecordingState.reviewing) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            Icons.mic,
            size: AppSizing.iconMd.r,
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _onTap,
      onLongPressStart: widget.hasText ? null : _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      behavior: HitTestBehavior.opaque,
      child: _buildContent(theme, size),
    );
  }

  Widget _buildContent(ThemeData theme, double size) {
    final isRecording = widget.recordingState == RecordingState.recording;
    final double safeLimit = (size / 2) - (AppSizing.iconMd.r / 2);

    // Hitung dulu offset mentah
    double rawX = isRecording ? _fingerOffset!.dx * 0.8 : 0.0;
    double rawY = isRecording ? _fingerOffset!.dy * 0.8 : 0.0;

    // Batasi hanya ke atas dan kiri
    rawX = rawX.clamp(-safeLimit, 0.0);
    rawY = rawY.clamp(-safeLimit, 0.0);

    // Hitung jarak diagonal
    final double distance = (Offset(rawX, rawY)).distance;

    // Kalau diagonal melebihi safeLimit, scale down keduanya
    double iconOffsetX = rawX;
    double iconOffsetY = rawY;

    if (distance > safeLimit) {
      final double scale = safeLimit / distance;
      iconOffsetX = rawX * scale;
      iconOffsetY = rawY * scale;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (isRecording)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              top: -96.h,
              child:
                  Container(
                        padding: EdgeInsets.all(AppSpacing.xs.r),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.full.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: AppSizing.iconMd.r,
                          color: _isInLockZone
                              ? AppColorTokens.primary
                              : AppColorTokens.info,
                        ),
                      )
                      .animate(target: _isInLockZone ? 1 : 0)
                      .shake(duration: 500.ms, curve: Curves.easeOutQuad)
                      .shakeY(duration: 500.ms, curve: Curves.easeInBack),
            ),

          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _isInLockZone || _isInCancelZone
                  ? Colors.transparent
                  : isRecording
                  ? AppColorTokens.error
                  : theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  transform: Matrix4.translationValues(
                    iconOffsetX,
                    iconOffsetY,
                    0,
                  ),
                  child:
                      Icon(
                            isRecording
                                ? Icons.mic
                                : widget.hasText
                                ? Icons.send
                                : Icons.mic,
                            size: AppSizing.iconMd.r,
                            color: _isInLockZone || _isInCancelZone
                                ? AppColorTokens.primary
                                : theme.colorScheme.onPrimary,
                          )
                          .animate(target: iconOffsetX < -10.w ? 1 : 0)
                          .rotate(
                            begin: 0,
                            end: -0.25,
                            duration: 200.ms,
                            curve: Curves.easeOut,
                          )
                          .animate(target: iconOffsetX < -80.w ? 1 : 0)
                          .rotate(begin: 0, end: 0.25, curve: Curves.easeIn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline stop + X controls shown when recording is locked.
class _LockedControls extends StatelessWidget {
  final double size;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _LockedControls({
    required this.size,
    required this.onStop,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 8,
      height: size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stop button
          GestureDetector(
            onTap: onStop,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.stop, color: Colors.white, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // X cancel button
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
