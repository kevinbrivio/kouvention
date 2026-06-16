import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';

/// Hold-to-record button with gesture detection for slide-to-cancel
/// and slide-up-to-lock.
///
/// Uses a single [GestureDetector] for all recording states so the
/// gesture arena stays stable across rebuilds — the finger doesn't
/// need to lift between idle→recording transitions.
///
/// Finger-position computation is widget-side (the VM only learns
/// which threshold was crossed on release — see recap §3.2).
class RecordButton extends StatefulWidget {
  final bool hasText;
  final bool isSending;
  final RecordingState recordingState;
  final bool isRecordingLocked;
  final VoidCallback onSend;
  final VoidCallback onStartRecord;   // long-press path → 'recording' state
  final VoidCallback onStartLockedRecord; // tap path → 'locked' state
  final VoidCallback onLockRecord;   // slide-up during recording
  final VoidCallback onStopRecord;   // stop button when locked
  final VoidCallback onCancelRecord;

  const RecordButton({
    super.key,
    required this.hasText,
    required this.isSending,
    required this.recordingState,
    required this.isRecordingLocked,
    required this.onSend,
    required this.onStartRecord,
    required this.onStartLockedRecord,
    required this.onLockRecord,
    required this.onStopRecord,
    required this.onCancelRecord,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with TickerProviderStateMixin {
  Offset? _fingerOffset;
  Offset? _longPressDownPosition;
  AnimationController? _pulseController;

  static const double _lockThreshold = -35.0;

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

  bool get _isInCancelZone {
    if (_fingerOffset == null) return false;
    final renderBox = context.findRenderObject() as RenderBox?;
    final cancelThreshold = (renderBox?.size.width ?? 100) * 0.2;
    return _fingerOffset!.dx < -cancelThreshold;
  }

  bool get _isInLockZone {
    if (_fingerOffset == null) return false;
    return _fingerOffset!.dy < _lockThreshold;
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
    widget.onStartRecord();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (widget.recordingState != RecordingState.recording) return;
    // Compute offset from initial press position
    if (_longPressDownPosition != null) {
      final delta = details.localPosition - _longPressDownPosition!;
      setState(() => _fingerOffset = delta);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (widget.recordingState != RecordingState.recording) return;
    // Compute offset from initial press position
    Offset delta = Offset.zero;
    if (_longPressDownPosition != null) {
      delta = details.localPosition - _longPressDownPosition!;
    }
    if (delta.dy < _lockThreshold) {
      widget.onLockRecord();
    } else {
      widget.onCancelRecord();
    }
    setState(() {
      _fingerOffset = null;
      _longPressDownPosition = null;
    });
  }

  void _onLongPressCancel() {
    if (widget.recordingState != RecordingState.recording) return;
    widget.onCancelRecord();
    setState(() {
      _fingerOffset = null;
      _longPressDownPosition = null;
    });
  }

  // ── Build ──

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

    // ── Idle / Recording ──
    // Single GestureDetector handles both states so the arena stays alive
    // across the idle→recording transition.
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

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse ring during recording
        if (isRecording && _pulseController != null)
          FadeTransition(
            opacity: Tween<double>(begin: 0.3, end: 0.8)
                .animate(_pulseController!),
            child: Container(
              width: size + 10,
              height: size + 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isInCancelZone
                      ? Colors.orange.shade400
                      : _isInLockZone
                          ? Colors.green.shade400
                          : Colors.red,
                  width: 3,
                ),
              ),
            ),
          ),
        // Main circle
        Container(
          width: isRecording ? size + 4 : size,
          height: isRecording ? size + 4 : size,
          decoration: BoxDecoration(
            color: isRecording
                ? (_isInCancelZone
                    ? Colors.orange.shade400
                    : Colors.red.shade400)
                : widget.hasText
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              isRecording
                  ? Icons.mic
                  : widget.hasText
                      ? Icons.send
                      : Icons.mic,
              size: AppSizing.iconMd.r,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ],
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
      width: size,
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
