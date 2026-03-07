import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

/// Mute, speaker, and end-call action buttons for the call screen.
class CallActions extends StatelessWidget {
  final bool isMuted;
  final bool isSpeaker;
  final bool showControls;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;

  const CallActions({
    super.key,
    required this.isMuted,
    required this.isSpeaker,
    required this.showControls,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showControls)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionCircle(
                  icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: isMuted ? 'Unmute' : 'Mute',
                  isActive: isMuted,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onToggleMute();
                  },
                ),
                _ActionCircle(
                  icon: isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                  label: 'Speaker',
                  isActive: isSpeaker,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onToggleSpeaker();
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 48),
        // End call
        GestureDetector(
          onTap: onEndCall,
          child: Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              gradient: AppGradients.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withOpacity(0.4),
                  blurRadius: 20, spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('End Call', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? AppColors.accent.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive ? AppColors.accent : Colors.white60,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.accent.withOpacity(0.8) : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
