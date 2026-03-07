import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/call_state.dart';

/// Animated status indicator for the call screen.
class CallStatusPill extends StatelessWidget {
  final CallStatus status;
  final int seconds;
  final Animation<double> pulseAnimation;

  const CallStatusPill({
    super.key,
    required this.status,
    required this.seconds,
    required this.pulseAnimation,
  });

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$secs';
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final text = status.isActive ? _formatDuration(seconds) : status.label;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.isRinging) _PulsingDot(color: color, animation: pulseAnimation),
          if (status.isActive) _PulsingDot(color: color, animation: pulseAnimation),
          if (status.isTerminal) Icon(Icons.error_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: status.isActive ? 3 : 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    if (status.isActive) return AppColors.success;
    if (status.isTerminal) return AppColors.error;
    if (status == CallStatus.reconnecting) return Colors.amberAccent;
    return AppColors.warning;
  }
}

class _PulsingDot extends StatelessWidget {
  final Color color;
  final Animation<double> animation;

  const _PulsingDot({required this.color, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6 + animation.value * 0.4),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4)],
          ),
        );
      },
    );
  }
}
