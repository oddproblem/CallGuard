import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

/// Full-screen incoming call dialog.
class IncomingCallDialog extends StatelessWidget {
  final String callerId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallDialog({
    super.key,
    required this.callerId,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.accentPurple,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 20, spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                callerId.isNotEmpty ? callerId[0] : '?',
                style: const TextStyle(
                  color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Incoming Call', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Text(
            callerId,
            style: AppTextStyles.idDisplaySmall.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircleButton(
                icon: Icons.call_end_rounded,
                label: 'Reject',
                gradient: AppGradients.error,
                color: AppColors.error,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onReject();
                },
              ),
              _CircleButton(
                icon: Icons.call_rounded,
                label: 'Accept',
                gradient: AppGradients.success,
                color: AppColors.success,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onAccept();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
