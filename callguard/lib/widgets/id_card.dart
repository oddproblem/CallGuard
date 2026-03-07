import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

/// Displays the user's CallGuard ID with copy-to-clipboard and status.
class IdCard extends StatelessWidget {
  final String userId;
  final bool isConnected;
  final Animation<double> revealAnimation;
  final VoidCallback? onCopied;

  const IdCard({
    super.key,
    required this.userId,
    required this.isConnected,
    required this.revealAnimation,
    this.onCopied,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: revealAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: revealAnimation as AnimationController,
          curve: Curves.easeOut,
        )),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: AppGradients.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accent.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fingerprint, color: AppColors.textSecondary, size: 16),
                  const SizedBox(width: 6),
                  Text('YOUR ID', style: AppTextStyles.label),
                ],
              ),
              const SizedBox(height: 16),
              // ID
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: userId));
                  onCopied?.call();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(userId, style: AppTextStyles.idDisplay),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Status pill
              StatusPill(isConnected: isConnected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small animated pill showing Online/Connecting status.
class StatusPill extends StatelessWidget {
  final bool isConnected;
  const StatusPill({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppColors.success : AppColors.warning;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Online' : 'Connecting...',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
