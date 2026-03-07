import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

/// Dialog shown when receiving a call while already on one.
class CallWaitingDialog extends StatelessWidget {
  final String callerId;
  final String currentCallId;
  final VoidCallback onReject;
  final VoidCallback onSwitch;

  const CallWaitingDialog({
    super.key,
    required this.callerId,
    required this.currentCallId,
    required this.onReject,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_callback, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Incoming Call', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            callerId,
            style: AppTextStyles.idDisplaySmall.copyWith(
              color: AppColors.accent, fontSize: 28, letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are on a call with $currentCallId',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.only(bottom: 16),
      actions: [
        _ActionButton(
          icon: Icons.call_end,
          label: 'Reject',
          color: AppColors.error,
          onTap: () {
            HapticFeedback.mediumImpact();
            onReject();
          },
        ),
        _ActionButton(
          icon: Icons.swap_calls,
          label: 'Switch',
          color: AppColors.warning,
          onTap: () {
            HapticFeedback.mediumImpact();
            onSwitch();
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
