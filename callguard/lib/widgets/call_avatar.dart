import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/call_state.dart';

/// Pulsing avatar circle displayed on the call screen.
class CallAvatar extends StatelessWidget {
  final String remoteId;
  final CallStatus status;
  final Animation<double> pulseAnimation;

  const CallAvatar({
    super.key,
    required this.remoteId,
    required this.status,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        final glow = status.isActive ? 15.0 : 15.0 + (pulseAnimation.value * 20);
        final scale = status.isActive ? 1.0 : 1.0 + (pulseAnimation.value * 0.05);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: status.isTerminal
                    ? [Colors.red.shade400, Colors.red.shade900]
                    : [AppColors.accent, AppColors.purple],
              ),
              boxShadow: [
                BoxShadow(
                  color: (status.isTerminal ? AppColors.error : AppColors.accent)
                      .withOpacity(0.4),
                  blurRadius: glow,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                remoteId.isNotEmpty ? remoteId[0] : '?',
                style: const TextStyle(
                  color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
