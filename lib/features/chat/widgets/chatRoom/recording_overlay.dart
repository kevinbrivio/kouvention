import 'package:flutter/material.dart';

/// Overlay shown during voice recording (before locking).
/// Displays slide hints and a pulsing red dot.
class RecordingOverlay extends StatefulWidget {
  final bool isLocked;
  final Offset fingerOffset;

  const RecordingOverlay({
    super.key,
    required this.isLocked,
    this.fingerOffset = Offset.zero,
  });

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cancelActive = widget.fingerOffset.dx < -20;
    final lockActive = widget.fingerOffset.dy < -20;

    return Container(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulse dot
          FadeTransition(
            opacity: Tween<double>(begin: 0.3, end: 1.0)
                .animate(_pulseController),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Hint text
          Text(
            widget.isLocked
                ? 'Recording locked'
                : cancelActive
                    ? 'Release to cancel'
                    : lockActive
                        ? 'Slide up to lock'
                        : 'Slide ← cancel · Slide ↑ lock',
            style: TextStyle(
              color: cancelActive
                  ? Colors.orange.shade400
                  : lockActive
                      ? Colors.green.shade400
                      : Colors.red.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
